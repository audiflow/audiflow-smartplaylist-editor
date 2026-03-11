use std::path::Path;

/// Writes content to a file atomically via a .tmp intermediate.
///
/// Writes to a temporary file first, then renames to the target path.
/// This prevents partial reads if the process crashes mid-write.
pub fn atomic_write_str(path: &Path, content: &str) -> std::io::Result<()> {
    // Append .tmp to the full filename (e.g. meta.json -> meta.json.tmp)
    // rather than replacing the extension, to avoid collisions.
    let mut tmp_name = path.as_os_str().to_owned();
    tmp_name.push(".tmp");
    let tmp_path = std::path::PathBuf::from(tmp_name);

    std::fs::write(&tmp_path, content)?;
    // On Windows, rename does not overwrite an existing destination.
    #[cfg(windows)]
    if path.exists() {
        std::fs::remove_file(path)?;
    }
    std::fs::rename(&tmp_path, path)?;
    Ok(())
}
