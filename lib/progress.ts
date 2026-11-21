import type { Progress } from "./types";

export type ProgressScope = { accountId: string; profileId: string };
export type ProgressIdentity = ProgressScope & { token: string };
type Entry = { event: string; point: Progress };
export type ProgressSnapshot = ProgressScope & {
  clear: string;
  deleted: [string, string][];
  items: Entry[];
};
type Operation = { event: string; clear: string };
export type ProgressEvent = Operation & (
  | { kind: "put"; deleted: string; point: Progress }
  | { kind: "delete"; deleted: string; id: string }
  | { kind: "clear" }
);
export type ProgressCache = { snapshot: ProgressSnapshot; pending: ProgressEvent[] };
export const PROGRESS_BATCH = 25;
const MAX_VISIBLE = 100;
const MAX_SECONDS = 604800;

const record = (v: unknown) => v && typeof v === "object" && !Array.isArray(v)
  ? v as Record<string, unknown> : null;
export const isProgressId = (v: unknown): v is string =>
  typeof v === "string" && /^[A-Za-z0-9._:-]{1,128}(?![\s\S])/.test(v);
const isNonce = (v: unknown): v is string =>
  typeof v === "string" && /^[a-z0-9]{1,64}(?![\s\S])/.test(v);
const isFence = (v: unknown): v is string => v === "" || isNonce(v);
const isSeconds = (v: unknown): v is number =>
  typeof v === "number" && Number.isFinite(v) && v >= 0 && v <= MAX_SECONDS;
const isEpisodeNumber = (v: unknown): v is number =>
  typeof v === "number" && Number.isInteger(v) && v >= 0 && v <= 10000;
const isTimestamp = (v: unknown): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v > 0;

export function progressScope(value: unknown): ProgressScope | null {
  const v = record(value);
  return v && typeof v.accountId === "string" && /^[1-9][0-9]{0,19}(?![\s\S])/.test(v.accountId)
    && isProgressId(v.profileId)
    ? { accountId: v.accountId, profileId: v.profileId } : null;
}

export function progressKey(service: string, scope: ProgressScope): string {
  return `neostream.progress.v2:${JSON.stringify([service, scope.accountId, scope.profileId])}`;
}

export function normalisePoint(value: unknown): Progress | null {
  const p = record(value);
  if (!p || !isProgressId(p.id) || !isSeconds(p.position) || !isSeconds(p.total) || !isTimestamp(p.updated))
    return null;
  return {
    id: p.id,
    position: p.total > 0 ? Math.min(p.position, p.total) : p.position,
    total: p.total,
    updated: p.updated,
    ...(isEpisodeNumber(p.season) ? { season: p.season } : {}),
    ...(isEpisodeNumber(p.episode) ? { episode: p.episode } : {}),
    // Round-trip lone surrogates safely: JSON sent to PHP must be valid UTF-8.
    ...(typeof p.label === "string" ? {
      label: Array.from(p.label).slice(0, 120).join("").replace(/[\uD800-\uDFFF]/gu, "\uFFFD"),
    } : {}),
  };
}

export function decodeProgressSnapshot(value: unknown, scope: ProgressScope): ProgressSnapshot | null {
  const v = record(value);
  if (!v || v.accountId !== scope.accountId || v.profileId !== scope.profileId
    || !isFence(v.clear) || !Array.isArray(v.deleted) || !Array.isArray(v.items)) return null;
  const deleted: [string, string][] = [];
  const items: Entry[] = [];
  for (const pair of v.deleted) {
    if (!Array.isArray(pair) || pair.length !== 2 || !isProgressId(pair[0]) || !isNonce(pair[1])) return null;
    deleted.push([pair[0], pair[1]]);
  }
  for (const item of v.items) {
    const entry = record(item);
    const point = normalisePoint(entry?.point);
    if (!point || !isNonce(entry?.event)) return null;
    items.push({ point, event: entry.event });
  }
  return { accountId: scope.accountId, profileId: scope.profileId, clear: v.clear, deleted, items };
}

function decodeEvent(value: unknown): ProgressEvent | null {
  const v = record(value);
  if (!v || !isNonce(v.event) || !isFence(v.clear)) return null;
  const common = { event: v.event, clear: v.clear };
  if (v.kind === "clear") return { ...common, kind: "clear" };
  if (!isFence(v.deleted)) return null;
  if (v.kind === "delete" && isProgressId(v.id))
    return { ...common, kind: "delete", id: v.id, deleted: v.deleted };
  const point = v.kind === "put" ? normalisePoint(v.point) : null;
  return point ? { ...common, kind: "put", point, deleted: v.deleted } : null;
}

export function decodeProgressCache(raw: string | null, scope: ProgressScope): ProgressCache | null {
  if (!raw) return null;
  try {
    const v = record(JSON.parse(raw));
    const snapshot = decodeProgressSnapshot(v?.snapshot, scope);
    if (!snapshot || !Array.isArray(v?.pending)) return null;
    return { snapshot, pending: v.pending.map(decodeEvent).filter((e): e is ProgressEvent => !!e) };
  } catch {
    return null;
  }
}

export function emptyProgress(scope: ProgressScope): ProgressCache {
  return {
    snapshot: { accountId: scope.accountId, profileId: scope.profileId, clear: "", deleted: [], items: [] },
    pending: [],
  };
}

function compare(a: Entry, b: Entry): number {
  return a.point.updated - b.point.updated || (a.event > b.event ? 1 : a.event < b.event ? -1 : 0);
}

/** Replay identique au serveur ; une génération de suppression ne se réécrit jamais. */
export function projectProgress({ snapshot, pending }: ProgressCache) {
  let clear = snapshot.clear;
  const deleted = new Map(snapshot.deleted);
  const points = new Map(snapshot.items.map((e) => [e.point.id, e]));
  for (const e of pending) {
    if (e.clear !== clear) continue;
    if (e.kind === "clear") {
      if (e.event === clear) continue;
      clear = e.event;
      deleted.clear();
      points.clear();
      continue;
    }
    const id = e.kind === "put" ? e.point.id : e.id;
    if ((deleted.get(id) ?? "") !== e.deleted) continue;
    if (e.kind === "delete") {
      if (e.event === e.deleted) continue;
      deleted.set(id, e.event);
      points.delete(id);
      continue;
    }
    const previous = points.get(id);
    if (!previous || compare(e, previous) > 0) points.set(id, e);
  }
  return { clear, deleted, points };
}

export function visibleProgress(cache: ProgressCache): Progress[] {
  return [...projectProgress(cache).points.values()].sort((a, b) => compare(b, a))
    .slice(0, MAX_VISIBLE).map((e) => e.point);
}

export function queueProgress(cache: ProgressCache, event: ProgressEvent): ProgressCache {
  let pending = cache.pending;
  if (event.kind === "put") {
    // A newer checkpoint can replace its own generation’s queued predecessor,
    // never deletes/clears. An in-flight batch is a separate immutable copy.
    pending = pending.filter((e) => !(e.kind === "put" && e.point.id === event.point.id
      && e.clear === event.clear && e.deleted === event.deleted && compare(event, e) > 0));
  }
  return { snapshot: cache.snapshot, pending: [...pending, event] };
}

export function acknowledgeProgress(cache: ProgressCache, snapshot: ProgressSnapshot, sent: ProgressEvent[]): ProgressCache {
  const acknowledged = new Set(sent.map((e) => e.event));
  return { snapshot, pending: cache.pending.filter((e) => !acknowledged.has(e.event)) };
}
