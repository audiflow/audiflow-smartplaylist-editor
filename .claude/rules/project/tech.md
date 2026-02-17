# audiflow v2 - Tech Stack

## Core Stack
- **Flutter 3.38.5** / **Dart 3.10.4**
- **Analyzer**: 10.x (overridden in root pubspec.yaml for Riverpod 4.x compatibility)

## Common Commands

**Analysis:**
```bash
flutter analyze  # Must pass with zero issues
flutter test     # Must pass all tests
```

**Localization:**
```bash
flutter gen-l10n  # Generate from ARB files
```

## Generated Files
- `*.freezed.dart` - Freezed classes
- `*.gr.dart` - GoRouter routes

**Never edit generated files manually!**

## Post-Implementation Checklist (MANDATORY)

After completing implementation, Claude MUST perform all of the following:

1. **Format**: Run `dart_format` tool
2. **Analyze**: Run `analyze_files` tool - must have zero errors/warnings
3. **Tests**: Run `run_tests` tool - all tests must pass
4. **Bookmark**: Run `jj bookmark create <type>/<description>`
   - Naming: `feat/`, `fix/`, `refactor/`, `chore/`

**Do NOT report completion if any of these steps fail.** Fix issues first.
