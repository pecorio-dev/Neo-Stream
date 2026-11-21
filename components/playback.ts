import type { Kind, Progress, VideoSource } from "../lib/types";
import { progressEpisode } from "../lib/resume";

export type PlaybackSource = VideoSource;

/** Equality for transport only. Never display this key or change the URL the decoder receives. */
export function playbackAddress(raw: unknown): string | undefined {
  if (typeof raw !== 'string' || !/^https:\/\/[^\s]+$/i.test(raw)) return;
  try {
    const url = new URL(`https://${raw.slice(8)}`);
    // React Native's URL has a getter-only hash. Query strings, including relay session IDs, matter.
    if (url.hostname && !url.username && !url.password) return url.href.split('#', 1)[0];
  } catch { /* Invalid entries are never passed to the player. */ }
}

export function playableSources(...inputs: unknown[]): PlaybackSource[] {
  const seen = new Set<string>();
  const sources: PlaybackSource[] = [];
  for (const input of inputs) {
    if (!Array.isArray(input)) continue;
    for (const source of input) {
      if (!source || (source.type !== 'video' && source.type !== 'hls')) continue;
      const key = playbackAddress(source.url);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      sources.push(source);
    }
  }
  return sources;
}

export const initialAttempt = { index: 0, generation: 0, failed: [] as number[], exhausted: false };
export type Attempt = typeof initialAttempt;
export type AttemptAction =
  | { type: "fail"; generation: number; count: number }
  | { type: "select"; index: number; count: number }
  | { type: "extend"; count: number }
  | { type: "retry" };

export function updateAttempt(state: Attempt, action: AttemptAction): Attempt {
  if (action.type === "retry") return { ...initialAttempt, generation: state.generation + 1 };
  if (action.type === 'extend') {
    // Only an appended, as-yet untried transport can revive an exhausted inventory.
    if (!state.exhausted || !Number.isSafeInteger(action.count) || action.count <= state.failed.length) return state;
    const failed = new Set(state.failed);
    let index = 0;
    while (failed.has(index)) index++;
    return { ...state, index, generation: state.generation + 1, exhausted: false };
  }
  if (action.type === "select") {
    if (!Number.isInteger(action.index) || action.index < 0 || action.index >= action.count ||
        state.failed.includes(action.index) || state.index === action.index) return state;
    return { ...state, index: action.index, generation: state.generation + 1 };
  }
  if (state.exhausted || action.generation !== state.generation) return state;
  const failed = [...state.failed, state.index];
  for (let offset = 1; offset < action.count; offset++) {
    const index = (state.index + offset) % action.count;
    if (!failed.includes(index)) return { index, generation: state.generation + 1, failed, exhausted: false };
  }
  return { ...state, failed, exhausted: true };
}

export function playbackTarget(kind: Kind, entry?: Progress, season?: number, episode?: number, episodic = kind !== "Film") {
  if (!episodic) return { season: undefined, episode: undefined, position: entry && entry.season == null && entry.episode == null && !(entry.total > 0 && entry.position >= entry.total) ? entry.position : 0 };
  if (season == null || !Number.isInteger(season) || season < 0 ||
      episode == null || !Number.isInteger(episode) || episode < 1) return null;
  const previous = entry ? progressEpisode(entry) : null;
  return { season, episode, position: entry && previous?.season === season && previous.episode === episode ? entry.position : 0 };
}

const onlyVariant = /^(?:(?:auto|sd|hd|full\s?hd|fhd|uhd|hdr|sdr|[248]k|\d{3,4}[pi]?|vf|vo|vostfr|multi|français|anglais|hls|mp4|lecture)\s*)+$/i;
function readerIdentity(source: PlaybackSource) {
  const index = [source.playerIndex, source.player, /[?&]player=(\d+)(?=&|#|$)/i.exec(source.url)?.[1], /^lecteur\s+(\d+)$/i.exec(source.label)?.[1]]
    .map(v => /^(?:(?:lecteur|player)\s+)?([1-9]\d{0,4})$/i.exec(String(v ?? '').trim())?.[1]).find(Boolean);
  const raw = String(source.playerName || (typeof source.player === 'string' ? source.player : '')).trim();
  // Only an explicitly supplied human name, never a URL, token, rendition label or hostname.
  const name = /^[\p{L}][\p{L}\p{M}\p{N} ’'&()_-]{0,47}$/u.test(raw) && !onlyVariant.test(raw) && !/^(?:lecteur|player)(?:\s+\d+)?$/i.test(raw) ? raw : '';
  return { key: index ? `index:${index}` : name ? `name:${name.toLocaleLowerCase('fr')}` : 'unassigned', name: name || (index ? `Lecteur ${index}` : 'Lecture intégrée'), named: !!name };
}

export type Reader = { key: string; name: string; indices: number[] };
/** Transport order is grouped too: a broken rendition first tries another URL from the same reader. */
export function groupReaders(input: PlaybackSource[]): { sources: PlaybackSource[]; readers: Reader[] } {
  const groups = new Map<string, { name: string; variants: PlaybackSource[] }>();
  for (const source of input) {
    const { key, name, named } = readerIdentity(source);
    const group = groups.get(key) ?? { name, variants: [] };
    if (named) group.name = name;
    group.variants.push(source); groups.set(key, group);
  }
  const sources: PlaybackSource[] = [];
  const readers = Array.from(groups, ([key, { name, variants }]) => ({ key, name, indices: variants.map(s => sources.push(s) - 1) }));
  return { sources, readers };
}
