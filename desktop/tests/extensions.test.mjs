import test from "node:test";
import assert from "node:assert/strict";
import { resolveComponents, componentStatus } from "../src/extension-state.mjs";

const items = [
  {
    id: "profile:web",
    kind: "profile",
    name: "web",
    skills: ["design"],
    mcp: ["browser"],
    requires: ["node"],
  },
  { id: "skill:design", kind: "skill", name: "design", requires: ["git"] },
  { id: "mcp:browser", kind: "mcp", name: "browser", requires: ["node"] },
  { id: "cli:node", kind: "cli", name: "node", requires: [] },
];
test("empty choices never expand to all extensions", () => {
  assert.deepEqual(resolveComponents(items, []), {
    skill: [],
    mcp: [],
    cli: [],
  });
});
test("mixed profiles and individual choices retain all members and deduplicate prerequisites", () => {
  assert.deepEqual(
    resolveComponents(items, ["profile:web", "skill:design", "cli:node"]),
    { skill: ["design"], mcp: ["browser"], cli: ["git", "node"] },
  );
});
test("MCP configuration and stale checks do not imply a healthy running server", () => {
  assert.deepEqual(componentStatus({ kind: "mcp", installed: true }), [
    "ok",
    "已有配置",
  ]);
  assert.deepEqual(componentStatus({ kind: "skill", installed: true }, true), [
    "unknown",
    "需要重新检查",
  ]);
});
test("skill collection aliases show actual members without counting the alias as an extra skill", () => {
  const collections = [
    ...items,
    {
      id: "skill:collection",
      kind: "skill",
      name: "collection",
      skills: ["design", "detail"],
      requires: [],
    },
  ];
  assert.deepEqual(
    resolveComponents(collections, ["skill:collection", "skill:design"]),
    { skill: ["design", "detail"], mcp: [], cli: ["git"] },
  );
});
