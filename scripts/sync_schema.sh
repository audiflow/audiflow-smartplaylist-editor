#!/usr/bin/env bash
set -euo pipefail

# Copies schema files from the data repo (source of truth) into the editor repo.
# Requires DATA_DIR to point at a cloned audiflow-smartplaylist repo.

REPO_ROOT="$(unset CDPATH && cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/../audiflow-smartplaylist}"
SCHEMA_SRC="$DATA_DIR/schema"
SCHEMA_DST="$REPO_ROOT/crates/sp_core/assets"

if [ ! -d "$SCHEMA_SRC" ]; then
  echo "Error: schema source not found at $SCHEMA_SRC" >&2
  echo "Set DATA_DIR to point at the audiflow-smartplaylist repo." >&2
  exit 1
fi

echo "Syncing schemas from $SCHEMA_SRC -> $SCHEMA_DST"

for f in pattern-index.schema.json pattern-meta.schema.json playlist-definition.schema.json; do
  if [ ! -f "$SCHEMA_SRC/$f" ]; then
    echo "  Warning: $f not found in source, skipping" >&2
    continue
  fi
  cp "$SCHEMA_SRC/$f" "$SCHEMA_DST/$f"
  echo "  $f"
done

echo "Done. Run 'make schema-doc' to regenerate HTML docs."
