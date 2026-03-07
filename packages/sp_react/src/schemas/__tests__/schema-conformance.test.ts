import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  smartPlaylistSortSpecSchema,
  contentTypeSchema,
  yearHeaderModeSchema,
  resolverTypeSchema,
  sortFieldSchema,
  sortOrderSchema,
  sortConditionSchema,
} from '../config-schema';

// Load vendored playlist-definition.schema.json from sp_shared
const schemaPath = resolve(
  __dirname,
  '../../../../sp_shared/assets/playlist-definition.schema.json',
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
  it('resolverTypes match schema', () => {
    const schemaValues = extractEnum(topProps.resolverType);
    expect(resolverTypeSchema.options).toEqual(schemaValues);
  });

  it('contentTypes match schema', () => {
    const schemaValues = extractEnum(topProps.contentType);
    expect(contentTypeSchema.options).toEqual(schemaValues);
  });

  it('yearHeaderModes match schema', () => {
    const schemaValues = extractEnum(topProps.yearHeaderMode);
    expect(yearHeaderModeSchema.options).toEqual(schemaValues);
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
    const sortRule = defs.SortRule as Record<string, unknown>;
    const props = sortRule.properties as Record<
      string,
      Record<string, unknown>
    >;
    const order = props.order;
    const schemaValues = extractEnum(order);
    expect(sortOrderSchema.options).toEqual(schemaValues);
  });

  it('sortConditionTypes match schema', () => {
    const sortCondition = defs.SortCondition;
    const typeField = (
      sortCondition.properties as Record<string, Record<string, unknown>>
    ).type;
    const schemaValues = extractEnum(typeField);
    // Zod discriminated union options come from the literals
    const zodValues = sortConditionSchema.options.map(
      (opt) => (opt.shape.type as { value: string }).value,
    );
    expect(zodValues).toEqual(schemaValues);
  });
});

describe('Zod-parsed output validates against playlist-definition schema', () => {
  const validate = createValidator();

  it('minimal playlist definition validates directly', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'rss',
    });
    const valid = validate(parsed);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it('full playlist definition validates directly', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'seasons',
      displayName: 'Seasons',
      resolverType: 'rss',
      priority: 100,
      contentType: 'groups',
      yearHeaderMode: 'firstEpisode',
      episodeYearHeaders: true,
      showDateRange: true,
      showSortOrderToggle: true,
      showSeasonNumber: true,
      titleFilter: 'S\\d+',
      excludeFilter: 'Trailer',
      requireFilter: '\\[.+\\]',
      nullSeasonGroupKey: 0,
      groups: [
        { id: 'main', displayName: 'Main', pattern: '^Main\\b' },
        { id: 'other', displayName: 'Other' },
      ],
      customSort: {
        type: 'composite',
        rules: [
          {
            field: 'playlistNumber',
            order: 'descending',
            condition: { type: 'sortKeyGreaterThan', value: 0 },
          },
          { field: 'newestEpisodeDate', order: 'descending' },
        ],
      },
      titleExtractor: {
        source: 'title',
        pattern: '\\[(.+?)\\]',
        group: 1,
        template: 'Season {value}',
      },
      smartPlaylistEpisodeExtractor: {
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

  it('sort spec validates within playlist', () => {
    const sort = smartPlaylistSortSpecSchema.parse({
      rules: [{ field: 'alphabetical', order: 'ascending' }],
    });
    const playlist = {
      id: 'p1',
      displayName: 'P1',
      resolverType: 'rss',
      customSort: sort,
    };
    const valid = validate(playlist);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });
});
