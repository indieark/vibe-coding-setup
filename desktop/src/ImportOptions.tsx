import { ChevronRight, FileQuestion, Files, FolderCog, Settings2, Tag, type LucideIcon } from "lucide-react";
import { Toggle } from "./Toggle";
export type ImportPolicy = {
  orphanPolicy: "preserve" | "backup";
  foreignPolicy: "preserve" | "replace" | "rename";
  scenarioMode: "skip" | "default" | "custom";
  scenarioName: string;
  launchSkillsManager: boolean;
  replacementConfirmed: boolean;
  providerMode: "reuse" | "import";
};
export const defaultPolicy: ImportPolicy = {
  orphanPolicy: "preserve",
  foreignPolicy: "preserve",
  scenarioMode: "skip",
  scenarioName: "IndieArk Skills",
  launchSkillsManager: false,
  replacementConfirmed: false,
  providerMode: "reuse",
};
function Choices({
  label,
  icon: Icon,
  value,
  choices,
  disabled,
  change,
}: {
  label: string;
  icon: LucideIcon;
  value: string;
  choices: [string, string][];
  disabled: boolean;
  change: (value: any) => void;
}) {
  return (
    <fieldset className="policy-field" disabled={disabled}>
      <legend><span className="field-label"><Icon size={15} aria-hidden="true" />{label}</span></legend>
      <div className="policy-choices">
        {choices.map(([key, text]) => (
          <button
            type="button"
            key={key}
            aria-pressed={value === key}
            className={value === key ? "chosen" : ""}
            onClick={() => change(key)}
          >
            {text}
          </button>
        ))}
      </div>
    </fieldset>
  );
}
export function ImportOptions({
  policy,
  change,
  disabled,
}: {
  policy: ImportPolicy;
  change: (policy: ImportPolicy) => void;
  disabled: boolean;
}) {
  const set = (key: keyof ImportPolicy, value: any) =>
    change({
      ...policy,
      [key]: value,
      ...(key === "orphanPolicy" || key === "foreignPolicy"
        ? { replacementConfirmed: false }
        : {}),
    });
  return (
    <details
      className="import-options"
      open={
        policy.orphanPolicy !== "preserve" ||
        policy.foreignPolicy !== "preserve" ||
        policy.scenarioMode !== "skip"
      }
    >
      <summary>
        <ChevronRight className="disclosure-chevron" size={14} aria-hidden="true" />
        <Settings2 size={16} />
        导入与场景设置
      </summary>
      <div className="policy-body">
        <Choices
          label="无来源标记的同名 Skill"
          icon={FileQuestion}
          value={policy.orphanPolicy}
          choices={[
            ["preserve", "保留现有"],
            ["backup", "备份后替换"],
          ]}
          disabled={disabled}
          change={(value) => set("orphanPolicy", value)}
        />
        <Choices
          label="其他来源的同名 Skill"
          icon={Files}
          value={policy.foreignPolicy}
          choices={[
            ["preserve", "保留现有"],
            ["rename", "新版本改名导入"],
            ["replace", "备份后替换"],
          ]}
          disabled={disabled}
          change={(value) => set("foreignPolicy", value)}
        />
        {(policy.orphanPolicy === "backup" ||
          policy.foreignPolicy === "replace") && (
          <label className="check-label replacement-consent">
            <Toggle
              checked={policy.replacementConfirmed}
              disabled={disabled}
              label="确认备份后替换所选范围内的同名 Skill"
              onChange={() =>
                set("replacementConfirmed", !policy.replacementConfirmed)
              }
            />
            <span>我确认按上述策略备份并替换同名 Skill</span>
          </label>
        )}
        <Choices
          label="Skills Manager 场景注册"
          icon={FolderCog}
          value={policy.scenarioMode}
          choices={[
            ["skip", "跳过"],
            ["default", "默认场景"],
            ["custom", "自定义场景"],
          ]}
          disabled={disabled}
          change={(value) => set("scenarioMode", value)}
        />
        {policy.scenarioMode === "custom" && (
          <label>
            <span className="field-label"><Tag size={15} aria-hidden="true" />场景名称</span>
            <input
              name="scenarioName"
              value={policy.scenarioName}
              disabled={disabled}
              autoComplete="off"
              onChange={(e) => set("scenarioName", e.target.value)}
            />
          </label>
        )}
        {policy.scenarioMode !== "skip" && (
          <label className="check-label">
            <Toggle
              checked={policy.launchSkillsManager}
              disabled={disabled}
              label="允许初始化并打开 Skills Manager"
              onChange={() =>
                set("launchSkillsManager", !policy.launchSkillsManager)
              }
            />
            <span>允许初始化并打开 Skills Manager</span>
          </label>
        )}
        <p className="field-note">
          保留来源识别与备份机制；演练不会替换目录或注册场景。
        </p>
      </div>
    </details>
  );
}
