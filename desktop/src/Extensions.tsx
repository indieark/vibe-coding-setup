import { useState } from "react";
import { Boxes, CheckCircle2, Circle, RefreshCw, Search } from "lucide-react";
import { Toggle } from "./Toggle";
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
}: {
  catalog: ExtensionCatalog | null;
  selected: string[];
  onSelect: (ids: string[]) => void;
  busy: boolean;
  reload: (refresh?: boolean) => void;
}) {
  const [kind, setKind] = useState<ExtensionItem["kind"]>("profile");
  const [search, setSearch] = useState("");
  const [focus, setFocus] = useState("");
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
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th className="check-col" />
                <th>名称与用途</th>
                <th>本机状态</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((item) => {
                const explicit = selected.includes(item.id);
                const included =
                  item.kind !== "profile" &&
                  resolved[item.kind].includes(item.name);
                const [status, label] = componentStatus(item, catalog?.stale);
                return (
                  <tr
                    key={item.id}
                    className={focus === item.id ? "focused-row" : ""}
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
                        onClick={() => setFocus(item.id)}
                      >
                        {item.name}
                      </button>
                      <div className="app-purpose">
                        {included && !explicit ? "由套件或依赖包含 · " : ""}
                        {item.description ||
                          (item.kind === "skill"
                            ? "按需扩展 AI 工作能力"
                            : "点击名称查看详情")}
                      </div>
                    </td>
                    <td>
                      <span className={"status " + status}>
                        {status === "ok" ? (
                          <CheckCircle2 size={13} />
                        ) : (
                          <Circle size={10} />
                        )}
                        {label}
                      </span>
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
          <h2>本次选择</h2>
          <button
            className="text-button"
            disabled={busy || !selected.length}
            onClick={() => onSelect([])}
          >
            清空
          </button>
        </div>
        <div className="extension-detail-scroll">
          {!selected.length && (
            <p className="field-note">
              扩展项默认不安装。可选择一个套件，也可逐项选择 Skills、MCP 或
              CLI。
            </p>
          )}
          {(["skill", "mcp", "cli"] as const).map((key) => (
            <div className="selection-group" key={key}>
              <h3>
                {extensionKinds[key]}
                <span className="count">{resolved[key].length}</span>
              </h3>
              <p>{resolved[key].join("、") || "未选择"}</p>
            </div>
          ))}
          <p className="field-note">
            包含套件成员与所需 CLI。Skills 同步到 Codex
            和已存在的其他工具目录；MCP 写入支持的客户端配置。
          </p>
          <p className="field-note">
            保留来源不明或其他来源的同名
            Skill；更新继续使用原有备份逻辑。无需打开 Skills Manager。
          </p>
          {detail && (
            <div className="component-detail">
              <h3>{detail.name}</h3>
              <p>{detail.description}</p>
              {(detail.kind === "profile" || detail.skills.length > 0) && (
                <>
                  <h4>Skills</h4>
                  <p>{detail.skills.join("、") || "无"}</p>
                </>
              )}
              {detail.kind === "profile" && (
                <>
                  <h4>MCP</h4>
                  <p>{detail.mcp.join("、") || "无"}</p>
                </>
              )}
              <h4>CLI 依赖</h4>
              <p>{detail.requires.join("、") || "无"}</p>
              {detail.targets.length > 0 && (
                <>
                  <h4>已有配置的客户端</h4>
                  <p>{detail.targets.join("、")}</p>
                </>
              )}
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}
