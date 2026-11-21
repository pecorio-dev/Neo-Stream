import type {
  AccountProfileChange,
  CastMember,
  Channel,
  MediaInfo,
  MediaSeason,
  SessionInfo,
  Title,
  VideoSource,
  SourceBatch,
} from "./types";
import { decodeProfiles } from "./profiles";
import { CATALOGUE_BATCH, isCanonicalTitle } from "./catalogueLookup";
import { parseGenres, withGenres } from './genres';
import { decodeProgressSnapshot, type ProgressEvent, type ProgressIdentity, type ProgressSnapshot } from "./progress";
import { directReader, isDeclaredStartupMs, isReaderKey, nextReaderTickets, readerTickets } from './readerStartup';
import { relayLiveUrl } from './streamProxy';

// The service URL is supplied by the operator; no private Neo-stream endpoints are assumed.
export const API_BASE = (process.env.EXPO_PUBLIC_NEO_API_URL || "")
  .trim()
  .replace(/\/$/, "");
export const OFFICIAL_SITE = "https://neo-stream.eu/";
// Every operation appends its own ?op=. A misconfigured endpoint must keep
// both account entry and stored-session restoration closed, not just the form.
export function isServiceEndpoint(value: string): boolean {
  if (!/^https:\/\/[^\s/?#@]+(?:\/[^\s?#]*)?$/i.test(value)) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !!url.hostname && !url.username && !url.password;
  } catch { return false; }
}
export const hasService = isServiceEndpoint(API_BASE);
export const safeUrl = (value: unknown): value is string =>
  typeof value === "string" && /^https:\/\/[^\s]+$/i.test(value);

// The backend exposes a single PHP entry point and discriminates operations with ?op=.
const OPS: Record<string, string> = {
  "/auth/login": "login",
  "/auth/register": "register",
  "/auth/verify": "verify",
  "/auth/resend": "resend",
  "/auth/me": "me",
  "/auth/logout": "logout",
  "/auth/sessions": "sessions",
  "/auth/sessions/revoke": "session-revoke",
  "/auth/profiles": "profiles",
  "/catalogue": "catalogue",
  "/search": "search",
  "/catalogue/ids": "catalogue_ids",
  "/channels": "channels",
  "/media": "media",
  "/progress": "progress",
};

/** Translate a friendly path into the operation query used by the public adapter. */
function endpoint(path: string): string {
  const mark = path.indexOf("?");
  const pathname = mark < 0 ? path : path.slice(0, mark);
  const query = mark < 0 ? "" : path.slice(mark + 1);
  const op = OPS[pathname];
  if (!op) return path;
  return `?op=${op}${query ? `&${query}` : ""}`;
}

function errorDetails(body: unknown): { message?: unknown; code?: unknown } | undefined {
  if (!body || typeof body !== "object") return;
  const error = (body as { error?: unknown }).error;
  if (error && typeof error === "object") return error;
}

export class ApiHttpError extends Error {
  constructor(readonly status: number, message: string, readonly retryAt = 0, readonly code?: string) { super(message); }
}
export class ApiTimeoutError extends Error {}

// One app provider. Capture the lease at dispatch, not just its token at reply:
// even reactivating the same bearer must not inherit an older request's 401.
let observed: { token: string; expire: () => void } | null = null;
export function observeBearer(token: string, expire: () => void) {
  const lease = { token, expire };
  observed = lease;
  return () => { if (observed === lease) observed = null; };
}

export async function request<T>(
  path: string,
  options: RequestInit = {},
  token?: string,
  timeoutMs = 10000,
): Promise<T> {
  if (!hasService)
    throw new Error("Le service Neo-stream n’est pas configuré.");
  const lease = token && path !== '/auth/logout' && observed?.token === token ? observed : null;
  const controller = new AbortController();
  const cancel = () => controller.abort();
  if (options.signal?.aborted) cancel(); else options.signal?.addEventListener('abort', cancel);
  const timeout = setTimeout(cancel, timeoutMs);
  try {
    const response = await fetch(API_BASE + endpoint(path), {
      ...options,
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        ...(options.body != null ? { "Content-Type": "application/json" } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    });
    if (response.status === 401 && lease && lease === observed) lease.expire();
    const text = await response.text();
    let body: unknown = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      /* A non-JSON reply still produces a readable French error below. */
    }
    const details = errorDetails(body);
    const message = typeof details?.message === "string" && details.message.trim() ? details.message : "";
    if (!response.ok) {
      const after = response.headers.get('Retry-After');
      const retryAt = !after ? 0 : /^\d+$/.test(after) ? Date.now() + Number(after) * 1000 : Date.parse(after);
      throw new ApiHttpError(response.status,
        message ||
          (response.status === 401
            ? "Identifiants incorrects ou session expirée."
            : "Le service est momentanément indisponible."), Number.isFinite(retryAt) ? retryAt : 0,
        typeof details?.code === "string" ? details.code : undefined,
      );
    }
    if (message) throw new Error(message);
    return body as T;
  } catch (error) {
    if (controller.signal.aborted && !options.signal?.aborted)
      throw new ApiTimeoutError("Le service met trop de temps à répondre. Réessayez.");
    throw error;
  } finally {
    clearTimeout(timeout);
    options.signal?.removeEventListener('abort', cancel);
  }
}

export type AuthProfile = {
  name: string;
  email: string;
  emailVerified?: boolean;
  accountId?: string;
  profileId?: string;
};
export type SessionQuota = { active: number; limit: number };
export type AuthResult = {
  token: string;
  profile: AuthProfile;
  sessions?: SessionQuota;
};
export type RegisterResult = {
  pending: boolean;
  email: string;
  emailSent: boolean;
  message: string;
};
export type ResendResult = { sent: boolean; message: string };
export type MeResult = { profile: AuthProfile; sessions: SessionQuota };
// server/api/app.php: login, verify and me each use neo_app_public_user,
// which always emits a JSON boolean. Missing/legacy flags are not evidence.
export function verifiedProfile(profile: AuthProfile | null | undefined): boolean {
  return profile?.emailVerified === true && typeof profile.email === 'string'
    && /^[^\s@]+@[^\s@]+$/.test(profile.email);
}
export type SessionsResult = { items: SessionInfo[]; limit: number };
export type OkResult = { ok: boolean };

export async function apiProfiles(token: string, accountId: string, change?: AccountProfileChange) {
  const data = await request<unknown>("/auth/profiles", change
    ? { method: "POST", body: JSON.stringify(change) } : {}, token);
  const profiles = decodeProfiles(data, accountId);
  if (!profiles) throw new Error("Réponse de profils invalide.");
  return profiles;
}

/** Resolve declared sources for a catalogue title or a specific episode. */
export async function apiSources(
  target: { id: string; type: "film" | "serie" | "anime"; season?: number; episode?: number; title?: string; year?: number },
  token?: string,
  signal?: AbortSignal,
  options?: { preferReader?: string; remaining?: readonly string[] },
): Promise<SourceBatch> {
  if (target.type !== "film" && (!Number.isInteger(target.season) || target.season! < 0 || !Number.isInteger(target.episode) || target.episode! < 1)) {
    throw new Error("Choisissez un épisode avant de lancer la lecture.");
  }
  const anime = target.type === 'anime';
  const sent = anime ? readerTickets(options?.remaining) : undefined;
  if (anime && options?.remaining !== undefined && !sent) throw new Error('Suite de lecteurs invalide.');
  const parts = Object.entries({
    id: target.id, type: target.type, title: target.title, year: target.year,
    ...(target.type !== "film" ? { season: target.season, episode: target.episode } : {}),
    ...(sent ? { remaining: sent.join(',') } : anime && isReaderKey(options?.preferReader) ? { preferReader: options.preferReader } : {}),
  }).filter(([, value]) => value != null && value !== "")
    .map(([key, value]) => `${key}=${encodeURIComponent(String(value))}`);
  const checkAbort = () => { if (signal?.aborted) throw Object.assign(new Error('Recherche annulée.'), { name: 'AbortError' }); };
  checkAbort();
  const data = await request<{ sources?: unknown; remaining?: unknown }>(`?op=sources&${parts.join("&")}`, { signal }, token, 35000);
  checkAbort();
  if (!Array.isArray(data?.sources)) throw new Error("Réponse de lecture invalide.");
  const sources = validSources(data.sources).map(source => {
    const direct = anime && directReader(source);
    const readerKey = direct && isReaderKey(source.readerKey) ? source.readerKey : undefined;
    const startupMs = direct && isDeclaredStartupMs(source.startupMs) ? source.startupMs : undefined;
    if (readerKey === source.readerKey && startupMs === source.startupMs) return source;
    const { readerKey: _key, startupMs: _ms, ...rest } = source;
    return { ...rest, ...(readerKey ? { readerKey } : {}), ...(startupMs ? { startupMs } : {}) };
  });
  const remaining = anime ? nextReaderTickets(data.remaining, sent) : undefined;
  return { sources, ...(remaining ? { remaining } : {}) };
}

export async function apiChannelSources(slug: string, signal?: AbortSignal): Promise<{ items: VideoSource[] }> {
  if (!/^[A-Za-z0-9_-]+$/.test(slug)) throw new Error("Identifiant de chaîne invalide.");
  // This is a public endpoint. Do not send a session or trigger a cross-origin authorization preflight.
  const data = await request<{ items?: unknown; slug?: unknown }>(`?op=channel_sources&slug=${encodeURIComponent(slug)}`, { signal, credentials: 'omit' }, undefined, 35000);
  if (signal?.aborted) throw Object.assign(new Error('Recherche annulée.'), { name: 'AbortError' });
  // Keep accepting items-only replies. If an echo is present, it must identify
  // the exact channel, not just a name or a case-insensitive slug.
  if (!Array.isArray(data?.items) || (data.slug !== undefined && data.slug !== slug)) throw new Error("Réponse de lecture invalide.");
  // The live host sends no usable CORS header: in a browser, play it through our own
  // relay. Native keeps the original URL, and unknown hosts are never relayed.
  return {
    items: validSources(data.items)
      .filter(source => source.type !== 'external')
      .map(source => ({ ...source, url: relayLiveUrl(source.url, source.type === 'video' ? 'video' : 'hls', API_BASE) })),
  };
}
export function sourceFailure(error: unknown, web: boolean, live = false) {
  const status = error instanceof ApiHttpError ? error.status : 0;
  const message = status === 401 ? (live ? 'Le service refuse la demande publique de sources (401).' : 'Votre session a expiré. Reconnectez-vous pour accéder à la lecture.')
    : status === 403 ? (live ? 'Le service refuse la demande de sources pour cette chaîne (403).' : 'Le serveur refuse l’accès à ce contenu (403).')
    : status === 429 ? 'Trop de demandes de lecture. Patientez avant de réessayer.'
    : status === 404 ? (detailIssue(error) === 'unsupported' ? 'Cette version du serveur ne fournit pas le service de lecture.' : 'Le serveur ne trouve pas la source de ce contenu.')
    : status >= 500 ? `Le service de lecture est indisponible (${status}). Réessayez plus tard.`
    : error instanceof ApiTimeoutError ? 'Le serveur de lecture n’a pas répondu à temps. Réessayez.'
    : error instanceof TypeError ? (web ? 'Le navigateur ne peut pas joindre le service de lecture. Vérifiez la connexion ou réessayez plus tard.' : 'Le service de lecture est injoignable. Vérifiez votre connexion.')
    : 'Le service a renvoyé une réponse de lecture non reconnue.';
  return { message, status, retryAt: error instanceof ApiHttpError && error.retryAt > Date.now() ? error.retryAt : status === 429 ? Date.now() + 30000 : 0 };
}

export function channelDirectoryFailure(error: unknown) {
  const status = error instanceof ApiHttpError ? error.status : 0;
  const message = status === 403 ? 'Le service refuse l’accès à la liste des chaînes (403).'
    : status === 429 ? 'Trop de demandes pour la liste des chaînes. Patientez avant de réessayer.'
    : 'La liste des chaînes n’a pas pu être actualisée.';
  return { status, message: `${message} Les chaînes déjà affichées restent visibles.` };
}
export async function apiLogin(
  email: string,
  password: string,
): Promise<AuthResult> {
  return request<AuthResult>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}
export async function apiRegister(
  name: string,
  email: string,
  password: string,
): Promise<RegisterResult> {
  return request<RegisterResult>("/auth/register", {
    method: "POST",
    body: JSON.stringify({ name, email, password }),
  });
}
export async function apiVerify(
  email: string,
  code: string,
): Promise<AuthResult> {
  return request<AuthResult>("/auth/verify", {
    method: "POST",
    body: JSON.stringify({ email, code }),
  });
}
export async function apiResend(email: string): Promise<ResendResult> {
  return request<ResendResult>("/auth/resend", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}
export async function apiMe(token: string): Promise<MeResult> {
  const lease = observed?.token === token ? observed : null;
  const me = await request<MeResult>("/auth/me", {}, token);
  if (lease && lease === observed && !verifiedProfile(me?.profile)) lease.expire();
  return me;
}
export function shouldDiscardStoredBearer(error: unknown): boolean {
  return error instanceof ApiHttpError && (error.status === 401 || error.code === "ACCOUNT_BANNED");
}
export async function apiSessions(token: string): Promise<SessionsResult> {
  return request<SessionsResult>("/auth/sessions", {}, token);
}
export async function apiRevokeSession(
  token: string,
  id: string,
): Promise<OkResult> {
  return request<OkResult>("/auth/sessions/revoke", {
    method: "POST",
    body: JSON.stringify({ id }),
  }, token);
}
export async function apiLogout(token: string): Promise<OkResult> {
  return request<OkResult>("/auth/logout", { method: "POST" }, token);
}

export function validSources(input: unknown): VideoSource[] {
  if (!Array.isArray(input)) return [];
  return input.filter(
    (s) =>
      s &&
      typeof s.id === "string" &&
      typeof s.label === "string" &&
      safeUrl(s.url) &&
      ["video", "external", "hls"].includes(s.type),
  );
}
export async function loadCatalogue(
  cursor?: string,
): Promise<{ items: Title[]; nextCursor: string | null }> {
  const data = await request<{ items: Title[]; nextCursor?: string }>(
    `/catalogue?limit=24${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`,
  );
  if (!Array.isArray(data?.items)) throw new Error("Catalogue indisponible.");
  const items = data.items
    .filter(
      (m) =>
        m && typeof m.id === "string" &&
        typeof m.title === "string" &&
        ["Film", "Série", "Animé"].includes(m.kind) &&
        safeUrl(m.poster) &&
        safeUrl(m.backdrop),
    )
    .map((m) => ({ ...withGenres(m), episodic: typeof m.episodic === "boolean" ? m.episodic : undefined, sources: validSources(m.sources) }));
  return {
    items,
    nextCursor: typeof data.nextCursor === "string" ? data.nextCursor : null,
  };
}

function remoteTitles(value: unknown): Title[] {
  if (!Array.isArray(value)) throw new Error("Catalogue indisponible.");
  return value.filter((item): item is Title => item && typeof item.id === "string" && isCanonicalTitle(item.id) &&
    typeof item.title === "string" && ["Film", "Série", "Animé"].includes(item.kind) &&
    safeUrl(item.poster) && safeUrl(item.backdrop) &&
    (item.episodic === undefined || typeof item.episodic === "boolean"))
    .map((item) => ({ ...withGenres(item), sources: validSources(item.sources) }));
}

export async function apiSearch(q: string, type: "all" | "film" | "serie" | "anime", cursor?: string) {
  const params = `q=${encodeURIComponent(q)}&type=${type}&limit=24${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`;
  const data = await request<{ items?: unknown; nextCursor?: unknown }>(`/search?${params}`);
  return { items: remoteTitles(data?.items), nextCursor: typeof data?.nextCursor === "string" ? data.nextCursor : null };
}

export async function apiCatalogueIds(ids: string[]): Promise<Title[]> {
  const requested = new Set(ids.filter(isCanonicalTitle));
  if (!requested.size) return [];
  if (requested.size > CATALOGUE_BATCH) throw new Error("Lot de médias trop grand.");
  const data = await request<{ items?: unknown }>(`/catalogue/ids?ids=${encodeURIComponent([...requested].join(","))}`);
  return remoteTitles(data?.items).filter((item) => requested.has(item.id));
}
export async function loadChannels(
  cursor?: string,
): Promise<{ items: Channel[]; nextCursor: string | null }> {
  const data = await request<{ items: Channel[]; nextCursor?: string }>(
    `/channels?limit=24${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`,
    { credentials: 'omit' },
  );
  if (!Array.isArray(data?.items)) throw new Error("Liste des chaînes indisponible.");
  const valid = data.items.filter((c) =>
    c && typeof c.id === "string" && c.id.trim() && typeof c.name === "string" && c.name.trim() && typeof c.category === "string",
  );
  if (data.items.length && !valid.length) throw new Error("Liste des chaînes indisponible.");
  return {
    items: valid.map((c) => ({
      ...c,
      mark: c.mark || c.name.substring(0, 3),
      colors:
        Array.isArray(c.colors) && c.colors.length === 2
          ? c.colors
          : ["#252a3a", "#161820"],
      sources: validSources(c.sources),
    })),
    nextCursor: typeof data.nextCursor === "string" ? data.nextCursor : null,
  };
}

/* -------------------------------------------------------------------------- */
/* Média enrichi (cast, saisons, épisodes) et progression synchronisée.         */
/* -------------------------------------------------------------------------- */

const asRecord = (v: unknown): Record<string, any> | null =>
  v && typeof v === "object" ? (v as Record<string, any>) : null;
const asNumber = (v: unknown) =>
  typeof v === "number" && Number.isFinite(v)
    ? v
    : typeof v === "string" && v.trim() && Number.isFinite(Number(v))
      ? Number(v)
      : undefined;

function normaliseCast(value: unknown): CastMember[] {
  const record = asRecord(value);
  const list = Array.isArray(value)
    ? value
    : record && Array.isArray(record.cast)
      ? record.cast
      : [];
  return list
    .map(asRecord)
    .filter((c): c is Record<string, any> => !!c && typeof c.name === "string" && !!c.name)
    .map((c) => ({
      name: c.name,
      profile_path:
        typeof c.profile_path === "string" ? c.profile_path : null,
      character: typeof c.character === "string" ? c.character : undefined,
    }));
}

function normaliseSeasons(value: unknown): MediaSeason[] {
  if (!Array.isArray(value)) return [];
  const seasons: MediaSeason[] = [];
  for (const raw of value) {
    const s = asRecord(raw);
    if (!s) continue;
    const season = asNumber(s.season ?? s.season_number);
    if (season == null || !Number.isSafeInteger(season) || season < 0) continue;
    const episodes = (Array.isArray(s.episodes) ? s.episodes : [])
      .map(asRecord)
      .filter((e): e is Record<string, any> => !!e)
      .map((e) => {
        const episode = asNumber(e.episode ?? e.episode_number);
        if (episode == null || !Number.isSafeInteger(episode) || episode < 1) return null;
        return {
          episode,
          name: typeof e.name === "string" && e.name ? e.name : `Épisode ${episode}`,
          overview: typeof e.overview === "string" ? e.overview : undefined,
          air_date: typeof e.air_date === "string" ? e.air_date : undefined,
          runtime: asNumber(e.runtime),
        };
      })
      .filter((e): e is NonNullable<typeof e> => !!e)
      .sort((a, b) => a.episode - b.episode);
    seasons.push({ season, episodes });
  }
  return seasons.sort((a, b) => a.season - b.season);
}

type MediaHints = Pick<Title, "title" | "kind" | "episodic" | "year">;

function normaliseMedia(value: unknown, id: string, hints?: MediaHints) {
  const raw = asRecord(value);
  if (!raw || typeof raw.id !== "string" || !raw.id || (/^(fs|fm)_/.test(id) && raw.id !== id))
    throw new Error("La fiche de ce titre n’est pas disponible.");
  const hasSeasons = Array.isArray(raw.seasons);
  const episodic = typeof raw.episodic === "boolean" ? raw.episodic : hints?.episodic ?? hints?.kind === "Série";
  if (episodic && !hasSeasons) throw new Error("La liste des épisodes n’est pas disponible.");
  const credits = asRecord(raw.credits);
  const crew = Array.isArray(raw.crew) ? raw.crew : Array.isArray(credits?.crew) ? credits.crew : [];
  const directorEntry = crew
    .map(asRecord)
    .find((c) => c && /^director$/i.test(String(c.job || "")) && typeof c.name === "string");
  const media: MediaInfo = {
    id: typeof raw.id === "string" ? raw.id : id,
    title: typeof raw.title === "string" ? raw.title : undefined,
    ...(typeof raw.episodic === "boolean" ? { episodic: raw.episodic } : {}),
    cast: normaliseCast(raw.cast ?? credits?.cast),
    director:
      typeof raw.director === "string" && raw.director.trim()
        ? raw.director
        : directorEntry
          ? String(directorEntry.name)
          : undefined,
    genres: parseGenres(raw.genres, raw.genre),
    seasons: normaliseSeasons(raw.seasons),
  };
  return { media, hasSeasons };
}

export type DetailIssue = 'unsupported' | 'missing' | 'unavailable';
export function detailIssue(error: unknown): DetailIssue {
  if (!(error instanceof ApiHttpError) || error.status !== 404) return 'unavailable';
  // Older adapters shipped the same explicit messages without a machine code.
  if (error.code !== undefined && error.code !== 'NOT_FOUND') return 'unavailable';
  const message = error.message.trim();
  if (/^endpoint inconnu[.!]?$/i.test(message)) return 'unsupported';
  if (/^média introuvable[.!]?$/i.test(message)) return 'missing';
  return 'unavailable';
}
let mediaUnsupportedUntil = 0;
let mediaRequestOrder = 0;
let mediaEvidenceOrder = 0;

function recordMediaCapability(order: number, supported: boolean) {
  // A slower reply must not overwrite evidence from a later request.
  if (order < mediaEvidenceOrder) return;
  mediaEvidenceOrder = order;
  mediaUnsupportedUntil = supported ? 0 : Date.now() + 300_000;
}

/** Cache only the explicit missing-operation response, never a missing title or a network failure. */
export async function apiMedia(id: string, hints?: MediaHints, retry = false): Promise<MediaInfo> {
  if (!retry && Date.now() < mediaUnsupportedUntil) throw new ApiHttpError(404, 'Endpoint inconnu.', 0, 'NOT_FOUND');
  const order = ++mediaRequestOrder;
  const query = [`id=${encodeURIComponent(id)}`];
  if (hints && /^tt\d+$/.test(id)) {
    const type = hints.episodic === false || hints.kind === "Film" ? "film" : hints.kind === "Série" ? "serie" : "anime";
    query.push(`title=${encodeURIComponent(hints.title)}`, `type=${type}`, `year=${hints.year}`);
  }
  try {
    const data = await request<{ media?: unknown }>(`/media?${query.join("&")}`);
    const { media, hasSeasons } = normaliseMedia(data?.media ?? data, id, hints);
    if (hasSeasons) recordMediaCapability(order, true);
    return media;
  } catch (error) {
    const issue = detailIssue(error);
    if (issue !== 'unavailable') recordMediaCapability(order, issue === 'missing');
    throw error;
  }
}

async function progressRequest(identity: ProgressIdentity, options: RequestInit): Promise<ProgressSnapshot> {
  const query = `accountId=${encodeURIComponent(identity.accountId)}&profileId=${encodeURIComponent(identity.profileId)}`;
  const data = await request<unknown>(`/progress?${query}`, options, identity.token);
  const snapshot = decodeProgressSnapshot(data, identity);
  if (!snapshot) throw new Error("Réponse de progression invalide.");
  return snapshot;
}

export function apiGetProgress(identity: ProgressIdentity): Promise<ProgressSnapshot> {
  return progressRequest(identity, {});
}

export function apiPostProgress(identity: ProgressIdentity, events: ProgressEvent[]): Promise<ProgressSnapshot> {
  return progressRequest(identity, { method: "POST", body: JSON.stringify({ events }) });
}
