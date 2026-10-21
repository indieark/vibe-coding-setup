import { Boxes } from "lucide-react";
import git from "./assets/apps/git.svg";
import nodejs from "./assets/apps/nodejs.svg";
import python from "./assets/apps/python.svg";
import vscode from "./assets/apps/vscode.svg";
import codex from "./assets/apps/codex.svg";
import openai from "./assets/apps/openai.svg";
import ccSwitch from "./assets/apps/cc-switch.png";
import skillsManager from "./assets/apps/skills-manager.png";

const icons: Record<string, string> = {
  git, nodejs, python, vscode, codex, chatgpt: openai,
  "cc-switch": ccSwitch, "skills-manager": skillsManager,
};

export function AppIcon({ appKey }: { appKey: string }) {
  return <span className={"app-icon app-icon-" + appKey} aria-hidden="true">
    {icons[appKey] ? <img src={icons[appKey]} alt="" draggable={false} /> : <Boxes size={23} />}
  </span>;
}
