import type { VideoSource } from './types';

const TTL = 30 * 60 * 1000;
const FAILURE_TTL = 2 * 60 * 1000;
const CAPACITY = 128;

export const isReaderKey = (value: unknown): value is string =>
  typeof value === 'string' && value.length === 27 && /^rd_[0-9a-f]{24}$/.test(value);

export const isDeclaredStartupMs = (value: unknown): value is number =>
  typeof value === 'number' && Number.isInteger(value) && value >= 1 && value <= 35_000;

const isFrameMs = (value: unknown): value is number =>
  typeof value === 'number' && value > 0 && value <= 60_000;

export function readerTickets(value: unknown): string[] | undefined {
  if (!Array.isArray(value) || value.length < 1 || value.length > 3 ||
      !Array.from(value).every(v => typeof v === 'string' && v.length === 26 && /^c_[0-9a-f]{24}$/.test(v)) ||
      new Set(value).size !== value.length) return undefined;
  return [...value];
}

export function nextReaderTickets(value: unknown, sent?: readonly string[]): string[] | undefined {
  const next = readerTickets(value);
  if (!next || (sent && (next.length >= sent.length || next.some(ticket => !sent.includes(ticket))))) return undefined;
  return next;
}

export function shouldContinueReaders(remaining: readonly string[] | undefined, exhausted: boolean, openedMenu: boolean, hasError: boolean) {
  return !!remaining?.length && !hasError && (exhausted || openedMenu);
}

/** Only a direct episode VOD and a real frame can supply local evidence. */
export function directReader(source: VideoSource) {
  return source.type === 'hls' || source.type === 'video';
}

// A null score is a recent decoder failure, not an observed startup duration.
type ReaderScores = ReadonlyMap<string, number | null>;
export type ReaderBatch = VideoSource[] | { ordered: VideoSource[] };

export function rankReaderBatch(sources: VideoSource[], scores?: ReaderScores): ReaderBatch {
  const unknown = 60_001, failed = 60_002;
  const score = (source: VideoSource) => {
    if (!directReader(source)) return unknown;
    const local = isReaderKey(source.readerKey) ? scores?.get(source.readerKey) : undefined;
    return local === null ? failed : isFrameMs(local) ? local
      : isDeclaredStartupMs(source.startupMs) ? source.startupMs : unknown;
  };
  const ranked = sources.map(source => ({ source, ms: score(source) }));
  // No signal: keep the legacy grouping. Otherwise the exact ranked order wins.
  return ranked.some(({ ms }) => ms !== unknown)
    ? { ordered: ranked.sort((a, b) => a.ms - b.ms).map(({ source }) => source) }
    : sources;
}

export function preferredReader(scores?: ReaderScores): string | undefined {
  let best = Infinity, key: string | undefined;
  scores?.forEach((ms, reader) => { if (isFrameMs(ms) && ms < best) { best = ms; key = reader; } });
  return key;
}

/** One in-memory cache per authentication session; no transport or user identifiers. */
export function createReaderStartup() {
  const entries = new Map<string, { platform: string; catalogId: string; reader: string; ms: number | null; at: number }>();
  let closed = false;
  const expire = (now: number) => {
    for (const [key, entry] of entries) if (now - entry.at >= (entry.ms === null ? FAILURE_TTL : TTL)) entries.delete(key);
  };
  const put = (platform: string, catalogId: string, reader: unknown, ms: number | null, now: number) => {
    if (closed || !/^(?:f[sm]_\d{1,61}|tt\d{1,61})(?![\s\S])/.test(catalogId) || !isReaderKey(reader)) return;
    expire(now);
    const key = `${platform}:${catalogId}:${reader}`;
    const previous = entries.get(key)?.ms;
    entries.delete(key);
    entries.set(key, { platform, catalogId, reader, ms: ms !== null && typeof previous === 'number' ? (previous + ms) / 2 : ms, at: now });
    if (entries.size > CAPACITY) entries.delete(entries.keys().next().value!);
  };
  return {
    read(platform: string, catalogId: string, now: number) {
      expire(now);
      return new Map(Array.from(entries.values()).filter(v => v.platform === platform && v.catalogId === catalogId).map(v => [v.reader, v.ms]));
    },
    recordFrame(platform: string, catalogId: string, reader: unknown, ms: number, now: number) {
      if (isFrameMs(ms)) put(platform, catalogId, reader, ms, now);
    },
    recordFailure(platform: string, catalogId: string, reader: unknown, now: number) {
      put(platform, catalogId, reader, null, now);
    },
    close() { closed = true; entries.clear(); },
  };
}
