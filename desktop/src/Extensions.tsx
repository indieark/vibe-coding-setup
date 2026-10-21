import { ImportOptions, type ImportPolicy } from "./ImportOptions";
import { Boxes, CheckCircle2, ChevronRight, Circle, Eraser, Info, ListChecks, ListFilter, MonitorCheck, RefreshCw, Search, Settings2 } from "lucide-react";
import { Toggle } from "./Toggle";
import { ItemKindIcon } from "./ItemKindIcon";
import {
  componentStatus,
  extensionKinds,
  resolveComponents,
} from "./extension-state.mjs";

export type ExtensionItem = {
  id: string;
  kind: "profile" | "skill" | "mcp" | "cli";
  name: string;
  description: string;
  skills: string[];
  mcp: string[];
  requires: string[];
  installed: boolean | null;
  updateAvailable: boolean;
  targets: string[];
};
export type ExtensionCatalog = {
  items: ExtensionItem[];
  checkedAt: string;
  stale?: boolean;
};

export function Extensions({
  catalog,
  selected,
  onSelect,
  busy,
  reload,
  policy,
  onPolicy,
  view,
  onView,
  componentRows,
}: {
  catalog: ExtensionCatalog | null;
  selected: string[];
  onSelect: (ids: string[]) => void;
  busy: boolean;
  reload: (refresh?: boolean) => void;
  policy: ImportPolicy;
  onPolicy: (policy: ImportPolicy) => void;
  view: { kind: ExtensionItem["kind"]; search: string; focus: string };
  onView: (view: {
    kind: ExtensionItem["kind"];
    search: string;
    focus: string;
  }) => void;
  componentRows: Record<string, any>;
}) {
  const { kind, search, focus } = view;
  const setKind = (kind: ExtensionItem["kind"]) => onView({ ...view, kind });
  const setSearch = (search: string) => onView({ ...view, search });
  const setFocus = (focus: string) => onView({ ...view, focus });
  const items = catalog?.items || [];
  const resolved = resolveComponents(items, selected);
  const rows = items.filter(
    (item) =>
      item.kind === kind &&
      `${item.name} ${item.description}`
        .toLowerCase()
        .includes(search.toLowerCase()),
  );
  const detail = items.find((item) => item.id === focus);
  return (
    <div className="setup-grid extensions-grid">
      <section className="panel extension-list">
        <div className="panel-heading">
          <h2>
            <Boxes size={17} />
            扩展组件<span className="count">{selected.length}</span>
          </h2>
          <button
            className="text-button"
            disabled={busy}
            onClick={() => reload(true)}
          >
            <RefreshCw size={14} />
            更新清单
          </button>
        </div>
        <div className="extension-toolbar">
          <div className="kind-tabs" aria-label="组件类型">
            {Object.entries(extensionKinds).map(([key, label]) => (
              <button
                key={key}
                className={kind === key ? "active" : ""}
                aria-pressed={kind === key}
                onClick={() => setKind(key as ExtensionItem["kind"])}
              >
                <ItemKindIcon kind={key} />
                {label}
                <span>{items.filter((item) => item.kind === key).length}</span>
              </button>
            ))}
          </div>
          <label className="extension-search">
            <Search size={15} />
            <input
              aria-label="搜索扩展组件"
              placeholder="搜索名称或用途"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </label>
        </div>
        <div className="selection-actions">
          <button
            className="text-button"
            disabled={busy || !rows.length}
            onClick={() =>
              onSelect([
                ...new Set([...selected, ...rows.map((item) => item.id)]),
              ])
            }
          >
            <ListFilter size={14} aria-hidden="true" />
            选择筛选结果（{rows.length}）
          </button>
          <button
            className="text-button"
            disabled={busy || !catalog}
            onClick={() =>
              onSelect([
                ...new Set([
                  ...selected,
                  ...items
                    .filter((item) => item.kind === "skill")
                    .map((item) => item.id),
                ]),
              ])
            }
          >
            <ItemKindIcon kind="skill" size={14} />
            全部 Skills
          </button>
          <button
            className="text-button"
            disabled={busy || !catalog}
            onClick={() =>
              onSelect([
                ...new Set([
                  ...selected,
                  ...items
                    .filter((item) => item.kind === "profile")
                    .map((item) => item.id),
                ]),
              ])
            }
          >
            <ItemKindIcon kind="profile" size={14} />
            全部套件
          </button>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th className="check-col" />
                <th><span className="field-label"><ListChecks size={14} aria-hidden="true" />名称与用途</span></th>
                <th><span className="field-label"><MonitorCheck size={14} aria-hidden="true" />本机状态</span></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((item) => {
                const explicit = selected.includes(item.id);
                const included =
                  item.kind !== "profile" &&
                  resolved[item.kind].includes(item.name);
                const result = componentRows[item.id];
                const resultLabels: Record<string, string> = {
                  ok: "已完成",
                  preview: "演练完成",
                  failed: "失败",
                  skipped: "已跳过",
                  warning: "有提示",
                  manual: "需手动处理",
                  running: "处理中",
                };
                const [status, label] = result
                  ? [
                      result.Status,
                      resultLabels[result.Status] || result.Status,
                    ]
                  : componentStatus(item, catalog?.stale);
                return (
                  <tr
                    key={item.id}
                    className={
                      "selectable-row " +
                      (focus === item.id ? "focused-row" : "")
                    }
                    onClick={(event) => {
                      if (!(event.target as Element).closest("button")) {
                        setFocus(item.id);
                        if (!busy && (!included || explicit))
                          onSelect(
                            explicit
                              ? selected.filter((id) => id !== item.id)
                              : [...selected, item.id],
                          );
                      }
                    }}
                  >
                    <td>
                      <Toggle
                        label={"选择 " + item.name}
                        checked={explicit || included}
                        disabled={busy || (included && !explicit)}
                        onChange={() =>
                          onSelect(
                            explicit
                              ? selected.filter((id) => id !== item.id)
                              : [...selected, item.id],
                          )
                        }
                      />
                    </td>
                    <td>
                      <button
                        className="component-name"
                        aria-pressed={explicit || included}
                        disabled={busy}
                        onClick={() => {
                          setFocus(item.id);
                          if (!included || explicit)
                            onSelect(
                              explicit
                                ? selected.filter((id) => id !== item.id)
                                : [...selected, item.id],
                            );
                        }}
                      >
                        <span className="component-title">{item.name}</span>
                        <span className="app-purpose">
                          {included && !explicit ? "由套件或依赖包含 · " : ""}
                          {item.description ||
                            (item.kind === "skill"
                              ? "按需扩展 AI 工作能力"
                              : "按需安装")}
                        </span>
                      </button>
                    </td>
                    <td>
                      <div className="component-state">
                        <span className={"status " + status}>
                          {status === "ok" ? (
                            <CheckCircle2 size={13} />
                          ) : (
                            <Circle size={10} />
                          )}
                          {label}
                        </span>
                        <button
                          className="text-button detail-button"
                          onClick={() => setFocus(item.id)}
                          aria-label={"查看 " + item.name + " 详情"}
                        >
                          <Info size={13} aria-hidden="true" />
                          详情
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              {!rows.length && (
                <tr>
                  <td className="loading" colSpan={3}>
                    {!catalog ? (
                      busy ? (
                        "正在读取扩展清单与本机状态…"
                      ) : (
                        <button
                          className="text-button"
                          onClick={() => reload()}
                        >
                          加载扩展清单
                        </button>
                      )
                    ) : (
                      "没有匹配的组件"
                    )}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        <div className="software-footer">
          <span>
            {catalog
              ? catalog.stale
                ? "状态来自安装前检查"
                : "检查于 " + catalog.checkedAt
              : "首次打开时下载公开扩展包"}
          </span>
          <button
            className="button secondary compact"
            disabled={busy}
            onClick={() => reload()}
          >
            <RefreshCw size={14} />
            检查状态
          </button>
        </div>
      </section>
      <aside className="panel extension-summary">
        <div className="panel-heading">
          <h2><ListChecks size={17} aria-hidden="true" />本次选择</h2>
          <button
            className="text-button"
            disabled={busy || !selected.length}
            onClick={() => onSelect([])}
          >
            <Eraser size={14} aria-hidden="true" />
            清空
          </button>
        </div>
        <div className="extension-detail-scroll">
          {detail && (
            <section className="component-detail">
              <h3><ItemKindIcon kind={detail.kind} />{detail.name}</h3>
              <p>{detail.description || "按需安装的扩展组件"}</p>
              {detail.skills.length > 0 && (
                <details>
                  <summary><ChevronRight className="disclosure-chevron" size={14} aria-hidden="true" /><ItemKindIcon kind="skill" />包含 {detail.skills.length} 个 Skills</summary>
                  <ul className="name-list">
                    {detail.skills.map((name) => (
                      <li key={name}>{name}</li>
                    ))}
                  </ul>
                </details>
              )}
              {detail.mcp.length > 0 && <p className="detail-property"><ItemKindIcon kind="mcp" /><span>MCP：{detail.mcp.join("、")}</span></p>}
              <p className="detail-property"><ItemKindIcon kind="cli" /><span>CLI 依赖：{detail.requires.join("、") || "无"}</span></p>
              {detail.targets.length > 0 && (
                <p className="detail-property"><Settings2 size={15} aria-hidden="true" /><span>已有配置：{detail.targets.join("、")}</span></p>
              )}
            </section>
          )}
          {!selected.length && (
            <p className="field-note">
              选择套件或单项组件；所需依赖会自动合并。
            </p>
          )}
          {(["skill", "mcp", "cli"] as const).map((key) => (
            <details
              className="selection-group"
              key={key}
              open={resolved[key].length > 0 && resolved[key].length <= 6}
            >
              <summary>
                <ChevronRight className="disclosure-chevron" size={14} aria-hidden="true" />
                <ItemKindIcon kind={key} />
                {extensionKinds[key]}{" "}
                <span className="count">{resolved[key].length}</span>
              </summary>
              <ul className="name-list">
                {resolved[key].map((name: string) => (
                  <li key={name}>
                    <span>{name}</span>
                    {selected.includes(`${key}:${name}`) && (
                      <button
                        className="remove-choice"
                        disabled={busy}
                        aria-label={"移除 " + name}
                        onClick={() =>
                          onSelect(
                            selected.filter((id) => id !== `${key}:${name}`),
                          )
                        }
                      >
                        ×
                      </button>
                    )}
                  </li>
                ))}
              </ul>
            </details>
          ))}
          <ImportOptions policy={policy} change={onPolicy} disabled={busy} />
        </div>
      </aside>
    </div>
  );
}
