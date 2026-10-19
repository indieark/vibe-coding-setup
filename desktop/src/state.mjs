export const initialRun = () => ({
  phase: "ready",
  rows: {},
  logs: [],
  percent: null,
  detail: "",
  results: [],
  error: "",
  cancelled: false,
  dryRun: false,
  checkedOnly: false,
  componentRows: {},
});
export function reduceEvent(state, event) {
  const next = { ...state };
  if (event.type === "component-result")
    next.componentRows = { ...state.componentRows, [event.key]: event.result };
  if (event.type === "log")
    next.logs = [
      ...state.logs,
      (event.level && event.level !== "INFO" ? `[${event.level}] ` : "") +
        event.message,
    ].slice(-500);
  if (event.type === "phase") {
    next.phase = event.phase;
    next.detail = "";
    next.percent = null;
  }
  if (event.type === "progress") {
    next.percent = event.percent ?? null;
    next.detail = event.detail || event.label || "";
  }
  if (event.type === "checked")
    next.rows = { ...state.rows, [event.key]: { ...event, status: "checked" } };
  if (event.type === "app-start") {
    next.rows = {
      ...state.rows,
      [event.key]: { ...state.rows[event.key], status: "running" },
    };
    next.percent = null;
    next.detail = event.name;
  }
  if (event.type === "app-result") {
    next.rows = {
      ...state.rows,
      [event.key]: {
        ...state.rows[event.key],
        status:
          event.result.Status === "failed"
            ? "failed"
            : event.result.Source === "precheck-skip"
              ? "skipped"
              : "ok",
        result: event.result,
      },
    };
    next.results = [
      ...state.results.filter((r) => r.Key !== event.key),
      event.result,
    ];
  }
  if (event.type === "done") {
    next.phase = "done";
    next.results = event.results || [];
    next.cancelled = !!event.cancelled;
    next.dryRun = !!event.dryRun;
    next.checkedOnly = !!event.checkedOnly;
    next.percent = null;
    next.detail = "";
  }
  if (event.type === "fatal") {
    next.phase = "error";
    next.error = event.message;
    next.percent = null;
  }
  return next;
}
export function describeRow(row) {
  if (!row) return ["unknown", "尚未检查"];
  if (row.status === "running") return ["running", "处理中"];
  if (row.status === "failed") return ["failed", "失败"];
  if (row.status === "skipped") return ["ok", "已安装，跳过"];
  if (row.result?.Preview) return ["preview", "演练完成"];
  if (row.status === "ok") return ["ok", "已完成"];
  if (row.status === "checked" && row.error) return ["failed", "检查失败"];
  if (row.decision?.Action === "skip") return ["ok", "已安装"];
  if (row.decision?.Reason === "outdated") return ["update", "可更新"];
  if (row.decision?.Reason === "missing") return ["unknown", "未安装"];
  return ["unknown", "版本未知"];
}
