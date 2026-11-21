import { useEffect, useState } from "react";
import { apiMedia, detailIssue, hasService, type DetailIssue } from "./api";
import type { MediaInfo, Title } from "./types";

// Public title metadata only. Share a request between Home and the detail sheet;
// never cache user progress here. Expired/failed fetches can be retried.
const cache = new Map<string, { data: MediaInfo; until: number }>();
const pending = new Map<string, Promise<MediaInfo>>();
function cached(id: string) {
  const hit = cache.get(id);
  return hit && hit.until > Date.now() ? hit.data : null;
}
function load(id: string, hints: Pick<Title, "kind" | "episodic" | "title" | "year">, retry: boolean) {
  const existing = pending.get(id);
  if (existing) return existing;
  const job = apiMedia(id, hints, retry).then((data) => {
    if (cache.size >= 32) cache.delete(cache.keys().next().value!);
    cache.set(id, { data, until: Date.now() + 5 * 60_000 });
    return data;
  }).finally(() => pending.delete(id));
  pending.set(id, job);
  return job;
}

export function useTitleMedia(item: Title, enabled = true) {
  const { title, kind, year, episodic } = item;
  const id = item.catalogId ?? item.id;
  const [attempt, setAttempt] = useState(0);
  const [reply, setReply] = useState<{ id: string; attempt: number; data: MediaInfo | null; issue: DetailIssue | null } | null>(null);
  const active = enabled && hasService;
  const data = active ? cached(id) ?? (reply?.id === id && reply.attempt === attempt ? reply.data : null) : null;
  const failed = active && !data && reply?.id === id && reply.attempt === attempt;
  useEffect(() => {
    if (!active || cached(id)) return;
    let live = true;
    load(id, { title, kind, year, episodic }, attempt > 0).then(
      (result) => { if (live) setReply({ id, attempt, data: result, issue: null }); },
      (error) => { if (live) setReply({ id, attempt, data: null, issue: detailIssue(error) }); },
    );
    return () => { live = false; };
  }, [id, title, kind, year, episodic, attempt, active]);
  return { data, loading: active && !data && !failed, failed, issue: failed ? reply.issue : null, retry: () => setAttempt((n) => n + 1) };
}
