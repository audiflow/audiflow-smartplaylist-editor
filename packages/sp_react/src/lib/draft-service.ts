export interface DraftEntry {
  base: unknown;
  modified: unknown;
  savedAt: string;
}

function parseDraftEntry(raw: string): DraftEntry | null {
  try {
    const parsed: unknown = JSON.parse(raw);
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      'base' in parsed &&
      'modified' in parsed &&
      'savedAt' in parsed
    ) {
      return parsed as DraftEntry;
    }
    return null;
  } catch {
    return null;
  }
}

export class DraftService {
  private storageKey(configId: string | null): string {
    return `autosave:${configId ?? '__new__'}`;
  }

  saveDraft(params: {
    configId: string | null;
    base: unknown;
    modified: unknown;
  }): void {
    const entry: DraftEntry = {
      base: params.base,
      modified: params.modified,
      savedAt: new Date().toISOString(),
    };
    localStorage.setItem(
      this.storageKey(params.configId),
      JSON.stringify(entry),
    );
  }

  loadDraft(configId: string | null): DraftEntry | null {
    const raw = localStorage.getItem(this.storageKey(configId));
    if (!raw) return null;
    return parseDraftEntry(raw);
  }

  hasDraft(configId: string | null): boolean {
    return localStorage.getItem(this.storageKey(configId)) !== null;
  }

  clearDraft(configId: string | null): void {
    localStorage.removeItem(this.storageKey(configId));
  }
}
