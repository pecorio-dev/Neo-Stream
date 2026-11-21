import type { Kind, MediaSeason, Progress, Title } from "./types";

type Format = { kind?: Kind; episodic?: boolean };
type Options = Format & { seasons?: MediaSeason[] };
type EpisodeRef = { season: number; episode: number };
export const isEpisodicTitle = (item: Pick<Title, "kind" | "episodic">) =>
  item.episodic ?? item.kind !== "Film";
const validNumber = (n: unknown): n is number => typeof n === "number" && Number.isSafeInteger(n) && n >= 0;
const code = (e: EpisodeRef) => `S${e.season} E${e.episode}`;
export const progressEpisode = (entry: Progress): EpisodeRef | null => {
  if (validNumber(entry.season) && validNumber(entry.episode)) return { season: entry.season, episode: entry.episode };
  const match = /^S(\d+)\s*(?:[·-]\s*)?E(\d+)$/i.exec(entry.label?.trim() ?? "");
  return match ? { season: Number(match[1]), episode: Number(match[2]) } : null;
};

function listed(seasons: MediaSeason[] = []): EpisodeRef[] {
  return seasons.flatMap((s) => s.episodes.map((e) => ({ season: s.season, episode: e.episode })))
    .filter((e) => validNumber(e.season) && validNumber(e.episode))
    .sort((a, b) => a.season - b.season || a.episode - b.episode);
}
export function firstEpisode(seasons?: MediaSeason[]) {
  const entries = listed(seasons);
  return entries.find((e) => e.season > 0) ?? entries[0] ?? null;
}

// A jump is allowed only to an actual entry following an actual episode in
// this title. Specials (S0), gaps, season boundaries and finales are explicit.
export function buildResume(entry: Progress | undefined, options: Options = {}) {
  if (!entry) return null;
  const last = progressEpisode(entry);
  const serial = options.episodic ?? (options.kind ? options.kind !== "Film" : !!last);
  if (serial && !last) return null;
  const complete = entry.total > 0 && entry.position / entry.total > 0.9;
  const all = serial && complete ? listed(options.seasons) : [];
  const at = last ? all.findIndex((e) => e.season === last.season && e.episode === last.episode) : -1;
  const nextRef = at >= 0 ? all[at + 1] : undefined;
  const restart = serial ? at >= 0 && !nextRef : entry.total > 0 && entry.position >= entry.total;
  const label = serial && last ? code(last) : "";
  const target = serial ? nextRef ?? last : null;
  return {
    entry, label, next: !!nextRef, restart,
    needsCatalogue: serial && complete && at < 0,
    target: target ? { ...target, label: code(target) } : null,
    buttonLabel: nextRef ? `Épisode suivant ${code(nextRef)}` : serial
      ? `${restart ? "Revoir" : "Reprendre"} ${label}` : restart ? "Revoir le film" : "Reprendre le film",
    position: restart || nextRef ? 0 : entry.position,
  };
}
export type ResumeInfo = NonNullable<ReturnType<typeof buildResume>>;

/** Input is the active profile's hydrated history, newest first (including off-page titles). */
export function homeSessions(history: { entry: Progress; item: Title }[]) {
  // A finished film still belongs to this profile's last session. buildResume
  // will offer a replay; do not silently substitute an older title instead.
  return history.filter(({ entry }) => entry.position > 0);
}

export function timecode(seconds: number) {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  return `${m >= 60 ? `${Math.floor(m / 60)}:${String(m % 60).padStart(2, '0')}` : m}:${String(s % 60).padStart(2, '0')}`;
}

export function resumeFor(id: string, progress: Progress[], options: Options = {}) {
  return buildResume(progress.find((p) => p.id === id), options);
}
