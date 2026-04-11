import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
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
  it('resolverTypes match schema (v5 values only)', () => {
    const groupingDef = defs.GroupingConfig as Record<string, unknown>;
    const groupingProps = groupingDef.properties as Record<string, Record<string, unknown>>;
    const schemaValues = extractEnum(groupingProps.by);
    // Schema includes both v5 and deprecated v3 aliases; Zod only declares v5 values.
    const legacyAliases = ['rss', 'category', 'titleAppearanceOrder'];
    const v5Only = schemaValues.filter((v: string) => !legacyAliases.includes(v));
    expect([...resolverTypeValues]).toEqual(v5Only);
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
    expect(parsed.grouping.by).toBe('titleDiscovery');
    expect(parsed.grouping.discoveryHint).toBe('【(?:出演：)?(.+?)(?:\\s*編.?)?】');
    expect(parsed.groupItem?.showDateRange).toBe(true);
    expect(parsed.groupItem?.pinToYear).toBe(false);
    expect(parsed.episodeItem?.titleExtractor?.pattern).toBe('#\\d+(?:-\\d+)?\\s+(.+?)\\s*【');
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
    expect(parsed.grouping.by).toBe('seasonNumber');
    expect(parsed.grouping.numberingExtractor?.seasonGroup).toBe(1);
    expect(parsed.groupItem?.showDateRange).toBe(true);
  });
});
