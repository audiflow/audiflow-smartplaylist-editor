# v5 Schema Design Spec

## Design Principle

Schema fields follow the data processing pipeline. Reading top-to-bottom mirrors how the app processes episodes.

```
filter -> group -> select -> display
```

## Full Structure

```json
{
  "id": "professors",
  "displayName": "シーズン別",

  "episodeFilters": {
    "require": [{ "title": "regex" }],
    "exclude": [{ "title": "regex" }]
  },

  "grouping": {
    "by": "titleDiscovery",
    "discoveryHint": "regex pattern for group extraction",
    "numberingExtractor": {
      "source": "title",
      "pattern": "regex",
      "seasonGroup": 1,
      "episodeGroup": 2,
      "fallbackSeasonNumber": 0,
      "fallbackEpisodePattern": "regex",
      "fallbackEpisodeCaptureGroup": 1,
      "fallbackToRss": false
    },
    "staticClassifiers": [
      {
        "id": "unique_id",
        "displayName": "Display Name",
        "pattern": "regex",
        "groupItem": { "showDateRange": true, "pinToYear": false },
        "episodeListing": { "sort": { "field": "publishedAt", "order": "ascending" } },
        "episodeItem": { "titleExtractor": { "..." } },
        "numberingExtractor": { "..." }
      }
    ]
  },

  "selector": {
    "partitionBy": "seasonNumber",
    "titleExtractor": { "source": "seasonNumber", "template": "Season {value}" }
  },

  "groupListing": {
    "sort": { "field": "playlistNumber", "order": "ascending" },
    "userSortable": true,
    "sectionBy": {
      "year": { "pin": true },
      "seasonNumber": false
    }
  },

  "groupItem": {
    "showDateRange": true,
    "pinToYear": true,
    "prependSeasonNumber": false,
    "titleExtractor": {
      "source": "title",
      "pattern": "regex",
      "group": 1,
      "template": "format {value}",
      "fallback": { "..." },
      "fallbackValue": "default"
    }
  },

  "episodeListing": {
    "sort": { "field": "publishedAt", "order": "ascending" },
    "showYearHeaders": false
  },

  "episodeItem": {
    "titleExtractor": {
      "source": "title",
      "pattern": "regex",
      "group": 1
    }
  }
}
```

## Pipeline Stages

```
episodeFilters     filter episodes before processing
       |
    grouping       group filtered episodes
       |           - by: seasonNumber | year | titleDiscovery | titleClassifier
       |           - discoveryHint: regex (titleDiscovery fallback)
       |           - numberingExtractor: parse season/episode from titles
       |           - staticClassifiers: manual group definitions (titleClassifier)
       |
    selector       organize groups into dropdown entries
       |           - partitionBy: group | seasonNumber | year
       |           - titleExtractor: names for partitioned entries
       |
    display        how things look
       |--- groupListing   how the group list is arranged
       |--- groupItem      defaults for each group card
       |--- episodeListing  how episodes are arranged within a group
       |--- episodeItem     defaults for each episode row
```

## Field Reference

### Top-Level Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique ID, must match filename |
| `displayName` | string | Name shown to users |

### episodeFilters

Optional. Pre-processing step that includes/excludes episodes before grouping.

| Field | Type | Description |
|-------|------|-------------|
| `require` | array | Include rules (AND). All must match |
| `exclude` | array | Exclude rules (OR). Any match rejects |

### grouping

Required. Defines how episodes are organized into groups.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `by` | enum | yes | `seasonNumber`, `year`, `titleDiscovery`, `titleClassifier` |
| `discoveryHint` | string | no | Regex for titleDiscovery fallback (replaces groups[0].pattern overload) |
| `numberingExtractor` | object | no | Parses season/episode numbers from titles (seasonNumber resolver) |
| `staticClassifiers` | array | conditional | Group definitions. Required for titleClassifier |

### selector

Optional. Controls how groups map to dropdown entries.

| Field | Type | Description |
|-------|------|-------------|
| `partitionBy` | enum | `group`, `seasonNumber`, `year`. Absent = single entry |
| `titleExtractor` | object | Names for partitioned entries (seasonNumber/year) |

### groupListing

Optional. How the group list is arranged.

| Field | Type | Description |
|-------|------|-------------|
| `sort` | object | `{ field, order }` for group ordering |
| `userSortable` | boolean | Allow users to flip sort order |
| `sectionBy` | object | `{ year: { pin: bool }, seasonNumber: bool }` |

### groupItem

Optional. Defaults for individual group display. Overridable per-classifier in staticClassifiers[].groupItem.

| Field | Type | Description |
|-------|------|-------------|
| `showDateRange` | boolean | Show date range on group card |
| `pinToYear` | boolean | Pin group to its earliest year's section |
| `prependSeasonNumber` | boolean | Prefix group title with "S{n}" |
| `titleExtractor` | object | Generates group display names |

### episodeListing

Optional. How episodes are arranged within groups. Overridable per-classifier.

| Field | Type | Description |
|-------|------|-------------|
| `sort` | object | `{ field, order }` for episode ordering |
| `showYearHeaders` | boolean | Show year dividers in episode list |

### episodeItem

Optional. Defaults for individual episode display. Overridable per-classifier.

| Field | Type | Description |
|-------|------|-------------|
| `titleExtractor` | object | Transforms episode display names |

## Rename Map (v4 -> v5)

| v4 | v5 | Notes |
|----|-----|-------|
| `resolverType` | `grouping.by` | |
| `groups` | `grouping.staticClassifiers` | |
| `groups[0].pattern` (titleDiscovery) | `grouping.discoveryHint` | No more overloading |
| `numberingExtractor` | `grouping.numberingExtractor` | Moved into grouping block |
| `presentation` | `selector` | Replaced entirely |
| `groupList` | `groupListing` | Collection-level settings only |
| `groupList.yearBinding` | `groupListing.sectionBy` | Expanded to multiple axes |
| `groupList.showDateRange` | `groupItem.showDateRange` | Moved to item-level |
| `titleExtractor` (top-level) | `groupItem.titleExtractor` | Moved to where it belongs |
| `prependSeasonNumber` | `groupItem.prependSeasonNumber` | Moved to where it belongs |
| `episodeList` | `episodeListing` | Collection-level settings only |
| `episodeList.titleExtractor` | `episodeItem.titleExtractor` | Moved to item-level |
| `episodeFilters` | `episodeFilters` | Unchanged |
| `priority` | `priority` | Unchanged |

## Migration (v4 aliases)

During transition, v4 field names are accepted as aliases:

- Rust: `#[serde(alias = "resolverType")]` on `grouping.by`
- Zod: `z.preprocess(migrateLegacyKeys, ...)` transforms old keys to new

Legacy `presentation` values derive `selector`:
- `"combined"` -> no selector (single entry)
- `"separate"` -> `selector: { partitionBy: "group" }`

## Per-Classifier Overrides

Each entry in `grouping.staticClassifiers` can override display defaults:

```json
{
  "id": "extras",
  "displayName": "Extras",
  "pattern": null,
  "groupItem": { "showDateRange": false },
  "episodeListing": { "sort": { "field": "publishedAt", "order": "descending" } },
  "episodeItem": { "titleExtractor": { "..." } },
  "numberingExtractor": { "..." }
}
```

Omitted fields inherit from the playlist-level defaults.

## Example: ReTACTION RADIO

```json
{
  "id": "professors",
  "displayName": "シーズン別",

  "grouping": {
    "by": "titleDiscovery",
    "discoveryHint": "【(?:出演：)?(.+?)(?:\\s*編.?)?】"
  },

  "selector": {
    "partitionBy": "seasonNumber",
    "titleExtractor": { "source": "seasonNumber", "template": "シーズン {value}" }
  },

  "groupListing": {
    "sort": { "field": "playlistNumber", "order": "ascending" },
    "userSortable": true
  },

  "groupItem": {
    "showDateRange": true,
    "titleExtractor": {
      "source": "title",
      "pattern": "【(?:出演：)?(.+?)\\s*編",
      "group": 1,
      "fallback": {
        "source": "title",
        "pattern": "【(?:出演：)?(.+?)\\s*】",
        "group": 1
      }
    }
  },

  "episodeItem": {
    "titleExtractor": {
      "source": "title",
      "pattern": "#\\d+(?:-\\d+)?\\s+(.+?)\\s*【",
      "group": 1
    }
  }
}
```

## Example: COTEN RADIO (regular series)

```json
{
  "id": "regular",
  "displayName": "レギュラーシリーズ",

  "episodeFilters": {
    "require": [{ "title": "【\\d+-\\d+】" }],
    "exclude": [{ "title": "【COTEN RADIO\\s*ショート" }]
  },

  "grouping": {
    "by": "seasonNumber",
    "numberingExtractor": {
      "source": "title",
      "pattern": "【(\\d+)-(\\d+)】",
      "seasonGroup": 1,
      "episodeGroup": 2,
      "fallbackSeasonNumber": 0,
      "fallbackEpisodePattern": "(\\d+)】",
      "fallbackToRss": true
    }
  },

  "groupListing": {
    "sort": { "field": "playlistNumber", "order": "ascending" },
    "userSortable": true,
    "sectionBy": { "year": { "pin": true } }
  },

  "groupItem": {
    "showDateRange": true,
    "titleExtractor": {
      "source": "title",
      "pattern": "【COTEN RADIO\\s*([^】]+)編\\s*(\\d+)】",
      "group": 1,
      "fallback": {
        "source": "title",
        "pattern": "【COTEN RADIO\\s*(.+?)\\s*(\\d+)】",
        "group": 1
      },
      "fallbackValue": "その他"
    }
  },

  "episodeItem": {
    "titleExtractor": {
      "source": "title",
      "pattern": "【COTEN RADIO\\s*.+?\\s*\\d+】\\s*(.+)",
      "group": 1
    }
  }
}
```
