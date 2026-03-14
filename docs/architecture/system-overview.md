# System Overview

## Goal

Provide a local web editor that lets users create and manage smart playlist configurations for the audiflow podcast app, with live preview, schema validation, and file-system reactivity.

## Context

This repository is part of the audiflow podcast ecosystem:
- **audiflow** (Flutter app): Consumes configs from hosted mirrors (GitHub Pages / GCS)
- **audiflow-smartplaylist** (prod data): Static JSON files deployed to GitHub Pages
- **audiflow-smartplaylist-dev** (dev data): Static JSON files deployed to GCS
- **This repo** (editor): Reads/writes config files in a locally cloned data repo

## High-level structure

- **sp_core**: Pure Rust domain library. Models, resolvers, schema validation, services. No framework dependencies.
- **sp_server**: Axum-based local API server. Config CRUD, feed caching, file watching, SSE, static file serving.
- **sp_cli**: CLI binary wrapping sp_server. Subcommands: `serve`, `validate`, `format`.
- **sp_react**: React 19 SPA. Pattern browsing, config editing with forms, live preview, SSE-driven cache invalidation.

## Main data flow

1. User clones a data repo (`audiflow-smartplaylist` or `audiflow-smartplaylist-dev`) locally
2. User starts the editor: `cargo run -- serve --data-dir /path/to/data-repo`
3. `sp_server` reads split config files from the data directory via `LocalConfigRepository`
4. `sp_react` SPA loads in the browser, fetches config data via REST API
5. User edits configs through forms; `sp_server` writes changes atomically to disk
6. `FileWatcherService` detects file changes (including external edits) and broadcasts SSE events
7. `sp_react` receives SSE events and invalidates TanStack Query cache for real-time updates
8. For preview: `sp_server` fetches/caches RSS feeds, runs resolver chain, returns grouped episodes
9. User commits and pushes changes to the data repo themselves

## Primary interfaces

- **Input**: Local JSON config files (split config structure), RSS feed URLs (HTTP/HTTPS)
- **Output**: Modified JSON config files on disk, preview results via API
- **External dependencies**: RSS feed servers (for episode data), local filesystem (for config persistence)
- **Internal API**: REST endpoints on `127.0.0.1` (see `.claude/rules/project/architecture.md` for full route table)

## Design constraints

- **Local-only**: Server binds to `127.0.0.1`, no authentication, no remote config storage
- **Atomic writes**: All file writes go through `.tmp` then rename to prevent partial reads
- **Schema at boundaries**: Three JSON Schemas validate config at write time and via CLI
- **Path traversal protection**: `LocalConfigRepository` validates all path segments
- **Feed URL restriction**: Only `http://` and `https://` URLs accepted for feed fetching
- **Embedded assets**: JSON Schemas embedded via `include_str!`; SPA assets via `rust-embed` (with `--static-dir` override)

## When to update

Update when: crates/packages added or removed, data flow changes, new external dependencies introduced, design constraints modified.
