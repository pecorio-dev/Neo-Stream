import React, { useLayoutEffect, useRef, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, ScrollView, View } from "react-native";
import { requestTvControlFocus } from './tv/TvFocus';
import { BlurTargetView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { Glass } from './Glass';
import { ProgressMeter } from './ProgressMeter';
import { AsciiField } from './phone/AsciiField';
import { SheetText as T } from './SheetText';
import { useApp } from "../lib/store";
import {
  CastMember,
  MediaSeason,
  Title,
} from "../lib/types";
import { firstEpisode, isEpisodicTitle, resumeFor } from "../lib/resume";
import { useTitleMedia } from "../lib/useTitleMedia";
import { titleGenres, matchesGenre } from '../lib/genres';
import {
  Art,
  Button,
  Chip,
  Click,
  fill,
  I,
  row,
  useLayout,
} from "./UI";
function Metadata({ item }: { item: Title }) {
  const { phone } = useLayout();
  const { theme } = useApp();
  return (
    <View style={[row, { flexWrap: "wrap", gap: 9 }]}>
      {!!item.rating && (
        <View style={[row, { gap: 4 }]}>
          <I name="star" size={13} color={phone ? theme.accent : '#F5F5F3'} />
          <T size={13} color={phone ? theme.text : '#F5F5F3'} weight="bold">
            {item.rating}
          </T>
        </View>
      )}
      <T size={13} color={phone ? theme.muted : '#E9E9E6'} weight="medium" style={phone && { flexShrink: 1 }}>
        {[item.kind, item.year || null, item.duration].filter(Boolean).join('  /  ')}
      </T>
    </View>
  );
}

const TMDB_PROFILE = "https://image.tmdb.org/t/p/w185";
function profileUri(path?: string | null): string | null {
  if (!path) return null;
  if (/^https:\/\//i.test(path)) return path;
  if (!/^\/?[\w.-]+$/.test(path)) return null;
  return TMDB_PROFILE + (path.startsWith("/") ? path : `/${path}`);
}
function Pill({ label }: { label: string }) {
  const { theme } = useApp();
  return (
    <View
      style={{
        borderRadius: 11,
        borderWidth: 1,
        borderColor: theme.border,
        backgroundColor: theme.elevated,
        paddingHorizontal: 10,
        paddingVertical: 4,
      }}
    >
      <T size={12} weight="medium" color={theme.muted}>
        {label}
      </T>
    </View>
  );
}
/** Photos TMDB en rangée horizontale ; repli sur des chips de noms. */
function CastStrip({ cast, names }: { cast: CastMember[]; names: string[] }) {
  const { theme, tv } = useApp();
  const withPhoto = cast.some((c) => !!profileUri(c.profile_path));
  if (!withPhoto) {
    return names.length ? (
      <View style={[row, { flexWrap: "wrap", gap: 7 }]}>
        {names.map((name, i) => (
          <Pill key={`${name}-${i}`} label={name.replace(/&apos;/g, "'")} />
        ))}
      </View>
    ) : null;
  }
  const portrait = (person: CastMember, index: number) => (
        <View key={`${person.name}-${index}`} style={{ width: tv ? 112 : 74, gap: 5 }}>
          <View
            style={{
              height: tv ? 146 : 98,
              borderRadius: 8,
              overflow: "hidden",
              backgroundColor: theme.elevated,
            }}
          >
            {profileUri(person.profile_path) ? (
              <Art source={profileUri(person.profile_path)!} style={fill} label={`Photo de ${person.name}`} />
            ) : (
              <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
                <I name="person-outline" size={24} color={theme.muted} />
              </View>
            )}
          </View>
          <T size={10} weight="semibold" lines={2}>
            {person.name}
          </T>
          {!!person.character && (
            <T size={9} color={theme.faint} lines={1}>
              {person.character}
            </T>
          )}
        </View>
      );
  if (tv) return <View style={[row, { gap: 12, flexWrap: 'wrap', alignItems: 'flex-start' }]}>{cast.map(portrait)}</View>;
  return (
    <FlatList horizontal data={cast} keyExtractor={(c, i) => `${c.name}-${i}`} showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ gap: 10, paddingRight: 4 }} renderItem={({ item, index }) => portrait(item, index)}
    />
  );
}
/** Saisons + épisodes cliquables, chargés à la demande via `?op=media`. */
type Visit = { season?: number; limit?: number; episode?: number; y?: number };
const episodeMemory = new WeakMap<object, Visit>();
function remember(key: object | null, change: Visit) {
  if (key) episodeMemory.set(key, { ...episodeMemory.get(key), ...change });
}
function DetailBody({ children }: { children: React.ReactNode }) {
  const { tv, overlay } = useApp();
  const scroller = useRef<ScrollView>(null);
  const visit = tv && overlay ? episodeMemory.get(overlay) : undefined;
  // Never replay a throttled pixel offset over the returning episode's focus scroll.
  const restore = useRef(typeof HTMLElement === 'undefined' || visit?.episode == null ? visit?.y : undefined);
  if (!tv) return <View>{children}</View>;
  return <ScrollView ref={scroller} testID="detail-commands" style={{ flex: 1, minWidth: 0 }}
    scrollEventThrottle={48} onScroll={e => remember(overlay, { y: e.nativeEvent.contentOffset.y })}
    onContentSizeChange={() => { if (restore.current !== undefined) { scroller.current?.scrollTo({ y: restore.current, animated: false }); restore.current = undefined; } }}>{children}</ScrollView>;
}
function EpisodeBlock({
  seasons,
  loading,
  selectedSeason,
  onPlay,
}: {
  seasons: MediaSeason[];
  loading: boolean;
  selectedSeason?: number;
  onPlay: (season: number, episode: number, label: string) => void;
}) {
  const { theme, overlay, tv, phone } = useApp();
  const memoryKey = tv || phone ? overlay : null;
  const previous = memoryKey && episodeMemory.get(memoryKey);
  const [selection, setSelection] = useState<number | null>(previous?.season ?? null);
  const [limit, setLimit] = useState(previous?.limit ?? 24);
  const [returnTo, setReturnTo] = useState(tv ? previous?.episode : undefined);
  const restored = useRef(false);
  const episodeRef = useRef<React.ComponentRef<typeof Pressable>>(null);
  const delayed = useRef(loading);
  const seasonNumber = selection ?? selectedSeason;
  useLayoutEffect(() => {
    const target = episodeRef.current;
    if (!tv || loading || returnTo == null || typeof HTMLElement === 'undefined' || !(target instanceof HTMLElement)) return;
    const reveal = () => {
      if (target.isConnected && document.activeElement === target)
        target.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
    };
    // The portal may focus before layout settles, or after async seasons arrive.
    const observer = typeof IntersectionObserver !== 'undefined' ? new IntersectionObserver(([entry]) => {
      if (entry && entry.intersectionRatio < 1) reveal();
    }, { threshold: 1 }) : undefined;
    const stop = () => { observer?.disconnect(); target.removeEventListener('focus', reveal); };
    observer?.observe(target);
    target.addEventListener('focus', reveal);
    target.addEventListener('blur', stop, { once: true });
    reveal();
    return () => { stop(); target.removeEventListener('blur', stop); };
  }, [tv, overlay, returnTo, loading, seasonNumber]);
  useLayoutEffect(() => {
    // Synchronous returns are restored by TvDialogScope. If public metadata expired
    // during playback, the episode control didn't exist at scope entry.
    if (!tv || !delayed.current || returnTo == null || loading || restored.current) return;
    const frame = requestAnimationFrame(() => {
      if (episodeRef.current) { restored.current = true; requestTvControlFocus(episodeRef.current); }
    });
    return () => cancelAnimationFrame(frame);
  }, [tv, returnTo, loading, seasonNumber]);
  if (loading)
    return (
      <View style={[row, { gap: 9, paddingVertical: 8 }]}>
        <ActivityIndicator size="small" color={theme.accent} />
        <T size={12} color={theme.muted}>
          Chargement des épisodes…
        </T>
      </View>
    );
  const current = seasons.find((s) => s.season === (selection ?? selectedSeason)) ?? seasons.find((s) => s.season > 0 && s.episodes.length) ?? seasons[0];
  if (!current)
    return (
      <T size={12} color={theme.muted}>
        Aucun épisode n’est répertorié pour ce titre.
      </T>
    );
  const shown = current.episodes.slice(0, limit);
  const seasonChip = (season: MediaSeason) => <View key={season.season} testID={`season-${season.season}`}><Chip label={season.season === 0 ? 'Hors-série' : `Saison ${season.season}`}
    active={season.season === current.season} onPress={() => { restored.current = true; setReturnTo(undefined); setSelection(season.season); setLimit(24); remember(memoryKey, { season: season.season, limit: 24, episode: undefined }); }} /></View>;
  return (
    <View style={{ gap: 12 }}>
      {seasons.length > 1 && (tv ? <View style={[row, { flexWrap: 'wrap', gap: 8 }]}>{seasons.map(seasonChip)}</View> :
        <FlatList
          horizontal
          data={seasons}
          keyExtractor={(s) => String(s.season)}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={{ gap: 7 }}
          renderItem={({ item: season }) => seasonChip(season)}
        />
      )}
      <View style={{ gap: 7 }}>
        {!shown.length && <T size={12} color={theme.muted}>Aucun épisode dans cette saison.</T>}
        {shown.map((e) => {
          const label = `S${current.season} E${e.episode}`;
          const meta = e.runtime
            ? `${e.runtime} min`
            : e.air_date
              ? e.air_date
              : "";
          return (
            <Click
              key={`${current.season}-${e.episode}`}
              testID={`episode-${current.season}-${e.episode}`}
              controlRef={previous?.season === current.season && returnTo === e.episode ? episodeRef : undefined}
              autoFocus={tv && previous?.season === current.season && returnTo === e.episode}
              label={`Lire ${label} : ${e.name}`}
              onPress={() => { remember(memoryKey, { season: current.season, episode: e.episode, limit }); onPlay(current.season, e.episode, label); }}
              style={[
                row,
                {
                  gap: 11,
                  borderWidth: 1,
                  borderColor: theme.border,
                  backgroundColor: theme.bg,
                  borderRadius: 9,
                  padding: 11,
                },
              ]}
            >
              <View
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 7,
                  backgroundColor: theme.soft,
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <T size={12} weight="bold" color={theme.accent}>
                  E{e.episode}
                </T>
              </View>
              <View style={{ flex: 1, gap: 3 }}>
                <T size={14} weight="semibold" lines={2}>
                  {e.name}
                </T>
                {!!e.overview && (
                  <T size={12} color={theme.muted} lines={2}>
                    {e.overview}
                  </T>
                )}
              </View>
              {!!meta && (
                <T size={10} color={theme.faint}>
                  {meta}
                </T>
              )}
              <I name="play-circle-outline" size={17} color={theme.accent} />
            </Click>
          );
        })}
      </View>
      {current.episodes.length > limit && (
        <Button
          small
          variant="secondary"
          label={`Afficher plus d’épisodes (${current.episodes.length - limit})`}
          icon="chevron-down"
          onPress={() => { setLimit(limit + 24); remember(memoryKey, { season: current.season, limit: limit + 24 }); }}
        />
      )}
    </View>
  );
}

export function DetailSheet({ item }: { item: Title }) {
  const { theme, tv, overlay, open, favorites, toggleFavorite, items, progress } = useApp();
  const { compact, phone, height } = useLayout();
  const photo = useRef<View>(null);
  const saved = favorites.includes(item.id);
  const { data: media, loading: mediaLoading, failed, issue, retry } = useTitleMedia(item);
  const playableItem = media ? { ...item, catalogId: media.id, episodic: item.episodic ?? media.episodic } : item;
  const serial = isEpisodicTitle(playableItem);
  const resume = resumeFor(item.id, progress, {
    kind: item.kind,
    episodic: serial,
    seasons: media?.seasons,
  });
  const first = serial ? firstEpisode(media?.seasons) : null;
  const playback = resume?.target ?? (first && { ...first, label: `S${first.season} E${first.episode}` });
  const playLabel = resume?.buttonLabel ?? (playback ? `Lire ${playback.label}` : serial ? "Aucun épisode disponible" : "Regarder");
  const genres = media?.genres.length ? media.genres : titleGenres(item);
  const director = media?.director || item.director;
  const cast = media?.cast || [];
  const castNames = cast.length ? cast.map((c) => c.name) : item.cast || [];
  const related = items
    .filter((m) => m.id !== item.id && genres.some(g => matchesGenre(m, g)))
    .slice(0, 3);
  const playEpisode = (season: number, episode: number, label: string) =>
    open({ type: "watch", item: playableItem, season, episode, label });
  const actions = <View style={[row, { gap: 9, marginBottom: 3, flexWrap: "wrap" }]}>
          <Button
            autoFocus={(!serial || !!playback) && !(tv && overlay && episodeMemory.get(overlay)?.episode != null)}
            disabled={serial && !playback}
            label={serial && !playback && mediaLoading ? "Chargement des épisodes…" : serial && !playback && failed ? 'Liste des épisodes indisponible' : playLabel}
            icon={resume?.next ? "play-skip-forward" : "play"}
            onPress={() => { if (!serial || playback) { if (tv) remember(overlay, { episode: undefined }); open({ type: "watch", item: playableItem, ...playback, restart: !!resume?.restart }); } }}
          />
          <Button
            label={saved ? "Dans ma liste" : "Ma liste"}
            icon={saved ? "checkmark" : "add"}
            variant="secondary"
            onPress={() => toggleFavorite(item.id)}
          />
        </View>;
  const genreLine = genres.length > 0 && <T size={12} color={tv ? theme.muted : theme.faint} weight="semibold">{genres.join(', ')}</T>;
  const synopsis = !!item.description && <T size={tv ? 20 : 15} color={theme.text} style={{ lineHeight: tv ? 29 : 23, maxWidth: 740 }}>{item.description}</T>;
  // Keep an unabridged long series synopsis without pushing seasons out of reach.
  const synopsisAfterEpisodes = tv && serial && (item.description?.length ?? 0) > 180;
  const gutter = phone ? 16 : compact ? 20 : 28;
  return (
    <View style={tv && { flex: 1, minHeight: 0 }}>
      {!tv && (phone ? <View style={{ backgroundColor: theme.surface }}>
        <View style={{ width: '100%', aspectRatio: 2.25, overflow: 'hidden' }}>
          {item.backdrop || item.poster ? <Art source={item.backdrop || item.poster} priority="high" style={fill} label={item.title} /> : <AsciiField variant="fold" />}
        </View>
        <View style={{ padding: 16, gap: 8 }}>
          <T role="header" size={34} weight="display">{item.title}</T>
          <Metadata item={item} />
        </View>
      </View> : <View style={{ backgroundColor: '#191919', paddingHorizontal: compact ? 12 : 22, paddingBottom: 14, paddingTop: compact ? 114 : 152 }}>
        <BlurTargetView ref={photo} style={fill}><Art source={item.backdrop || item.poster} style={fill} position="top center" priority="high" /></BlurTargetView>
        <Glass dark blur target={photo} style={{ alignSelf: 'flex-start', maxWidth: '100%', gap: 7, paddingHorizontal: compact ? 16 : 20, paddingVertical: 14, borderRadius: 14 }}>
          <T role="header" color="#FFF" size={compact ? 35 : 47} weight="display" style={{ letterSpacing: -.5, lineHeight: compact ? 38 : 51 }}>{item.title}</T>
          <Metadata item={item} />
        </Glass>
      </View>)}
      <DetailBody>
        {tv && <View style={{ minHeight: Math.min(325, height * .42), paddingHorizontal: gutter, paddingVertical: 16, justifyContent: 'flex-end', gap: 9, backgroundColor: theme.bg }}>
          <View pointerEvents="none" aria-hidden style={fill}>
            {!!(item.backdrop || item.poster) && <Art source={item.backdrop || item.poster} priority="high" style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: '82%' }} />}
            <LinearGradient style={fill} start={{ x: 0, y: .5 }} end={{ x: 1, y: .5 }} colors={[theme.bg, `${theme.bg}ed`, `${theme.bg}a8`, `${theme.bg}00`]} locations={[0, .22, .5, .8]} />
            <LinearGradient style={fill} colors={[`${theme.bg}00`, theme.bg]} locations={[.65, 1]} />
          </View>
          <View style={{ maxWidth: '67%', gap: 4 }}>
            <T role="header" size={height < 600 ? 38 : 48} weight="display">{item.title}</T>
            <Metadata item={item} />
            {genreLine}
          </View>
          {actions}
          {!!resume && <View style={{ width: '50%' }}><ProgressMeter entry={resume.entry} /></View>}
        </View>}
        <View style={{ paddingHorizontal: gutter, paddingBottom: 25, paddingTop: tv ? 4 : 16, gap: 12, ...(phone && { backgroundColor: theme.bg }) }}>
        {!!resume && !tv && <ProgressMeter entry={resume.entry} />}
        {!tv && actions}
        {!tv && genreLine}
        {!synopsisAfterEpisodes && synopsis}
        {failed && (serial || issue === 'unavailable') && <View accessibilityLiveRegion="polite" style={{ gap: 8, alignItems: 'flex-start' }}>
          <T size={13} color={theme.muted}>{issue === 'unsupported' ? 'Cette version du serveur fournit la fiche du catalogue, mais pas la liste des épisodes.'
            : issue === 'missing' ? 'Le serveur ne répertorie pas de fiche détaillée pour ce titre.'
            : 'Le service de fiches ne répond pas. Les informations du catalogue restent disponibles.'}</T>
          <Button small variant="secondary" label="Réessayer le chargement" icon="refresh" onPress={retry} />
        </View>}
        {serial && !failed && (
          <View style={{ borderTopWidth: 1, borderColor: theme.border, paddingTop: 15, gap: 11 }}>
            <T weight="display" size={27} role="header">Épisodes</T>
            <EpisodeBlock seasons={media?.seasons || []} selectedSeason={playback?.season} loading={mediaLoading} onPlay={playEpisode} />
          </View>
        )}
        {synopsisAfterEpisodes && synopsis}
        {!!director && (
          <View style={[row, { gap: 12, alignItems: "flex-start" }]}>
            <T size={12} color={theme.faint}>
              Réalisation
            </T>
            <T size={12} weight="semibold" style={{ flex: 1 }}>
              {director}
            </T>
          </View>
        )}
        {(cast.length > 0 || castNames.length > 0) && (
          <View
            style={{
              borderTopWidth: 1,
              borderColor: theme.border,
              paddingTop: 15,
              gap: 10,
            }}
          >
            <T weight="display" size={27} role="header">
              Distribution
            </T>
            <CastStrip cast={cast} names={castNames} />
          </View>
        )}
        {related.length > 0 && (
          <View
            style={{
              borderTopWidth: 1,
              borderColor: theme.border,
              marginTop: 9,
              paddingTop: 17,
              gap: 11,
            }}
          >
            <T weight="display" size={27} role="header">
              Dans le même univers
            </T>
            <View style={[row, { gap: 10 }]}>
              {related.map((m) => (
                <Click
                  key={m.id}
                  label={`Voir ${m.title}`}
                  onPress={() => open({ type: "detail", item: m })}
                  style={{ flex: 1, gap: 6 }}
                >
                  <View
                    style={{
                      height: compact ? 57 : 81,
                      borderRadius: 7,
                      overflow: "hidden",
                    }}
                  >
                    <Art source={m.backdrop} style={fill} />
                  </View>
                  <T weight="semibold" size={11} lines={1}>
                    {m.title}
                  </T>
                </Click>
              ))}
            </View>
          </View>
        )}
      </View></DetailBody>
    </View>
  );
}
export { WatchPlayback as WatchSheet, LivePlayback as LiveSheet } from "./PlaybackSheet";
