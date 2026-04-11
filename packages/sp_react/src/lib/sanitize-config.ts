import type { PatternConfig, ResolverType } from '@/schemas/config-schema.ts';

/**
 * Removes fields from each playlist that are irrelevant to the current
 * resolverType. This ensures hidden fields don't influence preview or
 * get persisted on save, while the form state keeps them for undo.
 *
 * Conditional fields by resolverType:
 * - seasonNumber:      numberingExtractor, titleExtractor
 * - titleDiscovery:    titleExtractor, groups (groups[0].pattern used as fallback)
 * - titleClassifier:   groups
 * - year:              titleExtractor
 */
export function stripConditionalFields(config: PatternConfig): PatternConfig {
  return {
    ...config,
    playlists: config.playlists.map((playlist) => {
      const rt: ResolverType | undefined = playlist.resolverType ?? undefined;
      const stripped = { ...playlist };

      // numberingExtractor: only seasonNumber
      if (rt !== 'seasonNumber') {
        delete stripped.numberingExtractor;
      }

      // titleExtractor (top-level only): seasonNumber, titleDiscovery, or year
      // Note: episodeList.titleExtractor is NOT stripped -- it is an
      // episode-list display setting independent of resolver type.
      if (rt !== 'seasonNumber' && rt !== 'titleDiscovery' && rt !== 'year') {
        delete stripped.titleExtractor;
      }

      // groups: titleClassifier uses full group definitions;
      // titleDiscovery uses groups[0].pattern as a fallback extraction pattern
      if (rt !== 'titleClassifier' && rt !== 'titleDiscovery') {
        delete stripped.groups;
      }

      return stripped;
    }),
  };
}

/**
 * Strips keys with empty-string or null values from a config object before
 * sending to the server. React Hook Form converts null/undefined default
 * values to "" for registered <Input> fields, but the Rust server treats
 * "" as a valid regex (e.g., a filter pattern of "" matches all episodes).
 *
 * The schema validator expects keys to be absent, not null. So we remove
 * the key entirely.
 */
export function sanitizeConfig(config: unknown): unknown {
  if (config === null || config === undefined) return undefined;
  if (typeof config === 'string') return config === '' ? undefined : config;
  if (Array.isArray(config)) {
    const cleaned = config.map(sanitizeConfig).filter((v) => v !== undefined);
    return cleaned.length === 0 ? undefined : cleaned;
  }
  if (typeof config === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(config)) {
      const sanitized = sanitizeConfig(value);
      if (sanitized !== undefined) {
        result[key] = sanitized;
      }
    }
    return Object.keys(result).length === 0 ? undefined : result;
  }
  return config;
}
