import test from "node:test";
import assert from "node:assert/strict";
import { initialRun, reduceEvent, describeRow } from "../src/state.mjs";
test("checking presence does not claim an installation completed", () => {
  const state = reduceEvent(initialRun(), {
    type: "checked",
    key: "git",
    status: "ok",
    decision: { Action: "install", Reason: "missing" },
  });
  assert.deepEqual(describeRow(state.rows.git), ["unknown", "未安装"]);
});
test("failed application remains retryable and is replaced by a later result", () => {
  let state = reduceEvent(initialRun(), {
    type: "app-result",
    key: "git",
    result: { Key: "git", Status: "failed", Detail: "download failed" },
  });
  assert.deepEqual(describeRow(state.rows.git), ["failed", "失败"]);
  state = reduceEvent(state, {
    type: "app-result",
    key: "git",
    result: { Key: "git", Status: "ok", Source: "winget" },
  });
  assert.equal(state.results.length, 1);
  assert.equal(state.results[0].Status, "ok");
});
test("cancelled completion is separate from successful installation", () => {
  const state = reduceEvent(initialRun(), {
    type: "done",
    success: false,
    cancelled: true,
    results: [],
  });
  assert.equal(state.phase, "done");
  assert.equal(state.cancelled, true);
});
test("unknown progress stays indeterminate and logs remain bounded", () => {
  let state = reduceEvent(initialRun(), {
    type: "progress",
    percent: null,
    label: "install",
  });
  assert.equal(state.percent, null);
  for (let n = 0; n < 600; n++)
    state = reduceEvent(state, { type: "log", message: String(n) });
  assert.equal(state.logs.length, 500);
  assert.equal(state.logs[0], "100");
});
test("component outcomes retain failures, skipped items and backup paths independently", () => {
  let state = reduceEvent(initialRun(), {
    type: "component-result",
    key: "skill:a",
    result: { Key: "skill:a", Status: "failed", Backups: ["fixture-backup"] },
  });
  state = reduceEvent(state, {
    type: "component-result",
    key: "cli:b",
    result: { Key: "cli:b", Status: "skipped" },
  });
  state = reduceEvent(state, { type: "done", results: [], success: false });
  assert.equal(state.componentRows["skill:a"].Status, "failed");
  assert.deepEqual(state.componentRows["skill:a"].Backups, ["fixture-backup"]);
  assert.equal(state.componentRows["cli:b"].Status, "skipped");
});
test("application preview is distinct from installation and retains detected versions", () => {
  let state = reduceEvent(initialRun(), {
    type: "checked",
    key: "git",
    decision: { InstalledVersion: "1", DesiredVersion: "2" },
  });
  state = reduceEvent(state, {
    type: "app-result",
    key: "git",
    result: { Key: "git", Status: "ok", Preview: true },
  });
  assert.deepEqual(describeRow(state.rows.git), ["preview", "演练完成"]);
  assert.equal(state.rows.git.decision.InstalledVersion, "1");
});
