# Branching Policy

Never commit directly to `main`. Before making any changes, create a feature branch and work on it.

## Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Feature | `feat/<short-description>` | `feat/mini-player` |
| Bugfix | `fix/<short-description>` | `fix/build-failure` |
| Refactor | `refactor/<short-description>` | `refactor/player-state` |
| Chore | `chore/<short-description>` | `chore/deps-update` |

## Workflow

1. Create a branch from `main`: `git checkout -b <type>/<description>`
2. Make changes and commit on the branch
3. Push and create a PR for review
4. Merge via PR (merge commits only)
