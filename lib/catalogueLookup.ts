import type { Progress, Title } from "./types";

export const CATALOGUE_BATCH = 24;
export const isCanonicalTitle = (id: string) => /^f[sm]_[0-9]{1,61}(?![\s\S])/.test(id);

export function missingHistoryIds(progress: Progress[], known: Title[]) {
  const ids = new Set(known.map((item) => item.id));
  return [...new Set(progress.map(({ id }) => id).filter((id) => isCanonicalTitle(id) && !ids.has(id)))].sort();
}

export function historyCards<Identity extends object>(
  identity: Identity | null,
  progress: Progress[],
  known: Title[],
  resolved: { identity: Identity; items: Title[] } | null,
) {
  if (!identity) return [];
  const items = new Map([
    ...(resolved?.identity === identity ? resolved.items : []),
    ...known,
  ].map((item) => [item.id, item]));
  return progress.flatMap((entry) => {
    const item = items.get(entry.id);
    return item ? [{ entry, item }] : [];
  });
}

type Page = { items: Title[]; nextCursor: string | null };
export type SearchResult = Page & { pending: boolean; error: boolean };

/** One instance per debounced search generation; never publishes after a reset. */
export function createSearchSession(fetchPage: (cursor?: string) => Promise<Page>, show: (state: SearchResult) => void) {
  let active = true;
  let started = false;
  let cursor: string | null = null;
  let busy = false;
  const items = new Map<string, Title>();
  const consumed = new Set<string>();
  const emit = (error = false) => show({ items: [...items.values()], nextCursor: cursor, pending: busy, error });
  return {
    stop: () => { active = false; },
    async load() {
      if (!active || busy || (started && cursor === null)) return;
      busy = true;
      emit();
      const requested = cursor;
      let error = false;
      try {
        const result = await fetchPage(requested ?? undefined);
        if (!active) return;
        started = true;
        if (requested) consumed.add(requested);
        for (const item of result.items) items.set(item.id, item);
        cursor = result.nextCursor && !consumed.has(result.nextCursor) ? result.nextCursor : null;
      } catch {
        error = true;
      } finally {
        busy = false;
        if (active) emit(error);
      }
    },
  };
}
