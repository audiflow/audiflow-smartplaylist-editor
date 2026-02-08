# jj (Jujutsu) Workflow

Bookmark creation is part of the Post-Implementation Checklist in `tech.md`.

## Bookmark Naming Convention

| Type | Format | Example |
|------|--------|---------|
| Feature | `feat/<short-description>` | `feat/mini-player` |
| Bugfix | `fix/<short-description>` | `fix/build-failure` |
| Refactor | `refactor/<short-description>` | `refactor/player-state` |
| Chore | `chore/<short-description>` | `chore/deps-update` |

## Common Commands

```bash
# Create bookmark at current revision
jj bookmark create <name>

# Move bookmark to current revision
jj bookmark move <name>

# List bookmarks
jj bookmark list

# Push bookmark to remote
jj git push --bookmark <name>
```
