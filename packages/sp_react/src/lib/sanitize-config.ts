import type { PresetConfig, ResolverType } from '@/schemas/config-schema.ts';

/**
 * Removes fields from each playlist that are irrelevant to the current
 * grouping.by resolver type. This ensures hidden fields don't influence
 * preview or get persisted on save, while the form state keeps them for undo.
 *
 * Conditional fields by resolver type:
 * - seasonNumber:      grouping.numberingExtractor, groupItem.titleExtractor
 * - titleDiscovery:    groupItem.titleExtractor, grouping.staticClassifiers
 * - titleClassifier:   grouping.staticClassifiers
 * - year:              groupItem.titleExtractor
 */
export function stripConditionalFields(config: PresetConfig): PresetConfig {
  return {
    ...config,
    playlists: config.playlists.map((playlist) => {
      const rt: ResolverType = playlist.grouping.by;
      const stripped = { ...playlist };
      const grouping = { ...stripped.grouping };

      // numberingExtractor: only seasonNumber
      if (rt !== 'seasonNumber') {
        delete grouping.numberingExtractor;
      }

      // groupItem.titleExtractor: seasonNumber, titleDiscovery, or year
      if (rt !== 'seasonNumber' && rt !== 'titleDiscovery' && rt !== 'year') {
        if (stripped.groupItem) {
          const groupItem = { ...stripped.groupItem };
          delete groupItem.titleExtractor;
          stripped.groupItem = groupItem;
        }
      }

      // groupItem.prependSeasonNumber: only meaningful for seasonNumber groups.
      if (rt !== 'seasonNumber' && stripped.groupItem) {
        const groupItem = { ...stripped.groupItem };
        delete groupItem.prependSeasonNumber;
        stripped.groupItem = groupItem;
      }

      // staticClassifiers: titleClassifier and titleDiscovery only
      if (rt !== 'titleClassifier' && rt !== 'titleDiscovery') {
        delete grouping.staticClassifiers;
      } else if (grouping.staticClassifiers) {
        // Drop matchers still being typed. A matcher is valid only when both
        // `source` and a non-empty `pattern` are set; otherwise treat the
        // group as a catch-all for the duration of the edit so preview
        // requests never carry a half-built Matcher shape.
        grouping.staticClassifiers = grouping.staticClassifiers.map((g) => {
          if (g.pattern && (!g.pattern.source || !g.pattern.pattern)) {
            const { pattern: _omit, ...rest } = g;
            return rest;
          }
          return g;
        });
      }

      stripped.grouping = grouping;
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
