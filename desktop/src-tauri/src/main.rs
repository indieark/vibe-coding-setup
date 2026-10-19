#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
#[cfg(windows)]
use std::os::windows::process::CommandExt;
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    path::PathBuf,
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    time::{SystemTime, UNIX_EPOCH},
};
use tauri::{Emitter, Manager, State};

const WORKER: &str = include_str!("../../../scripts/DesktopWorker.ps1");
const COMMON: &str = include_str!("../../../modules/common.psm1");
const MANIFEST: &str = include_str!("../../../manifest/apps.json");
const BOOTSTRAP: &str = include_str!("../../../bootstrap.ps1");

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Plan {
    mode: String,
    app_keys: Vec<String>,
    dry_run: bool,
    configure_provider: bool,
    provider: Value,
    #[serde(default)]
    component_ids: Vec<String>,
    #[serde(default)]
    refresh_bundle: bool,
    #[serde(default)]
    run_id: String,
}

struct Engine {
    root: PathBuf,
    home: String,
    dry_run_only: bool,
    busy: Arc<AtomicBool>,
    stop: Mutex<Option<PathBuf>>,
    report: Arc<Mutex<Vec<Value>>>,
}

impl Engine {
    fn apply_policy(&self, plan: &mut Plan) {
        if self.dry_run_only {
            plan.dry_run = true;
        }
    }
}

fn nonce() -> String {
    format!(
        "{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    )
}
fn prepare() -> Result<Engine, String> {
    let args: Vec<_> = std::env::args().collect();
    let home = args
        .windows(2)
        .find(|a| a[0] == "--user-home")
        .map(|a| a[1].clone())
        .unwrap_or_else(|| std::env::var("USERPROFILE").unwrap_or_default());
    let source = args
        .windows(2)
        .find(|a| a[0] == "--source-root")
        .map(|a| PathBuf::from(&a[1]));
    let base = std::env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    let root = base
        .join("IndieArk")
        .join("Setup")
        .join("runs")
        .join(nonce());
    fs::create_dir_all(root.join("modules")).map_err(|e| e.to_string())?;
    fs::create_dir_all(root.join("scripts")).map_err(|e| e.to_string())?;
    fs::create_dir_all(root.join("manifest")).map_err(|e| e.to_string())?;
    for (path, content) in [
        ("scripts/DesktopWorker.ps1", WORKER),
        ("modules/common.psm1", COMMON),
        ("manifest/apps.json", MANIFEST),
        ("bootstrap.ps1", BOOTSTRAP),
    ] {
        let bytes = if let Some(source) = &source {
            fs::read(source.join(path))
                .map_err(|e| format!("Installer source {path} is unavailable: {e}"))?
        } else {
            content.as_bytes().to_vec()
        };
        fs::write(root.join(path), bytes).map_err(|e| e.to_string())?;
    }
    Ok(Engine {
        root,
        home,
        dry_run_only: args.iter().any(|arg| arg == "--dry-run-only"),
        busy: Arc::new(AtomicBool::new(false)),
        stop: Mutex::new(None),
        report: Arc::new(Mutex::new(Vec::new())),
    })
}

fn worker(
    root: &PathBuf,
    home: &str,
    plan: &Plan,
    stop: &PathBuf,
    mut emit: impl FnMut(Value),
) -> Result<(), String> {
    let mut cmd = Command::new("powershell.exe");
    cmd.args([
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    ])
    .arg(root.join("scripts/DesktopWorker.ps1"))
    .arg("-StopPath")
    .arg(stop)
    .env("VIBE_CODING_USER_HOME", home)
    .stdin(Stdio::piped())
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());
    #[cfg(windows)]
    cmd.creation_flags(0x08000000);
    let mut child = cmd
        .spawn()
        .map_err(|e| format!("Cannot start PowerShell: {e}"))?;
    let secret = plan
        .provider
        .get("apiKey")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_owned();
    let sanitize = |text: &str| {
        if secret.is_empty() {
            text.to_owned()
        } else {
            text.replace(&secret, "[redacted]")
        }
    };
    let input = serde_json::to_vec(plan).map_err(|e| e.to_string())?;
    child
        .stdin
        .take()
        .ok_or("Worker stdin unavailable")?
        .write_all(&input)
        .map_err(|e| e.to_string())?;
    let stderr = child.stderr.take().ok_or("Worker stderr unavailable")?;
    let error_reader = std::thread::spawn(move || {
        let mut text = String::new();
        for line in BufReader::new(stderr).lines().map_while(Result::ok) {
            if text.len() < 32000 {
                text.push_str(&line);
                text.push('\n');
            }
        }
        text
    });
    let stdout = child.stdout.take().ok_or("Worker stdout unavailable")?;
    let mut terminal = false;
    for line in BufReader::new(stdout).lines() {
        let text = line.map_err(|e| e.to_string())?;
        if let Some(payload) = text.strip_prefix("@@INDIEARK@@") {
            let event: Value = serde_json::from_str(payload).map_err(|_| "Invalid worker event")?;
            if matches!(event["type"].as_str(), Some("done" | "fatal" | "catalog")) {
                terminal = true;
            }
            emit(event);
        } else if !text.trim().is_empty() {
            emit(
                json!({"type":"log","runId":plan.run_id,"message":sanitize(&text),"level":"INFO"}),
            );
        }
    }
    let status = child.wait().map_err(|e| e.to_string())?;
    let errors = sanitize(&error_reader.join().unwrap_or_default());
    if !terminal {
        return Err(if errors.is_empty() {
            format!("Worker exited without a result: {status}")
        } else {
            errors
        });
    }
    Ok(())
}

fn empty_plan(mode: &str) -> Plan {
    Plan {
        mode: mode.into(),
        app_keys: vec![],
        dry_run: true,
        configure_provider: false,
        provider: json!({}),
        component_ids: vec![],
        refresh_bundle: false,
        run_id: nonce(),
    }
}

#[tauri::command]
async fn get_catalog(engine: State<'_, Engine>) -> Result<Value, String> {
    let root = engine.root.clone();
    let home = engine.home.clone();
    let dry_run_only = engine.dry_run_only;
    tauri::async_runtime::spawn_blocking(move || {
        let mut catalog = None;
        worker(&root, &home, &empty_plan("describe"), &root.join("describe.stop"), |event| { if event["type"] == "catalog" {catalog=Some(event);} })?;
        let mut catalog = catalog.ok_or("Catalog unavailable")?;
        if catalog["protocolVersion"] != 1 { return Err("Installer worker protocol is incompatible. Update the desktop program and restart.".into()); }
        catalog["dryRunOnly"] = json!(dry_run_only);
        Ok(catalog)
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
fn start_run(
    app: tauri::AppHandle,
    engine: State<'_, Engine>,
    mut plan: Plan,
) -> Result<String, String> {
    if !matches!(
        plan.mode.as_str(),
        "check" | "install" | "extensions" | "install-components"
    ) {
        return Err("Unsupported operation".into());
    }
    if engine
        .busy
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        return Err("An operation is already running".into());
    }
    plan.run_id = nonce();
    engine.apply_policy(&mut plan);
    let id = plan.run_id.clone();
    let root = engine.root.clone();
    let home = engine.home.clone();
    let busy = engine.busy.clone();
    let report = engine.report.clone();
    let stop = root.join(format!("{}.stop", plan.run_id));
    *engine.stop.lock().map_err(|_| "State unavailable")? = Some(stop.clone());
    report.lock().map_err(|_| "Report unavailable")?.clear();
    std::thread::spawn(move || {
        let outcome = worker(&root, &home, &plan, &stop, |event| {
            if let Ok(mut lines) = report.lock() {
                if lines.len() < 10000 {
                    lines.push(event.clone());
                }
            }
            let _ = app.emit("installer", event);
        });
        if let Err(message) = outcome {
            let event = json!({"type":"fatal","runId":plan.run_id,"message":message});
            if let Ok(mut lines) = report.lock() {
                lines.push(event.clone());
            }
            let _ = app.emit("installer", event);
        }
        busy.store(false, Ordering::SeqCst);
        let _ = app.emit("installer-idle", &plan.run_id);
    });
    Ok(id)
}

#[tauri::command]
fn stop_after_current(engine: State<'_, Engine>) -> Result<(), String> {
    if let Some(path) = engine
        .stop
        .lock()
        .map_err(|_| "State unavailable")?
        .as_ref()
    {
        fs::write(path, b"stop").map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn export_report(engine: State<'_, Engine>) -> Result<String, String> {
    let path = engine.root.join(format!("diagnostics-{}.json", nonce()));
    let report = engine.report.lock().map_err(|_| "Report unavailable")?;
    fs::write(
        &path,
        serde_json::to_vec_pretty(&*report).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    Ok(path.to_string_lossy().into_owned())
}

fn smoke(engine: &Engine, path: &str) -> Result<(), String> {
    let mut events = Vec::new();
    let components = std::env::args().any(|arg| arg == "--smoke-components");
    worker(
        &engine.root,
        &engine.home,
        &empty_plan("describe"),
        &engine.root.join("smoke.stop"),
        |e| events.push(e),
    )?;
    let mut plan = if components {
        worker(
            &engine.root,
            &engine.home,
            &empty_plan("extensions"),
            &engine.root.join("smoke.stop"),
            |e| events.push(e),
        )?;
        let id = events
            .iter()
            .find(|e| e["type"] == "extensions-catalog")
            .and_then(|e| e["items"].as_array())
            .and_then(|items| items.iter().find(|item| item["kind"] == "cli"))
            .and_then(|item| item["id"].as_str())
            .ok_or("No CLI component in catalog")?;
        let mut plan = empty_plan("install-components");
        plan.component_ids = vec![id.to_owned()];
        plan
    } else {
        let mut plan = empty_plan("install");
        plan.app_keys = vec!["codex".into()];
        plan
    };
    if engine.dry_run_only {
        plan.dry_run = false;
    }
    engine.apply_policy(&mut plan);
    worker(
        &engine.root,
        &engine.home,
        &plan,
        &engine.root.join("smoke.stop"),
        |e| events.push(e),
    )?;
    let success = events
        .iter()
        .rev()
        .find(|e| e["type"] == "done" || e["type"] == "fatal")
        .is_some_and(|e| e["type"] == "done" && e["success"] == true);
    fs::write(
        path,
        serde_json::to_vec_pretty(&events).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    if success {
        Ok(())
    } else {
        Err("Worker smoke test failed".into())
    }
}

fn main() {
    let engine = prepare().expect("Cannot prepare installer resources");
    let args: Vec<_> = std::env::args().collect();
    if let Some(pair) = args.windows(2).find(|pair| pair[0] == "--smoke-test") {
        if smoke(&engine, &pair[1]).is_err() {
            std::process::exit(1);
        }
        return;
    }
    tauri::Builder::default()
        .manage(engine)
        .invoke_handler(tauri::generate_handler![
            get_catalog,
            start_run,
            stop_after_current,
            export_report
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                if window.state::<Engine>().busy.load(Ordering::SeqCst) {
                    api.prevent_close();
                    let _ = window.emit("installer-close-blocked", ());
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("Cannot start desktop installer");
}
