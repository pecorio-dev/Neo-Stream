import type { RefObject } from 'react';
import type { VideoSource } from "../lib/types";
import type { ObservedSourceInfo } from '../lib/sourceInfo';
export type ObservedTracks = ObservedSourceInfo;
export type TrackSelection = { options: { id: string; label: string }[]; selected: string | null };
export type Transport = { ready: boolean; playing: boolean; position: number; duration: number; live: boolean; muted: boolean; volume: number; audio: string | null; subtitles: string | null; observed?: ObservedTracks; qualityMenu?: TrackSelection; subtitleMenu?: TrackSelection };
export const atRest: Transport = { ready: false, playing: false, position: 0, duration: 0, live: false, muted: false, volume: 1, audio: null, subtitles: null };
export type Engine = { read: () => Transport; toggle: () => void; seek: (seconds: number) => void; mute: () => void; volume: (fraction: number) => void; nextAudio: () => void; nextSubtitles: () => void; selectQuality?: (id: string) => void; selectSubtitle?: (id: string) => void };
export const clamp = (value: number, max: number) => Math.max(0, Math.min(max, value));
export type PlayerProps = {
  source: VideoSource;
  title: string;
  initialPosition?: number;
  autoplay: boolean;
  /** First frame presented by the decoder, once on supported platforms; not replayed. */
  onFirstFrame?: () => void;
  onProgress?: (position: number, total: number) => void;
  onError: () => void;
  engine: RefObject<Engine | null>;
  onState: (state: Transport) => void;
  initialMuted: boolean;
  initialVolume: number;
  /** Pas de reprise ni de progression pour un direct, même avec une fenêtre DVR. */
  live?: boolean;
};
