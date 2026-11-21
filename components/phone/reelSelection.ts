import { homeSessions } from '../../lib/resume';
import type { Progress, Title } from '../../lib/types';

export type Frame = { item: Title; entry?: Progress };

/** Hydrated history can contain titles absent from the current catalogue page. */
export function reelSelection(history: { entry: Progress; item: Title }[], items: Title[]) {
  const sessions = homeSessions(history);
  const frames: Frame[] = [];
  const seen = new Set<string>();
  function add(item: Title, entry?: Progress) {
    const id = item.catalogId ?? item.id;
    if (!seen.has(id)) {
      seen.add(id);
      frames.push({ item, entry });
    }
  }
  for (const { item, entry } of sessions) { if (frames.length === 4) break; add(item, entry); }
  const others = frames.slice(1);
  const entries = new Map(sessions.map(v => [v.item.id, v.entry]));
  for (const item of items) { if (frames.length === 6) break; add(item, entries.get(item.id)); }
  return { frames, others };
}
