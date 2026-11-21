import React, { useLayoutEffect, useRef } from 'react';
import { Platform } from 'react-native';
import { useVideoPlayer, VideoView, type SubtitleTrack, type VideoPlayerStatus, type VideoSource } from 'expo-video';
import { trackLanguageName } from '../lib/sourceInfo';
import { androidVideoQuality } from './androidVideoQuality';
import { clamp, type Engine, type PlayerProps, type Transport } from './playerTypes';
import { createChoiceScope } from './trackChoices';
import { observeTracks } from './observedTracks';
import { fill } from './UI';

type Track = { id?: string; language: string; label: string; name?: string };
const key = (t: Track | null) => t?.id || (t ? `${t.language}/${t.name}/${t.label}` : '');
function distinct<T extends Track>(tracks: T[]) {
  const seen = new Set<string>();
  return tracks.filter(t => { const k = key(t); if ((Platform.OS === 'android' && !t.id) || seen.has(k)) return false; seen.add(k); return true; });
}
const name = (t: Track | null) => t?.label || t?.name || t?.language || 'Choisir';
const subtitleKey = (track: SubtitleTrack | null) => track === null ? 'off' : Platform.OS === 'android'
  ? `subtitle:${JSON.stringify([track.id, track.language, track.label, track.name])}`
  // AVPlayer's expo-video setter identifies an option by display name and locale.
  : `subtitle:${JSON.stringify([track.language, track.label])}`;
const subtitleLanguage = (track: SubtitleTrack) => trackLanguageName(track.language) ?? trackLanguageName(track.label) ?? 'Piste';

function subtitleChoices(tracks: SubtitleTrack[]) {
  const ambiguous = new Set<string>();
  if (Platform.OS === 'android') {
    // The SDK resolves a subtitle by id alone. If that id identifies different tracks,
    // passing a particular track object will not disambiguate them.
    const keysById = new Map<string, string>();
    for (const track of tracks) {
      if (!track.id) continue;
      const key = subtitleKey(track), previous = keysById.get(track.id);
      if (previous !== undefined && previous !== key) ambiguous.add(track.id);
      keysById.set(track.id, key);
    }
  }
  const byKey = new Map(tracks.filter(t => Platform.OS !== 'android' || (t.id && !ambiguous.has(t.id))).map(t => [subtitleKey(t), t]));
  const counts = new Map<string, number>(), ordinals = new Map<string, number>();
  for (const track of byKey.values()) {
    const label = subtitleLanguage(track);
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  return Array.from(byKey, ([key, value]) => {
    const title = subtitleLanguage(value);
    const ordinal = (ordinals.get(title) ?? 0) + 1;
    ordinals.set(title, ordinal);
    return { key, label: counts.get(title) === 1 ? title : `${title} ${ordinal}`, value };
  });
}

/** AVPlayer / Media3 decode the stream; only the Neo-stream desk handles input. */
export default function Player({ source, title, live, initialPosition = 0, initialMuted, initialVolume, autoplay, engine: engineRef, onState, onProgress, onError, onFirstFrame }: PlayerProps) {
  const callbacks = useRef({ onState, onProgress, onError, onFirstFrame });
  useLayoutEffect(() => { callbacks.current = { onState, onProgress, onError, onFirstFrame }; }, [onState, onProgress, onError, onFirstFrame]);
  const videoSource: VideoSource = { uri: source.url, contentType: source.type === 'hls' ? 'hls' : 'auto', metadata: { title } };
  const p = useVideoPlayer(videoSource, p => {
    p.timeUpdateEventInterval = live ? 0 : .5; p.muted = initialMuted; p.volume = clamp(initialVolume, 1);
  });
  const presented = useRef(new WeakSet<typeof p>());
  const currentPlayer = useRef<typeof p | null>(null);
  useLayoutEffect(() => {
    currentPlayer.current = p;
    return () => { currentPlayer.current = null; };
  }, [p]);
  const onFirstFrameRender = () => {
    if (currentPlayer.current !== p || presented.current.has(p)) return;
    presented.current.add(p); // Expo can also emit this event after a track switch.
    callbacks.current.onFirstFrame?.();
  };
  useLayoutEffect(() => {
    let active = true, failed = false, ready = false, lastSave = 0;
    let observed: Transport['observed'];
    const subtitles = createChoiceScope<SubtitleTrack | null>();
    const quality = createChoiceScope<number | null>();
    const bridge = source.type === 'hls' ? androidVideoQuality : null;
    let qualityMenu: Transport['qualityMenu'], subtitleMenu: Transport['subtitleMenu'];
    let subtitleLabel: string | null = null;
    let qualityRevision = 0, pendingQuality = false;
    let qualityQueue = Promise.resolve();
    const refreshSubtitles = (available = p.availableSubtitleTracks) => {
      const tracks = subtitleChoices(available), selected = p.subtitleTrack;
      const entries = tracks.length || (available.length && selected)
        ? [{ key: 'off', label: 'Désactivés', value: null }, ...tracks] : [];
      const previous = subtitleMenu;
      subtitleMenu = subtitles.update(entries, subtitleKey(selected));
      const menu = subtitleMenu;
      subtitleLabel = menu?.options.find(option => option.id === menu.selected)?.label ?? null;
      return previous !== subtitleMenu;
    };
    const refreshObserved = (updateSubtitles: boolean) => {
      const available = p.availableSubtitleTracks;
      if (updateSubtitles) refreshSubtitles(available);
      observed = observeTracks({ audio: p.availableAudioTracks, subtitles: available, video: p.availableVideoTracks });
    };
    const read = (): Transport => {
      const isLive = !!live || p.isLive;
      return { ready, playing: p.playing, position: p.currentTime || 0, duration: !isLive && Number.isFinite(p.duration) ? p.duration : 0,
        live: isLive, muted: p.muted, volume: p.volume, audio: distinct(p.availableAudioTracks).length > 1 ? name(p.audioTrack) : null,
        subtitles: subtitleLabel, subtitleMenu, qualityMenu, observed };
    };
    const publish = () => { if (active && !failed) callbacks.current.onState(read()); };
    const refreshQuality = async () => {
      if (!bridge || !active || failed || pendingQuality) return;
      const revision = ++qualityRevision;
      // Only Media3 knows which variants are supported and whether a video override is active.
      const state = await bridge.getQuality(p).catch(() => null);
      if (!active || failed || revision !== qualityRevision) return;
      const heights = state?.heights ?? [];
      const selected = state?.selectedHeight;
      const next = quality.update(heights.length > 1 ? [
        { key: 'auto', label: 'Auto', value: null },
        ...heights.map(height => ({ key: String(height), label: `${height}p`, value: height })),
      ] : [], selected == null ? 'auto' : String(selected));
      if (next !== qualityMenu) { qualityMenu = next; publish(); }
    };
    const tracksChanged = (updateSubtitles: boolean) => {
      if (active && !failed) { refreshObserved(updateSubtitles); publish(); void refreshQuality(); }
    };
    const subtitleChanged = () => { if (active && !failed && refreshSubtitles()) publish(); };
    const save = () => { if (active && !failed && ready && !live && !p.isLive && p.currentTime > 0 && p.duration > 0 && Number.isFinite(p.duration)) callbacks.current.onProgress?.(p.currentTime, p.duration); };
    const selectSubtitle = (id: string) => {
      if (!active || failed) return;
      const changed = refreshSubtitles(); // Rebind against the decoder before using the token.
      subtitles.choose(id, track => { p.subtitleTrack = track; });
      if (changed) publish();
    };
    const controls: Engine = {
      read, toggle: () => { if (ready) { if (p.playing) p.pause(); else { if (p.duration > 0 && p.currentTime >= p.duration) p.currentTime = 0; p.play(); } } },
      seek: (n: number) => { const s = read(); if (ready && s.duration > 0 && Number.isFinite(n)) { p.currentTime = clamp(n, s.duration); publish(); } },
      mute: () => { p.muted = !(p.muted || p.volume === 0); if (!p.muted && !p.volume) p.volume = 1; },
      volume: (n: number) => { p.volume = clamp(n, 1); p.muted = n === 0; },
      nextAudio: () => { const a = distinct(p.availableAudioTracks); if (a.length > 1) p.audioTrack = a[(a.findIndex(t => key(t) === key(p.audioTrack)) + 1) % a.length]; },
      nextSubtitles: () => {
        if (!active || failed) return;
        const changed = refreshSubtitles();
        const menu = subtitleMenu;
        if (menu) {
          const next = (menu.options.findIndex(option => option.id === menu.selected) + 1) % menu.options.length;
          subtitles.choose(menu.options[next].id, track => { p.subtitleTrack = track; });
        }
        if (changed) publish();
      },
      selectSubtitle,
      selectQuality: bridge ? id => {
        if (!active || failed) return;
        quality.choose(id, height => {
          const revision = ++qualityRevision;
          pendingQuality = true;
          // Serialize native writes, dropping superseded commands that haven't started yet.
          qualityQueue = qualityQueue.then(async () => {
            if (!active || failed || revision !== qualityRevision) return;
            try { await bridge.selectHeight(p, height); } catch { /* The decoder may have been released. */ }
            if (!active || failed || revision !== qualityRevision) return;
            pendingQuality = false;
            // Read back even on refusal; neither a requested height nor an old promise is UI state.
            await refreshQuality();
          });
        });
      } : undefined,
    };
    engineRef.current = controls;
    const fail = () => { if (!active || failed) return; failed = true; clearTimeout(timer); callbacks.current.onError(); p.pause(); };
    const timer = setTimeout(fail, 15000);
    const update = (status: VideoPlayerStatus) => {
      if (!active || failed) return;
      if (status === 'error') { fail(); return; }
      if (status !== 'readyToPlay') return;
      if (ready) { tracksChanged(true); return; }
      ready = true; clearTimeout(timer); refreshObserved(true); const s = read();
      if (s.duration > 0 && initialPosition > 0) p.currentTime = Math.min(initialPosition, Math.max(0, s.duration - .1));
      publish(); void refreshQuality(); if (autoplay) p.play();
    };
    const subs = [p.addListener('statusChange', ({ status }) => update(status)), p.addListener('playingChange', ({ isPlaying }) => { publish(); if (!isPlaying) save(); }),
      p.addListener('timeUpdate', () => { publish(); if (Date.now() - lastSave > 4500) { lastSave = Date.now(); save(); } }),
      p.addListener('playToEnd', () => { publish(); save(); }), p.addListener('volumeChange', publish), p.addListener('mutedChange', publish),
      p.addListener('sourceLoad', () => tracksChanged(true)), p.addListener('videoTrackChange', () => tracksChanged(false)),
      p.addListener('availableAudioTracksChange', () => tracksChanged(false)), p.addListener('availableSubtitleTracksChange', () => tracksChanged(true)),
      p.addListener('audioTrackChange', publish), p.addListener('subtitleTrackChange', subtitleChanged)];
    void Promise.resolve().then(() => {
      if (!active || failed) return;
      const status = p.status;
      update(status);
      if (status === 'idle' || status === 'loading') tracksChanged(true);
    });
    return () => { active = false; quality.clear(); subtitles.clear(); clearTimeout(timer); subs.forEach(s => s.remove()); if (engineRef.current === controls) engineRef.current = null; };
  }, [p, engineRef, autoplay, live, initialPosition, source.type]);
  // Expo keys the decoder by the serialized source. Scope Android's untagged view events to that same source.
  return <VideoView key={Platform.OS === 'android' ? JSON.stringify(videoSource) : undefined} player={p} style={fill} pointerEvents="none" nativeControls={false} focusable={false} accessible={false}
    onFirstFrameRender={Platform.OS === 'android' ? onFirstFrameRender : undefined}
    contentFit="contain" fullscreenOptions={{ enable: false }} playsInline allowsVideoFrameAnalysis={false} />;
}
