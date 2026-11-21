import type { Progress, Title } from './types';

export type TvCut = { item: Title; entry?: Progress; id: string };
export type TvShelf = { key: string; title: string; cuts: TvCut[] };
const limit = 10;

/** Keep display/control IDs stable when a newly saved session inserts a row above the catalogue. */
export function tvShelves(items: Title[], sessions: { item: Title; entry: Progress }[]): TvShelf[] {
  const result: TvShelf[] = [];
  const entries = new Map<string, Progress>();
  for (const { item, entry } of sessions) {
    for (const id of [item.id, item.catalogId, entry.id]) if (id && !entries.has(id)) entries.set(id, entry);
  }
  function add(key: string, title: string, source: Title[], kind?: Title['kind']) {
    const cuts: TvCut[] = [], seen = new Set<string>();
    for (const item of source) {
      if ((kind && item.kind !== kind) || seen.has(item.id) || (item.catalogId && seen.has(item.catalogId))) continue;
      seen.add(item.id);
      if (item.catalogId) seen.add(item.catalogId);
      cuts.push({ item, entry: entries.get(item.catalogId ?? item.id) ?? entries.get(item.id), id: `tv-${key}-${item.id}` });
      if (cuts.length === limit) break;
    }
    if (cuts.length) result.push({ key, title, cuts });
  }
  add('resume', 'Reprendre la lecture', sessions.map(s => s.item));
  add('title', 'À l’affiche', items);
  add('films', 'Films', items, 'Film');
  add('series', 'Séries', items, 'Série');
  add('animes', 'Animés', items, 'Animé');
  return result;
}

/** Nearest edge, no movement while the whole target is already visible. */
export function revealOffset(offset: number, viewport: number, start: number, end: number) {
  if (viewport <= 0) return offset;
  return Math.max(0, Math.min(start, Math.max(offset, end - viewport)));
}
