import { sourceVersion, type ObservedSourceInfo } from '../lib/sourceInfo';
import type { ReaderBatch } from '../lib/readerStartup';
import type { VideoSource } from '../lib/types';
import { groupReaders, playableSources, playbackAddress } from './playback';

export type PlaybackLink = { source: VideoSource; info: VideoSource };
export type LinkChoice = { index: number; label: string };

/** A reader can offer several distinct links. An adaptive stream, on the other hand,
 * stays one link even if its manifest lists several resolutions or soundtracks. */
export function playbackLinks(local: VideoSource[], ...batches: ReaderBatch[]): PlaybackLink[] {
  const links = new Map<string, PlaybackLink>();
  // Keep the local prefix intact when the menu retrieves additional declarations:
  // an index already playing (or failed) must still refer to precisely the same URL.
  for (const batch of [local, ...batches]) {
    const ordered = Array.isArray(batch) ? groupReaders(playableSources(batch)).sources : playableSources(batch.ordered);
    for (const s of ordered) {
      const key = playbackAddress(s.url)!; // checked by playableSources
      const existing = links.get(key);
      if (!existing) links.set(key, { source: s, info: s });
      // Two declarations of the same transport do not attest two independent
      // versions. Keep the fresh declaration intact: don't attach old subtitles to it.
      else existing.info = s;
    }
  }
  return [...links.values()];
}

// Keep the session caller compatible. Decoder observations are only relevant to its own settings panel.
export function linkChoices(links: PlaybackLink[], _observed?: ReadonlyMap<VideoSource, ObservedSourceInfo>,
  _active?: { source: VideoSource; tracks?: ObservedSourceInfo }): LinkChoice[] {
  return links.map(({ info }, index) => {
    const version = sourceVersion(info);
    return { index, label: `Lien ${index + 1}${version ? ` · ${version}` : ''}` };
  });
}
