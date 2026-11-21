import React, { useMemo, useRef, useState } from 'react';
import { ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { type Tabs, usePathname } from 'expo-router';
import { useApp } from '../../lib/store';
import { homeSessions, timecode } from '../../lib/resume';
import { explore } from '../../lib/navigation';
import { genreOptions } from '../../lib/genres';
import { useSessionAction } from '../../lib/useSessionAction';
import type { Progress, Title } from '../../lib/types';
import { Avatar, Brand, Emblem } from '../Brand';
import { Art, I, row, T } from '../UI';
import { StudioControl } from './StudioControl';
import { AsciiField } from '../phone/AsciiField';

type BottomTabBarProps = Parameters<NonNullable<React.ComponentProps<typeof Tabs>['tabBar']>>[0];
type Cut = { item: Title; entry?: Progress };
const titles: Record<string, string> = { index: 'Accueil', catalogue: 'Catalogue', recherche: 'Recherche', direct: 'En direct' };
const tab = (route: string) => `tv-tab-${route}`;
const thumb = (item: Title) => `tv-title-${item.id}`;
const heading = tab('index'), watch = 'tv-watch', secondary = 'tv-detail', historyId = 'tv-history', genreId = 'tv-genre';
const centered = { alignItems: 'center', justifyContent: 'center' } as const;

function useScale() {
  const { width, height } = useWindowDimensions();
  return Math.max(.85, Math.min(width / 960, height / 540, 2));
}

export function TvNavigation({ state, navigation }: BottomTabBarProps) {
  const s = useScale(), { width } = useWindowDimensions();
  const { profile, open, theme } = useApp();
  const { bg: ink, text: paper, muted } = theme;
  const ids = [...state.routes.map(r => tab(r.name)), 'tv-library', 'tv-settings'];
  const home = state.routes[state.index]?.name === 'index';
  const links = (i: number) => ({ left: ids[i - 1], right: ids[i + 1], down: home ? i < 2 ? watch : 'tv-first-title' : undefined });
  return <View testID="tv-navigation" style={[row, { minHeight: 61*s, paddingHorizontal: 25*s, gap: 6*s,
    backgroundColor: ink, borderBottomWidth: 1, borderBottomColor: theme.border }]}>
    <View style={{ marginRight: 16*s }}>{width < 820 ? <Emblem size={36*s} /> : <Brand color={paper} />}</View>
    {state.routes.map((route, i) => {
      const active = i === state.index;
      return <StudioControl key={route.key} id={ids[i]} label={titles[route.name]} selected={active} {...links(i)}
        onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
        onPress={() => { const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
          if (!event.defaultPrevented) navigation.navigate(route.name); }}
        style={[centered, { minHeight: 40*s, paddingHorizontal: 11*s, backgroundColor: active ? paper : ink }]}>
        <T size={16*s} weight="bold" color={active ? ink : muted}>{titles[route.name]}</T>
      </StudioControl>;
    })}
    <View style={{ flex: 1 }} />
    <StudioControl id="tv-library" label={`Mon espace : ${profile.name}`} {...links(ids.length - 2)} onPress={() => open({ type: 'library' })}
      style={[row, { minHeight: 40*s, paddingHorizontal: 5*s, gap: 8*s }]}>
      <Avatar size={27*s} index={profile.color} portraitId={profile.portraitId} />
      {width >= 820 && <T size={14*s} weight="bold" color={paper}>Mon espace</T>}
    </StudioControl>
    <StudioControl id="tv-settings" label="Paramètres" {...links(ids.length - 1)} onPress={() => open({ type: 'settings' })}
      style={[centered, { width: 42*s, height: 42*s }]}><I name="settings-outline" color={paper} size={21*s} /></StudioControl>
  </View>;
}

function Preview({ cut: { item, entry }, below, s, lead }: { cut: Cut; below: string; s: number; lead: boolean }) {
  const { label, a11yLabel, play } = useSessionAction(item, entry, lead);
  const { open, favorites, toggleFavorite, theme } = useApp();
  const { bg: ink, text: paper, muted, surface: plate } = theme;
  const episodes = label === 'Voir les épisodes', saved = favorites.includes(item.id);
  const secondLabel = episodes ? saved ? 'Dans ma liste' : 'Ma liste' : 'La fiche';
  const actionStyle = [row, centered, { minHeight: 46*s, paddingHorizontal: 14*s, gap: 8*s, flexShrink: 1 }];
  return <View testID="tv-preview" style={{ flex: 1, minHeight: 0, gap: 10*s }}>
    <View style={{ flex: 1, minHeight: 0, overflow: 'hidden', backgroundColor: plate, borderRadius: 4 }}>
      {!!(item.backdrop || item.poster) ? <Art source={item.backdrop || item.poster} priority="high" style={StyleSheet.absoluteFill} /> : <AsciiField variant="fold" />}
    </View>
    <View style={{ gap: 3*s }}>
      <T role="header" size={40*s} weight="display" lines={2} style={{ lineHeight: 42*s }} color={paper}>{item.title}</T>
      <T size={15*s} color={muted} lines={1}>{[item.kind, item.year || '', item.genre, item.duration].filter(Boolean).join('   /   ')}</T>
      {entry && <View style={[row, { marginTop: 3*s, gap: 12*s }]}>
        {entry.total > 0 && <View style={{ width: 76*s, height: 4*s, backgroundColor: '#4D5451' }}>
          <View style={{ height: '100%', width: `${Math.min(100, Math.max(0, entry.position / entry.total * 100))}%`, backgroundColor: paper }} /></View>}
        <T size={14*s} color={paper} lines={1}>{[entry.label, timecode(entry.position) + (entry.total > 0 ? ` / ${timecode(entry.total)}` : '')].filter(Boolean).join('   ')}</T>
      </View>}
    </View>
    <View style={[row, { gap: 8*s }]}>
      <StudioControl id={watch} up={heading} right={secondary} down={below} label={a11yLabel} onPress={play} style={[actionStyle, { backgroundColor: paper }]}>
        <I name={episodes ? 'list' : 'play'} size={19*s} color={ink} /><T size={16*s} weight="bold" lines={1} color={ink}>{label}</T>
      </StudioControl>
      <StudioControl id={secondary} left={watch} right={thumb(item)} up={heading} down={below} label={secondLabel}
        onPress={() => episodes ? toggleFavorite(item.id) : open({ type: 'detail', item })} style={[actionStyle, { backgroundColor: plate }]}>
        <I name={episodes ? saved ? 'checkmark' : 'add' : 'information-circle-outline'} size={19*s} color={paper} /><T size={16*s} weight="bold" color={paper}>{secondLabel}</T>
      </StudioControl>
    </View>
  </View>;
}

export function TvStudio() {
  const { profile } = useApp();
  return <Room key={JSON.stringify([profile.accountId, profile.profileId])} />;
}

function Room() {
  const { items, history, open, refresh, serviceError, overlay, theme } = useApp();
  const { bg: ink, text: paper, muted, surface: plate } = theme;
  const s = useScale(), path = usePathname();
  const cuts = useMemo(() => {
    const result: Cut[] = [], ids = new Set<string>();
    for (const cut of [...homeSessions(history), ...items.map(item => ({ item }))]) {
      const id = cut.item.catalogId || cut.item.id;
      if (!ids.has(id)) { ids.add(id); result.push(cut); }
      if (result.length === 8) break;
    }
    return result;
  }, [items, history]);
  const [choice, choose] = useState<string>();
  const active = cuts.find(c => c.item.id === choice) || cuts[0];
  const genre = active && genreOptions([active.item])[0];
  const list = useRef<ScrollView>(null), viewport = useRef(0), scrollY = useRef(0);
  const [initialGiven, setInitialGiven] = useState(false);
  const rowH = Math.round(65*s), gutter = Math.round(6*s);
  const reveal = (i: number) => {
    const y = i*(rowH + gutter), height = viewport.current, offset = scrollY.current;
    if (height <= 0) return;
    const next = y < offset ? y : y + rowH > offset + height ? y + rowH - height : offset;
    if (next !== offset) { scrollY.current = next; list.current?.scrollTo({ y: next, animated: false }); }
  };
  const footer = history.length ? historyId : genre ? genreId : 'tv-catalogue';
  return <View testID="tv-studio" style={{ flex: 1, minHeight: 0, backgroundColor: ink, paddingHorizontal: 26*s, paddingVertical: 18*s, gap: 13*s }}>
    {active ? <View style={{ flex: 1, minHeight: 0, flexDirection: 'row', gap: 22*s }}>
      <View style={{ flex: 1.84, minWidth: 0 }}><Preview cut={active} below={footer} s={s} lead={active === cuts[0]} /></View>
      <View style={{ flex: 1, minWidth: 0, gap: 8*s }}>
        <View style={[row, { justifyContent: 'space-between' }]}>
          <T role="header" size={23*s} weight="bold" color={paper}>À l’affiche</T>
          <T size={14*s} color={muted}>{cuts.indexOf(active) + 1} / {cuts.length}</T>
        </View>
        <ScrollView ref={list} testID="tv-titles" style={{ flex: 1 }} contentContainerStyle={{ gap: gutter }} removeClippedSubviews={false}
          showsVerticalScrollIndicator={false} onLayout={e => { viewport.current = e.nativeEvent.layout.height; }}
          onScroll={e => { scrollY.current = e.nativeEvent.contentOffset.y; }} scrollEventThrottle={16}>
          {cuts.map(({ item, entry }, i) => {
            const selected = item.id === active.item.id;
            return <StudioControl key={item.id} id={thumb(item)} alias={i === 0 ? 'tv-first-title' : undefined}
              initial={i === 0 && path === '/' && !overlay && !initialGiven} selected={selected} label={`Voir ${item.title}`}
              up={i ? thumb(cuts[i-1].item) : heading} down={cuts[i+1] ? thumb(cuts[i+1].item) : footer} left={secondary}
              onFocus={() => { setInitialGiven(true); choose(item.id); reveal(i); }}
              onPress={() => { choose(item.id); open({ type: 'detail', item }); }}
              style={[row, { height: rowH, gap: 10*s, padding: 3*s, paddingRight: 8*s, backgroundColor: selected ? paper : plate }]}>
              <Art source={item.backdrop || item.poster} style={{ width: 74*s, alignSelf: 'stretch', borderRadius: 2 }} />
              <View style={{ flex: 1, gap: 2*s }}>
                <T size={16*s} weight="bold" color={selected ? ink : paper} lines={2} style={{ lineHeight: 18*s }}>{item.title}</T>
                <T size={12*s} color={selected ? '#424944' : muted} lines={1}>{entry ? 'En reprise' : item.kind}{item.year ? `   ${item.year}` : ''}</T>
              </View>
            </StudioControl>;
          })}
        </ScrollView>
      </View>
    </View> : <View style={{ flex: 1, justifyContent: 'center' }}><T role="header" size={36*s} color={paper}>Aucun titre disponible</T></View>}
     <View style={[row, { gap: 10*s, borderTopWidth: 1, borderColor: theme.border, paddingTop: 7*s }]}>
      {!!history.length && <StudioControl id={historyId} label="Autres séances" onPress={() => open({ type: 'collection', section: 'history' })}
        up={watch} right={genre ? genreId : 'tv-catalogue'} style={[row, { minHeight: 36*s, gap: 7*s, paddingHorizontal: 5*s }]}>
        <I name="time-outline" color={muted} size={18*s} /><T size={15*s} color={paper}>Autres séances</T></StudioControl>}
      <StudioControl id={genre ? genreId : 'tv-catalogue'} label={genre ? `Explorer le genre ${genre}` : 'Voir le catalogue'}
        left={history.length ? historyId : undefined} up={watch} onPress={() => explore('Tout', genre)} style={[row, { minHeight: 36*s, gap: 7*s, paddingHorizontal: 5*s }]}>
        <I name="albums-outline" color={muted} size={18*s} /><T size={15*s} color={paper}>{genre ? `Genre : ${genre}` : 'Voir le catalogue'}</T>
      </StudioControl>
       {(!active || !!serviceError) && <StudioControl id="tv-refresh" label="Actualiser" up={watch} onPress={refresh} style={[row, { minHeight: 36*s, gap: 7*s }]}>
         <I name="refresh" color={muted} size={18*s} /><T size={15*s} color={paper}>Actualiser</T></StudioControl>}
       <View style={{ flex: 1 }} />
       <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants" style={{ width: 150*s, height: 26*s }}><AsciiField variant="trace" /></View>
    </View>
  </View>;
}
