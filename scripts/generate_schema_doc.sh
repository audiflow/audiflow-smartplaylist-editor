#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(unset CDPATH && cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/packages/preset_react/public/docs"

mkdir -p "$DOCS_DIR"

# 1. Copy playlist-definition schema (the only one relevant to editor users)
echo "Copying schema file..."
cp "$REPO_ROOT/crates/preset_core/assets/playlist-definition.schema.json" "$DOCS_DIR/schema.json"

# 2. Generate human-readable HTML
echo "Generating HTML documentation..."
uv run --with json-schema-for-humans \
  generate-schema-doc \
  --config template_name=js \
  --config expand_buttons=true \
  "$DOCS_DIR/schema.json" \
  "$DOCS_DIR/schema.html"

echo "Done. Files written to $DOCS_DIR/"
echo "  - schema.json  (playlist-definition schema)"
echo "  - schema.html  (for human reading)"
