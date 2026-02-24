# Data Repo CI: Config Validator & Version Bump

**Date:** 2026-02-24
**Target repo:** `audiflow/audiflow-smartplaylist-dev` (and later `audiflow/audiflow-smartplaylist`)
**Tool repo:** `audiflow/audiflow-smartplaylist-editor` (this repo)

---

## Goal

Add two CI capabilities to the data repos:

1. **Config Validator** (PR check) - ensures all JSON configs are valid and parseable before merge
2. **Version Bump + Deploy** (post-merge) - increments version fields for changed patterns, then deploys to GCS

## Architecture

```
audiflow-smartplaylist-editor/            audiflow-smartplaylist-dev/
├── packages/                             ├── .github/workflows/
│   └── sp_cli/              (NEW)        │   ├── validate.yml        (NEW: on PR)
│       ├── pubspec.yaml                  │   └── bump-deploy.yml     (NEW: replaces deploy-config.yml)
│       ├── bin/                          └── patterns/
│       │   ├── validate.dart             │   ├── meta.json
│       │   └── bump_versions.dart        │   ├── coten_radio/...
│       ├── lib/src/                      │   └── news_connect/...
│       │   ├── validate_command.dart
│       │   └── bump_command.dart
│       └── test/
│           ├── validate_command_test.dart
│           └── bump_command_test.dart
```

**sp_cli** is a new Dart workspace package depending only on `sp_shared` + `dart:io`.
Two CLI entry points. The data repo CI clones this editor repo and runs the tools.

---

## Part 1: Config Validator

### What It Validates

Four-level validation, in order:

1. **Root meta.json**: Parse via `RootMeta.fromJson()`, verify structure
2. **Pattern meta.json**: Parse via `PatternMeta.fromJson()`, verify each listed playlist file exists
3. **Playlist definitions**: Parse via `SmartPlaylistDefinition.fromJson()` to catch type/field errors
4. **Assembly**: Run `ConfigAssembler.assemble()` per pattern, then validate the assembled `SmartPlaylistPatternConfig` against `SmartPlaylistValidator` (JSON Schema)

### CLI Interface

```bash
dart run packages/sp_cli/bin/validate.dart <patterns-dir>
```

**Exit code**: 0 = all valid, 1 = errors found.

**Output**: Lists each file checked, prints errors with file paths for easy CI debugging.

```
Validating patterns in /path/to/patterns...
  [OK] meta.json
  [OK] coten_radio/meta.json
  [OK] coten_radio/playlists/regular.json
  [OK] coten_radio/playlists/short.json
  [OK] coten_radio/playlists/extras.json
  [OK] coten_radio: assembled config valid
  [OK] news_connect/meta.json
  ...
All configs valid.
```

On error:
```
  [FAIL] coten_radio/playlists/regular.json
    - resolverType: invalid value 'unknown' (expected: rss, category, year, titleAppearanceOrder)
  [FAIL] coten_radio: assembly failed
    - FormatException: Missing required field 'displayName'

Validation failed: 2 errors found.
```

### Implementation (`lib/src/validate_command.dart`)

```dart
/// Validates all configs in a patterns directory.
///
/// Returns a list of validation errors. Empty list = all valid.
Future<List<ValidationError>> validatePatterns(String patternsDir) async {
  // 1. Parse root meta.json
  // 2. For each pattern: parse meta, parse playlists, assemble, schema-validate
}
```

Key types:
- `ValidationError` - holds file path + error message
- `ValidateCommand` - orchestrates the validation pipeline

### Workflow (`validate.yml` in data repo)

```yaml
name: Validate Configs

on:
  pull_request:
    paths: ["patterns/**.json"]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Clone editor repo
        run: |
          git clone --depth 1 \
            https://github.com/audiflow/audiflow-smartplaylist-editor.git \
            /tmp/editor

      - name: Install dependencies
        working-directory: /tmp/editor
        run: dart pub get

      - name: Validate configs
        run: |
          dart run /tmp/editor/packages/sp_cli/bin/validate.dart \
            $GITHUB_WORKSPACE/patterns
```

> **Note:** If the editor repo is private, the clone step needs a PAT or
> deploy key stored in the data repo's secrets.

---

## Part 2: Version Bump

### Anti-Cheat Mechanism

PRs must not control version numbers. The CI reads the **previous** version
from git history and increments from there, overwriting whatever the PR set.

### Bump Logic

```
Input:
  - patterns-dir: path to patterns/ directory (post-merge working copy)
  - previous-ref: git ref for pre-merge state (e.g., HEAD~1)

Algorithm:
  1. git diff <previous-ref> --name-only -- patterns/
     -> extract unique pattern IDs from changed paths
  2. For each changed pattern:
     a. Read previous version: git show <previous-ref>:patterns/{id}/meta.json
     b. new_version = previous_version + 1
     c. Update current {id}/meta.json with new_version
  3. Read previous root meta.json: git show <previous-ref>:patterns/meta.json
  4. new_root_version = previous_root_version + 1
  5. For each changed pattern in root meta.json:
     - Set pattern version to its new value
     - Update playlistCount (in case playlists were added/removed)
  6. Write updated root meta.json with new_root_version
  7. Print summary

Edge cases:
  - New pattern (no previous state): version starts at 1
  - Pattern deleted: remove from root meta.json entries
  - No pattern changes detected: exit 0, no modifications
```

### CLI Interface

```bash
dart run packages/sp_cli/bin/bump_versions.dart <patterns-dir> <previous-ref>
```

**Exit code**: 0 = success (or no changes needed), 1 = error.

**Output**:
```
Detecting changes from HEAD~1...
  Changed patterns: coten_radio
  coten_radio: version 2 -> 3
  Root meta: version 2 -> 3
Version bump complete.
```

### Implementation (`lib/src/bump_command.dart`)

```dart
/// Bumps versions for changed patterns.
///
/// Reads previous versions from [previousRef] via git show,
/// increments, and writes to current files in [patternsDir].
Future<BumpResult> bumpVersions({
  required String patternsDir,
  required String previousRef,
}) async {
  // 1. Detect changed patterns via git diff
  // 2. Read previous versions via git show
  // 3. Increment and write
}
```

Key types:
- `BumpResult` - summary of what was bumped
- `BumpCommand` - orchestrates the bump pipeline

### Workflow (`bump-deploy.yml` in data repo)

Replaces the current `deploy-config.yml`. Combines version bump + deploy in one workflow.

```yaml
name: Bump Versions & Deploy

on:
  push:
    branches: [main]
    paths:
      - "patterns/**.json"
      - ".github/workflows/bump-deploy.yml"

permissions:
  contents: write     # needed for git push
  id-token: write     # needed for GCP auth

env:
  BUCKET_NAME: audiflow-dev-config

jobs:
  bump-and-deploy:
    # Prevent re-triggering on bot's version bump commit
    if: github.actor != 'github-actions[bot]'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2    # need HEAD~1 for diff

      - uses: dart-lang/setup-dart@v1

      # --- Version Bump ---
      - name: Clone editor repo
        run: |
          git clone --depth 1 \
            https://github.com/audiflow/audiflow-smartplaylist-editor.git \
            /tmp/editor

      - name: Install editor dependencies
        working-directory: /tmp/editor
        run: dart pub get

      - name: Bump versions
        run: |
          dart run /tmp/editor/packages/sp_cli/bin/bump_versions.dart \
            $GITHUB_WORKSPACE/patterns HEAD~1

      - name: Commit version bump
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add patterns/
          git diff --cached --quiet || git commit -m "chore: bump versions"
          git push

      # --- Deploy to GCS ---
      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2

      - name: Sync config files to GCS
        run: |
          gsutil -m rsync -r -d \
            patterns "gs://${BUCKET_NAME}/"

      - name: Set cache headers
        run: |
          gsutil -m setmeta \
            -h "Cache-Control:public, max-age=300" \
            "gs://${BUCKET_NAME}/meta.json"
          gsutil -m setmeta \
            -h "Cache-Control:public, max-age=1800" \
            "gs://${BUCKET_NAME}/**/meta.json" || true
          gsutil -m setmeta \
            -h "Cache-Control:public, max-age=1800" \
            "gs://${BUCKET_NAME}/**/playlists/*.json" || true
```

---

## sp_cli Package Structure

```yaml
# packages/sp_cli/pubspec.yaml
name: sp_cli
description: CLI tools for validating and managing smart playlist configs
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  sp_shared:
    path: ../sp_shared

dev_dependencies:
  test: ^1.25.0
```

Add `sp_cli` to the workspace pubspec.yaml.

---

## Implementation Order

### Phase 1: sp_cli package + validate command
1. Create `packages/sp_cli/` package scaffold
2. Implement `ValidationError` type
3. Implement `ValidateCommand` with four-level validation
4. Create `bin/validate.dart` entry point
5. Write tests using temp directories with fixture JSON files

### Phase 2: bump_versions command
6. Implement `BumpResult` type
7. Implement `BumpCommand` with git-based version reading
8. Create `bin/bump_versions.dart` entry point
9. Write tests (mock git commands or use temp git repos)

### Phase 3: Data repo workflows
10. Create `validate.yml` in data repo
11. Create `bump-deploy.yml` in data repo (replace `deploy-config.yml`)
12. Test both workflows with a trial PR

---

## Testing Strategy

### Unit tests (in sp_cli)
- Validate command: fixture JSON files in temp dirs, test all four validation levels
- Bump command: create temp git repos with known history, verify version increments

### Integration tests (manual or in CI)
- Run validate CLI against the actual dev data repo
- Simulate a PR merge and verify version bump output

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Editor repo is private, CI can't clone | Add deploy key or PAT to data repo secrets |
| `git show HEAD~1` fails on merge commits with multiple parents | Use `HEAD^1` (first parent) or detect merge commits |
| Version bump + deploy partially fails | Deploy step runs after commit; if deploy fails, versions are still correct and next push re-triggers |
| Dart SDK version mismatch in CI | Pin Dart SDK version in workflow to match editor repo's constraint |
