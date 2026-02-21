# Ecosystem Overview

This repo (`audiflow-smartplaylist-web`) is part of a three-repo ecosystem:

| Repo | Role | What lives there |
|------|------|-----------------|
| [audiflow](https://github.com/reedom/audiflow) | Flutter mobile app (podcast player) | `audiflow_domain` fetches smart playlist configs and caches locally |
| [audiflow-smartplaylist](https://github.com/reedom/audiflow-smartplaylist) | Production config data | JSON files (meta.json, pattern dirs, playlist definitions); deploys to GitHub Pages on push to main |
| [audiflow-smartplaylist-dev](https://github.com/reedom/audiflow-smartplaylist-dev) | Dev config data | Same structure as production; deploys to GCS dev bucket (`audiflow-dev-config`) on push to main |

## Data Flow

```
audiflow-smartplaylist-web          audiflow-smartplaylist           GitHub Pages        audiflow app
(this repo)                   PR    (production config data)  CI    (static hosting)    fetch
sp_react editor  ──────────────>  JSON files on main branch ────>  pages URL  <────────  audiflow_domain

                                    audiflow-smartplaylist-dev      GCS
                              PR    (dev config data)         CI    (dev bucket)
sp_react editor  ──────────────>  JSON files on main branch ────>  audiflow-dev-config
```

- **This repo** reads configs from a data repo and submits changes as GitHub PRs
- **Data repos** are the source of truth; CI syncs them to hosting on merge
- **audiflow app** consumes configs from the hosting layer, never directly from GitHub

## Working with Each Repo

- **audiflow**: Model serialization (JSON keys, field structure) in `audiflow_domain` must stay aligned with the config JSON schema defined in `sp_shared` here
- **audiflow-smartplaylist**: PR target for production config changes submitted by `sp_server`; do not push directly, always go through PR flow
- **audiflow-smartplaylist-dev**: PR target for dev/test config changes; same JSON schema as production, safe for experimentation
