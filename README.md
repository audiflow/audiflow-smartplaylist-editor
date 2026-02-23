# audiflow-smartplaylist-web

Local-first web editor and MCP server for managing [audiflow](https://github.com/reedom/audiflow) smart playlist configurations. Edit podcast playlist configs through a browser-based UI, preview resolver results against live RSS feeds, and save changes directly to your local data repo clone.

## Architecture

Dart workspace with three Dart packages plus a React SPA:

```
audiflow-smartplaylist-web/
├── packages/
│   ├── sp_shared/     # Domain models, resolvers, schema, services (pure Dart)
│   ├── sp_server/     # Local API server (shelf)
│   └── sp_react/      # React SPA web editor
└── mcp_server/        # MCP server for Claude integration
```

| Package | Role | Stack |
|---------|------|-------|
| `sp_shared` | Shared domain layer: models, resolvers, JSON schema validation, disk feed cache | Pure Dart |
| `sp_server` | Local API server: config CRUD, preview, feed caching, file watching, SSE | Dart, shelf |
| `sp_react` | Web editor UI: pattern browsing, config editing, live preview | React 19, TanStack, Zustand, shadcn/ui |
| `mcp_server` | Exposes smart playlist operations as MCP tools for Claude | Dart, JSON-RPC 2.0 over stdio |

### How It Works

Both the web server and MCP server read/write config files directly on disk. No authentication, no remote API calls for config operations.

```
Browser (sp_react)          sp_server (Dart)              MCP server (Dart)
   |                           |                              |
   |<--- HTTP REST API ------->|                              |
   |<--- SSE (file changes) ---|                              |
   |                           |                              |
   |                     local data repo directory
   |                     +-- schema/schema.json
   |                     +-- patterns/meta.json
   |                     +-- patterns/{id}/meta.json
   |                     +-- patterns/{id}/playlists/{pid}.json
   |                     +-- .cache/feeds/          (gitignored)
   |                           |                              |
   |                           |--- reads/writes/watches ---->|
   |                           |                              |
   |                           |<---- reads/writes -----------|
   |                           |                              |
                          localhost:8080              stdio JSON-RPC
```

### Ecosystem

This repo is part of a three-repo ecosystem:

```
User clones data repo locally
                |
                v
audiflow-smartplaylist-web              Local data repo clone         GitHub (remote)
(this repo)                 read/write  (on user's machine)  push    (source of truth)
sp_server + sp_react  <───────────────>  JSON files on disk  ──────>  origin/main
mcp_server            <───────────────>
                                                              CI
                                                              ──────>  GitHub Pages / GCS
                                                                          ^
                                                                          |
                                                                       audiflow app fetches
```

- **[audiflow-smartplaylist](https://github.com/reedom/audiflow-smartplaylist)**: Production config data (JSON on GitHub, synced to GitHub Pages)
- **[audiflow-smartplaylist-dev](https://github.com/reedom/audiflow-smartplaylist-dev)**: Dev config data (synced to GCS)
- **[audiflow](https://github.com/reedom/audiflow)**: Flutter mobile app that consumes configs from hosting

Users manage git operations (commit, push, PR) themselves.

## Prerequisites

- [Dart SDK](https://dart.dev/get-dart) 3.10+
- [Node.js](https://nodejs.org/) 22+
- [pnpm](https://pnpm.io/) 10+

## Setup

```bash
# Install all dependencies (Dart + React)
make setup

# Or manually:
dart pub get
cd packages/sp_react && pnpm install
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SP_DATA_DIR` | CWD | Path to a cloned data repo. If unset, auto-detects from current working directory |
| `PORT` | `8080` | Server listen port |
| `WEB_ROOT` | `public` | Directory containing the built React SPA |
| `SP_FEED_CACHE_TTL` | `3600` | Feed cache TTL in seconds |
| `SP_LOG_LEVEL` | `info` | Log verbosity: `info` (method/path/status) or `debug` (also logs request/response bodies for write operations and errors) |

## Development

Clone a data repo alongside this project, then start the server:

```bash
# Start both sp_server (port 8080) and React dev server
make dev

# Or with a custom data directory:
DATA_DIR=/path/to/audiflow-smartplaylist make dev

# Or run them separately:
make server                      # Backend API only
cd packages/sp_react && pnpm dev # React SPA only
```

The data directory defaults to `../audiflow-smartplaylist` relative to this project root. Override it with `DATA_DIR` in Make or `SP_DATA_DIR` as an env var.

## Testing

```bash
make test          # Run all tests (sp_shared, sp_server, mcp_server, sp_react)

make test-shared   # sp_shared only
make test-server   # sp_server only
make test-react    # sp_react only (vitest)
make test-mcp      # mcp_server only
```

## Quality Checks

```bash
make analyze       # Static analysis (dart analyze + TypeScript type check)
make lint          # Linters (dart analyze + oxlint)
make format        # Format all Dart files
make format-check  # Check formatting without applying
```

## MCP Server

The MCP server exposes smart playlist operations as tools for Claude via the [Model Context Protocol](https://modelcontextprotocol.io/). It reads and writes config files directly on the local filesystem and communicates over stdio using JSON-RPC 2.0.

### Available Tools

| Tool | Description |
|------|-------------|
| `search_configs` | Search SmartPlaylist configs by keyword |
| `get_config` | Get a specific config by ID |
| `get_schema` | Retrieve JSON Schema for configs |
| `fetch_feed` | Fetch and parse a podcast RSS feed (disk-cached) |
| `validate_config` | Validate a config against JSON Schema |
| `preview_config` | Preview how a config resolves episodes from a feed |
| `submit_config` | Save a config to disk (validates first) |

### Running Standalone

```bash
# Run from a data repo directory:
cd /path/to/audiflow-smartplaylist && dart run /path/to/mcp_server/bin/mcp_server.dart

# Or with SP_DATA_DIR:
SP_DATA_DIR=/path/to/audiflow-smartplaylist dart run mcp_server/bin/mcp_server.dart
```

### Connecting from Claude Code

Add the following to your Claude Code MCP settings (`.claude/mcp.json` or project-level):

```json
{
  "mcpServers": {
    "audiflow-smartplaylist": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "mcp_server/bin/mcp_server.dart"],
      "cwd": "/path/to/audiflow-smartplaylist-web",
      "env": {
        "SP_DATA_DIR": "/path/to/audiflow-smartplaylist"
      }
    }
  }
}
```

### Connecting from Claude Desktop

Add the following to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "audiflow-smartplaylist": {
      "command": "dart",
      "args": ["run", "mcp_server/bin/mcp_server.dart"],
      "cwd": "/path/to/audiflow-smartplaylist-web",
      "env": {
        "SP_DATA_DIR": "/path/to/audiflow-smartplaylist"
      }
    }
  }
}
```

## Split Config Structure

Configs are stored as a three-level file hierarchy in the data repos:

```
patterns/
  meta.json                             # Root: version + pattern summaries
  {patternId}/
    meta.json                           # Pattern: feedUrls, playlistIds, flags
    playlists/
      {playlistId}.json                 # SmartPlaylistDefinition
```

The canonical JSON Schema lives at `schema/schema.json` inside each data repo.

## License

Private.
