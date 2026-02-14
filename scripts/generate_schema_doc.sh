#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/packages/sp_web/web/docs"

mkdir -p "$DOCS_DIR"

# 1. Export JSON Schema from Dart
echo "Exporting JSON Schema..."
(cd "$REPO_ROOT/packages/sp_shared" && dart run bin/export_schema.dart "$DOCS_DIR/schema.json")

# 2. Generate human-readable HTML from JSON Schema
echo "Generating HTML documentation..."
uv run --with json-schema-for-humans \
  generate-schema-doc \
  --config template_name=js \
  --config expand_buttons=true \
  "$DOCS_DIR/schema.json" \
  "$DOCS_DIR/schema.html"

echo "Done. Files written to $DOCS_DIR/"
echo "  - schema.json  (for AI / machine consumption)"
echo "  - schema.html  (for human reading)"
