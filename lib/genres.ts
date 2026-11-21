import type { Category, Title } from './types';

/** Display names and known spellings from both film and TV catalogues. Keep unknown editorial genres. */
const key = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[-‐‑–_]/g, ' ').replace(/\s+/g, ' ').trim();
const aliases = new Map<string, string>();
for (const [label, ...others] of [
  ['Action'], ['Aventure', 'Adventure', 'Adventures'], ['Animation'], ['Comédie', 'Comedy'],
  ['Drame', 'Drama'], ['Science-fiction', 'Sci-fi', 'SF', 'Sciencefiction', 'Science fiction'], ['Fantastique', 'Fantasy', 'Fantaisie'],
  ['Policier', 'Crime', 'Criminel'], ['Thriller', 'Suspense'], ['Mystère', 'Mystery'], ['Horreur', 'Horror', 'Épouvante'],
  ['Romance'], ['Histoire', 'History', 'Historique'], ['Documentaire', 'Documentary', 'Documentaires'],
  ['Musique', 'Music'], ['Comédie musicale', 'Musical'], ['Familial', 'Family', 'Famille'], ['Jeunesse', 'Kids', 'Enfants'],
  ['Téléfilm', 'TV Movie', 'Television Movie'], ['Téléréalité', 'Reality', 'Reality TV', 'Télé-réalité'],
  ['Guerre', 'War'], ['Politique', 'Politics'], ['Western'], ['Actualités', 'News'], ['Talk-show', 'Talk', 'Talk Show'],
  ['Feuilleton', 'Soap', 'Soap Opera'], ['Sport', 'Sports'], ['Arts martiaux', 'Martial Arts'],
]) for (const word of [label, ...others]) aliases.set(key(word), label);

export function parseGenres(...values: unknown[]): string[] {
  const out = new Map<string, string>();
  function add(value: unknown, depth: number) {
    if (depth > 3 || value == null) return;
    if (Array.isArray(value)) { for (const v of value) add(v, depth + 1); return; }
    if (typeof value === 'object') { add((value as { name?: unknown }).name, depth + 1); return; }
    if (typeof value !== 'string' || value.length > 8192) return;
    const text = value.trim().replace(/&(?:amp|#38|#x26);/gi, '&').replace(/&(?:nbsp|#160);/gi, ' ');
    if (text.startsWith('[') || text.startsWith('{')) {
      try { add(JSON.parse(text), depth + 1); } catch { /* Never display malformed serialised metadata. */ } return;
    }
    for (const token of text.split(/[,;|/]/)) {
      const label = token.trim().replace(/\s+/g, ' ');
      if (!label || label.length > 70 || !/\p{L}/u.test(label) || /[<>\[\]{}]/.test(label) || /^(?:null|undefined|n\.?a\.?|non renseigné|inconnu|unknown|tout)$/i.test(label)) continue;
      const parts = label.split(/\s*&\s*|\s+(?:and|et)\s+/i);
      // Combined TMDB TV categories become individual filters, but don't cut an unfamiliar name like « Arts et essai ».
      for (const part of parts.length > 1 && parts.every(s => aliases.has(key(s))) ? parts : [label]) {
        const name = aliases.get(key(part)) ?? part;
        if (!out.has(key(name))) out.set(key(name), name);
      }
    }
  }
  for (const value of values) add(value, 0);
  return [...out.values()];
}

type GenreFields = Pick<Title, 'genre' | 'genres'>;
/** `genres` on a decoded app title is already canonical. Bundled titles predate the array. */
export const titleGenres = (item: GenreFields) => item.genres ?? parseGenres(item.genre);
export function withGenres<T extends { genre?: unknown; genres?: unknown }>(item: T) {
  const genres = parseGenres(item.genres, item.genre);
  return { ...item, genres, genre: genres.join(', ') };
}
export function genreOptions(items: (GenreFields & Pick<Title, 'kind'>)[], category: Category = 'Tout') {
  const unique = new Map<string, string>();
  for (const item of items) if (category === 'Tout' || item.kind === category)
    for (const g of titleGenres(item)) if (!unique.has(key(g))) unique.set(key(g), g);
  return [...unique.values()].sort((a,b) => a.localeCompare(b, 'fr', { sensitivity: 'base' }));
}
export const matchesGenre = (item: GenreFields, genre: string) => titleGenres(item).some(g => key(g) === key(genre));
