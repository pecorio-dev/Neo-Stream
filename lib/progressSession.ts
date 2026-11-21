import type { Progress } from "./types";
import {
  acknowledgeProgress,
  decodeProgressCache,
  emptyProgress,
  isProgressId,
  normalisePoint,
  progressKey,
  projectProgress,
  PROGRESS_BATCH,
  queueProgress,
  visibleProgress,
  type ProgressCache,
  type ProgressEvent,
  type ProgressIdentity,
  type ProgressSnapshot,
} from "./progress";

type IO = {
  service: string;
  read: (key: string) => Promise<string | null>;
  write: (key: string, value: string) => Promise<void>;
  get: (identity: ProgressIdentity) => Promise<ProgressSnapshot>;
  post: (identity: ProgressIdentity, events: ProgressEvent[]) => Promise<ProgressSnapshot>;
  show: (items: Progress[]) => void;
  storageError: () => void;
  debounceMs?: number;
};

// Also serializes a quick logout/relogin to the same key while native writes
// are still pending. The credential never goes to progress storage.
const writes = new Map<string, Promise<void>>();
const eventNonce = () => Date.now().toString(36) + Math.random().toString(36).slice(2)
  + Math.random().toString(36).slice(2);

export function createProgressSession(identity: ProgressIdentity, io: IO) {
  const key = progressKey(io.service, identity);
  let cache = emptyProgress(identity);
  let stopped = false;
  let hydrated = false;
  let running = false;
  let paused = false;
  let shouldPull = true;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let readTask: Promise<void> | undefined;
  let early: ((cache: ProgressCache) => ProgressCache)[] = [];
  const playbacks = new WeakMap<object, { clear: string; deleted: string }>();

  function persist(next: () => ProgressCache | Promise<ProgressCache>) {
    const prior = writes.get(key) ?? Promise.resolve();
    const task = prior.then(async () => io.write(key, JSON.stringify(await next()))).catch(() => {
      if (!stopped) io.storageError();
    });
    writes.set(key, task);
    void task.finally(() => { if (writes.get(key) === task) writes.delete(key); });
  }

  function publish() {
    if (stopped) return;
    io.show(visibleProgress(cache));
    const next = cache;
    persist(() => next);
  }

  function hydrate() {
    hydrated = true;
    for (const apply of early) cache = apply(cache);
    early = [];
  }

  async function sync() {
    if (!readTask || stopped || paused || running) return;
    running = true;
    try {
      await readTask;
      if (stopped) return;
      if (shouldPull) {
        const snapshot = await io.get(identity);
        if (stopped) return;
        cache = acknowledgeProgress(cache, snapshot, []);
        if (!hydrated) hydrate();
        shouldPull = false;
        publish();
      }
      while (!stopped && cache.pending.length) {
        const batch = cache.pending.slice(0, PROGRESS_BATCH);
        const snapshot = await io.post(identity, batch);
        if (stopped) return;
        cache = acknowledgeProgress(cache, snapshot, batch);
        publish();
      }
    } catch {
      if (stopped) return;
      // A transport failure never acknowledges the outbox. Do not retry on
      // every player tick while offline; retry on mount or explicit refresh.
      paused = true;
      shouldPull = true;
      if (!hydrated) {
        hydrate();
        publish();
      }
    } finally {
      running = false;
    }
  }

  function enqueue(apply: (cache: ProgressCache) => ProgressCache) {
    if (stopped) return;
    if (!hydrated) {
      early.push(apply);
      return;
    }
    const next = apply(cache);
    if (cache === next) return;
    cache = next;
    publish();
    if (timer || running || paused) return;
    timer = setTimeout(() => {
      timer = undefined;
      void sync();
    }, io.debounceMs ?? 1200);
  }

  return {
    start() {
      if (readTask || stopped) return;
      readTask = (async () => {
        await writes.get(key);
        let stored: ProgressCache | null = null;
        try {
          stored = decodeProgressCache(await io.read(key), identity);
        } catch {
          if (!stopped) io.storageError();
        }
        if (!stopped && stored) {
          cache = stored;
          hydrate();
          publish();
        }
      })();
      return sync();
    },
    retry() {
      if (running || stopped) return;
      paused = false;
      shouldPull = true;
      return sync();
    },
    stop() {
      if (stopped) return;
      stopped = true;
      clearTimeout(timer);
      if (early.length) {
        const pending = early;
        early = [];
        // A logout can preempt the first snapshot. Keep recorded actions
        // under the old key, never rebasing them onto a late server reply.
        persist(async () => {
          const raw = await io.read(key).catch(() => null);
          return pending.reduce((prior, apply) => apply(prior), decodeProgressCache(raw, identity) ?? cache);
        });
      }
    },
    save(point: Progress, playback?: object) {
      const safe = normalisePoint(point);
      if (!safe) return;
      const event = eventNonce();
      enqueue((previous) => {
        const { clear, deleted } = projectProgress(previous);
        const fence = { clear, deleted: deleted.get(safe.id) ?? "" };
        if (playback) {
          // A player already open during a remote deletion must not create a
          // new point on its next tick. Opening a new player starts a new fence.
          const started = playbacks.get(playback);
          if (started && (started.clear !== clear || started.deleted !== fence.deleted)) return previous;
          if (!started) playbacks.set(playback, fence);
        }
        return queueProgress(previous, { kind: "put", event, ...fence, point: safe });
      });
    },
    clear(id?: string) {
      if (id !== undefined && !isProgressId(id)) return;
      const event = eventNonce();
      enqueue((previous) => {
        const { clear, deleted } = projectProgress(previous);
        return queueProgress(previous, id === undefined
          ? { kind: "clear", event, clear }
          : { kind: "delete", event, clear, deleted: deleted.get(id) ?? "", id });
      });
    },
  };
}
