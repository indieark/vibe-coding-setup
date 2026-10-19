import React, { useEffect, useReducer, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { invoke, isTauri } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import {
  Boxes,
  CheckCircle2,
  Circle,
  Download,
  FileDown,
  KeyRound,
  LoaderCircle,
  Monitor,
  Moon,
  Play,
  RefreshCw,
  RotateCcw,
  Settings2,
  ShieldCheck,
  Square,
  Sun,
  Terminal,
  XCircle,
} from "lucide-react";
import { describeRow, initialRun, reduceEvent } from "./state.mjs";
import { Toggle } from "./Toggle";
import { Extensions, type ExtensionCatalog } from "./Extensions";
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
            taskRef.current === "components" &&
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
  async function start(
    mode: "check" | "install",
    dryRun = false,
    keys = selected,
    retryProvider = configure,
  ) {
    dryRun = dryRun || !!catalog?.dryRunOnly;
    setNotice("");
    if (!keys.length) {
      setNotice("请至少选择一个软件。");
      return;
    }
    if (mode === "install" && retryProvider) {
      if (
        !provider.name.trim() ||
        !provider.model.trim() ||
        !/^https?:\/\//i.test(provider.baseUrl)
      ) {
        setNotice("请填写完整的 Provider 名称、API 地址和模型。");
        return;
      }
      if (!dryRun && !provider.apiKey.trim()) {
        setNotice("请填写 API Key，或关闭“导入 CC Switch 配置”。");
        return;
      }
    }
    if (mode === "install" && !dryRun && !catalog?.isAdmin) {
      setNotice(
        "真实安装需要管理员权限。请关闭后通过启动脚本重新打开，并允许权限请求。",
      );
      return;
    }
    setBusy(true);
    setLastTask("setup");
    taskRef.current = "setup";
    if (mode === "install") setSelected(keys);
    setStopping(false);
    dispatch({ type: "reset" });
    try {
      await invoke("start_run", {
        plan: {
          mode,
          appKeys: keys,
          dryRun,
          configureProvider: mode === "install" && retryProvider,
          provider,
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
    if (busy || !catalog) return;
    dryRun = dryRun || catalog.dryRunOnly;
    setNotice("");
    if (mode === "install-components" && !components.length) {
      setNotice("请至少选择一个扩展组件。");
      return;
    }
    if (mode === "install-components" && !dryRun && !catalog.isAdmin) {
      setNotice("真实安装需要管理员权限，请通过启动脚本重新打开。");
      return;
    }
    setBusy(true);
    setStopping(false);
    setLastTask(mode === "extensions" ? "extension-check" : "components");
    taskRef.current = mode === "extensions" ? "extension-check" : "components";
    dispatch({ type: "reset" });
    try {
      await invoke("start_run", {
        plan: {
          mode,
          appKeys: [],
          dryRun,
          configureProvider: false,
          provider: {},
          componentIds: components,
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
  const appFailures = failed
    .filter((r: any) => r.Key !== "cc-switch-provider")
    .map((r: any) => r.Key);
  const done = run.phase === "done";
  const extensionContext =
    tab === "extensions" || (tab === "logs" && lastTask !== "setup");
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
      <header className="topbar">
        <div className="brand">
          <span className="brand-icon">
            <Boxes size={21} />
          </span>
          <strong>IndieArk</strong>
          <span className="brand-divider" />
          <span>环境安装</span>
        </div>
        <div className="top-actions">
          <span className="version">Desktop 0.1</span>
          <button
            className="icon-button"
            aria-label="切换亮暗主题"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
          >
            {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
          </button>
        </div>
      </header>
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
            执行记录
            {run.logs.length > 0 && (
              <span className="count">{run.logs.length}</span>
            )}
          </button>
        </nav>
        <main className="content">
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
                        <th className="check-col" />
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
                            className={
                              selected.includes(app.key) ? "" : "unselected"
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
                              <div className="app-name">
                                {app.name}
                                {app.defaultInstall === false && (
                                  <span className="optional">可选</span>
                                )}
                              </div>
                              <div className="app-purpose">
                                {purpose[app.key]}
                              </div>
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
                    disabled={busy || !catalog}
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
                    Provider 名称
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
                  <label>
                    API 地址
                    <input
                      name="baseUrl"
                      disabled={busy || !configure}
                      value={provider.baseUrl}
                      onChange={(e) =>
                        setProvider({ ...provider, baseUrl: e.target.value })
                      }
                      spellCheck={false}
                      autoComplete="off"
                    />
                  </label>
                  <label>
                    默认模型
                    <input
                      name="model"
                      disabled={busy || !configure}
                      value={provider.model}
                      onChange={(e) =>
                        setProvider({ ...provider, model: e.target.value })
                      }
                      spellCheck={false}
                      autoComplete="off"
                    />
                  </label>
                  <label>
                    API Key
                    <input
                      type="password"
                      name="apiKey"
                      disabled={busy || !configure}
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
                </div>
                <div className="config-footer">
                  {configure
                    ? "安装后打开 CC Switch，由你确认导入。"
                    : "本次保留现有 API 配置。"}
                </div>
              </section>
            </div>
          ) : tab === "extensions" ? (
            <Extensions
              catalog={extensions}
              selected={components}
              onSelect={setComponents}
              busy={busy}
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
            </section>
          )}
          {(done || run.phase === "error") && (
            <section className="result-strip" aria-live="polite">
              <span>
                {run.cancelled
                  ? "未执行的任务保持原状。"
                  : run.checkedOnly
                    ? "本机状态已更新，可选择需要处理的项目。"
                    : lastTask === "components" &&
                        !failed.length &&
                        run.results.length
                      ? (run.dryRun
                          ? "扩展演练完成，未写入用户配置。"
                          : run.results[0].Detail) +
                        (warnings.length
                          ? `（${warnings.length} 条提示，见执行记录）`
                          : "")
                      : `${run.results.filter((r: any) => r.Status !== "failed").length} 项已处理${failed.length ? `，${failed.length} 项失败` : ""}`}
              </span>
              <div>
                {failed.length > 0 && (
                  <button
                    className="text-button"
                    disabled={busy}
                    onClick={() =>
                      lastTask === "components"
                        ? extensionRun("install-components", run.dryRun)
                        : start(
                            "install",
                            run.dryRun,
                            appFailures.length ? appFailures : ["cc-switch"],
                            failed.some(
                              (r: any) => r.Key === "cc-switch-provider",
                            ),
                          )
                    }
                  >
                    <RotateCcw size={14} />
                    {lastTask === "components"
                      ? "重试所选扩展"
                      : appFailures.length
                        ? "重试失败项"
                        : "重试配置导入"}
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
                : "按需安装，现有软件会先检查"}
            </strong>
            <span>
              {busy && run.percent !== null
                ? `${run.percent}%`
                : busy
                  ? "请保持窗口打开"
                  : tab === "extensions"
                    ? "选择、演练和安装都在当前窗口完成"
                    : "Skills / MCP / CLI 可从扩展组件进入"}
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
                  (extensionContext && (!extensions || !components.length))
                }
                onClick={() =>
                  extensionContext
                    ? extensionRun("install-components", true)
                    : start("install", true)
                }
              >
                <Play size={15} />
                安全演练
              </button>
              <button
                className="button primary"
                disabled={
                  !catalog ||
                  (extensionContext
                    ? !extensions || !components.length
                    : !selected.length)
                }
                onClick={() =>
                  extensionContext
                    ? extensionRun("install-components")
                    : start("install")
                }
              >
                <Download size={16} />
                {catalog?.dryRunOnly
                  ? "开始演练"
                  : extensionContext
                    ? "安装所选扩展"
                    : "开始安装"}
              </button>
            </>
          )}
        </div>
      </footer>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<Setup />);
