# i18n and Enriched Schema Descriptions

## Problem

Field descriptions in the editor are too brief for users to understand what each option does (e.g., resolver types listed as raw enum values with no explanation). The app is English-only with no internationalization support.

## Solution

1. Add react-i18next for i18n with English and Japanese translations
2. Enrich all field descriptions to explain "what", "when", and "why"
3. Browser locale auto-detection (navigator.language), fallback to English

## Architecture

### i18n Library

- `i18next` + `react-i18next` + `i18next-browser-languagedetector`
- Static imports (no lazy loading; app is small)
- Namespaced JSON translation files

### Translation File Structure

```
src/locales/
  en/
    common.json      # Buttons, labels, errors, nav
    editor.json      # Editor form labels, placeholders, sections
    hints.json       # Enriched field descriptions for tooltips
    preview.json     # Preview panel strings
    settings.json    # Settings/API keys page
    feed.json        # Feed viewer
  ja/
    (same structure)
```

### Integration Points

- `src/lib/i18n.ts`: i18next initialization with browser language detector
- `main.tsx`: Wrap app with I18nextProvider
- Components: Replace hardcoded strings with `t('key')` via `useTranslation(namespace)`
- `HintLabel`: `hint` prop becomes a translation key instead of raw string
- `field-hints.ts`: Removed; replaced by `hints` namespace
- Tests: Mock i18n provider that returns keys as-is

### Enriched Descriptions

Each field gets a description explaining purpose and usage context. Enum fields (resolverType, contentType, etc.) get per-value descriptions explaining when and why to use each option.

### Language Detection

Browser locale auto-detect via `i18next-browser-languagedetector`. No manual toggle UI. Falls back to English for unsupported locales.

## Scope

~150 translation keys across 6 namespaces, 20+ component files migrated.
