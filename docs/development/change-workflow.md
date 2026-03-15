# Change Workflow

## Before making changes

- Read docs/overview.md for repository purpose and concepts
- Read docs/architecture/module-boundaries.md to understand crate/package boundaries
- If the change involves schemas, read docs/integration/editor-to-schema.md
- If the change involves file structure, read docs/integration/smartplaylist-contract.md
- Identify whether the change is localized to one crate/package or crosses boundaries

## During implementation

- Keep changes within documented module boundaries (see docs/architecture/module-boundaries.md)
- sp_core must remain a pure library with no I/O or framework dependencies
- Domain model changes in sp_core require corresponding Zod schema updates in sp_react
- Add or update tests for all changed behavior
- Follow the branching policy in `.claude/rules/project/branching.md`
- If adding podcast identifier fields, update cross-pattern uniqueness validation in sp_core and sp_server

## Schema change checklist

When modifying JSON Schema or related models:

1. Update schema files in `crates/sp_core/assets/`
2. Update sp_core Rust models and serde attributes
3. Update sp_core tests (`crates/sp_core/tests/schema_tests.rs`, `model_tests.rs`)
4. Update sp_react Zod schema (`packages/sp_react/src/schemas/config-schema.ts`)
5. Update sp_react form components if field names or types changed
6. Notify consumer repos to update their vendored schema copies
7. Update docs/integration/editor-to-schema.md if schema structure changed

## Required updates

Update documentation when:
- Architecture changes (new crates, changed boundaries) -> docs/architecture/*, `.claude/rules/project/architecture.md`
- Schema or config format changes -> docs/integration/editor-to-schema.md, docs/integration/smartplaylist-contract.md
- New API endpoints -> `.claude/rules/project/architecture.md` (route table)
- New concepts or entry points -> docs/overview.md
- Process changes -> this document, docs/development/review-checklist.md

## Validation checklist

```bash
cargo test                                      # Rust tests pass
cargo clippy -- -W warnings                     # Zero clippy warnings
cd packages/sp_react && pnpm test -- --run      # React tests pass
cd packages/sp_react && npx oxlint              # JS lint passes
cd packages/sp_react && npx tsc -b --noEmit     # TypeScript compiles
```

All checks must pass before submitting a PR. Use `make lint` and `make test` as shortcuts.

## When to update

Update this document when: validation commands change, new quality gates are added, the schema change process evolves.
