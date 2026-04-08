import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  playlistStructureSchema,
  yearBindingSchema,
  resolverTypeValues,
  sortFieldSchema,
  sortOrderSchema,
  episodeSortFieldSchema,
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
  it('resolverTypes match schema', () => {
    const schemaValues = extractEnum(topProps.resolverType);
    expect([...resolverTypeValues]).toEqual(schemaValues);
  });

  it('playlistStructure values match schema', () => {
    const schemaValues = extractEnum(topProps.playlistStructure);
    expect(playlistStructureSchema.options).toEqual(schemaValues);
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
      playlistStructure: 'grouped',
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
      playlistStructure: 'grouped',
      priority: 100,
      prependSeasonNumber: true,
      episodeFilters: {
        require: [{ title: 'S\\d+' }],
        exclude: [{ title: 'Trailer' }],
      },
      nullSeasonGroupKey: 0,
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
