# audiflow-smartplaylist-web

Web editor and API server for managing [audiflow](https://github.com/reedom/audiflow) smart playlist configurations. Edit podcast playlist configs through a browser-based UI, preview resolver results against live RSS feeds, and submit changes as GitHub PRs to the data repos.

## Architecture

Dart workspace with three Dart packages plus a React SPA:

```
audiflow-smartplaylist-web/
├── packages/
│   ├── sp_shared/     # Domain models, resolvers, schema, services (pure Dart)
│   ├── sp_server/     # REST API server (shelf)
│   └── sp_react/      # React SPA web editor
└── mcp_server/        # MCP server for Claude integration
```

| Package | Role | Stack |
|---------|------|-------|
| `sp_shared` | Shared domain layer: models, resolvers, JSON schema validation | Pure Dart |
| `sp_server` | Backend API: auth, config CRUD, preview, PR submission | Dart, shelf |
| `sp_react` | Web editor UI: pattern browsing, config editing, live preview | React 19, TanStack, Zustand, shadcn/ui |
| `mcp_server` | Exposes smart playlist operations as MCP tools for Claude | Dart, JSON-RPC 2.0 over stdio |

### Ecosystem

This repo is part of a three-repo ecosystem:

```
audiflow-smartplaylist-web          audiflow-smartplaylist           GitHub Pages        audiflow app
(this repo)                   PR    (production config data)  CI    (static hosting)    fetch
sp_react editor  ──────────────>  JSON files on main branch ────>  pages URL  <────────  audiflow_domain

                                    audiflow-smartplaylist-dev      GCS
                              PR    (dev config data)         CI    (dev bucket)
sp_react editor  ──────────────>  JSON files on main branch ────>  audiflow-dev-config
```

- **[audiflow-smartplaylist](https://github.com/reedom/audiflow-smartplaylist)**: Production config data (JSON on GitHub, synced to GitHub Pages)
- **[audiflow-smartplaylist-dev](https://github.com/reedom/audiflow-smartplaylist-dev)**: Dev config data (synced to GCS)
- **[audiflow](https://github.com/reedom/audiflow)**: Flutter mobile app that consumes configs from hosting

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

### Environment Variables

Copy `.env.example` to `.env` (or create `.env`) and set the following:

| Variable | Description |
|----------|-------------|
| `JWT_SECRET_LOCAL` | JWT signing secret for local development |
| `GITHUB_CLIENT_ID_LOCAL` | GitHub OAuth app client ID |
| `GITHUB_CLIENT_SECRET_LOCAL` | GitHub OAuth app client secret |
| `GITHUB_TOKEN_LOCAL` | GitHub personal access token for config repo access |

## Development

```bash
# Start both sp_server (port 8080) and React dev server
make dev

# Or run them separately:
make server                   # Backend API only
cd packages/sp_react && pnpm dev  # React SPA only
```

The server port defaults to `8080` and can be changed with `SERVER_PORT`:

```bash
SERVER_PORT=3000 make dev
```

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

The MCP server exposes smart playlist operations as tools for Claude via the [Model Context Protocol](https://modelcontextprotocol.io/). It communicates over stdio using JSON-RPC 2.0 and proxies requests to the running `sp_server` REST API.

### Available Tools

| Tool | Description |
|------|-------------|
| `search_configs` | Search SmartPlaylist configs by keyword |
| `get_config` | Get a specific config by ID |
| `get_schema` | Retrieve JSON Schema for configs |
| `fetch_feed` | Fetch and parse a podcast RSS feed |
| `validate_config` | Validate a config against JSON Schema |
| `preview_config` | Preview how a config resolves episodes from a feed |
| `submit_config` | Submit a config change as a GitHub PR |

### Running Standalone

Start `sp_server` first, then run the MCP server:

```bash
make server  # In one terminal
make mcp     # In another terminal
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
        "SP_API_URL": "http://localhost:8080",
        "SP_API_KEY": "<your-api-key>"
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
        "SP_API_URL": "http://localhost:8080",
        "SP_API_KEY": "<your-api-key>"
      }
    }
  }
}
```

### MCP Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SP_API_URL` | `http://localhost:8080` | Base URL of the sp_server REST API |
| `SP_API_KEY` | _(none)_ | API key for authenticating with sp_server (optional for local dev) |

## Deployment

The project deploys as a single Docker image containing both the compiled Dart server and the built React SPA.

```bash
# Dev
make deploy-dev    # Build, push, and deploy to dev (Cloud Run)

# Production
make deploy-prod   # Build, push, and deploy to prod (Cloud Run)
```

Infrastructure is managed with Terraform under `deploy/terraform/`.

## Split Config Structure

Configs are stored as a three-level file hierarchy in the data repos:

```
meta.json                               # Root: version + pattern summaries
{patternId}/
  meta.json                             # Pattern: feedUrls, playlistIds, flags
  playlists/
    {playlistId}.json                   # SmartPlaylistDefinition
```

The canonical JSON Schema lives at `packages/sp_shared/assets/schema.json`.

## License

Private.
