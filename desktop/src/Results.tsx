import { CheckCircle2, Circle, LoaderCircle, XCircle } from "lucide-react";
import { ItemKindIcon } from "./ItemKindIcon";
export type PlannedItem = { Key: string; Name: string; Kind: string };
export function Results({
  run,
  planned,
  busy,
}: {
  run: any;
  planned: PlannedItem[];
  busy: boolean;
}) {
  const completed = [
    ...run.results.filter(
      (r: any) =>
        r.Key !== "skills-bundle" ||
        !Object.keys(run.componentRows).length ||
        r.Status === "failed" ||
        r.Status === "warning",
    ),
    ...Object.values(run.componentRows),
  ] as any[];
  const byKey = new Map(completed.map((r) => [r.Key, r]));
  const plannedKeys = new Set(planned.map((item) => item.Key));
  const rows = [
    ...planned.map((item) => ({ ...item, ...(byKey.get(item.Key) || {}) })),
    ...completed.filter((item) => !plannedKeys.has(item.Key)),
  ];
  const labels: Record<string, string> = {
    ok: "已完成",
    preview: "演练完成",
    skipped: "已跳过",
    failed: "失败",
    manual: "需手动处理",
    warning: "有提示",
    running: "处理中",
    waiting: busy ? "等待执行" : "未执行",
    confirmation: "待外部确认",
  };
  return (
    <section className="result-table">
      <table>
        <thead>
          <tr>
            <th>任务</th>
            <th>结果</th>
            <th>详情与备份</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((item) => {
            const appRow = run.rows[item.Key];
            const status = item.NeedsConfirmation
              ? "confirmation"
              : item.Preview &&
                  item.Status !== "failed" &&
                  item.Status !== "skipped"
                ? "preview"
                : item.Status ||
                  (appRow?.status === "running" ? "running" : "waiting");
            return (
              <tr key={item.Key}>
                <td>
                  <strong>{item.Name}</strong>
                  <span className="kind-caption">
                    <ItemKindIcon kind={item.Kind} size={13} />
                    {(
                      {
                        app: "软件",
                        skill: "Skill",
                        mcp: "MCP",
                        cli: "CLI",
                        scenario: "场景",
                        provider: "API 配置",
                      } as Record<string, string>
                    )[item.Kind] || "任务"}
                  </span>
                </td>
                <td>
                  <span className={"status " + status}>
                    {status === "running" ? (
                      <LoaderCircle className="spin" size={15} />
                    ) : status === "failed" ? (
                      <XCircle size={15} />
                    ) : status === "ok" || status === "preview" ? (
                      <CheckCircle2 size={15} />
                    ) : (
                      <Circle size={12} />
                    )}{" "}
                    {labels[status] || status}
                  </span>
                </td>
                <td>
                  <span>
                    {item.NeedsConfirmation
                      ? "已打开 CC Switch，请在该程序中确认导入"
                      : item.Detail || (run.cancelled ? "本次未执行" : "")}
                  </span>
                  {item.Backups?.map((path: string) => (
                    <div className="backup-path" key={path}>
                      {status === "preview" ? "计划备份：" : "备份："}
                      {path}
                    </div>
                  ))}
                </td>
              </tr>
            );
          })}
          {!rows.length && (
            <tr>
              <td colSpan={3} className="loading">
                选择软件或扩展后，这里会列出本次计划与逐项结果。
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </section>
  );
}
