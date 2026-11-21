import React, { useEffect, useLayoutEffect, useRef } from 'react';
import { clamp, type PlayerProps, type Transport } from './playerTypes';
import { observeTracks } from './observedTracks';
import { createChoiceScope } from './trackChoices';
import { htmlSubtitles, matchingRendition, qualityChoices, subtitleChoices, type WebSubtitle } from './webTrackControls';
import { trackLanguageName } from '../lib/sourceInfo';
import type HlsEngine from 'hls.js';

type NativeAudio = { label: string; language: string; enabled: boolean };
type AudioList = EventTarget & ArrayLike<NativeAudio>;
const trackName = (t: { name?: string; label?: string; lang?: string; language?: string }, i: number) => t.name || t.label || t.lang || t.language || `Piste ${i + 1}`;

/** Decoder only. No browser controls, fullscreen video activity, embed or external chrome. */
export default function Player({ source: { url, type }, title, live, initialPosition = 0, initialMuted, initialVolume, autoplay, engine: engineRef, onState, onProgress, onError, onFirstFrame }: PlayerProps) {
  const ref = useRef<HTMLVideoElement>(null);
  const callbacks = useRef({ onState, onProgress, onError, onFirstFrame });
  useLayoutEffect(() => { callbacks.current = { onState, onProgress, onError, onFirstFrame }; }, [onState, onProgress, onError, onFirstFrame]);
  const frameGeneration = useRef<object | null>(null);
  // Invalidate notifications at commit, even if the old decoder's passive cleanup has not run yet.
  useLayoutEffect(() => {
    frameGeneration.current = {};
    return () => { frameGeneration.current = null; };
  }, [url, type, live, initialPosition, autoplay, initialVolume, initialMuted, engineRef]);
  useEffect(() => {
    const v = ref.current;
    if (!v) return;
    const generation = frameGeneration.current;
    let frameRequest: number | undefined;
    const cancelFrame = () => {
      if (frameRequest === undefined) return;
      v.cancelVideoFrameCallback?.(frameRequest);
      frameRequest = undefined;
    };
    let active = true, failed = false, ready = false, restored = false, streamLive = false, lastSave = 0;
    let hls: HlsEngine | undefined;
    let observed: Transport['observed'];
    let qualityMenu: Transport['qualityMenu'], subtitleMenu: Transport['subtitleMenu'], subtitleLabel: string | null = null;
    const qualityScope = createChoiceScope<number>(), subtitleScope = createChoiceScope<WebSubtitle>();
    const subtitleKeys = new WeakMap<object, string>();
    let nextSubtitleKey = 0, refreshQueued = false, groupsChanged = false;
    let preferredSubtitle: WebSubtitle | undefined;
    const valid = () => active && !failed && ref.current === v;
    const audioList = (v as HTMLVideoElement & { audioTracks?: AudioList }).audioTracks;
    const audio = () => Array.from(audioList ?? []);
    const captions = () => v.readyState >= 1 ? htmlSubtitles(v.textTracks, hls?.allSubtitleTracks ?? []) : [];
    const subtitleKey = (track: object) => {
      let key = subtitleKeys.get(track);
      if (!key) { key = `subtitle:${++nextSubtitleKey}`; subtitleKeys.set(track, key); }
      return key;
    };
    const refreshMenus = () => {
      const h = hls;
      const quality = qualityChoices(h?.levels ?? [], h?.manualLevel ?? -1, h?.audioTracks[h.audioTrack]?.groupId);
      const subtitle = subtitleChoices(h?.subtitleTracks ?? [], captions(), h?.subtitleDisplay ? h.subtitleTrack : -1, subtitleKey, trackLanguageName);
      qualityMenu = qualityScope.update(quality.entries, quality.selected);
      subtitleMenu = subtitleScope.update(subtitle.entries, subtitle.selected);
      subtitleLabel = subtitleMenu?.options.find(o => o.id === subtitleMenu?.selected)?.label ?? null;
    };
    const read = (): Transport => {
      const isLive = !!live || streamLive || v.duration === Infinity;
      const a = hls ? hls.audioTracks : audio(), ai = hls ? hls.audioTrack : audio().findIndex(t => t.enabled);
      return { ready, playing: !v.paused && !v.ended, position: v.currentTime || 0, duration: !isLive && Number.isFinite(v.duration) ? v.duration : 0, live: isLive,
        muted: v.muted, volume: v.volume, audio: a.length > 1 ? a[ai] ? trackName(a[ai], ai) : 'Choisir' : null,
        subtitles: subtitleLabel, observed, qualityMenu, subtitleMenu };
    };
    const publish = () => { if (valid()) callbacks.current.onState(read()); };
    const tracksChanged = () => {
      if (!valid()) return;
      const hasMetadata = v.readyState >= 1;
      // Track groups can change with the level: use the decoder's available list, not its selected index.
      const hlsAudio = hls?.audioTracks;
      observed = observeTracks({ audio: hlsAudio?.length ? hlsAudio : hasMetadata ? audioList : undefined,
        subtitles: hls?.subtitleTracks, textTracks: hasMetadata ? v.textTracks : undefined,
        video: hls?.levels, videoHeight: hasMetadata ? v.videoHeight : undefined });
      refreshMenus();
      publish();
    };
    const applySubtitle = (choice: WebSubtitle, preserve = false) => {
      const list = captions(), h = hls;
      if (choice.kind === 'hls') {
        if (!h) return;
        const index = preserve ? matchingRendition(h.subtitleTracks, choice.track) : h.subtitleTracks.findIndex(t => t === choice.track);
        if (index < 0) return;
        for (const track of list) if (track.mode !== 'disabled') track.mode = 'disabled';
        if (!h.subtitleDisplay) h.subtitleDisplay = true;
        if (!preserve || h.subtitleTrack !== index) h.subtitleTrack = index;
      } else {
        if (choice.kind === 'html' && !list.includes(choice.track)) return;
        if (h && (!preserve || h.subtitleTrack !== -1)) h.subtitleTrack = -1;
        for (const track of list) {
          const mode = choice.kind === 'html' && choice.track === track ? 'showing' : 'disabled';
          if (track.mode !== mode) track.mode = mode;
        }
      }
      if (!preserve) preferredSubtitle = choice;
    };
    const queueTracksChanged = () => {
      if (!valid() || refreshQueued) return;
      refreshQueued = true;
      // Hls emits SUBTITLE_TRACKS_UPDATED before applying its group selection and creating track nodes.
      queueMicrotask(() => {
        refreshQueued = false;
        if (!valid()) return;
        const restoreSubtitle = groupsChanged;
        groupsChanged = false;
        if (restoreSubtitle && preferredSubtitle) applySubtitle(preferredSubtitle, true);
        tracksChanged();
      });
    };
    const selectSubtitle = (id: string) => {
      if (!valid()) return;
      refreshMenus();
      if (subtitleScope.choose(id, applySubtitle)) tracksChanged();
    };
    const save = () => {
      if (!valid() || !ready || v.seeking) return;
      const s = read();
      if (s.duration > 0 && s.position > 0) callbacks.current.onProgress?.(s.position, s.duration);
    };
    const time = () => { publish(); if (Date.now() - lastSave > 4500) { lastSave = Date.now(); save(); } };
    const toggled = () => { publish(); if (v.paused) save(); };
    const play = () => { void v.play().catch(publish); }; // Autoplay denial is not a broken source.
    const controls = {
      read, toggle: () => { if (ready) { if (v.paused) play(); else v.pause(); } },
      seek: (t: number) => { const s = read(); if (ready && s.duration > 0 && Number.isFinite(t)) { v.currentTime = clamp(t, s.duration); publish(); } },
      mute: () => { v.muted = !(v.muted || v.volume === 0); if (!v.muted && !v.volume) v.volume = 1; },
      volume: (n: number) => { v.volume = clamp(n, 1); v.muted = n === 0; },
      nextAudio: () => { if (hls && hls.audioTracks.length > 1) hls.audioTrack = (hls.audioTrack + 1) % hls.audioTracks.length;
        else { const list = audio(); if (list.length > 1) list[(list.findIndex(t => t.enabled) + 1) % list.length].enabled = true; } publish(); },
      selectQuality: (id: string) => {
        const h = hls;
        if (!valid() || !h) return;
        refreshMenus();
        // A conservative loadLevel change alone can leave an entirely buffered
        // programme at the old resolution. Switch at a fragment boundary instead.
        if (qualityScope.choose(id, index => { if (h.manualLevel !== index) h.nextLevel = index; })) tracksChanged();
      },
      selectSubtitle,
      nextSubtitles: () => {
        if (!valid()) return;
        refreshMenus();
        const options = subtitleMenu?.options;
        if (options?.length) selectSubtitle(options[(options.findIndex(o => o.id === subtitleMenu?.selected) + 1) % options.length].id);
      },
    };
    engineRef.current = controls; v.muted = initialMuted; v.volume = clamp(initialVolume, 1);
    const fail = () => {
      if (!valid()) return;
      failed = true; clearTimeout(timer); cancelFrame(); hls?.stopLoad();
      callbacks.current.onError(); v.pause();
    };
    const timer = setTimeout(fail, 15000);
    const restore = () => {
      if (!valid() || restored || live || streamLive || !(initialPosition > 0) || !Number.isFinite(v.duration) || v.duration <= 0) return;
      restored = true; v.currentTime = Math.min(initialPosition, Math.max(0, v.duration - .1));
    };
    const canPlay = () => {
      if (!valid() || ready) return;
      restore(); if (v.seeking || v.readyState < 3) return;
      ready = true; clearTimeout(timer); publish(); if (autoplay) play();
    };
    const handlers = { loadedmetadata: () => { restore(); tracksChanged(); }, resize: tracksChanged,
      canplay: canPlay, seeked: () => { canPlay(); publish(); save(); }, timeupdate: time, play: toggled, pause: toggled,
      ended: toggled, volumechange: publish, durationchange: publish, error: fail };
    Object.entries(handlers).forEach(([e, fn]) => v.addEventListener(e, fn));
    for (const list of [v.textTracks, audioList]) for (const e of ['change', 'addtrack', 'removetrack']) list?.addEventListener(e, queueTracksChanged);
    const requestFirstFrame = () => {
      if (!valid() || frameGeneration.current !== generation || typeof v.requestVideoFrameCallback !== 'function') return;
      frameRequest = v.requestVideoFrameCallback(() => {
        if (frameRequest === undefined) return;
        frameRequest = undefined;
        if (valid() && frameGeneration.current === generation) callbacks.current.onFirstFrame?.();
      });
    };
    void (async () => {
      try {
        if (type !== 'hls') { v.src = url; requestFirstFrame(); return; }
        const Decoder = (await import('hls.js').catch(() => undefined))?.default;
        if (!valid()) return;
        if (!Decoder?.isSupported()) {
          if (v.canPlayType('application/vnd.apple.mpegurl')) { v.src = url; requestFirstFrame(); }
          else fail();
          return;
        }
        const h = new Decoder({ capLevelToPlayerSize: true }); hls = h;
        h.on(Decoder.Events.MANIFEST_PARSED, queueTracksChanged);
        h.on(Decoder.Events.AUDIO_TRACKS_UPDATED, queueTracksChanged);
        h.on(Decoder.Events.SUBTITLE_TRACKS_UPDATED, () => { groupsChanged = true; queueTracksChanged(); });
        h.on(Decoder.Events.LEVELS_UPDATED, queueTracksChanged); h.on(Decoder.Events.LEVEL_SWITCHING, queueTracksChanged);
        h.on(Decoder.Events.LEVEL_SWITCHED, queueTracksChanged);
        h.on(Decoder.Events.LEVEL_LOADED, (_e, { details }) => { streamLive = details.live; publish(); });
        h.on(Decoder.Events.AUDIO_TRACK_SWITCHED, queueTracksChanged); h.on(Decoder.Events.SUBTITLE_TRACK_SWITCH, queueTracksChanged);
        h.on(Decoder.Events.ERROR, (_e, data) => { if (data.fatal) fail(); });
        h.loadSource(url); h.attachMedia(v); requestFirstFrame();
      } catch { fail(); }
    })();
    return () => {
      active = false; clearTimeout(timer); cancelFrame(); if (engineRef.current === controls) engineRef.current = null;
      qualityScope.clear(); subtitleScope.clear();
      Object.entries(handlers).forEach(([e, fn]) => v.removeEventListener(e, fn));
      for (const list of [v.textTracks, audioList]) for (const e of ['change', 'addtrack', 'removetrack']) list?.removeEventListener(e, queueTracksChanged);
      hls?.destroy(); v.pause(); v.removeAttribute('src'); v.load();
    };
  }, [url, type, live, initialPosition, autoplay, initialVolume, initialMuted, engineRef]);
  return <video ref={ref} aria-label={title} tabIndex={-1} playsInline controls={false} disablePictureInPicture disableRemotePlayback preload="auto"
    style={{ display: 'block', width: '100%', height: '100%', objectFit: 'contain', background: '#000', pointerEvents: 'none' }} />;
}
