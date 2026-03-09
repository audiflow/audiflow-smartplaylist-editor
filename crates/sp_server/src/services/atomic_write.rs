use std::path::Path;

/// Writes content to a file atomically via a .tmp intermediate.
///
/// Writes to a temporary file first, then renames to the target path.
/// This prevents partial reads if the process crashes mid-write.
pub fn atomic_write_str(path: &Path, content: &str) -> std::io::Result<()> {
    let tmp_path = path.with_extension("tmp");
    std::fs::write(&tmp_path, content)?;
    std::fs::rename(&tmp_path, path)?;
    Ok(())
}
