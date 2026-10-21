import React, { useEffect, useReducer, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { invoke, isTauri } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import {
  Boxes,
  CheckCircle2,
  Circle,
  Cpu,
  Download,
  FileDown,
  KeyRound,
  LoaderCircle,
  Link,
  Monitor,
  Play,
  RefreshCw,
  RotateCcw,
  Settings2,
  ShieldCheck,
  Square,
  Terminal,
  Tag,
  XCircle,
} from "lucide-react";
import { describeRow, initialRun, reduceEvent } from "./state.mjs";
import { Toggle } from "./Toggle";
import { TitleBar } from "./TitleBar";
import { AppIcon } from "./AppIcon";
import { Extensions, type ExtensionCatalog } from "./Extensions";
import { defaultPolicy, type ImportPolicy } from "./ImportOptions";
import { resolveComponents } from "./extension-state.mjs";
import { Results, type PlannedItem } from "./Results";
import "./style.css";

type App = { key: string; name: string; defaultInstall?: boolean };
type Provider = {
  name: string;
  baseUrl: string;
  model: string;
  apiKey: string;
};
type Catalog = {
  apps: App[];
  provider: { Name: string; BaseUrl: string; Model: string };
  isAdmin: boolean;
  dryRunOnly: boolean;
};
const purpose: Record<string, string> = {
  git: "版本管理",
  nodejs: "JavaScript 运行环境",
  python: "Python 运行环境",
  vscode: "代码编辑器",
  codex: "AI 编程工作台",
  chatgpt: "日常 AI 助手",
  "cc-switch": "API 与模型配置",
  "skills-manager": "按需管理 Skills",
};
function Setup() {
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [provider, setProvider] = useState<Provider>({
    name: "",
    baseUrl: "",
    model: "",
    apiKey: "",
  });
  const [policy, setPolicy] = useState<ImportPolicy>(defaultPolicy);
  const [providerState, setProviderState] = useState<{
    status: string;
    name: string;
    message?: string;
  }>({ status: "unknown", name: "" });
  const [extensionView, setExtensionView] = useState<{
    kind: "profile" | "skill" | "mcp" | "cli";
    search: string;
    focus: string;
  }>({ kind: "profile", search: "", focus: "" });
  const [planned, setPlanned] = useState<PlannedItem[]>([]);
  const lastSelection = useRef({
    keys: [] as string[],
    ids: [] as string[],
    configure: false,
  });
  const [configure, setConfigure] = useState(true);
  const [busy, setBusy] = useState(false);
  const [stopping, setStopping] = useState(false);
  const [tab, setTab] = useState("setup");
  const [extensions, setExtensions] = useState<ExtensionCatalog | null>(null);
  const [components, setComponents] = useState<string[]>([]);
  const [lastTask, setLastTask] = useState("setup");
  const taskRef = useRef("setup");
  const [notice, setNotice] = useState("");
  const [theme, setTheme] = useState(
    () => localStorage.getItem("setup-theme") || "dark",
  );
  const [run, dispatch] = useReducer(
    (s: any, e: any) => (e.type === "reset" ? initialRun() : reduceEvent(s, e)),
    undefined,
    initialRun,
  );
  const mounted = useRef(true);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem("setup-theme", theme);
  }, [theme]);
  useEffect(() => {
    mounted.current = true;
    let cleanups: (() => void)[] = [];
    async function init() {
      if (!isTauri()) {
        setNotice("浏览器仅预览界面。请通过 bootstrap.cmd 打开桌面安装器。");
        return;
      }
      cleanups = await Promise.all([
        listen("installer", (e) => {
          if (!mounted.current) return;
          const event = e.payload as any;
          if (event.type === "extensions-catalog") {
            setExtensions({ items: event.items, checkedAt: event.checkedAt });
            setComponents((ids) =>
              ids.filter((id) =>
                event.items.some((item: any) => item.id === id),
              ),
            );
          }
          if (
            event.type === "done" &&
            event.results?.some((r: any) => r.Key === "skills-bundle") &&
            !event.dryRun &&
            event.results?.length
          ) {
            setExtensions((current) =>
              current ? { ...current, stale: true } : null,
            );
          }
          dispatch(event);
        }),
        listen("installer-idle", () => {
          if (mounted.current) {
            setBusy(false);
            setStopping(false);
          }
        }),
        listen("installer-close-blocked", () =>
          setNotice(
            "当前任务正在执行。可先停止后续任务，等待当前步骤完成再关闭。",
          ),
        ),
      ]);
      const data = await invoke<Catalog>("get_catalog");
      if (!mounted.current) return;
      setCatalog(data);
      setSelected(
        data.apps.filter((a) => a.defaultInstall !== false).map((a) => a.key),
      );
      setProvider({
        name: data.provider.Name,
        baseUrl: data.provider.BaseUrl,
        model: data.provider.Model,
        apiKey: "",
      });
    }
    init().catch((error) => setNotice(String(error)));
    return () => {
      mounted.current = false;
      cleanups.forEach((fn) => fn());
    };
  }, []);
  const reuseExisting =
    policy.providerMode === "reuse" &&
    providerState.name === provider.name &&
    providerState.status === "exists";
  async function inspectProvider() {
    if (!provider.name.trim() || !isTauri()) return;
    const name = provider.name;
    setProviderState({ status: "loading", name });
    try {
      const result = await invoke<{
        status: string;
        name: string;
        message?: string;
      }>("get_provider", { name });
      setProviderState(result);
    } catch {
      setProviderState({
        status: "unknown",
        name,
        message: "读取失败，可重新检查或选择重新导入",
      });
    }
  }
  useEffect(() => {
    if (!catalog || !provider.name.trim()) return;
    const timer = setTimeout(() => void inspectProvider(), 350);
    return () => clearTimeout(timer);
  }, [catalog, provider.name]);
  const planItems = (
    keys = selected,
    ids = components,
    includeProvider = configure,
  ) => {
    const resolved = resolveComponents(extensions?.items || [], ids);
    const items: PlannedItem[] = keys.map((key) => ({
      Key: key,
      Name: catalog?.apps.find((a) => a.key === key)?.name || key,
      Kind: "app",
    }));
    if (includeProvider)
      items.push({
        Key: "cc-switch-provider",
        Name: "CC Switch Provider",
        Kind: "provider",
      });
    for (const kind of ["skill", "mcp", "cli"] as const)
      for (const name of resolved[kind])
        items.push({ Key: `${kind}:${name}`, Name: name, Kind: kind });
    if (ids.length && policy.scenarioMode !== "skip")
      items.push({
        Key: "scenario:skills-manager",
        Name: "Skills Manager 场景",
        Kind: "scenario",
      });
    return items;
  };
  async function execute(
    dryRun = false,
    keys = selected,
    ids = components,
    includeProvider = configure,
  ) {
    if (busy || !catalog) return;
    dryRun = dryRun || catalog.dryRunOnly;
    setNotice("");
    if (!keys.length && !ids.length && !includeProvider) {
      setNotice("请选择软件、扩展或 API 配置。");
      return;
    }
    if (includeProvider && !reuseExisting) {
      if (
        !provider.name.trim() ||
        !provider.model.trim() ||
        !/^https?:\/\//i.test(provider.baseUrl)
      ) {
        setNotice("请填写 Provider 名称、API 地址和模型。");
        return;
      }
      if (
        !dryRun &&
        !provider.apiKey.trim() &&
        (policy.providerMode === "import" ||
          (providerState.name === provider.name &&
            providerState.status === "missing"))
      ) {
        setNotice("请输入 API Key，或选择复用已有配置。");
        return;
      }
    }
    if (
      ids.length &&
      policy.scenarioMode === "custom" &&
      !policy.scenarioName.trim()
    ) {
      setNotice("请输入 Skills Manager 场景名称。");
      return;
    }
    if (
      ids.length &&
      !dryRun &&
      (policy.orphanPolicy === "backup" ||
        policy.foreignPolicy === "replace") &&
      !policy.replacementConfirmed
    ) {
      setNotice("请在扩展导入设置中确认备份与替换策略。");
      setTab("extensions");
      return;
    }
    if (!dryRun && !catalog.isAdmin) {
      setNotice("真实执行需要管理员权限，请通过启动脚本重新打开。");
      return;
    }
    setBusy(true);
    setStopping(false);
    setLastTask("execute");
    taskRef.current = "execute";
    lastSelection.current = {
      keys: [...keys],
      ids: [...ids],
      configure: includeProvider,
    };
    setPlanned(planItems(keys, ids, includeProvider));
    dispatch({ type: "reset" });
    setTab("logs");
    try {
      await invoke("start_run", {
        plan: {
          mode: "execute",
          appKeys: keys,
          componentIds: ids,
          dryRun,
          configureProvider: includeProvider,
          provider,
          options: policy,
        },
      });
    } catch (error) {
      setBusy(false);
      dispatch({ type: "fatal", message: String(error) });
    }
  }
  async function start(
    mode: "check" | "install",
    dryRun = false,
    keys = selected,
    retryProvider = configure,
  ) {
    if (mode === "install") {
      await execute(dryRun, keys, [], retryProvider);
      return;
    }
    if (busy || !catalog || !keys.length) return;
    setBusy(true);
    setStopping(false);
    setLastTask("check");
    taskRef.current = "check";
    dispatch({ type: "reset" });
    setPlanned([]);
    try {
      await invoke("start_run", {
        plan: {
          mode: "check",
          appKeys: keys,
          dryRun: true,
          configureProvider: false,
          provider: {},
        },
      });
    } catch (error) {
      setBusy(false);
      dispatch({ type: "fatal", message: String(error) });
    }
  }
  async function extensionRun(
    mode: "extensions" | "install-components",
    dryRun = false,
    refreshBundle = false,
  ) {
    if (mode === "install-components") {
      await execute(dryRun, [], components, false);
      return;
    }
    if (busy || !catalog) return;
    setNotice("");
    setBusy(true);
    setStopping(false);
    setLastTask("extension-check");
    taskRef.current = "extension-check";
    dispatch({ type: "reset" });
    setPlanned([]);
    try {
      await invoke("start_run", {
        plan: {
          mode,
          appKeys: [],
          componentIds: [],
          dryRun: true,
          configureProvider: false,
          provider: {},
          refreshBundle,
        },
      });
    } catch (error) {
      setBusy(false);
      dispatch({ type: "fatal", message: String(error) });
    }
  }
  function showExtensions() {
    setTab("extensions");
    if (!extensions && !busy && catalog) void extensionRun("extensions");
  }
  async function retryFailed() {
    const previous = lastSelection.current;
    await execute(
      run.dryRun,
      previous.keys.filter((key) =>
        run.results.some((r: any) => r.Key === key && r.Status === "failed"),
      ),
      run.results.some(
        (r: any) => r.Key === "skills-bundle" && r.Status === "failed",
      )
        ? previous.ids
        : [],
      run.results.some(
        (r: any) => r.Key === "cc-switch-provider" && r.Status === "failed",
      ),
    );
  }
  async function stop() {
    try {
      await invoke("stop_after_current");
      setStopping(true);
    } catch (e) {
      setNotice(String(e));
    }
  }
  async function exportReport() {
    try {
      setNotice("诊断报告已导出：" + (await invoke<string>("export_report")));
    } catch (e) {
      setNotice(String(e));
    }
  }
  const failed = run.results.filter((r: any) => r.Status === "failed");
  const warnings = run.results.flatMap((r: any) => r.Warnings || []);
  const needsConfirmation = run.results.some((r: any) => r.NeedsConfirmation);
  const done = run.phase === "done";
  const title = busy
    ? {
        check: "正在检查环境",
        install: "正在安装软件",
        provider: "正在导入配置",
        extensions: "正在检查扩展组件",
        components: "正在安装扩展组件",
        ready: "正在准备",
      }[run.phase as string] || "正在执行"
    : run.phase === "error"
      ? "任务未完成"
      : done
        ? run.cancelled
          ? "已停止后续任务"
          : failed.length
            ? "部分任务需要处理"
            : needsConfirmation
              ? "请在 CC Switch 中确认导入"
              : warnings.length
                ? "任务完成，有提示需要查看"
                : run.checkedOnly
                  ? "环境检查完成"
                  : run.dryRun
                    ? "安全演练完成"
                    : "本次任务已完成"
        : "准备好你的工作环境";
  return (
    <div className="shell">
      <TitleBar theme={theme} onToggleTheme={() => setTheme(theme === "dark" ? "light" : "dark")} onError={setNotice} />
      <div className="workspace">
        <nav className="navigation" aria-label="安装器导航">
          <button
            className={tab === "setup" ? "active" : ""}
            onClick={() => setTab("setup")}
          >
            <Monitor size={17} />
            软件与配置
          </button>
          <button
            className={tab === "extensions" ? "active" : ""}
            onClick={showExtensions}
          >
            <Settings2 size={17} />
            扩展组件
          </button>
          <button
            className={tab === "logs" ? "active" : ""}
            onClick={() => setTab("logs")}
          >
            <Terminal size={17} />
            计划与结果
            {run.logs.length > 0 && (
              <span className="count">{run.logs.length}</span>
            )}
          </button>
        </nav>
        <main className={"content " + (tab === "extensions" ? "extension-content" : "")}>
          <div className="page-heading">
            <div>
              <h1>
                {!busy && tab === "extensions" ? "按需扩展你的工作环境" : title}
              </h1>
              <p>
                {busy
                  ? stopping
                    ? "当前步骤完成后停止，不会强制中断安装器。"
                    : run.detail || "窗口会持续显示执行结果。"
                  : tab === "extensions"
                    ? "选择需要的套件、Skills、MCP 和 CLI，在这里完成安装。"
                    : "检查、安装并配置常用开发工具。"}
              </p>
            </div>
            <span
              className={"permission " + (catalog?.isAdmin ? "granted" : "")}
            >
              <ShieldCheck size={15} />
              {catalog?.dryRunOnly
                ? "安全演练模式"
                : catalog?.isAdmin
                  ? "管理员权限已启用"
                  : "安全演练可用"}
            </span>
          </div>
          {notice && (
            <div className="notice" role="status">
              <Circle size={15} />
              <span>{notice}</span>
              <button aria-label="关闭提示" onClick={() => setNotice("")}>
                ×
              </button>
            </div>
          )}
          {run.error && (
            <div className="error-banner" role="alert">
              <XCircle size={17} />
              {run.error}
            </div>
          )}
          {tab === "setup" ? (
            <div className="setup-grid">
              <section className="software panel">
                <div className="panel-heading">
                  <h2>
                    <Boxes size={17} />
                    安装软件<span className="count">{selected.length}</span>
                  </h2>
                  <button
                    className="text-button"
                    disabled={busy || !catalog}
                    onClick={() =>
                      setSelected(
                        catalog!.apps
                          .filter((a) => a.defaultInstall !== false)
                          .map((a) => a.key),
                      )
                    }
                  >
                    恢复推荐
                  </button>
                </div>
                <div className="table-scroll">
                  <table>
                    <thead>
                      <tr>
                        <th className="check-col">
                          <Toggle
                            label="全选软件"
                            disabled={busy || !catalog}
                            checked={
                              !!catalog &&
                              selected.length === catalog.apps.length
                            }
                            onChange={() =>
                              setSelected(
                                selected.length === catalog?.apps.length
                                  ? []
                                  : catalog!.apps.map((a) => a.key),
                              )
                            }
                          />
                        </th>
                        <th>软件</th>
                        <th>本机状态</th>
                      </tr>
                    </thead>
                    <tbody>
                      {catalog?.apps.map((app) => {
                        const row = run.rows[app.key];
                        const [kind, label] = describeRow(row);
                        return (
                          <tr
                            key={app.key}
                            onClick={(event) => {
                              if (
                                !busy &&
                                !(event.target as Element).closest("button")
                              )
                                setSelected((s) =>
                                  s.includes(app.key)
                                    ? s.filter((key) => key !== app.key)
                                    : [...s, app.key],
                                );
                            }}
                            className={
                              "selectable-row " +
                              (selected.includes(app.key) ? "" : "unselected")
                            }
                          >
                            <td>
                              <Toggle
                                label={"选择 " + app.name}
                                disabled={busy}
                                checked={selected.includes(app.key)}
                                onChange={() =>
                                  setSelected((s) =>
                                    s.includes(app.key)
                                      ? s.filter((k) => k !== app.key)
                                      : [...s, app.key],
                                  )
                                }
                              />
                            </td>
                            <td>
                              <button
                                type="button"
                                className="app-name app-toggle"
                                disabled={busy}
                                aria-pressed={selected.includes(app.key)}
                                onClick={() =>
                                  setSelected((s) =>
                                    s.includes(app.key)
                                      ? s.filter((key) => key !== app.key)
                                      : [...s, app.key],
                                  )
                                }
                              >
                                  <AppIcon appKey={app.key} />
                                  <span className="app-copy">
                                    <span className="app-label">
                                      {app.name}
                                      {app.defaultInstall === false && (
                                        <span className="optional">可选</span>
                                      )}
                                    </span>
                                    <span className="app-purpose">{purpose[app.key]}</span>
                                  </span>
                              </button>
                            </td>
                            <td>
                              <span className={"status " + kind}>
                                {kind === "running" ? (
                                  <LoaderCircle className="spin" size={13} />
                                ) : kind === "ok" ? (
                                  <CheckCircle2 size={13} />
                                ) : kind === "failed" ? (
                                  <XCircle size={13} />
                                ) : (
                                  <Circle size={10} />
                                )}{" "}
                                {label}
                              </span>
                              {row?.decision && (
                                <div className="version-detail">
                                  检查时：
                                  {row.decision.InstalledVersion ||
                                    (row.decision.Reason === "missing"
                                      ? "未安装"
                                      : "版本未知")}{" "}
                                  →{" "}
                                  {row.decision.DesiredVersion ||
                                    "由安装源提供"}
                                </div>
                              )}
                            </td>
                          </tr>
                        );
                      }) || (
                        <tr>
                          <td colSpan={3} className="loading">
                            {isTauri()
                              ? "正在读取软件清单…"
                              : "请在桌面安装器中读取真实软件状态"}
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
                <div className="software-footer">
                  <span>默认安装不包含 Skills</span>
                  <button
                    className="button secondary compact"
                    disabled={busy || !catalog || !selected.length}
                    onClick={() => start("check")}
                  >
                    <RefreshCw size={14} />
                    检查环境
                  </button>
                </div>
              </section>
              <section className="configuration panel">
                <div className="panel-heading">
                  <h2>
                    <KeyRound size={17} />
                    CC Switch 配置
                  </h2>
                  <Toggle
                    label="导入 CC Switch 配置"
                    checked={configure}
                    disabled={busy}
                    onChange={() => setConfigure(!configure)}
                  />
                </div>
                <div
                  className={
                    "provider-form " + (!configure ? "muted-form" : "")
                  }
                >
                  <label>
                    <span className="field-label"><Tag size={15} aria-hidden="true" />Provider 名称</span>
                    <input
                      name="providerName"
                      disabled={busy || !configure}
                      value={provider.name}
                      onChange={(e) =>
                        setProvider({ ...provider, name: e.target.value })
                      }
                      autoComplete="off"
                    />
                  </label>
                  <div className="provider-state" role="status">
                    <span>
                      {providerState.name !== provider.name
                        ? "等待检查"
                        : (
                            {
                              loading: "正在检查已有配置…",
                              exists: "已找到同名 Provider",
                              missing: "未找到同名 Provider",
                              unknown: "已有配置状态未知",
                            } as Record<string, string>
                          )[providerState.status]}
                    </span>
                    <button
                      className="text-button"
                      disabled={busy || !provider.name.trim()}
                      onClick={() => void inspectProvider()}
                    >
                      <RefreshCw size={14} aria-hidden="true" />
                      重新检查
                    </button>
                  </div>
                  <div className="policy-choices">
                    <button
                      disabled={busy || !configure}
                      aria-pressed={policy.providerMode === "reuse"}
                      className={
                        policy.providerMode === "reuse" ? "chosen" : ""
                      }
                      onClick={() =>
                        setPolicy({ ...policy, providerMode: "reuse" })
                      }
                    >
                      已有则保留
                    </button>
                    <button
                      disabled={busy || !configure}
                      aria-pressed={policy.providerMode === "import"}
                      className={
                        policy.providerMode === "import" ? "chosen" : ""
                      }
                      onClick={() =>
                        setPolicy({ ...policy, providerMode: "import" })
                      }
                    >
                      重新导入
                    </button>
                  </div>
                  {!reuseExisting ? (
                    <>
                      <label>
                        <span className="field-label"><Link size={15} aria-hidden="true" />API 地址</span>
                        <input
                          name="baseUrl"
                          disabled={busy || !configure || reuseExisting}
                          value={provider.baseUrl}
                          onChange={(e) =>
                            setProvider({
                              ...provider,
                              baseUrl: e.target.value,
                            })
                          }
                          spellCheck={false}
                          autoComplete="off"
                        />
                      </label>
                      <label>
                        <span className="field-label"><Cpu size={15} aria-hidden="true" />默认模型</span>
                        <input
                          name="model"
                          disabled={busy || !configure || reuseExisting}
                          value={provider.model}
                          onChange={(e) =>
                            setProvider({ ...provider, model: e.target.value })
                          }
                          spellCheck={false}
                          autoComplete="off"
                        />
                      </label>
                      <label>
                        <span className="field-label"><KeyRound size={15} aria-hidden="true" />API Key</span>
                        <input
                          type="password"
                          name="apiKey"
                          disabled={busy || !configure || reuseExisting}
                          value={provider.apiKey}
                          onChange={(e) =>
                            setProvider({ ...provider, apiKey: e.target.value })
                          }
                          placeholder="输入你的 API Key"
                          autoComplete="off"
                          spellCheck={false}
                        />
                      </label>
                      <p className="field-note">
                        Key 仅用于本次导入，不写入诊断报告。
                      </p>
                    </>
                  ) : (
                    <p className="field-note">
                      保留已有地址、模型和 API Key；选择“重新导入”才使用新参数。
                    </p>
                  )}
                </div>
                <div className="config-footer">
                  <span>
                    {!configure
                      ? "本次保留 API 配置。"
                      : reuseExisting
                        ? "执行时会再次检查，并保留已有 Provider。"
                        : "导入后需在 CC Switch 中确认。"}
                  </span>
                  <button
                    className="button secondary compact"
                    disabled={busy || !catalog || !configure}
                    onClick={() => void execute(false, [], [], true)}
                  >
                    仅处理 API 配置
                  </button>
                </div>
              </section>
            </div>
          ) : tab === "extensions" ? (
            <Extensions
              catalog={extensions}
              selected={components}
              onSelect={setComponents}
              busy={busy}
              policy={policy}
              onPolicy={setPolicy}
              view={extensionView}
              onView={setExtensionView}
              componentRows={run.componentRows}
              reload={(refresh = false) =>
                void extensionRun("extensions", true, refresh)
              }
            />
          ) : (
            <section className="panel records">
              <div className="panel-heading">
                <h2>
                  <Terminal size={17} />
                  本次执行记录
                </h2>
                <button
                  className="text-button"
                  disabled={busy || !run.logs.length}
                  onClick={exportReport}
                >
                  <FileDown size={14} />
                  导出诊断
                </button>
              </div>
              <Results
                run={run}
                planned={planned.length ? planned : planItems()}
                busy={busy}
              />
              <details className="execution-logs">
                <summary>执行日志（{run.logs.length}）</summary>
                <div className="log-scroll">
                  {run.logs.length ? (
                    run.logs.map((line: string, i: number) => (
                      <div key={i} className="log-line">
                        {line}
                      </div>
                    ))
                  ) : (
                    <div className="empty">
                      <Terminal size={30} />
                      <p>执行任务后，这里会显示日志。</p>
                    </div>
                  )}
                </div>
              </details>
            </section>
          )}
          {(done || run.phase === "error") && (
            <section className="result-strip" aria-live="polite">
              <span>
                {run.cancelled
                  ? "未执行的任务保持原状。"
                  : run.checkedOnly
                    ? "本机状态已更新，可选择需要处理的项目。"
                    : run.phase === "error"
                      ? "任务未完整完成，请查看错误原因和逐项结果。"
                      : failed.length
                        ? `${failed.length} 个步骤失败，请查看逐项结果。`
                        : run.dryRun
                          ? "演练结束，未写入用户配置；逐项结果见计划与结果页。"
                          : needsConfirmation
                            ? "配置导入窗口已打开，仍需在 CC Switch 中确认。"
                            : "执行结束，成功、跳过、提示及备份路径见计划与结果页。"}
              </span>
              <div>
                {failed.length > 0 && (
                  <button
                    className="text-button"
                    disabled={busy}
                    onClick={() => void retryFailed()}
                  >
                    <RotateCcw size={14} />
                    重试失败步骤
                  </button>
                )}
                <button className="text-button" onClick={exportReport}>
                  <FileDown size={14} />
                  导出诊断
                </button>
              </div>
            </section>
          )}
          {failed.length > 0 && (
            <div className="failure-list">
              {failed.map((r: any) => (
                <p key={r.Key}>
                  <strong>{r.Name}</strong> {r.Detail}
                </p>
              ))}
            </div>
          )}
        </main>
      </div>
      <footer className="actionbar">
        <div className="execution-state" role="status">
          {busy ? (
            <LoaderCircle className="spin" size={18} />
          ) : done && !failed.length && !run.cancelled ? (
            <CheckCircle2 size={18} />
          ) : (
            <ShieldCheck size={18} />
          )}
          <div>
            <strong>
              {busy
                ? stopping
                  ? "等待当前步骤完成"
                  : run.detail || "正在执行"
                : `${selected.length} 个软件 · ${components.length} 项扩展选择 · ${configure ? "含 API 配置" : "保留 API 配置"}`}
            </strong>
            <span>
              {busy && run.percent !== null
                ? `${run.percent}%`
                : busy
                  ? "请保持窗口打开"
                  : "软件、API 与扩展按同一计划执行；可在计划与结果页查看明细"}
            </span>
          </div>
          {busy && run.percent !== null && (
            <progress max="100" value={run.percent} aria-label="当前步骤进度" />
          )}
        </div>
        <div className="action-buttons">
          {busy ? (
            <button
              className="button secondary"
              onClick={stop}
              disabled={stopping}
            >
              <Square size={14} />
              {stopping ? "已请求停止" : "停止后续任务"}
            </button>
          ) : (
            <>
              <button
                className="button secondary"
                disabled={
                  !catalog ||
                  (!selected.length && !components.length && !configure)
                }
                onClick={() => void execute(true)}
              >
                <Play size={15} />
                安全演练
              </button>
              <button
                className="button primary"
                disabled={
                  !catalog ||
                  (!selected.length && !components.length && !configure)
                }
                onClick={() => void execute()}
              >
                <Download size={16} />
                {catalog?.dryRunOnly ? "执行演练计划" : "执行本次计划"}
              </button>
            </>
          )}
        </div>
      </footer>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<Setup />);
