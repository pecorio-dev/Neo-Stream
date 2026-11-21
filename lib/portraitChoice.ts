import type { Profile } from './types';

export function portraitScope(service: string, profile: Profile) {
  if (!profile.connected) return 'guest';
  // An unrestored profile must not adopt the guest's or another viewer's portrait.
  return profile.accountId && profile.profileId ? JSON.stringify([service, profile.accountId, profile.profileId]) : null;
}

export type PortraitChoices = Record<string, string>;

// Call only with the directory returned by a successful, account-validated create.
export function createdPortraitUpdate<T extends { profile: Profile; portraits: PortraitChoices }>(
  service: string,
  accountId: string,
  before: readonly string[],
  after: readonly string[],
  portraitId: string | null,
  isCurrent: () => boolean,
): ((saved: T) => T) | null {
  // The only creation supported by the server adds the second slot.
  if (!accountId || before.length !== 1 || before[0] !== 'default'
    || after.length !== 2 || !after.includes('default')) return null;
  const profileId = after.find(id => id !== 'default');
  if (!profileId) return null;
  const scope = JSON.stringify([service, accountId, profileId]);
  return saved => {
    if (!isCurrent() || !saved.profile.connected || saved.profile.accountId !== accountId
      || (saved.portraits[scope] ?? null) === portraitId) return saved;
    const portraits = { ...saved.portraits };
    if (portraitId === null) delete portraits[scope]; else portraits[scope] = portraitId;
    return { ...saved, portraits };
  };
}

export function readPortraitChoices(value: unknown, known: (id: string) => boolean): PortraitChoices {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([scope, id]) => {
    if (typeof id !== 'string' || !known(id)) return false;
    if (scope === 'guest') return true;
    if (!scope.startsWith('[') || scope.length > 2048) return false;
    try {
      const parts: unknown = JSON.parse(scope);
      return Array.isArray(parts) && parts.length === 3 && parts.every(p => typeof p === 'string' && p.length > 0);
    } catch { return false; }
  }));
}
