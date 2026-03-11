# audiflow-smartplaylist-editor - Tech Stack

## Core Stack
- **Rust** edition 2024
- **React 19** / **TypeScript** (sp_react package)

## Common Commands

**Build:**
```bash
cargo build            # Debug build
cargo build --release  # Release build
```

**Testing:**
```bash
cargo test     # Run all Rust tests
```

**Linting:**
```bash
cargo clippy -- -W warnings  # Must pass with zero warnings
```

## Post-Implementation Checklist (MANDATORY)

After completing implementation, Claude MUST perform all of the following:

1. **Test**: Run `cargo test` - all tests must pass
2. **Lint**: Run `cargo clippy -- -W warnings` - must have zero warnings

**Do NOT report completion if any of these steps fail.** Fix issues first.
