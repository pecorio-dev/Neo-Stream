import type { ObservedTracks } from './playerTypes';

type LanguageTrack = { language?: string | null; lang?: string | null };
type TextTrack = LanguageTrack & { kind: string };
type VideoTrack = { height?: number; size?: { height?: number } | null; isSupported?: boolean };

const maxScanned = 1024;
const maxValues = 32;
const unknownLanguages = new Set(['und', 'mul', 'mis', 'zxx']);

function languageCode(raw?: string | null) {
  if (typeof raw !== 'string' || raw.length > 35) return;
  // AVPlayer can expose a locale such as fr_CA rather than fr-CA.
  const code = raw.trim().toLowerCase().replace(/_/g, '-');
  if (/^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/.test(code) && !unknownLanguages.has(code.split('-')[0])) return code;
}

function collect<T, V>(values: Set<V>, list: ArrayLike<T> | undefined, read: (item: T) => V | undefined) {
  for (let i = 0; list && i < list.length && i < maxScanned && values.size < maxValues; i++) {
    const item = list[i];
    const value = item == null ? undefined : read(item);
    if (value !== undefined) values.add(value);
  }
}

const trackLanguage = (t: LanguageTrack) => languageCode(t.language ?? t.lang);
const quality = (height?: number) => typeof height === 'number' && Number.isInteger(height) && height > 0 && height <= 16384 ? height : undefined;

/** Positive observations only; no labels, selection, mute or subtitle modes. */
export function observeTracks({ audio, subtitles, textTracks, video, videoHeight }: {
  audio?: ArrayLike<LanguageTrack>;
  subtitles?: ArrayLike<LanguageTrack>;
  textTracks?: ArrayLike<TextTrack>;
  video?: ArrayLike<VideoTrack>;
  videoHeight?: number;
}): ObservedTracks | undefined {
  const audioLanguages = new Set<string>(), subtitleLanguages = new Set<string>(), qualities = new Set<number>();
  collect(audioLanguages, audio, trackLanguage);
  collect(subtitleLanguages, subtitles, trackLanguage);
  collect(subtitleLanguages, textTracks, t => t.kind === 'captions' || t.kind === 'subtitles' ? trackLanguage(t) : undefined);
  collect(qualities, video, t => t.isSupported === false ? undefined : quality(t.height ?? t.size?.height));
  const decodedHeight = quality(videoHeight);
  if (!qualities.size && decodedHeight !== undefined) qualities.add(decodedHeight);
  if (!audioLanguages.size && !subtitleLanguages.size && !qualities.size) return;
  return {
    ...(audioLanguages.size ? { audioLanguages: [...audioLanguages] } : {}),
    ...(subtitleLanguages.size ? { subtitleLanguages: [...subtitleLanguages] } : {}),
    ...(qualities.size ? { qualities: [...qualities].sort((a, b) => b - a) } : {}),
  };
}
