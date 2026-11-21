import React, { useCallback, useEffect, useLayoutEffect, useMemo, useReducer, useRef, useState } from "react";
import { Platform, ScrollView, View } from "react-native";
import { SafeAreaView } from 'react-native-safe-area-context';
import { apiChannelSources, apiSources, hasService, sourceFailure } from "../lib/api";
import { isReaderKey, preferredReader, rankReaderBatch, shouldContinueReaders, type ReaderBatch } from '../lib/readerStartup';
import { isEpisodicTitle } from "../lib/resume";
import { useApp } from "../lib/store";
import type { Channel, Progress, SourceBatch, Title, VideoSource } from "../lib/types";
import Player from "./Player";
import { Button, T } from "./UI";
import { Glass } from './Glass';
import { initialAttempt, playbackTarget, playableSources, updateAttempt } from "./playback";
import { atRest, type Engine, type Transport } from './playerTypes';
import { PlaybackRoom } from './PlaybackRoom';
import { linkChoices, playbackLinks } from './sourceMenu';

function Notice({ title, children }: { title: string; children: React.ReactNode }) {
  const { dismiss } = useApp();
  return <SafeAreaView style={{ flex: 1, backgroundColor: 'rgba(0,0,0,.82)', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
    <Glass dark style={{ width: '100%', maxWidth: 520, maxHeight: '100%' }}><ScrollView contentContainerStyle={{ gap: 14, padding: 22 }}>
      <T role="header" size={33} weight="display" color="#FFF">{title}</T>{children}
      <Button variant="glass" label="Fermer" icon="close" onPress={dismiss} />
    </ScrollView></Glass>
  </SafeAreaView>;
}

type WatchProps = { item: Title; season?: number; episode?: number; label?: string; restart?: boolean };

export function WatchPlayback({ item, season, episode, label, restart }: WatchProps) {
  const { progress, open, token, authSessionId } = useApp();
  const episodic = isEpisodicTitle(item);
  const target = playbackTarget(item.kind, restart ? undefined : progress.find(p => p.id === item.id), season, episode, episodic);
  const type = !episodic ? "film" : item.kind === "Animé" ? "anime" : "serie";
  const catalogId = item.catalogId ?? item.id;
  if (!target) return <Notice title={item.title}>
    <T color="#DDD">Choisissez un épisode dans la fiche pour lancer la lecture.</T>
    <Button autoFocus label="Choisir un épisode" icon="list" onPress={() => open({ type: "detail", item })} />
  </Notice>;
  const episodeLabel = target.episode == null ? undefined : label || `S${target.season} E${target.episode}`;
  return <PlaybackSheet
    key={`vod:${authSessionId}:${item.id}:${catalogId}:${type}:${target.season ?? ""}:${target.episode ?? ""}:${!!restart}`}
    title={item.title}
    subtitle={episodeLabel}
    initialPosition={target.position}
    // Catalogue-level embeds cannot identify an episode.
    declared={type === "film" ? item.sources : undefined}
    animeId={type === 'anime' ? catalogId : undefined}
    resolve={hasService && token ? (signal, options) => apiSources({
      id: catalogId, type, season: target.season, episode: target.episode,
      ...(!item.catalogId && /^tt\d+$/i.test(item.id) ? { title: item.title, year: item.year || undefined } : {}),
    }, token, signal, options) : undefined}
    record={{ id: item.id, label: episodeLabel, season: target.season, episode: target.episode }}
    needsAccount={hasService && !token}
    credit={item.id === "tt1254207" ? "Big Buck Bunny · © Blender Foundation · CC BY 3.0." : undefined}
  />;
}

export function LivePlayback({ channel }: { channel: Channel }) {
  const slug = /^tv_([A-Za-z0-9_-]+)$/.exec(channel.id)?.[1];
  return <PlaybackSheet
    key={`live:${channel.id}`}
    title={channel.name}
    subtitle={channel.category}
    // A remote card always resolves on open. The server decides which variants
    // to serve; a bundled stream here would defer discovery of that inventory.
    declared={slug ? undefined : channel.sources}
    resolve={hasService && slug ? async signal => ({ sources: (await apiChannelSources(slug, signal)).items }) : undefined}
    live
  />;
}

type SessionProps = {
  title: string;
  subtitle?: string;
  declared?: VideoSource[];
  resolve?: (signal: AbortSignal, options?: { preferReader?: string; remaining?: string[] }) => Promise<SourceBatch>;
  animeId?: string;
  initialPosition?: number;
  record?: Pick<Progress, "id" | "label" | "season" | "episode">;
  live?: boolean;
  needsAccount?: boolean;
  credit?: string;
};

type Lookup = { retry: number; batches: ReaderBatch[]; remaining?: string[]; error?: ReturnType<typeof sourceFailure> };

function canObserveFirstFrame() {
  return Platform.OS === 'android' || (Platform.OS === 'web' && typeof HTMLVideoElement !== 'undefined'
    && typeof HTMLVideoElement.prototype.requestVideoFrameCallback === 'function');
}

function PlaybackSheet({ title, subtitle, declared, resolve, animeId, initialPosition = 0, record, live, needsAccount, credit }: SessionProps) {
  const app = useApp();
  const { prefs, saveProgress, back, open, logout } = app;
  const readerStartup = animeId ? app.readerStartup : undefined;
  const resolver = useRef(resolve);
  const [local] = useState(() => playableSources(declared));
  const [retry, retryLookup] = useReducer(n => n + 1, 0);
  const [result, setResult] = useState<Lookup | null>(null);
  // Play a declared direct stream for this exact title/channel immediately. No account-bound VOD is fetched anonymously.
  const [askRemote, setAskRemote] = useState(!local.length);
  const [drainMenu, setDrainMenu] = useState(false);
  const [attempt, dispatch] = useReducer(updateAttempt, initialAttempt);
  const engine = useRef<Engine | null>(null);
  const position = useRef(initialPosition);
  const [start, setStart] = useState({ position: initialPosition, autoplay: prefs.autoplay, muted: false, volume: 1 });
  const capture = () => {
    const s = engine.current?.read();
    if (s?.ready && !s.live && s.duration > 0 && Number.isFinite(s.position)) position.current = s.position;
    setStart(prev => ({ position: position.current, autoplay: s?.ready ? s.playing : prev.autoplay, muted: s?.ready ? s.muted : prev.muted, volume: s?.ready ? s.volume : prev.volume }));
  };
  useLayoutEffect(() => { resolver.current = resolve; }, [resolve]);
  const remote = !!resolve && askRemote;
  const currentResult = remote && result?.retry === retry ? result : null;
  const batches = currentResult?.batches;
  const links = useMemo(() => playbackLinks(local, ...(batches ?? [])), [local, batches]);
  const source = links[attempt.index]?.source;
  const count = links.length;
  const exhausted = attempt.exhausted;
  const canExtend = exhausted && count > attempt.failed.length;
  const needsMore = count === 0 || (exhausted && !canExtend);
  const issue = currentResult?.error;
  const remaining = currentResult?.remaining;
  const continuing = shouldContinueReaders(remaining, needsMore, drainMenu, !!issue);
  // Keep a single in-flight batch. Its response can only append to the prefix
  // used to request it, even when exhaustion and the drawer both ask for it.
  const request = !remote ? false : !currentResult ? null : continuing ? remaining! : false;
  useLayoutEffect(() => {
    if (request === false) return;
    const controller = new AbortController();
    const readScores = () => animeId ? readerStartup?.read(Platform.OS, animeId, performance.now()) : undefined;
    const preferReader = request === null ? preferredReader(readScores()) : undefined;
    resolver.current?.(controller.signal, request ? { remaining: request } : preferReader ? { preferReader } : undefined)
      .then(reply => {
        if (controller.signal.aborted) return;
        const playable = playableSources(reply.sources);
        const batch = animeId ? rankReaderBatch(playable, readScores()) : playable;
        setResult(previous => ({ retry, batches: [...(request ? previous?.batches ?? [] : []), batch], remaining: reply.remaining }));
      }).catch((err: unknown) => {
        if (controller.signal.aborted) return;
        const error = sourceFailure(err, Platform.OS === 'web', !!live);
        setResult(previous => ({ retry, batches: request ? previous?.batches ?? [] : [], remaining: request ?? undefined, error }));
      });
    return () => controller.abort();
  }, [request, retry, animeId, readerStartup, live]);

  const [clock, setClock] = useState(Date.now);
  const retryAt = issue?.retryAt ?? 0;
  useEffect(() => {
    if (!retryAt || clock >= retryAt) return;
    const timer = setTimeout(() => setClock(Date.now()), Math.min(2_000_000_000, Math.max(1, retryAt - Date.now())));
    return () => clearTimeout(timer);
  }, [retryAt, clock]);
  const pending = request !== false;
  // An optional lookup only enriches the menu while a playable link remains.
  const loading = pending && needsMore;
  useLayoutEffect(() => {
    if (canExtend) dispatch({ type: 'extend', count });
  }, [canExtend, count]);
  const canRetryRemote = remote && !pending;
  const retryDisabled = clock < retryAt;
  const generation = attempt.generation;
  const playback = useMemo(() => !exhausted && !loading && source ? { generation, source } : null, [exhausted, generation, loading, source]);
  const current = useRef(playback);
  const startup = useRef<{ mountedAt: number; played: boolean; invalid: boolean } | null>(null);
  useLayoutEffect(() => {
    current.current = playback;
    startup.current = animeId && playback && start.autoplay && isReaderKey(playback.source.readerKey) && canObserveFirstFrame()
      ? { mountedAt: performance.now(), played: false, invalid: false } : null;
    return () => { current.current = null; startup.current = null; };
  }, [playback, animeId, start.autoplay]);
  const onFirstFrame = () => {
    const sample = startup.current;
    if (!animeId || !playback || current.current !== playback || !sample) return;
    startup.current = null; // Even an unscorable frame ends the startup attempt.
    if (sample.invalid) return;
    const state = engine.current?.read();
    if (!state?.playing || state.live) return;
    const now = performance.now();
    readerStartup?.recordFrame(Platform.OS, animeId, playback.source.readerKey, now - sample.mountedAt, now);
  };
  const [report, setReport] = useState({ playback: null as typeof playback, state: atRest, engine: null as Engine | null });
  const onState = useCallback((state: Transport) => {
    if (!playback || current.current !== playback) return;
    const sample = startup.current;
    if (sample) {
      if (state.playing) sample.played = true;
      else if (sample.played) sample.invalid = true; // Pausing before the frame invalidates the sample.
    }
    setReport({ playback, state, engine: engine.current });
  }, [playback]);
  const activeReport = playback && report.playback === playback ? report : null;
  // Source labels depend only on the inventory. Track menus come from the current decoder below.
  const choices = useMemo(() => linkChoices(links), [links]);
  const state = activeReport?.state ?? { ...atRest, live: !!live };
  const selectTrack = (method: 'selectQuality' | 'selectSubtitle', menu: 'qualityMenu' | 'subtitleMenu') => {
    const decoder = activeReport?.engine;
    if (!decoder?.[method]) return undefined;
    return (id: string) => {
      if (current.current !== playback || engine.current !== decoder) return;
      if (decoder.read()[menu]?.options.some(option => option.id === id)) decoder[method]?.(id);
    };
  };
  const remember = (value: number, total: number) => {
    if (!playback || current.current !== playback || live || !record || !(value > 0 && total > 0)) return;
    position.current = value; saveProgress({ ...record, position: Math.min(value, total), total, updated: Date.now() });
  };
  const reload = () => {
    if (Date.now() < retryAt || pending || issue?.status === 401 || issue?.status === 403) return;
    if (issue && remaining) {
      setResult(previous => previous && { ...previous, error: undefined });
      return;
    }
    current.current = null;
    dispatch({ type: 'retry' });
    if (canRetryRemote) retryLookup();
  };

  if (!loading && (!source || (exhausted && (issue?.status === 401 || issue?.status === 403)))) return <Notice title={title}>
    {!!subtitle && <T color="#C1C1BF">{subtitle}</T>}
    <View accessibilityLiveRegion="polite"><T color="#DDD">
      {issue?.message ?? (needsAccount ? 'Connectez-vous pour rechercher les lecteurs de ce titre.' : 'Aucune source de lecture intégrée n’est disponible.')}
    </T></View>
    {canRetryRemote && issue?.status !== 401 && issue?.status !== 403 && <Button autoFocus disabled={retryDisabled} label={retryDisabled ? 'Réessayer plus tard' : 'Recharger les sources'} icon="refresh" onPress={reload} />}
    {!live && issue?.status === 401 && <Button autoFocus label="Me reconnecter" icon="person-outline" onPress={() => { logout(); open({ type: 'account' }); }} />}
    {needsAccount && <Button autoFocus label="Connecter mon compte" icon="person-outline" onPress={() => open({ type: "account" })} />}
    {!canRetryRemote && !needsAccount && <Button autoFocus label="Retour" icon="arrow-back" onPress={back} />}
  </Notice>;

  return <PlaybackRoom title={title} subtitle={subtitle} credit={credit} state={state} engine={engine} choices={choices}
    index={attempt.index} failed={attempt.failed} exhausted={exhausted && !loading} resolving={loading} issue={issue?.message} retryDisabled={retryDisabled}
    onOpenMenu={() => { setAskRemote(true); if (animeId) setDrainMenu(true); }}
    onTogglePlayback={() => { if (startup.current) startup.current.invalid = true; }}
    onSelect={index => { capture(); current.current = null; dispatch({ type: 'select', index, count }); }}
    onSelectQuality={selectTrack('selectQuality', 'qualityMenu')} onSelectSubtitle={selectTrack('selectSubtitle', 'subtitleMenu')}
    onRetry={reload}
    onQuit={() => { const s = engine.current?.read(); if (s?.ready) remember(s.position, s.duration); current.current = null; back(); }}>
    {playback && <Player key={generation} engine={engine} onState={onState} source={playback.source} title={title}
      autoplay={start.autoplay} initialPosition={start.position} initialMuted={start.muted} initialVolume={start.volume} live={live}
      onFirstFrame={animeId && start.autoplay && isReaderKey(playback.source.readerKey) ? onFirstFrame : undefined}
      onError={() => {
        if (current.current !== playback) return;
        const sample = startup.current;
        const state = engine.current?.read();
        if (animeId && sample && !sample.invalid && !state?.live && (!sample.played || state?.playing)) {
          readerStartup?.recordFailure(Platform.OS, animeId, playback.source.readerKey, performance.now());
        }
        startup.current = null;
        capture(); current.current = null; dispatch({ type: 'fail', generation, count });
      }} onProgress={record ? remember : undefined} />}
  </PlaybackRoom>;
}
