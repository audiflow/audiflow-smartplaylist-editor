# Bump Version

Bump the workspace version to the version specified in $ARGUMENTS.

## Input

$ARGUMENTS should be a semver version string (e.g., `4.0.0` or `v4.0.0`).
Strip the leading `v` if present.

## Steps

1. **Validate** the version string is valid semver (MAJOR.MINOR.PATCH).
2. **Read** the root `Cargo.toml` to confirm the current version.
3. **Update** all three version occurrences in the root `Cargo.toml`:
   - `[workspace.package] version`
   - `[workspace.dependencies] preset_core` version field
   - `[workspace.dependencies] preset_server` version field
4. **Verify** by running `cargo clippy -- -W warnings` (zero warnings required).
5. **Verify** by running `cargo test` (all tests must pass).
6. Report the old and new version to the user.

## Important

- Do NOT create a git commit or push. The user handles that separately.
- Do NOT create or switch branches. The user handles that separately.
- If clippy or tests fail, fix the issues before reporting success.
