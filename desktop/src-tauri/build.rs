fn main() {
    println!("cargo:rerun-if-changed=../../manifest/apps.json");
    println!("cargo:rerun-if-changed=../../modules/common.psm1");
    println!("cargo:rerun-if-changed=../../scripts/DesktopWorker.ps1");
    println!("cargo:rerun-if-changed=../../bootstrap.ps1");
    tauri_build::build()
}
