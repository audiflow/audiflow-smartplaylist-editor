# Cargo Publish Setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable `cargo install audiflow-editor` by publishing `sp_cli` (and its dependencies `sp_core`, `sp_server`) to crates.io, with automated publishing in the release workflow.

**Architecture:** All three crates must be published since crates.io requires all path dependencies to also be on crates.io. We add `publish = false` nowhere — instead we publish all three in dependency order (sp_core -> sp_server -> sp_cli). Each crate gets the required metadata. The release workflow gains a `publish` job that runs before the binary build.

**Tech Stack:** Cargo, crates.io, GitHub Actions

---

### Task 1: Add LICENSE file

The workspace declares `license = "MIT"` but no LICENSE file exists. crates.io requires the license file to be present.

**Files:**
- Create: `LICENSE`

**Step 1: Create the MIT LICENSE file**

Create `LICENSE` with standard MIT text, copyright holder "audiflow contributors", year 2025.

**Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license file"
```

---

### Task 2: Add crates.io metadata to workspace and sp_core

**Files:**
- Modify: `Cargo.toml` (workspace)
- Modify: `crates/sp_core/Cargo.toml`

**Step 1: Add shared metadata to workspace Cargo.toml**

Add to `[workspace.package]`:

```toml
[workspace.package]
version = "2.0.0"
edition = "2024"
license = "MIT"
repository = "https://github.com/audiflow/audiflow-smartplaylist-editor"
```

**Step 2: Add metadata to sp_core/Cargo.toml**

```toml
[package]
name = "sp_core"
description = "Domain models, resolvers, and schema validation for audiflow smart playlists"
version.workspace = true
edition.workspace = true
license.workspace = true
repository.workspace = true
```

**Step 3: Verify it compiles**

Run: `cargo check`
Expected: success with no errors

**Step 4: Commit**

```bash
git add Cargo.toml crates/sp_core/Cargo.toml
git commit -m "chore: add crates.io metadata to workspace and sp_core"
```

---

### Task 3: Add crates.io metadata to sp_server

**Files:**
- Modify: `crates/sp_server/Cargo.toml`

**Step 1: Add metadata and version to path dependency**

```toml
[package]
name = "sp_server"
description = "Local API server for audiflow smart playlist editor"
version.workspace = true
edition.workspace = true
license.workspace = true
repository.workspace = true

[dependencies]
sp_core = { path = "../sp_core", version = "2.0.0" }
```

The `version` field alongside `path` tells cargo: use the path locally, but when publishing, declare `sp_core = "2.0.0"` as the registry dependency.

**Step 2: Verify it compiles**

Run: `cargo check`
Expected: success

**Step 3: Commit**

```bash
git add crates/sp_server/Cargo.toml
git commit -m "chore: add crates.io metadata to sp_server"
```

---

### Task 4: Add crates.io metadata to sp_cli

**Files:**
- Modify: `crates/sp_cli/Cargo.toml`

**Step 1: Add metadata, version to path dependencies, and keywords**

```toml
[package]
name = "sp_cli"
description = "CLI and local server for editing audiflow smart playlist configurations"
version.workspace = true
edition.workspace = true
license.workspace = true
repository.workspace = true
keywords = ["podcast", "playlist", "editor"]
categories = ["command-line-utilities"]

[[bin]]
name = "audiflow-editor"
path = "src/main.rs"

[dependencies]
sp_core = { path = "../sp_core", version = "2.0.0" }
sp_server = { path = "../sp_server", version = "2.0.0" }
```

**Step 2: Verify it compiles**

Run: `cargo check`
Expected: success

**Step 3: Commit**

```bash
git add crates/sp_cli/Cargo.toml
git commit -m "chore: add crates.io metadata to sp_cli"
```

---

### Task 5: Dry-run publish to validate packaging

**Step 1: Dry-run sp_core**

Run: `cargo publish -p sp_core --dry-run`
Expected: success — "warning: aborting upload due to dry run"

**Step 2: Dry-run sp_server**

Run: `cargo publish -p sp_server --dry-run`
Expected: success

**Step 3: Dry-run sp_cli**

Run: `cargo publish -p sp_cli --dry-run`
Expected: success

**Step 4: Fix any issues surfaced by dry-run, then commit if changes were needed**

---

### Task 6: Add publish job to release workflow

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: Add a `publish` job between `version` and `build`**

Insert after the `sync` job:

```yaml
  publish:
    needs: version
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - name: Publish to crates.io
        env:
          CARGO_REGISTRY_TOKEN: ${{ secrets.CARGO_REGISTRY_TOKEN }}
        run: |
          # Publish in dependency order; --no-verify skips build (CI already tests)
          for crate in sp_core sp_server sp_cli; do
            echo "Publishing $crate..."
            # Check if this version is already published
            VERSION=$(cargo metadata --no-deps --format-version 1 \
              | python3 -c "import sys,json; pkgs=json.load(sys.stdin)['packages']; print([p['version'] for p in pkgs if p['name']=='$crate'][0])")
            if cargo search "$crate" 2>/dev/null | grep -q "^${crate} = \"${VERSION}\""; then
              echo "$crate@$VERSION already published — skipping"
            else
              cargo publish -p "$crate" --no-verify
              echo "Waiting for crates.io index to update..."
              sleep 30
            fi
          done
```

Note: the `sleep 30` between publishes is necessary because crates.io needs time to index the newly published crate before dependents can resolve it.

**Step 2: Make `build` depend on `publish` so binaries are built after publish succeeds**

Change `build.needs` from:

```yaml
  build:
    needs: version
```

to:

```yaml
  build:
    needs: [version, publish]
```

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add cargo publish step to release workflow"
```

---

### Task 7: Verify full workflow and run tests

**Step 1: Run all Rust tests**

Run: `cargo test`
Expected: all pass

**Step 2: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

**Step 3: Final commit if any fixups were needed**

---

## Post-Plan: Manual Steps (not automated)

1. **Create `CARGO_REGISTRY_TOKEN` secret** in the GitHub repo settings:
   - Generate a token at https://crates.io/settings/tokens (scope: `publish-update`)
   - Add as repository secret: Settings > Secrets > Actions > `CARGO_REGISTRY_TOKEN`

2. **First publish must be manual** (to claim the crate names):
   ```bash
   cargo publish -p sp_core
   sleep 30
   cargo publish -p sp_server
   sleep 30
   cargo publish -p sp_cli
   ```
