import { ApiHttpError } from "./api";

type Page<T> = { items: T[]; nextCursor: string | null };
type Commit<T> = (page: Page<T>) => void;

const DEFAULT_RETRY_MS = 30_000;

export function createRefreshGate() {
  let running = false;
  return async (work: () => Promise<void>) => {
    if (running) return;
    running = true;
    try {
      await work();
    } finally {
      running = false;
    }
  };
}

/** Coordinates one feed without relying on when React publishes state. */
export function createListRequests<T>(load: (cursor?: string) => Promise<Page<T>>, now = Date.now) {
  let cursor: string | null = null;
  let generation = 0;
  let refreshing = false;
  let retryAt = 0;
  const pendingCursors = new Set<string>();

  const recordFailure = (error: unknown) => {
    if (error instanceof ApiHttpError && error.status === 429) {
      retryAt = error.retryAt || now() + DEFAULT_RETRY_MS;
    }
  };
  const commit = (page: Page<T>, publish: Commit<T>) => {
    cursor = page.nextCursor;
    publish(page);
  };

  return {
    stopPagination() { cursor = null; },
    async refresh(publish: Commit<T>) {
      if (refreshing || now() < retryAt) return "skipped";
      refreshing = true;
      generation++;
      try {
        commit(await load(), publish);
      } catch (error) {
        recordFailure(error);
        throw error;
      } finally {
        refreshing = false;
      }
    },
    async loadMore(publish: Commit<T>, onError: (error: unknown) => void) {
      const requested = cursor;
      if (!requested || refreshing || now() < retryAt || pendingCursors.has(requested)) return;
      const startedAt = generation;
      pendingCursors.add(requested);
      try {
        const page = await load(requested);
        if (startedAt !== generation) return;
        commit(page.nextCursor === requested ? { ...page, nextCursor: null } : page, publish);
      } catch (error) {
        if (startedAt !== generation) return;
        recordFailure(error);
        onError(error);
      } finally {
        pendingCursors.delete(requested);
      }
    },
  };
}
