export type Kind = "Film" | "Série" | "Animé";
export type Category = "Tout" | Kind;
export type PresetBase = 'cinema' | 'minuit' | 'salon';
export type DisplayPreset = { id: string; name: string; base: PresetBase; matte: boolean };
export type DisplaySettings = { selected: string; custom: DisplayPreset[] };
export type TabName = "Accueil" | "Catalogue" | "Recherche" | "Direct";
export type VideoSource = {
  id: string;
  label: string;
  url: string;
  type: "video" | "external" | "hls";
  player?: string | number;
  playerIndex?: number;
  /** Public display name explicitly declared by the source operator. */
  playerName?: string;
  /** Opaque reader identity and optional declared startup estimate, for direct anime VOD. */
  readerKey?: string;
  startupMs?: number;
  version?: "VF" | "VFF" | "VFQ" | "VO" | "VOSTFR" | "MULTI";
  audioLanguages?: string[];
  qualities?: (string | number | { height?: string | number; quality?: string | number; label?: string; url?: string })[];
  /** An empty list means no subtitles announced by the catalogue. */
  subtitleLanguages?: string[];
  quality?: string | number;
};
export type SourceBatch = { sources: VideoSource[]; remaining?: string[] };
export type Title = {
  id: string;
  /** Catalogue lookup for a bundled card, once its exact identity is resolved. */
  catalogId?: string;
  /** An animated feature can belong to “Animé” without having episodes. */
  episodic?: boolean;
  title: string;
  kind: Kind;
  genre: string;
  genres?: string[];
  year: number;
  duration: string;
  description: string;
  poster: number | string;
  backdrop: number | string;
  rating: string;
  trailer?: string | null;
  sources?: VideoSource[];
  director?: string;
  cast?: string[];
  durationSeconds?: number;
};
export type Channel = {
  id: string;
  name: string;
  category: string;
  mark: string;
  colors: [string, string];
  description: string;
  sources: VideoSource[];
};
/**
 * Point de reprise courant d’un titre. `updated` est en millisecondes Unix.
 */
export type Progress = {
  id: string;
  season?: number;
  episode?: number;
  position: number;
  total: number;
  label?: string;
  updated: number;
};
/** Membre du casting tel que renvoyé par `?op=media` (photos TMDB). */
export type CastMember = {
  name: string;
  profile_path?: string | null;
  character?: string;
};
/** Épisode d'une saison, tel que renvoyé par `?op=media`. */
export type MediaEpisode = {
  episode: number;
  name: string;
  overview?: string;
  air_date?: string;
  runtime?: number;
};
export type MediaSeason = { season: number; episodes: MediaEpisode[] };
/** Média enrichi, normalisé par `apiMedia()` pour l'application. */
export type MediaInfo = {
  id: string;
  episodic?: boolean;
  title?: string;
  cast: CastMember[];
  director?: string;
  genres: string[];
  seasons: MediaSeason[];
};
export type AuthenticatedAccount = { name: string; email: string; emailVerified: boolean; accountId?: string };
export type Profile = {
  name: string;
  color: number;
  /** Device-local viewing portrait; never sent to the account API. */
  portraitId?: string;
  connected?: boolean;
  accountId?: string;
  profileId?: string;
};
export type AccountProfile = { id: string; name: string; color: number };
export type AccountProfileChange = Pick<AccountProfile, "name" | "color"> & (
  { action: "create" } | { action: "update"; id: string }
);
export type SessionInfo = {
  id: string;
  label: string;
  type: string;
  createdAt: string;
  lastSeen: string;
  current: boolean;
};
export type Preferences = {
  display: DisplaySettings;
  history: boolean;
  rememberSearch: boolean;
  autoplay: boolean;
};
export type Overlay =
  | {
      type: "detail" | "watch";
      item: Title;
      /** Épisode ciblé quand la lecture vient d'une fiche ou d'une reprise. */
      season?: number;
      episode?: number;
      label?: string;
      restart?: boolean;
    }
  | { type: "channel"; channel: Channel }
  | { type: "settings" | "library" | "account" | "credits" | "profile" }
  | { type: "collection"; section: "favorites" | "history" };
export type Theme = {
  bg: string;
  surface: string;
  elevated: string;
  text: string;
  muted: string;
  faint: string;
  border: string;
  accent: string;
  onAccent: string;
  soft: string;
  glassTint: string;
  glassEdge: string;
  glassGlint: string;
  danger: string;
  light: boolean;
};
