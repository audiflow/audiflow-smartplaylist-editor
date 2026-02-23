import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  patternConfigSchema,
  smartPlaylistSortSpecSchema,
  contentTypeSchema,
  yearHeaderModeSchema,
  resolverTypeSchema,
  sortFieldSchema,
  sortOrderSchema,
  sortConditionSchema,
} from '../config-schema';

// Load vendored schema.json from sp_shared
const schemaPath = resolve(
  __dirname,
  '../../../../sp_shared/assets/schema.json',
);
const schemaJson = JSON.parse(readFileSync(schemaPath, 'utf-8'));
const defs = schemaJson.$defs as Record<string, Record<string, unknown>>;

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

describe('Zod enums match vendored schema.json', () => {
  it('resolverTypes match schema', () => {
    const defProps = (defs.SmartPlaylistDefinition.properties as Record<string, Record<string, unknown>>);
    const schemaValues = extractEnum(defProps.resolverType);
    expect(resolverTypeSchema.options).toEqual(schemaValues);
  });

  it('contentTypes match schema', () => {
    const defProps = (defs.SmartPlaylistDefinition.properties as Record<string, Record<string, unknown>>);
    const schemaValues = extractEnum(defProps.contentType);
    expect(contentTypeSchema.options).toEqual(schemaValues);
  });

  it('yearHeaderModes match schema', () => {
    const defProps = (defs.SmartPlaylistDefinition.properties as Record<string, Record<string, unknown>>);
    const schemaValues = extractEnum(defProps.yearHeaderMode);
    expect(yearHeaderModeSchema.options).toEqual(schemaValues);
  });

  it('sortFields match schema', () => {
    const sortRule = defs.SmartPlaylistSortRule as Record<string, unknown>;
    const props = sortRule.properties as Record<string, Record<string, unknown>>;
    const field = props.field;
    const schemaValues = extractEnum(field);
    expect(sortFieldSchema.options).toEqual(schemaValues);
  });

  it('sortOrders match schema', () => {
    const sortRule = defs.SmartPlaylistSortRule as Record<string, unknown>;
    const props = sortRule.properties as Record<string, Record<string, unknown>>;
    const order = props.order;
    const schemaValues = extractEnum(order);
    expect(sortOrderSchema.options).toEqual(schemaValues);
  });

  it('sortConditionTypes match schema', () => {
    const sortCondition = defs.SmartPlaylistSortCondition;
    const typeField = (sortCondition.properties as Record<string, Record<string, unknown>>).type;
    const schemaValues = extractEnum(typeField);
    // Zod discriminated union options come from the literals
    const zodValues = sortConditionSchema.options.map(
      (opt) => (opt.shape.type as { value: string }).value,
    );
    expect(zodValues).toEqual(schemaValues);
  });
});

describe('Zod-parsed output validates against JSON Schema', () => {
  const validate = createValidator();

  it('minimal playlist definition validates', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'rss',
    });
    const wrapped = {
      version: 1,
      patterns: [{ id: 'test', playlists: [parsed] }],
    };
    const valid = validate(wrapped);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it('full playlist definition validates', () => {
    const parsed = playlistDefinitionSchema.parse({
      id: 'seasons',
      displayName: 'Seasons',
      resolverType: 'rss',
      priority: 100,
      contentType: 'groups',
      yearHeaderMode: 'firstEpisode',
      episodeYearHeaders: true,
      showDateRange: true,
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
    const wrapped = {
      version: 1,
      patterns: [
        {
          id: 'complex',
          podcastGuid: 'guid-123',
          feedUrls: ['https://example.com/feed.xml'],
          yearGroupedEpisodes: true,
          playlists: [parsed],
        },
      ],
    };
    const valid = validate(wrapped);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it('pattern config round-trips through Zod and validates', () => {
    const parsed = patternConfigSchema.parse({
      id: 'test-podcast',
      podcastGuid: 'guid-abc',
      feedUrls: ['https://example.com/feed'],
      yearGroupedEpisodes: true,
      playlists: [
        {
          id: 'main',
          displayName: 'Main',
          resolverType: 'category',
          groups: [{ id: 'g1', displayName: 'Group 1', pattern: '.*' }],
        },
      ],
    });
    const wrapped = {
      version: 1,
      patterns: [parsed],
    };
    const valid = validate(wrapped);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it('sort spec validates', () => {
    const sort = smartPlaylistSortSpecSchema.parse({
      rules: [{ field: 'alphabetical', order: 'ascending' }],
    });
    const wrapped = {
      version: 1,
      patterns: [
        {
          id: 'test',
          playlists: [
            {
              id: 'p1',
              displayName: 'P1',
              resolverType: 'rss',
              customSort: sort,
            },
          ],
        },
      ],
    };
    const valid = validate(wrapped);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });
});
