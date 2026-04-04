# Semi-Deterministic Pattern IDs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make pattern IDs semi-deterministic -- computed at creation time from podcast identity (MD5 of podcastGuid or feedUrls[0]) to prevent duplicate configs.

**Architecture:** A `pattern_id` service in sp_core derives IDs via MD5. The server enforces deterministic IDs on creation and exposes a derivation endpoint. The CLI validates deterministic IDs match their source. The frontend auto-populates a read-only ID field from the derivation endpoint.

**Tech Stack:** Rust (md5 crate), axum, React 19 + TanStack Query + React Hook Form, i18next

**Out of scope:** JSON Schema description updates (owned by data repo).

---

## File Map

### PR 1: sp_core utility

| Action | File | Responsibility |
|--------|------|----------------|
| CREATE | `crates/sp_core/src/services/pattern_id.rs` | `derive_pattern_id` and `is_deterministic_id` functions |
| MODIFY | `crates/sp_core/src/services/mod.rs` | Register module, re-export public API |
| MODIFY | `crates/sp_core/Cargo.toml` | Add `md5 = "0.7"` dependency |

### PR 2: Server + CLI

| Action | File | Responsibility |
|--------|------|----------------|
| CREATE | `crates/sp_server/src/routes/derive.rs` | `POST /api/configs/derive-pattern-id` endpoint |
| MODIFY | `crates/sp_server/src/routes/mod.rs` | Register `derive` module and route |
| MODIFY | `crates/sp_server/src/routes/config.rs` | Enforce deterministic ID on `create_pattern` |
| MODIFY | `crates/sp_cli/src/cmd_validate.rs` | Add `validate_pattern_id_integrity` check |

### PR 3: Frontend

| Action | File | Responsibility |
|--------|------|----------------|
| CREATE | `packages/sp_react/src/hooks/use-derive-pattern-id.ts` | Hook calling derivation endpoint (debounced) |
| MODIFY | `packages/sp_react/src/api/queries.ts` | Add `useDerivePatternId` mutation |
| MODIFY | `packages/sp_react/src/components/editor/pattern-settings.tsx` | Auto-populate read-only ID for new patterns |
| MODIFY | `packages/sp_react/src/locales/en/editor.json` | Add derivation-related strings |
| MODIFY | `packages/sp_react/src/locales/ja/editor.json` | Add Japanese translations |

---

## Task 1: Add `pattern_id` service to sp_core

**Branch:** `feat/deterministic-pattern-ids`

**Files:**
- Create: `crates/sp_core/src/services/pattern_id.rs`
- Modify: `crates/sp_core/src/services/mod.rs`
- Modify: `crates/sp_core/Cargo.toml`

- [ ] **Step 1: Add `md5` dependency**

In `crates/sp_core/Cargo.toml`, add `md5 = "0.7"` to `[dependencies]`:

```toml
[dependencies]
serde = { workspace = true }
serde_json = { workspace = true }
regex = "1"
jsonschema = "0.29"
sha2 = "0.10"
chrono = { version = "0.4", features = ["serde"] }
md5 = "0.7"
```

- [ ] **Step 2: Write failing tests**

Create `crates/sp_core/src/services/pattern_id.rs` with tests only:

```rust
/// Derives a semi-deterministic pattern ID from podcast identity.
///
/// Priority: podcastGuid (if non-empty) > feedUrls[0].
/// Returns the first 12 hex characters of the MD5 digest, or `None`
/// if no usable input is available.
pub fn derive_pattern_id(podcast_guid: Option<&str>, feed_urls: &[String]) -> Option<String> {
    todo!()
}

/// Returns `true` if `id` looks like a deterministic pattern ID
/// (exactly 12 lowercase hex characters). Non-matching IDs are
/// implicitly grandfathered.
pub fn is_deterministic_id(id: &str) -> bool {
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derive_from_guid() {
        let id = derive_pattern_id(Some("abcdef-1234"), &[]).unwrap();
        assert_eq!(id.len(), 12);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit()));
        // MD5("abcdef-1234") is stable -- verify determinism
        let id2 = derive_pattern_id(Some("abcdef-1234"), &[]).unwrap();
        assert_eq!(id, id2);
    }

    #[test]
    fn derive_from_feed_url_when_no_guid() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let id = derive_pattern_id(None, &urls).unwrap();
        assert_eq!(id.len(), 12);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn guid_takes_priority_over_feed_url() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let from_guid = derive_pattern_id(Some("my-guid"), &urls).unwrap();
        let from_url = derive_pattern_id(None, &urls).unwrap();
        assert_ne!(from_guid, from_url);
    }

    #[test]
    fn empty_guid_falls_through_to_feed_url() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let from_empty_guid = derive_pattern_id(Some(""), &urls).unwrap();
        let from_none_guid = derive_pattern_id(None, &urls).unwrap();
        assert_eq!(from_empty_guid, from_none_guid);
    }

    #[test]
    fn returns_none_when_no_input() {
        assert!(derive_pattern_id(None, &[]).is_none());
        assert!(derive_pattern_id(Some(""), &[]).is_none());
    }

    #[test]
    fn is_deterministic_id_valid() {
        assert!(is_deterministic_id("a1b2c3d4e5f6"));
        assert!(is_deterministic_id("000000000000"));
        assert!(is_deterministic_id("abcdef123456"));
    }

    #[test]
    fn is_deterministic_id_invalid() {
        assert!(!is_deterministic_id("coten_radio"));       // human-readable
        assert!(!is_deterministic_id("a1b2c3d4e5"));        // too short (10)
        assert!(!is_deterministic_id("a1b2c3d4e5f6a7"));    // too long (14)
        assert!(!is_deterministic_id("a1b2c3d4e5g6"));      // 'g' not hex
        assert!(!is_deterministic_id("A1B2C3D4E5F6"));      // uppercase
        assert!(!is_deterministic_id(""));                   // empty
    }

    #[test]
    fn known_md5_vector() {
        // MD5("hello") = 5d41402abc4b2a76b9719d911017c592
        let id = derive_pattern_id(Some("hello"), &[]).unwrap();
        assert_eq!(id, "5d41402abc4b");
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p audiflow-smartplaylist-core pattern_id`
Expected: FAIL with `not yet implemented`

- [ ] **Step 4: Implement `derive_pattern_id` and `is_deterministic_id`**

Replace the `todo!()` bodies in `crates/sp_core/src/services/pattern_id.rs`:

```rust
pub fn derive_pattern_id(podcast_guid: Option<&str>, feed_urls: &[String]) -> Option<String> {
    let input = podcast_guid
        .filter(|g| !g.is_empty())
        .or_else(|| feed_urls.first().map(|s| s.as_str()))?;
    let digest = md5::compute(input.as_bytes());
    Some(format!("{digest:x}")[..12].to_string())
}

pub fn is_deterministic_id(id: &str) -> bool {
    id.len() == 12 && id.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
}
```

- [ ] **Step 5: Register module in mod.rs**

In `crates/sp_core/src/services/mod.rs`, add the module declaration and re-exports:

```rust
pub mod config_assembler;
pub mod episode_sorter;
pub mod group_sorter;
pub mod helpers;
pub mod pattern_id;
pub mod resolver_service;
pub mod uniqueness;

pub use config_assembler::ConfigAssembler;
pub use episode_sorter::sort_episode_ids_by_published_at;
pub use group_sorter::sort_groups;
pub use helpers::{parse_playlist_structure, parse_year_binding};
pub use pattern_id::{derive_pattern_id, is_deterministic_id};
pub use resolver_service::ResolverService;
pub use uniqueness::{check_uniqueness, UniquenessConflict};
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cargo test -p audiflow-smartplaylist-core pattern_id`
Expected: all 8 tests PASS

- [ ] **Step 7: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

- [ ] **Step 8: Commit**

```bash
git add crates/sp_core/src/services/pattern_id.rs crates/sp_core/src/services/mod.rs crates/sp_core/Cargo.toml Cargo.lock
git commit -m "feat(sp_core): add derive_pattern_id and is_deterministic_id"
```

---

## Task 2: Add derive-pattern-id endpoint to sp_server

**Files:**
- Create: `crates/sp_server/src/routes/derive.rs`
- Modify: `crates/sp_server/src/routes/mod.rs`

- [ ] **Step 1: Create the derive endpoint handler**

Create `crates/sp_server/src/routes/derive.rs`:

```rust
use axum::Json;
use serde_json::Value;
use sp_core::services::derive_pattern_id;

use crate::app::AppError;

/// POST /api/configs/derive-pattern-id
///
/// Derives a deterministic pattern ID from the given podcast identity.
/// Returns the derived ID and which source field was used.
///
/// Request:  `{ "podcastGuid": "...", "feedUrls": ["..."] }`
/// Response: `{ "id": "a1b2c3d4e5f6", "source": "podcastGuid" | "feedUrl" }`
pub async fn derive_pattern_id_handler(
    Json(body): Json<Value>,
) -> Result<Json<Value>, AppError> {
    let guid = body
        .get("podcastGuid")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty());

    let feed_urls: Vec<String> = body
        .get("feedUrls")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string())
                .collect()
        })
        .unwrap_or_default();

    let has_guid = guid.is_some();
    let id = derive_pattern_id(guid, &feed_urls).ok_or_else(|| {
        AppError::bad_request(
            "Cannot derive pattern ID: provide a non-empty podcastGuid or at least one feedUrl",
        )
    })?;

    let source = if has_guid { "podcastGuid" } else { "feedUrl" };

    Ok(Json(serde_json::json!({
        "id": id,
        "source": source,
    })))
}
```

- [ ] **Step 2: Register route in mod.rs**

In `crates/sp_server/src/routes/mod.rs`, add `pub mod derive;` to the module list, and add the route inside `create_router`:

```rust
pub mod config;
pub mod derive;
pub mod events;
pub mod feed;
pub mod health;
pub mod identifiers;
pub mod preview;
pub mod schema;
```

Add this line inside `create_router` after the existing config routes:

```rust
.route(
    "/configs/derive-pattern-id",
    post(derive::derive_pattern_id_handler),
)
```

- [ ] **Step 3: Run build check**

Run: `cargo check -p audiflow-smartplaylist-server`
Expected: compiles without errors

- [ ] **Step 4: Commit**

```bash
git add crates/sp_server/src/routes/derive.rs crates/sp_server/src/routes/mod.rs
git commit -m "feat(sp_server): add POST /api/configs/derive-pattern-id endpoint"
```

---

## Task 3: Enforce deterministic ID on pattern creation

**Files:**
- Modify: `crates/sp_server/src/routes/config.rs`

- [ ] **Step 1: Add enforcement to `create_pattern` handler**

In `crates/sp_server/src/routes/config.rs`, add the import at the top:

```rust
use sp_core::services::derive_pattern_id;
```

Then, in the `create_pattern` function, add validation after the `id` extraction (after line 37, before the `pattern_exists` check). Insert:

```rust
    // Enforce deterministic ID for new patterns.
    let guid = meta
        .get("podcastGuid")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty());
    let feed_urls: Vec<String> = meta
        .get("feedUrls")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string())
                .collect()
        })
        .unwrap_or_default();

    if let Some(expected_id) = derive_pattern_id(guid, &feed_urls) {
        if id != expected_id {
            return Err(AppError::bad_request(format!(
                "Pattern ID must be \"{expected_id}\" (derived from {}). Got \"{id}\".",
                if guid.is_some() { "podcastGuid" } else { "feedUrl" },
            )));
        }
    }
```

- [ ] **Step 2: Run all tests**

Run: `cargo test`
Expected: all tests PASS

- [ ] **Step 3: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

- [ ] **Step 4: Commit**

```bash
git add crates/sp_server/src/routes/config.rs
git commit -m "feat(sp_server): enforce deterministic ID on pattern creation"
```

---

## Task 4: Add pattern ID integrity validation to CLI

**Files:**
- Modify: `crates/sp_cli/src/cmd_validate.rs`

- [ ] **Step 1: Add import**

In `crates/sp_cli/src/cmd_validate.rs`, add to the existing sp_core imports:

```rust
use sp_core::services::{check_uniqueness, derive_pattern_id, is_deterministic_id};
```

- [ ] **Step 2: Add `validate_pattern_id_integrity` function**

Add this function after `validate_cross_pattern_uniqueness`:

```rust
/// Checks that deterministic pattern IDs match their expected derivation.
/// Grandfathered (non-12-hex) IDs are skipped.
fn validate_pattern_id_integrity(patterns_dir: &Path) -> anyhow::Result<u32> {
    let metas = load_pattern_metas(patterns_dir)?;
    let mut error_count = 0u32;

    for meta in &metas {
        if !is_deterministic_id(&meta.id) {
            continue; // grandfathered
        }
        let expected = derive_pattern_id(
            meta.podcast_guid.as_deref(),
            &meta.feed_urls,
        );
        if let Some(expected_id) = expected {
            if meta.id != expected_id {
                println!(
                    "  FAIL: pattern \"{}\" -- ID mismatch: expected \"{expected_id}\"",
                    meta.id,
                );
                error_count += 1;
            }
        }
    }

    Ok(error_count)
}
```

- [ ] **Step 3: Call the new validation in `validate_all`**

In `validate_all`, add a call after `validate_cross_pattern_uniqueness` (line 40):

```rust
    error_count += validate_cross_pattern_uniqueness(patterns_dir)?;
    error_count += validate_pattern_id_integrity(patterns_dir)?;
```

- [ ] **Step 4: Call the new validation in `validate_files` (directory branch)**

In the `validate_files` function, inside the `if path.is_dir()` block, add after `validate_cross_pattern_uniqueness` (line 76):

```rust
            error_count += validate_cross_pattern_uniqueness(&patterns_dir)?;
            error_count += validate_pattern_id_integrity(&patterns_dir)?;
```

- [ ] **Step 5: Run all tests**

Run: `cargo test`
Expected: all tests PASS

- [ ] **Step 6: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

- [ ] **Step 7: Commit**

```bash
git add crates/sp_cli/src/cmd_validate.rs
git commit -m "feat(sp_cli): validate deterministic pattern ID integrity"
```

---

## Task 5: Add derive-pattern-id query hook to sp_react

**Files:**
- Modify: `packages/sp_react/src/api/queries.ts`

- [ ] **Step 1: Add `useDerivePatternId` mutation**

In `packages/sp_react/src/api/queries.ts`, add after `useCreatePattern`:

```typescript
export function useDerivePatternId() {
  const client = useApiClient();
  return useMutation({
    mutationFn: (params: {
      podcastGuid?: string | null;
      feedUrls?: string[] | null;
    }) =>
      client.post<{ id: string; source: string }>(
        '/api/configs/derive-pattern-id',
        {
          podcastGuid: params.podcastGuid ?? null,
          feedUrls: params.feedUrls ?? [],
        },
      ),
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/sp_react/src/api/queries.ts
git commit -m "feat(sp_react): add useDerivePatternId mutation hook"
```

---

## Task 6: Create use-derive-pattern-id hook with debounce

**Files:**
- Create: `packages/sp_react/src/hooks/use-derive-pattern-id.ts`

- [ ] **Step 1: Create the debounced derivation hook**

Create `packages/sp_react/src/hooks/use-derive-pattern-id.ts`:

```typescript
import { useEffect, useRef, useState } from 'react';
import { useDerivePatternId } from '@/api/queries.ts';

interface DeriveResult {
  id: string | null;
  source: string | null;
  isLoading: boolean;
}

/**
 * Debounced hook that derives a deterministic pattern ID from
 * podcastGuid and feedUrls via the server endpoint.
 *
 * Returns `null` ID when neither input is provided.
 * Only fires after 300ms of input stability.
 */
export function useDerivedPatternId(
  podcastGuid: string | null | undefined,
  feedUrls: string[] | null | undefined,
): DeriveResult {
  const mutation = useDerivePatternId();
  const [result, setResult] = useState<{ id: string | null; source: string | null }>({
    id: null,
    source: null,
  });
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const hasInput =
    (podcastGuid != null && podcastGuid !== '') ||
    (feedUrls != null && 0 < feedUrls.filter(Boolean).length);

  useEffect(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    if (!hasInput) {
      setResult({ id: null, source: null });
      return;
    }

    timerRef.current = setTimeout(() => {
      mutation.mutate(
        { podcastGuid, feedUrls },
        {
          onSuccess: (data) => setResult({ id: data.id, source: data.source }),
          onError: () => setResult({ id: null, source: null }),
        },
      );
    }, 300);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, [podcastGuid, JSON.stringify(feedUrls)]); // eslint-disable-line react-hooks/exhaustive-deps

  return {
    id: result.id,
    source: result.source,
    isLoading: mutation.isPending,
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/sp_react/src/hooks/use-derive-pattern-id.ts
git commit -m "feat(sp_react): add useDerivedPatternId hook with debounce"
```

---

## Task 7: Auto-populate read-only ID in PatternSettingsCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/pattern-settings.tsx`

- [ ] **Step 1: Update PatternSettingsCard for auto-derived ID**

In `packages/sp_react/src/components/editor/pattern-settings.tsx`:

Add import:

```typescript
import { useDerivedPatternId } from '@/hooks/use-derive-pattern-id.ts';
import { Loader2 } from 'lucide-react';
```

Add `useRef` and `useEffect` to the existing React imports:

```typescript
import { useRef, useEffect } from 'react';
```

Inside `PatternSettingsCard`, after the `useDuplicateCheck` call (line 30), add:

```typescript
  const isNewConfig = configId === null;
  const derived = useDerivedPatternId(
    isNewConfig ? podcastGuid : undefined,
    isNewConfig ? feedUrls : undefined,
  );

  // Auto-populate ID when derived value changes (new config only)
  const prevDerivedId = useRef<string | null>(null);
  useEffect(() => {
    if (!isNewConfig || !derived.id || derived.id === prevDerivedId.current) return;
    prevDerivedId.current = derived.id;
    setValue('id', derived.id, { shouldDirty: true });
  }, [isNewConfig, derived.id, setValue]);
```

Then replace the Config ID input field (the `<div>` containing `config-id`) with:

```tsx
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-id" hint="patternId">
              {t('configId')}
            </HintLabel>
            {isNewConfig ? (
              <div className="relative">
                <Input
                  id="config-id"
                  {...register('id')}
                  readOnly
                  className="bg-muted"
                  placeholder={t('placeholderDerivedId')}
                />
                {derived.isLoading && (
                  <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-muted-foreground" />
                )}
              </div>
            ) : (
              <Input
                id="config-id"
                {...register('id')}
                readOnly
                className="bg-muted"
              />
            )}
            {isNewConfig && derived.source && (
              <p className="text-xs text-muted-foreground">
                {t('derivedFrom', { source: derived.source === 'podcastGuid' ? t('podcastGuid') : t('feedUrlsLabel') })}
              </p>
            )}
          </div>
```

- [ ] **Step 2: Run TypeScript check**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no type errors

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/pattern-settings.tsx
git commit -m "feat(sp_react): auto-derive read-only pattern ID for new configs"
```

---

## Task 8: Add translations for derived ID

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

- [ ] **Step 1: Add English translations**

In `packages/sp_react/src/locales/en/editor.json`, add after `"placeholderPatternId"`:

```json
  "placeholderDerivedId": "Auto-generated from GUID or feed URL",
  "derivedFrom": "Derived from {{source}}",
```

- [ ] **Step 2: Add Japanese translations**

In `packages/sp_react/src/locales/ja/editor.json`, add after `"placeholderPatternId"`:

```json
  "placeholderDerivedId": "GUID またはフィード URL から自動生成",
  "derivedFrom": "{{source}} から生成",
```

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "feat(i18n): add derived pattern ID translations (en, ja)"
```

---

## Task 9: Run full verification

- [ ] **Step 1: Run all Rust tests**

Run: `cargo test`
Expected: all tests PASS

- [ ] **Step 2: Run Rust linting**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

- [ ] **Step 3: Run React type check**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no type errors

- [ ] **Step 4: Run React lint**

Run: `cd packages/sp_react && npx oxlint`
Expected: no errors

- [ ] **Step 5: Run React tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests PASS

---

## PR Sequence

| PR | Tasks | Branch Strategy |
|----|-------|----------------|
| PR 1 | Task 1 | `feat/deterministic-pattern-ids` (base off `main`) |
| PR 2 | Tasks 2-4 | `feat/deterministic-pattern-ids-enforcement` (base off PR 1 branch) |
| PR 3 | Tasks 5-8 | `feat/deterministic-pattern-ids-frontend` (base off PR 2 branch) |

Each PR should pass Task 9 verification before merging.
