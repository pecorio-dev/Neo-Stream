/**
 * Same-origin relay for live streams whose host does not send a usable CORS header.
 *
 * The host's relay (`/api/proxy.php`) is already restricted to the witv family and
 * rewrites child playlists and segments, so the browser only ever talks to our own
 * origin. Only the exact hosts we actually receive are relayed here: an unknown
 * host keeps its direct URL instead of turning the client into an open relay.
 */
const RELAY_HOSTS = ['iptv.mine.bz'] as const;
const RELAY_PATH = '/api/proxy.php';

/** The browser origin, or undefined on native where CORS does not apply. */
function browserOrigin(): string | undefined {
  const location = (globalThis as { location?: { origin?: unknown } }).location;
  const origin = location?.origin;
  return typeof origin === 'string' && /^https?:\/\/[^/]+$/.test(origin) ? origin : undefined;
}

/**
 * Rewrite a cross-origin live URL through the same-origin relay, when the page is a
 * browser and the host is allowlisted. Anything else is returned untouched.
 *
 * `base` is the API base: empty on the deployed site, where the relay shares the page
 * origin. An already-relayed or same-origin URL is never wrapped twice.
 */
export function relayLiveUrl(url: string, kind: 'hls' | 'video', base = ''): string {
  const origin = browserOrigin();
  if (!origin || typeof url !== 'string' || url === '') return url;
  let parsed: URL;
  try {
    parsed = new URL(url, origin);
  } catch {
    return url;
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return url;
  const root = (base.trim().replace(/\/$/, '') || origin);
  let relayRoot: URL;
  try {
    relayRoot = new URL(root);
  } catch {
    return url;
  }
  if (parsed.origin === origin && parsed.pathname === RELAY_PATH) return url;
  if (parsed.origin === relayRoot.origin && parsed.pathname === RELAY_PATH) return url;
  if (parsed.origin === origin) return url;
  if (!RELAY_HOSTS.some((host) => parsed.hostname === host || parsed.hostname.endsWith('.' + host))) return url;
  const type = kind === 'video' ? 'mp4' : 'hls';
  return `${root}${RELAY_PATH}?url=${encodeURIComponent(parsed.href)}&type=${type}`;
}
