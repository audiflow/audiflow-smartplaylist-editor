/**
 * Strips keys with empty-string or null values from a config object before
 * sending to the server. React Hook Form converts null/undefined default
 * values to "" for registered <Input> fields, but the Dart server treats
 * "" as a valid regex (e.g., excludeFilter: "" matches all episodes).
 *
 * The Dart schema validator uses `_optionalString` which passes when the
 * key is absent, but rejects null. So we remove the key entirely.
 */
export function sanitizeConfig(config: unknown): unknown {
  if (config === null || config === undefined) return undefined;
  if (typeof config === 'string') return config === '' ? undefined : config;
  if (Array.isArray(config)) return config.map(sanitizeConfig);
  if (typeof config === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(config)) {
      const sanitized = sanitizeConfig(value);
      if (sanitized !== undefined) {
        result[key] = sanitized;
      }
    }
    return result;
  }
  return config;
}
