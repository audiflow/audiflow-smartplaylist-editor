use std::path::Path;

fn main() {
    // rust-embed requires the folder to exist at compile time.
    // Create it if missing so local builds work without pre-building
    // the React SPA (the directory will simply be empty, meaning no
    // embedded assets -- the --static-dir flag serves files instead).
    let dist = Path::new("../../packages/sp_react/dist");
    if !dist.exists() {
        std::fs::create_dir_all(dist).expect("failed to create sp_react dist placeholder");
    }
}
