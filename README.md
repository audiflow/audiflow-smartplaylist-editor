# audiflow-smartplaylist-editor

Local web editor for managing [audiflow](https://github.com/audiflow/audiflow) smart playlist configurations. Edit podcast playlist configs through a browser UI, preview resolver results against live RSS feeds, and save changes directly to your local data repo clone.

## Quick Start

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) (edition 2024)
- [Node.js](https://nodejs.org/) 22+
- [pnpm](https://pnpm.io/) 10+

### Setup

1. Clone this repo and a data repo side by side:

```bash
git clone https://github.com/audiflow/audiflow-smartplaylist-editor.git
git clone https://github.com/audiflow/audiflow-smartplaylist.git
```

2. Install dependencies:

```bash
cd audiflow-smartplaylist-editor
make deps
```

3. Start the editor:

```bash
make dev
```

This launches the API server on port 8080 and the React dev server. Open the URL shown by Vite in your browser.

The data directory defaults to `../audiflow-smartplaylist`. Override with:

```bash
DATA_DIR=/path/to/your/data-repo make dev
```

### Docker

```bash
docker build -t audiflow-editor .
docker run -p 8080:8080 -v /path/to/data-repo:/data audiflow-editor
```

## How It Works

The editor reads and writes JSON config files in your locally cloned data repo. You manage git operations (commit, push, PR) yourself.

```
Browser (sp_react)          API server (Rust/axum)
   |                           |
   |<--- HTTP REST API ------->|
   |<--- SSE (file changes) ---|
   |                           |
                         local data repo directory
                         +-- presets/meta.json
                         +-- presets/{id}/meta.json
                         +-- presets/{id}/playlists/{pid}.json
                         +-- .cache/feeds/          (gitignored)
```

Changes you make in the editor are written to disk immediately. The browser receives live updates via SSE when files change on disk.

## Ecosystem

This repo is part of a three-repo ecosystem:

| Repo | Role |
|------|------|
| [audiflow-smartplaylist](https://github.com/audiflow/audiflow-smartplaylist) | Config data for all envs (GitHub Pages) |
| [audiflow](https://github.com/audiflow/audiflow) | Flutter mobile app that fetches configs |

```
editor  <--read/write-->  local data repo  --push-->  GitHub  --CI-->  hosting
                                                                         ^
                                                                    audiflow app
```

## CLI Commands

The binary `audiflow-editor` provides three subcommands:

| Command | Description |
|---------|-------------|
| `serve` | Start the web editor server (`--data-dir`, `--host`, `--port`, `--static-dir`) |
| `validate` | Validate config files against JSON schema |
| `format` | Format/normalize config JSON (`--check` for CI) |

## Project Structure

```
audiflow-smartplaylist-editor/
├── crates/
│   ├── preset_core/       # Domain models, resolvers, schema validation (pure Rust)
│   ├── preset_server/     # API server (axum, tokio, SSE, feed caching)
│   └── preset_cli/        # CLI binary (serve, validate, format)
└── packages/
    └── sp_react/      # React SPA (TanStack, Zustand, shadcn/ui, CodeMirror)
```

## Config File Structure

Configs are stored as a three-level file hierarchy in data repos:

```
patterns/
  meta.json                        # Root: version + pattern summaries
  {presetId}/
    meta.json                      # Pattern: feedUrls, playlistIds, flags
    playlists/
      {playlistId}.json            # Playlist definition
```

The canonical JSON Schema files live in `crates/preset_core/assets/`.

## Development

```bash
make dev          # Start server + React dev server
make dev-server   # Backend only
make dev-ui       # Frontend only
make test         # Run all tests (Rust + React)
make lint         # clippy + oxlint + tsc
make build        # Build React SPA + Rust release binary
make validate     # Validate configs against schema
make format-check # Check JSON formatting
```

See `make help` for the full list.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md)
before submitting a pull request. All contributors must sign the
[Contributor License Agreement](CLA.md).

## License

This project is licensed under the [GNU Affero General Public License v3.0 or later](LICENSE).
