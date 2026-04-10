#!/usr/bin/env bash
set -euo pipefail

# Copies schema files from the data repo (source of truth) into the editor repo.
# Uses DATA_DIR if set; otherwise defaults to a sibling audiflow-smartplaylist checkout.

REPO_ROOT="$(unset CDPATH && cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/../audiflow-smartplaylist}"
SCHEMA_SRC="$DATA_DIR/schema"
SCHEMA_DST="$REPO_ROOT/crates/sp_core/assets"

if [ ! -d "$SCHEMA_SRC" ]; then
  echo "Error: schema source not found at $SCHEMA_SRC" >&2
  echo "Set DATA_DIR to point at the audiflow-smartplaylist repo." >&2
  exit 1
fi

if [ ! -d "$SCHEMA_DST" ]; then
  echo "Error: schema destination not found at $SCHEMA_DST" >&2
  echo "Expected crates/sp_core/assets to exist in the editor repo." >&2
  exit 1
fi

echo "Syncing schemas from $SCHEMA_SRC -> $SCHEMA_DST"

SCHEMA_FILES="pattern-index.schema.json pattern-meta.schema.json playlist-definition.schema.json"

# Validate all files exist before copying any (prevent partial updates)
missing_count=0
for f in $SCHEMA_FILES; do
  if [ ! -f "$SCHEMA_SRC/$f" ]; then
    echo "  Error: $f not found in source" >&2
    missing_count=$((missing_count + 1))
  fi
done

if [ 0 -lt "$missing_count" ]; then
  echo "Error: $missing_count schema file(s) missing from source. Aborting sync." >&2
  exit 1
fi

# All files validated; now copy each file into the destination
for f in $SCHEMA_FILES; do
  cp "$SCHEMA_SRC/$f" "$SCHEMA_DST/$f"
  echo "  $f"
done

echo "Done. Run 'make schema-doc' to regenerate HTML docs."
