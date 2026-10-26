import { useEffect, useState } from "react";
import { isTauri } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { Boxes, Copy, Minus, Moon, Square, Sun, X } from "lucide-react";

export function TitleBar({ theme, onToggleTheme, onError }: {
  theme: string;
  onToggleTheme: () => void;
  onError: (message: string) => void;
}) {
  const [maximized, setMaximized] = useState(false);
  useEffect(() => {
    if (!isTauri()) return;
    const appWindow = getCurrentWindow();
    let disposed = false;
    const update = () => appWindow.isMaximized().then((value) => {
      if (!disposed) setMaximized(value);
    }).catch(() => {});
    void update();
    const listening = appWindow.onResized(() => { void update(); });
    return () => {
      disposed = true;
      void listening.then((unlisten) => unlisten()).catch(() => {});
    };
  }, []);

  async function control(action: "minimize" | "toggleMaximize" | "close") {
    if (!isTauri()) return;
    try {
      // close() goes through Rust's CloseRequested guard while a task is running.
      await getCurrentWindow()[action]();
    } catch (error) {
      onError("窗口操作失败：" + String(error));
    }
  }

  return (
    <header className="topbar" data-tauri-drag-region>
      <div className="brand" data-tauri-drag-region>
        <span className="brand-icon"><Boxes size={19} /></span>
        <strong>IndieArk</strong>
        <span className="brand-divider" />
        <span>环境安装</span>
      </div>
      <div className="titlebar-space" data-tauri-drag-region />
      <div className="top-actions">
        <span className="version">Desktop 0.2.3</span>
        <button type="button" className="theme-button"
          aria-label={theme === "dark" ? "切换到浅色主题" : "切换到深色主题"}
          title={theme === "dark" ? "切换到浅色主题" : "切换到深色主题"}
          onClick={onToggleTheme}>
          {theme === "dark" ? <Sun size={16} /> : <Moon size={16} />}
          <span>{theme === "dark" ? "浅色" : "深色"}</span>
        </button>
        <div className="window-controls" aria-label="窗口控制">
          <button type="button" className="window-control" aria-label="最小化" title="最小化" onClick={() => void control("minimize")}><Minus size={16} /></button>
          <button type="button" className="window-control" aria-label={maximized ? "还原窗口" : "最大化"} title={maximized ? "还原窗口" : "最大化"} onClick={() => void control("toggleMaximize")}>
            {maximized ? <Copy size={13} /> : <Square size={13} />}
          </button>
          <button type="button" className="window-control window-close" aria-label="关闭窗口" title="关闭窗口" onClick={() => void control("close")}><X size={17} /></button>
        </div>
      </div>
    </header>
  );
}
