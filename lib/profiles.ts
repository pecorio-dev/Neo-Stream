import { isProgressId } from "./progress";
import type { AccountProfile } from "./types";

export function decodeProfiles(raw: unknown, accountId: string): AccountProfile[] | null {
  if (!raw || typeof raw !== "object") return null;
  const { accountId: owner, items } = raw as { accountId?: unknown; items?: unknown };
  if (owner !== accountId || !Array.isArray(items) || items.length < 1 || items.length > 2) return null;
  const seen = new Set<string>();
  const profiles: AccountProfile[] = [];
  for (const item of items) {
    if (!item || !isProgressId(item.id) || seen.has(item.id) || typeof item.name !== "string"
      || !item.name.trim() || !Number.isInteger(item.color) || item.color < 0 || item.color > 3) return null;
    seen.add(item.id);
    profiles.push({ id: item.id, name: item.name, color: item.color });
  }
  return seen.has("default") ? profiles : null;
}

export const selectionKey = (service: string, accountId: string) =>
  `neostream.selected-profile.v1:${JSON.stringify([service, accountId])}`;

export function restoreProfile(items: AccountProfile[], id: string | null) {
  return items.find((p) => p.id === id) ?? items.find((p) => p.id === "default");
}
