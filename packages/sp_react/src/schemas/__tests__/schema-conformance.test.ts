import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  presentationSchema,
  partitionByValues,
  yearBindingSchema,
  resolverTypeValues,
  sortFieldSchema,
  sortOrderSchema,
  episodeSortFieldSchema,
  groupingConfigSchema,
  groupItemConfigSchema,
  episodeItemConfigSchema,
} from '../config-schema';

// Load canonical playlist-definition.schema.json from sp_core
const schemaPath = resolve(
  __dirname,
  '../../../../../crates/sp_core/assets/playlist-definition.schema.json',
);
const schemaJson = JSON.parse(readFileSync(schemaPath, 'utf-8'));
const defs = schemaJson.$defs as Record<string, Record<string, unknown>>;
const topProps = schemaJson.properties as Record<
  string,
  Record<string, unknown>
>;

function extractEnum(property: Record<string, unknown>): string[] {
  if ('enum' in property) {
    return property.enum as string[];
  }
  if ('oneOf' in property) {
    return (property.oneOf as Array<Record<string, unknown>>).map(
      (e) => e.const as string,
    );
  }
  return [];
}

function createValidator() {
  const ajv = new Ajv({ allErrors: true });
  return ajv.compile(schemaJson);
}

describe('Zod enums match vendored playlist-definition schema', () => {
  it('resolverTypes match schema (v4 values present, legacy aliases allowed)', () => {
    const schemaValues = extractEnum(topProps.resolverType);
    // Schema includes both v4 and deprecated v3 aliases; Zod only declares v4 values.
    const legacyAliases = ['rss', 'category', 'titleAppearanceOrder'];
    const v4Only = schemaValues.filter((v: string) => !legacyAliases.includes(v));
    expect([...resolverTypeValues]).toEqual(v4Only);
  });

  it('presentation values match schema (deprecated, includes legacy aliases)', () => {
    const schemaValues = extractEnum(topProps.presentation);
    const legacyAliases = ['grouped', 'split'];
    const v4Only = schemaValues.filter((v: string) => !legacyAliases.includes(v));
    expect(presentationSchema.options).toEqual(v4Only);
  });

  it('partitionBy values match schema', () => {
    const selectorDef = defs.SelectorConfig as Record<string, unknown>;
    const selectorProps = selectorDef.properties as Record<string, Record<string, unknown>>;
    const schemaValues = extractEnum(selectorProps.partitionBy);
    expect([...partitionByValues]).toEqual(schemaValues);
  });

  it('yearBinding values match schema', () => {
    const yearBinding = defs.YearBinding as Record<string, unknown>;
    const schemaValues = extractEnum(yearBinding);
    expect(yearBindingSchema.options).toEqual(schemaValues);
  });

  it('sortFields match schema', () => {
    const sortRule = defs.SortRule as Record<string, unknown>;
    const props = sortRule.properties as Record<
      string,
      Record<string, unknown>
    >;
    const field = props.field;
    const schemaValues = extractEnum(field);
    expect(sortFieldSchema.options).toEqual(schemaValues);
  });

  it('sortOrders match schema', () => {
    const sortOrder = defs.SortOrder as Record<string, unknown>;
    const schemaValues = extractEnum(sortOrder);
    expect(sortOrderSchema.options).toEqual(schemaValues);
  });

  it('episodeSortFields match schema', () => {
    const episodeSortRule = defs.EpisodeSortRule as Record<string, unknown>;
    const props = episodeSortRule.properties as Record<
      string,
      Record<string, unknown>
    >;
    const field = props.field;
    const schemaValues = extractEnum(field);
    expect(episodeSortFieldSchema.options).toEqual(schemaValues);
  });
});

describe('Zod-parsed output validates against playlist-definition schema', () => {
  const validate = createValidator();

  it('minimal playlist definition validates directly', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'seasonNumber',
      presentation: 'combined',
    });
    const valid = validate(parsed);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it('full playlist definition validates directly', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'seasons',
      displayName: 'Seasons',
      resolverType: 'seasonNumber',
      presentation: 'combined',
      priority: 100,
      prependSeasonNumber: true,
      episodeFilters: {
        require: [{ title: 'S\\d+' }],
        exclude: [{ title: 'Trailer' }],
      },
      groups: [
        { id: 'main', displayName: 'Main', pattern: '^Main\\b' },
        { id: 'other', displayName: 'Other' },
      ],
      groupList: {
        yearBinding: 'pinToYear',
        userSortable: true,
        showDateRange: true,
        sort: { field: 'playlistNumber', order: 'descending' },
      },
      episodeList: {
        showYearHeaders: true,
        sort: { field: 'publishedAt', order: 'ascending' },
      },
      titleExtractor: {
        source: 'title',
        pattern: '\\[(.+?)\\]',
        group: 1,
        template: 'Season {value}',
      },
      numberingExtractor: {
        source: 'title',
        pattern: '\\[(\\d+)-(\\d+)\\]',
        seasonGroup: 1,
        episodeGroup: 2,
        fallbackToRss: true,
      },
    });
    const valid = validate(parsed);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });
});

describe('v5-style playlist definition with Zod schemas', () => {
  it('parses a v5-style playlist using grouping, groupItem, episodeItem', () => {
    const input = {
      id: 'professors',
      displayName: 'Seasons',
      grouping: {
        by: 'titleDiscovery',
        discoveryHint: '【(?:出演：)?(.+?)(?:\\s*編.?)?】',
      },
      groupListing: {
        sort: { field: 'playlistNumber', order: 'ascending' },
        userSortable: true,
      },
      groupItem: {
        showDateRange: true,
        pinToYear: false,
        prependSeasonNumber: false,
        titleExtractor: {
          source: 'title',
          pattern: '【(?:出演：)?(.+?)\\s*編',
          group: 1,
        },
      },
      episodeListing: {
        sort: { field: 'publishedAt', order: 'ascending' },
        showYearHeaders: false,
      },
      episodeItem: {
        titleExtractor: {
          source: 'title',
          pattern: '#\\d+(?:-\\d+)?\\s+(.+?)\\s*【',
          group: 1,
        },
      },
    };

    const parsed = playlistDefinitionSchema.parse(input);
    expect(parsed.id).toBe('professors');
    expect(parsed.grouping?.by).toBe('titleDiscovery');
    expect(parsed.grouping?.discoveryHint).toBe('【(?:出演：)?(.+?)(?:\\s*編.?)?】');
    expect(parsed.groupItem?.showDateRange).toBe(true);
    expect(parsed.groupItem?.pinToYear).toBe(false);
    expect(parsed.episodeItem?.titleExtractor?.pattern).toBe('#\\d+(?:-\\d+)?\\s+(.+?)\\s*【');
  });

  it('migrates v4 resolverType to grouping.by via preprocess', () => {
    const input = {
      id: 'legacy',
      displayName: 'Legacy Config',
      resolverType: 'seasonNumber',
    };

    const parsed = playlistDefinitionSchema.parse(input);
    // v4 resolverType is preserved as-is
    expect(parsed.resolverType).toBe('seasonNumber');
    // Migration populates grouping.by from resolverType
    expect(parsed.grouping?.by).toBe('seasonNumber');
  });

  it('does not overwrite explicit grouping with resolverType migration', () => {
    const input = {
      id: 'mixed',
      displayName: 'Mixed',
      resolverType: 'seasonNumber',
      grouping: {
        by: 'titleDiscovery',
        discoveryHint: 'some hint',
      },
    };

    const parsed = playlistDefinitionSchema.parse(input);
    // Explicit grouping takes precedence
    expect(parsed.grouping?.by).toBe('titleDiscovery');
  });

  it('parses groupingConfigSchema independently', () => {
    const input = {
      by: 'titleClassifier',
      staticClassifiers: [
        { id: 'main', displayName: 'Main', pattern: '^Main' },
      ],
    };
    const parsed = groupingConfigSchema.parse(input);
    expect(parsed.by).toBe('titleClassifier');
    expect(parsed.staticClassifiers).toHaveLength(1);
  });

  it('parses groupItemConfigSchema independently', () => {
    const input = {
      showDateRange: true,
      pinToYear: true,
      prependSeasonNumber: false,
      titleExtractor: { source: 'title', pattern: '(.+)', group: 1 },
    };
    const parsed = groupItemConfigSchema.parse(input);
    expect(parsed.showDateRange).toBe(true);
    expect(parsed.pinToYear).toBe(true);
    expect(parsed.titleExtractor?.source).toBe('title');
  });

  it('parses episodeItemConfigSchema independently', () => {
    const input = {
      titleExtractor: { source: 'title', pattern: '#\\d+ (.+)', group: 1 },
    };
    const parsed = episodeItemConfigSchema.parse(input);
    expect(parsed.titleExtractor?.pattern).toBe('#\\d+ (.+)');
  });

  it('accepts a v5 playlist with seasonNumber grouping and numberingExtractor', () => {
    const input = {
      id: 'regular',
      displayName: 'Regular Series',
      grouping: {
        by: 'seasonNumber',
        numberingExtractor: {
          source: 'title',
          pattern: '【(\\d+)-(\\d+)】',
          seasonGroup: 1,
          episodeGroup: 2,
          fallbackToRss: true,
        },
      },
      groupListing: {
        sort: { field: 'playlistNumber', order: 'ascending' },
        userSortable: true,
      },
      groupItem: {
        showDateRange: true,
      },
    };

    const parsed = playlistDefinitionSchema.parse(input);
    expect(parsed.grouping?.by).toBe('seasonNumber');
    expect(parsed.grouping?.numberingExtractor?.seasonGroup).toBe(1);
    expect(parsed.groupItem?.showDateRange).toBe(true);
  });
});
