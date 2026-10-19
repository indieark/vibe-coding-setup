export const extensionKinds = {
  profile: "套件",
  skill: "Skills",
  mcp: "MCP",
  cli: "CLI",
};

// IDs identify explicit choices; resolved names also include profile members and prerequisites.
export function resolveComponents(items, ids) {
  const selected = items.filter((item) => ids.includes(item.id));
  const names = { skill: new Set(), mcp: new Set(), cli: new Set() };
  for (const item of selected) {
    if (item.kind === "profile") {
      item.skills.forEach((name) => names.skill.add(name));
      item.mcp.forEach((name) => names.mcp.add(name));
    } else if (item.kind === "skill" && item.skills?.length) {
      item.skills.forEach((name) => names.skill.add(name));
    } else names[item.kind].add(item.name);
    item.requires.forEach((name) => names.cli.add(name));
  }
  for (const item of items) {
    if (item.kind !== "profile" && names[item.kind].has(item.name)) {
      item.requires.forEach((name) => names.cli.add(name));
    }
  }
  return Object.fromEntries(
    Object.entries(names).map(([kind, values]) => [kind, [...values].sort()]),
  );
}

export function componentStatus(item, stale = false) {
  if (item.kind === "profile") return ["unknown", "按包含项安装"];
  if (stale) return ["unknown", "需要重新检查"];
  if (item.installed === null) return ["unknown", "状态未知"];
  if (item.updateAvailable) return ["update", "可更新"];
  if (item.kind === "mcp")
    return item.installed ? ["ok", "已有配置"] : ["unknown", "未配置"];
  return item.installed ? ["ok", "已安装"] : ["unknown", "未安装"];
}
