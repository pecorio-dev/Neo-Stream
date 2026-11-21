import { progressScope, type ProgressScope } from './progress';

export type Library = { favorites: string[]; searches: string[] };
export const emptyLibrary: Library = { favorites: [], searches: [] };
export type LibraryAction = { toggle: string } | { search: string } | { remove: string | undefined };

export function libraryKey(service: string, owner: ProgressScope | null) {
  const scope = progressScope(owner);
  return service && scope ? `neostream.library.v1:${JSON.stringify([service, scope.accountId, scope.profileId])}` : null;
}

function decode(raw: string | null): Library {
  if (raw === null) return emptyLibrary;
  const data = JSON.parse(raw);
  const strings = (v: unknown): v is string[] => Array.isArray(v) && v.every(x => typeof x === 'string');
  if (!strings(data?.favorites) || !strings(data?.searches)) throw new Error('Bibliothèque illisible.');
  return { favorites: data.favorites, searches: data.searches };
}

function update(library: Library, action: LibraryAction): Library {
  const { favorites, searches } = library;
  if ('toggle' in action) return { searches, favorites: favorites.includes(action.toggle)
    ? favorites.filter(id => id !== action.toggle) : [action.toggle, ...favorites] };
  if ('remove' in action) return { favorites, searches: action.remove ? searches.filter(s => s !== action.remove) : [] };
  const q = action.search.trim();
  return { favorites, searches: [q, ...searches.filter(s => s.toLowerCase() !== q.toLowerCase())].slice(0, 12) };
}

/** Serialize reads AND writes by durable key, even across provider remounts.
 * Each accepted edit uses the persisted base; a failed read never causes a destructive write. */
export function createLibraryStore(storage: {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, data: string) => Promise<void>;
}) {
  const tails = new Map<string, Promise<void>>();
  return function access(key: string | null, current: () => boolean, action?: LibraryAction): Promise<Library | null> {
    if (!key || !current()) return Promise.resolve(null);
    const task = (tails.get(key) ?? Promise.resolve()).then(async () => {
      if (!current()) return null;
      const base = decode(await storage.getItem(key));
      if (!current()) return null;
      if (!action) return base;
      const next = update(base, action);
      await storage.setItem(key, JSON.stringify(next));
      return current() ? next : null;
    });
    const tail = task.then(() => {}, () => {});
    tails.set(key, tail);
    void tail.then(() => { if (tails.get(key) === tail) tails.delete(key); });
    return task;
  };
}
