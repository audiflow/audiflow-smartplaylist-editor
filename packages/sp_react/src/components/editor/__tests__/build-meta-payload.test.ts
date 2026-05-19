import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import Ajv from 'ajv';
import { describe, it, expect } from 'vitest';
import {
  buildUpdateMetaPayload,
  buildCreateMetaPayload,
  buildCreatePatternPayload,
  type MetaPayloadSnapshot,
} from '../editor-layout.tsx';

/**
 * Regression coverage for the tri-state `showEpisodeThumbnail` round-trip
 * on the **update** endpoint (`PUT /api/configs/patterns/{id}/meta`).
 *
 * The server's update flow strips unknown keys before validation and treats
 * JSON `null` as "remove key from disk", so the client must translate an
 * undefined snapshot value into an explicit `null` payload. Without this,
 * cycling the toggle back to "unset" cannot reach the on-disk absence and
 * the field is permanently stuck at the last explicit value.
 */
describe('buildUpdateMetaPayload', () => {
  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('sends showEpisodeThumbnail=true when snapshot is true', () => {
    const out = buildUpdateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: true },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBe(true);
  });

  it('sends showEpisodeThumbnail=false when snapshot is false', () => {
    const out = buildUpdateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBe(false);
  });

  it('sends null when snapshot is undefined to clear on-disk value', () => {
    const out = buildUpdateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: undefined },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBeNull();
  });

  it('forces id to the route-derived value', () => {
    const out = buildUpdateMetaPayload(baseSnapshot, 'route-id');
    expect(out.id).toBe('route-id');
  });

  it('flattens playlists to an ID array', () => {
    const out = buildUpdateMetaPayload(
      { ...baseSnapshot, playlists: [{ id: 'a' }, { id: 'b' }] },
      'p1',
    );
    expect(out.playlists).toEqual(['a', 'b']);
  });
});

/**
 * The **create** endpoint validates the nested `meta` against
 * `pattern-meta.schema.json` directly, which has `additionalProperties: false`
 * and requires `showEpisodeThumbnail` (when present) to be a real boolean.
 * So the create payload must omit `displayName` and only include
 * `showEpisodeThumbnail` when explicitly chosen.
 */
describe('buildCreateMetaPayload', () => {
  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('omits displayName from meta', () => {
    const out = buildCreateMetaPayload(baseSnapshot, 'p1');
    expect('displayName' in out).toBe(false);
  });

  it('sends showEpisodeThumbnail=true when snapshot is true', () => {
    const out = buildCreateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: true },
      'p1',
    );
    expect('showEpisodeThumbnail' in out).toBe(true);
    expect(
      (out as { showEpisodeThumbnail?: boolean }).showEpisodeThumbnail,
    ).toBe(true);
  });

  it('sends showEpisodeThumbnail=false when snapshot is false', () => {
    const out = buildCreateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'p1',
    );
    expect('showEpisodeThumbnail' in out).toBe(true);
    expect(
      (out as { showEpisodeThumbnail?: boolean }).showEpisodeThumbnail,
    ).toBe(false);
  });

  it('omits showEpisodeThumbnail entirely when snapshot is undefined', () => {
    const out = buildCreateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: undefined },
      'p1',
    );
    expect('showEpisodeThumbnail' in out).toBe(false);
  });

  it('forces id to the route-derived value', () => {
    const out = buildCreateMetaPayload(baseSnapshot, 'route-id');
    expect(out.id).toBe('route-id');
  });
});

describe('buildCreatePatternPayload', () => {
  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('keeps outer displayName but omits it from nested meta', () => {
    const out = buildCreatePatternPayload(baseSnapshot, 'new-id');
    expect(out.id).toBe('new-id');
    expect(out.displayName).toBe('P1');
    expect('displayName' in out.meta).toBe(false);
  });

  it('omits showEpisodeThumbnail from meta when snapshot is undefined', () => {
    const out = buildCreatePatternPayload(
      { ...baseSnapshot, showEpisodeThumbnail: undefined },
      'new-id',
    );
    expect('showEpisodeThumbnail' in out.meta).toBe(false);
  });

  it('propagates an explicit false through the meta payload', () => {
    const out = buildCreatePatternPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'new-id',
    );
    expect(
      (out.meta as { showEpisodeThumbnail?: boolean }).showEpisodeThumbnail,
    ).toBe(false);
  });
});

/**
 * Schema round-trip: validate that what `buildCreateMetaPayload` actually
 * sends conforms to the canonical `pattern-meta.schema.json`. This is the
 * real safety net against the regression -- the unit tests above can pass
 * while the schema still rejects the payload (e.g. additional properties or
 * `null` instead of boolean).
 *
 * The server adds `dataVersion` itself on create, so the client never sends
 * it; we drop it from `required` to mirror that division of responsibility.
 */
describe('buildCreateMetaPayload validates against pattern-meta.schema.json', () => {
  const schemaPath = resolve(
    __dirname,
    '../../../../../../crates/preset_core/assets/preset-meta.schema.json',
  );
  const schema = JSON.parse(readFileSync(schemaPath, 'utf-8')) as {
    required: string[];
    [key: string]: unknown;
  };
  const clientSchema = {
    ...schema,
    required: schema.required.filter((r) => r !== 'dataVersion'),
  };
  const ajv = new Ajv({ allErrors: true, strict: false });
  const validate = ajv.compile(clientSchema);

  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('payload with showEpisodeThumbnail=true validates', () => {
    const out = buildCreateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: true },
      'p1',
    );
    const ok = validate(out);
    expect(validate.errors ?? []).toEqual([]);
    expect(ok).toBe(true);
  });

  it('payload with showEpisodeThumbnail=false validates', () => {
    const out = buildCreateMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'p1',
    );
    const ok = validate(out);
    expect(validate.errors ?? []).toEqual([]);
    expect(ok).toBe(true);
  });

  it('payload with showEpisodeThumbnail undefined validates', () => {
    const out = buildCreateMetaPayload(baseSnapshot, 'p1');
    const ok = validate(out);
    expect(validate.errors ?? []).toEqual([]);
    expect(ok).toBe(true);
  });
});
