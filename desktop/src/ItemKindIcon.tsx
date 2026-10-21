import { Boxes, FolderCog, KeyRound, Layers3, Monitor, Plug, Sparkles, Terminal, type LucideIcon } from "lucide-react";

const icons: Record<string, LucideIcon> = {
  profile: Layers3,
  skill: Sparkles,
  mcp: Plug,
  cli: Terminal,
  app: Monitor,
  provider: KeyRound,
  scenario: FolderCog,
};

export function ItemKindIcon({ kind, size = 15 }: { kind: string; size?: number }) {
  const Icon = icons[kind] || Boxes;
  return <Icon size={size} aria-hidden="true" />;
}
