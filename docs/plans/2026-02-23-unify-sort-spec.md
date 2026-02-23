# Unify SmartPlaylistSortSpec Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the `simple`/`composite` type discriminator from `SmartPlaylistSortSpec`, always using a `rules` array.

**Architecture:** Collapse the sealed class hierarchy (`SimpleSmartPlaylistSort` / `CompositeSmartPlaylistSort`) into a single `SmartPlaylistSortSpec` class with `List<SmartPlaylistSortRule> rules`. Update `schema.json`, Dart models, group sorter, resolvers, React Zod schema, and React UI. Legacy `simple` format accepted in `fromJson` for migration but never written.

**Tech Stack:** Dart 3.10, React 19, Zod, React Hook Form, Vitest, JSON Schema draft-07

---

### Task 1: Update `schema.json`

**Files:**
- Modify: `packages/sp_shared/assets/schema.json:204-280`

**Step 1: Replace `SmartPlaylistSortSpec` definition**

Replace the current `SmartPlaylistSortSpec` (with `oneOf` + `type` discriminator) with a plain object:

```json
"SmartPlaylistSortSpec": {
  "type": "object",
  "description": "Sort specification with one or more rules applied in order.",
  "required": [
    "rules"
  ],
  "additionalProperties": false,
  "properties": {
    "rules": {
      "type": "array",
      "description": "Ordered list of sort rules.",
      "items": {
        "$ref": "#/$defs/SmartPlaylistSortRule"
      },
      "minItems": 1
    }
  }
}
```

**Step 2: Verify the rest of schema.json is unchanged**

`SmartPlaylistSortRule` and `SmartPlaylistSortCondition` definitions stay exactly as-is.

**Step 3: Commit**

```bash
jj commit -m "refactor: unify SmartPlaylistSortSpec schema to rules-only"
```

---

### Task 2: Update Dart model (`smart_playlist_sort.dart`)

**Files:**
- Modify: `packages/sp_shared/lib/src/models/smart_playlist_sort.dart`

**Step 1: Write failing tests**

Replace `packages/sp_shared/test/models/smart_playlist_sort_json_test.dart` with:

```dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortSpec JSON', () {
    test('round-trip with single rule', () {
      final sort = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);
      final json = sort.toJson();

      expect(json.containsKey('type'), isFalse);
      expect(json['rules'], isList);

      final decoded = SmartPlaylistSortSpec.fromJson(json);
      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.ascending);
    });

    test('round-trip with multiple rules and conditions', () {
      final sort = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
          condition: SortKeyGreaterThan(0),
        ),
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.ascending,
        ),
      ]);
      final json = sort.toJson();
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded.rules, hasLength(2));
      expect(decoded.rules[0].condition, isA<SortKeyGreaterThan>());
      expect((decoded.rules[0].condition! as SortKeyGreaterThan).value, 0);
      expect(decoded.rules[1].condition, isNull);
    });

    test('fromJson migrates legacy simple format', () {
      final json = {
        'type': 'simple',
        'field': 'playlistNumber',
        'order': 'ascending',
      };
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.ascending);
      expect(decoded.rules[0].condition, isNull);
    });

    test('fromJson migrates legacy composite format', () {
      final json = {
        'type': 'composite',
        'rules': [
          {'field': 'playlistNumber', 'order': 'descending'},
        ],
      };
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.descending);
    });

    test('SmartPlaylistSortCondition.fromJson throws on unknown type', () {
      expect(
        () => SmartPlaylistSortCondition.fromJson({'type': 'unknown'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

**Step 2: Run tests to verify they fail**

```bash
dart test packages/sp_shared/test/models/smart_playlist_sort_json_test.dart
```

Expected: FAIL (classes don't exist yet).

**Step 3: Replace the model**

Replace `packages/sp_shared/lib/src/models/smart_playlist_sort.dart` with:

```dart
/// Fields by which smart playlists can be sorted.
enum SmartPlaylistSortField {
  /// Sort by playlist number.
  playlistNumber,

  /// Sort by newest episode date in smart playlist.
  newestEpisodeDate,

  /// Sort by playback progress (least complete first).
  progress,

  /// Sort alphabetically by display name.
  alphabetical,
}

/// Sort direction.
enum SortOrder { ascending, descending }

/// Specification for how to sort smart playlists.
///
/// Always contains a list of rules. Accepts legacy `simple` and
/// `composite` JSON formats in [fromJson] for migration.
final class SmartPlaylistSortSpec {
  const SmartPlaylistSortSpec(this.rules);

  /// Deserializes from JSON.
  ///
  /// Accepts three formats:
  /// - New: `{ "rules": [...] }`
  /// - Legacy simple: `{ "type": "simple", "field": "...", "order": "..." }`
  /// - Legacy composite: `{ "type": "composite", "rules": [...] }`
  factory SmartPlaylistSortSpec.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    // Legacy simple format: convert to single-rule list.
    if (type == 'simple') {
      return SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.values.byName(json['field'] as String),
          order: SortOrder.values.byName(json['order'] as String),
        ),
      ]);
    }

    // Both new format and legacy composite have a `rules` array.
    final rulesJson = json['rules'] as List<dynamic>;
    return SmartPlaylistSortSpec(
      rulesJson
          .map(
            (e) => SmartPlaylistSortRule.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final List<SmartPlaylistSortRule> rules;

  /// Serializes to JSON. Never writes `type` discriminator.
  Map<String, dynamic> toJson() => {
    'rules': rules.map((r) => r.toJson()).toList(),
  };
}

/// A single sort rule with field, order, and optional condition.
final class SmartPlaylistSortRule {
  const SmartPlaylistSortRule({
    required this.field,
    required this.order,
    this.condition,
  });

  /// Deserializes from JSON.
  factory SmartPlaylistSortRule.fromJson(Map<String, dynamic> json) {
    final conditionJson = json['condition'] as Map<String, dynamic>?;
    return SmartPlaylistSortRule(
      field: SmartPlaylistSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
      condition: conditionJson != null
          ? SmartPlaylistSortCondition.fromJson(conditionJson)
          : null,
    );
  }

  final SmartPlaylistSortField field;
  final SortOrder order;

  /// Optional condition for when this rule applies.
  final SmartPlaylistSortCondition? condition;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
    'field': field.name,
    'order': order.name,
    if (condition != null) 'condition': condition!.toJson(),
  };
}

/// Conditions for conditional sorting rules.
sealed class SmartPlaylistSortCondition {
  const SmartPlaylistSortCondition();

  /// Deserializes from JSON using a `type` discriminator.
  factory SmartPlaylistSortCondition.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'sortKeyGreaterThan' ||
      'greaterThan' => SortKeyGreaterThan.fromJson(json),
      _ => throw FormatException(
        'Unknown SmartPlaylistSortCondition type: $type',
      ),
    };
  }

  /// Serializes to JSON with a `type` discriminator.
  Map<String, dynamic> toJson();
}

/// Condition: smart playlist sort key greater than value.
final class SortKeyGreaterThan extends SmartPlaylistSortCondition {
  const SortKeyGreaterThan(this.value);

  /// Deserializes from JSON.
  factory SortKeyGreaterThan.fromJson(Map<String, dynamic> json) {
    return SortKeyGreaterThan(json['value'] as int);
  }

  final int value;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sortKeyGreaterThan',
    'value': value,
  };
}
```

**Step 4: Update `smart_playlist_sort_test.dart`**

Replace `packages/sp_shared/test/models/smart_playlist_sort_test.dart` with:

```dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortField', () {
    test('all enum values exist', () {
      expect(
        SmartPlaylistSortField.values,
        containsAll([
          SmartPlaylistSortField.playlistNumber,
          SmartPlaylistSortField.newestEpisodeDate,
          SmartPlaylistSortField.progress,
          SmartPlaylistSortField.alphabetical,
        ]),
      );
    });
  });

  group('SortOrder', () {
    test('ascending and descending exist', () {
      expect(
        SortOrder.values,
        containsAll([SortOrder.ascending, SortOrder.descending]),
      );
    });
  });

  group('SmartPlaylistSortSpec', () {
    test('single-rule sort spec holds one rule', () {
      final spec = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);

      expect(spec.rules, hasLength(1));
      expect(spec.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(spec.rules[0].order, SortOrder.ascending);
    });

    test('multi-rule sort spec holds multiple rules', () {
      final spec = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.descending,
        ),
      ]);

      expect(spec.rules.length, 2);
    });
  });
}
```

**Step 5: Run tests to verify they pass**

```bash
dart test packages/sp_shared/test/models/smart_playlist_sort_test.dart packages/sp_shared/test/models/smart_playlist_sort_json_test.dart
```

Expected: PASS

**Step 6: Commit**

```bash
jj commit -m "refactor: collapse SmartPlaylistSortSpec sealed class to single rules-based class"
```

---

### Task 3: Update `group_sorter.dart`

**Files:**
- Modify: `packages/sp_shared/lib/src/services/group_sorter.dart`
- Modify: `packages/sp_shared/test/services/group_sorter_test.dart`

**Step 1: Update the test file**

Replace all `SimpleSmartPlaylistSort(field, order)` with `SmartPlaylistSortSpec([SmartPlaylistSortRule(field: field, order: order)])` and all `CompositeSmartPlaylistSort([...])` with `SmartPlaylistSortSpec([...])`.

In the test file, update the group names from `SimpleSmartPlaylistSort` to `single-rule sort` and from `CompositeSmartPlaylistSort` to `multi-rule sort`.

**Step 2: Run tests to verify they fail**

```bash
dart test packages/sp_shared/test/services/group_sorter_test.dart
```

Expected: FAIL (old class names no longer exist).

**Step 3: Update `group_sorter.dart`**

Replace the function body of `sortGroups` -- no more pattern matching on Simple vs Composite. The logic is now:

```dart
import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_sort.dart';

/// Sorts groups within a playlist according to a [SmartPlaylistSortSpec].
///
/// Returns the groups unchanged when [sortSpec] is null or the list has
/// fewer than two elements. The `progress` field is mobile-only and
/// treated as a no-op in preview.
List<SmartPlaylistGroup> sortGroups(
  List<SmartPlaylistGroup> groups,
  SmartPlaylistSortSpec? sortSpec,
  Map<int, EpisodeData> episodeById,
) {
  if (sortSpec == null || groups.length < 2) return groups;

  SmartPlaylistSortRule? conditionalRule;
  SmartPlaylistSortRule? unconditionalRule;

  for (final rule in sortSpec.rules) {
    if (rule.condition != null && conditionalRule == null) {
      conditionalRule = rule;
    } else if (rule.condition == null && unconditionalRule == null) {
      unconditionalRule = rule;
    }
  }

  if (conditionalRule == null) {
    if (unconditionalRule == null) return groups;
    return _sortByRule(groups, unconditionalRule, episodeById);
  }

  final matching = <SmartPlaylistGroup>[];
  final nonMatching = <SmartPlaylistGroup>[];

  for (final group in groups) {
    if (_matchesCondition(group, conditionalRule.condition!)) {
      matching.add(group);
    } else {
      nonMatching.add(group);
    }
  }

  matching.sort(
    (a, b) => _compareByField(
      conditionalRule!.field,
      a,
      b,
      episodeById,
      conditionalRule.order,
    ),
  );

  if (unconditionalRule != null) {
    nonMatching.sort(
      (a, b) => _compareByField(
        unconditionalRule!.field,
        a,
        b,
        episodeById,
        unconditionalRule.order,
      ),
    );
  }

  return [...matching, ...nonMatching];
}

List<SmartPlaylistGroup> _sortByRule(
  List<SmartPlaylistGroup> groups,
  SmartPlaylistSortRule rule,
  Map<int, EpisodeData> episodeById,
) {
  final sorted = List.of(groups);
  sorted.sort(
    (a, b) => _compareByField(rule.field, a, b, episodeById, rule.order),
  );
  return sorted;
}
```

Keep `_matchesCondition`, `_compareByField`, `_compareNewestDate`, and `_newestDate` unchanged.

**Step 4: Run tests to verify they pass**

```bash
dart test packages/sp_shared/test/services/group_sorter_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
jj commit -m "refactor: simplify group_sorter to use unified SmartPlaylistSortSpec"
```

---

### Task 4: Update resolvers and resolver tests

**Files:**
- Modify: `packages/sp_shared/lib/src/resolvers/rss_metadata_resolver.dart:14-17`
- Modify: `packages/sp_shared/lib/src/resolvers/category_resolver.dart:20-23`
- Modify: `packages/sp_shared/lib/src/resolvers/year_resolver.dart:14-17`
- Modify: `packages/sp_shared/lib/src/resolvers/title_appearance_order_resolver.dart:27-30`
- Modify: `packages/sp_shared/test/resolvers/smart_playlist_resolver_test.dart`
- Modify: `packages/sp_shared/test/resolvers/rss_metadata_resolver_test.dart`
- Modify: `packages/sp_shared/test/resolvers/year_resolver_test.dart`

**Step 1: Update all four resolvers' `defaultSort`**

Replace each `SimpleSmartPlaylistSort(field, order)` with:

```dart
SmartPlaylistSortSpec get defaultSort => SmartPlaylistSortSpec([
  SmartPlaylistSortRule(
    field: SmartPlaylistSortField.playlistNumber,
    order: SortOrder.ascending,  // or descending for year_resolver
  ),
]);
```

**Step 2: Update resolver tests**

In `smart_playlist_resolver_test.dart`:
- Replace `SimpleSmartPlaylistSort` in `TestSmartPlaylistResolver.defaultSort` with `SmartPlaylistSortSpec([SmartPlaylistSortRule(...)])`
- Change `isA<SimpleSmartPlaylistSort>()` to `isA<SmartPlaylistSortSpec>()`

In `rss_metadata_resolver_test.dart` and `year_resolver_test.dart`:
- Change `isA<SimpleSmartPlaylistSort>()` to `isA<SmartPlaylistSortSpec>()`
- Remove casts to `SimpleSmartPlaylistSort`; instead check `sort.rules[0].field` and `sort.rules[0].order`

**Step 3: Run all resolver tests**

```bash
dart test packages/sp_shared/test/resolvers/
```

Expected: PASS

**Step 4: Commit**

```bash
jj commit -m "refactor: update resolvers to use unified SmartPlaylistSortSpec"
```

---

### Task 5: Update `SmartPlaylistDefinition` test and schema conformance test

**Files:**
- Modify: `packages/sp_shared/test/models/smart_playlist_definition_test.dart`
- Modify: `packages/sp_shared/test/schema/schema_conformance_test.dart`

**Step 1: Update definition test**

In `smart_playlist_definition_test.dart`:
- Replace `SimpleSmartPlaylistSort(field, order)` with `SmartPlaylistSortSpec([SmartPlaylistSortRule(field: field, order: order)])`
- Change `isA<SimpleSmartPlaylistSort>()` to `isA<SmartPlaylistSortSpec>()`

**Step 2: Update schema conformance test**

In `schema_conformance_test.dart`:
- Replace `CompositeSmartPlaylistSort([...])` with `SmartPlaylistSortSpec([...])`
- Update the `sortFields match schema oneOf` test: the schema no longer has `oneOf` on `SmartPlaylistSortSpec`. Instead, read `sortFields` from `SmartPlaylistSortRule.properties.field`.
- Update the `sortOrders match schema enum` test: read from `SmartPlaylistSortRule.properties.order`.

The conformance tests for sortFields/sortOrders should change from:

```dart
final sortSpec = defs['SmartPlaylistSortSpec'] as Map<String, dynamic>;
final simpleVariant = (sortSpec['oneOf'] as List<dynamic>).firstWhere(...);
```

To:

```dart
final sortRule = defs['SmartPlaylistSortRule'] as Map<String, dynamic>;
final props = sortRule['properties'] as Map<String, dynamic>;
final field = props['field'] as Map<String, dynamic>;
final schemaValues = _extractEnum(field);
```

And similarly for `order`.

**Step 3: Run tests**

```bash
dart test packages/sp_shared/test/models/smart_playlist_definition_test.dart packages/sp_shared/test/schema/schema_conformance_test.dart
```

Expected: PASS

**Step 4: Run full sp_shared test suite**

```bash
dart test packages/sp_shared
```

Expected: PASS (all ~155 tests)

**Step 5: Commit**

```bash
jj commit -m "refactor: update definition and conformance tests for unified sort spec"
```

---

### Task 6: Update React Zod schema and config-schema tests

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts:48-69`
- Modify: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`
- Modify: `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts`

**Step 1: Update Zod schema**

Replace the `sortSpecUnionSchema` + `smartPlaylistSortSpecSchema` transform pipeline with:

```typescript
export const smartPlaylistSortSpecSchema = z
  .unknown()
  .transform((v) => {
    if (v == null || typeof v !== 'object') return null;
    const obj = v as Record<string, unknown>;

    // Legacy simple format: convert to rules array
    if (obj.type === 'simple' && 'field' in obj && 'order' in obj) {
      return { rules: [{ field: obj.field, order: obj.order }] };
    }

    // Legacy composite or new format: must have rules array
    if ('rules' in obj && Array.isArray(obj.rules)) {
      // Strip the legacy type field if present
      const { type: _, ...rest } = obj;
      return rest;
    }

    return null;
  })
  .pipe(
    z.object({
      rules: z.array(sortRuleSchema).min(1),
    }).nullable(),
  );
```

**Step 2: Update config-schema.test.ts**

Change the test input from `{ type: 'simple', field: '...', order: '...' }` to `{ rules: [{ field: '...', order: '...' }] }` and update the expected output accordingly. Also add a test for legacy simple migration.

**Step 3: Update schema-conformance.test.ts**

- Update `sortFields match schema` test: read from `SmartPlaylistSortRule.properties.field` instead of finding the simple variant of `SmartPlaylistSortSpec.oneOf`.
- Update `sortOrders match schema enum` test: same approach.
- Update `simple sort validates` test: change to use `{ rules: [...] }` format instead of `{ type: 'simple', ... }`.

**Step 4: Run tests**

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: PASS

**Step 5: Commit**

```bash
jj commit -m "refactor: update React Zod schema for unified sort spec"
```

---

### Task 7: Update React sort form UI

**Files:**
- Modify: `packages/sp_react/src/components/editor/sort-form.tsx`
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

**Step 1: Simplify `SortForm`**

Remove the simple/composite toggle. The form always shows the rules list (using `SortRuleCard`). When `customSort` is null, show an "Enable" button. When enabled, initialize with one rule.

Replace `sort-form.tsx` with:

```tsx
import { useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SortRuleCard } from '@/components/editor/sort-rule-card.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus } from 'lucide-react';

interface SortFormProps {
  index: number;
}

const EMPTY_RULE = { field: 'playlistNumber', order: 'ascending' } as const;

export function SortForm({ index }: SortFormProps) {
  const { control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.customSort` as const;

  const contentType = watch(`playlists.${index}.contentType`);
  const isGroupsMode = contentType === 'groups';
  const customSort = watch(prefix);

  const { fields, append, remove } = useFieldArray({
    control,
    name: `playlists.${index}.customSort.rules` as `playlists.${number}.customSort.rules`,
  });

  const isEnabled = customSort != null;

  function handleToggle() {
    if (isEnabled) {
      setValue(prefix, null, { shouldDirty: true });
    } else {
      setValue(prefix, { rules: [{ ...EMPTY_RULE }] }, { shouldDirty: true });
    }
  }

  return (
    <div className="space-y-4">
      <h4 className="text-sm font-medium">{t('sortSection')}</h4>

      {!isGroupsMode ? (
        <p className="text-muted-foreground text-sm">{t('sortDisabledNote')}</p>
      ) : (
        <>
          <div className="space-y-1.5">
            <HintLabel hint="customSort">{t('sortToggle')}</HintLabel>
            <Button
              type="button"
              variant={isEnabled ? 'default' : 'outline'}
              size="sm"
              onClick={handleToggle}
            >
              {isEnabled ? t('sortEnabled') : t('sortDisabled')}
            </Button>
          </div>

          {isEnabled && (
            <div className="space-y-3">
              {fields.map((field, ruleIndex) => (
                <SortRuleCard
                  key={field.id}
                  playlistIndex={index}
                  ruleIndex={ruleIndex}
                  onRemove={() => remove(ruleIndex)}
                />
              ))}

              <Button
                variant="outline"
                size="sm"
                type="button"
                onClick={() => append({ ...EMPTY_RULE })}
              >
                <Plus className="mr-2 h-4 w-4" />
                {t('addSortRule')}
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
```

**Step 2: Update locale files**

In `packages/sp_react/src/locales/en/editor.json`, replace:
- `"sortType": "Sort Type"` -> remove
- `"sortSimple": "Simple"` -> remove
- `"sortComposite": "Composite"` -> remove
- Add: `"sortToggle": "Custom Sort"`, `"sortEnabled": "Enabled"`, `"sortDisabled": "Disabled"`

In `packages/sp_react/src/locales/ja/editor.json`, replace:
- `"sortType": "ソートタイプ"` -> remove
- `"sortSimple": "シンプル"` -> remove
- `"sortComposite": "複合"` -> remove
- Add: `"sortToggle": "カスタムソート"`, `"sortEnabled": "有効"`, `"sortDisabled": "無効"`

**Step 3: Run tests**

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: PASS

**Step 4: Commit**

```bash
jj commit -m "refactor: simplify sort form UI, remove simple/composite toggle"
```

---

### Task 8: Full validation pass

**Step 1: Run sp_shared tests**

```bash
dart test packages/sp_shared
```

Expected: PASS

**Step 2: Run sp_server tests**

```bash
dart test packages/sp_server
```

Expected: PASS

**Step 3: Run sp_react tests**

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: PASS

**Step 4: Run Dart analysis**

```bash
dart analyze
```

Expected: No issues

**Step 5: Commit and bookmark**

```bash
jj bookmark create refactor/unify-sort-spec
```
