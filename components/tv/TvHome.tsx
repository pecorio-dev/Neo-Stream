import React, { useMemo, useRef, useState } from 'react';
import { ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { usePathname } from 'expo-router';
import { homeSessions, timecode } from '../../lib/resume';
import { useApp } from '../../lib/store';
import { revealOffset, tvShelves, type TvCut, type TvShelf } from '../../lib/tvShelves';
import { useSessionAction } from '../../lib/useSessionAction';
import { Art, I, T, row } from '../UI';
import { StudioControl } from './StudioControl';

const watch = 'tv-watch', detail = 'tv-detail', rail = 'tv-tab-index';
const fill = { flex: 1, minHeight: 0, minWidth: 0 };
const cardChoices = new Map<string, string>(); // Only a control ID; never retain profile history or media.

function Hero({ cut, lead, s, height, reveal }: { cut: TvCut; lead: TvCut; s: number; height: number; reveal: () => void }) {
  const { theme, open } = useApp();
  const { item, entry } = cut;
  // Resolving a nearly finished lead episode is tied to the saved session, never to D-pad movement.
  const leadAction = useSessionAction(lead.item, lead.entry, !!lead.entry);
  const otherAction = useSessionAction(item, entry, false);
  const action = entry && entry === lead.entry ? leadAction : otherAction;
  const button = [row, { paddingHorizontal: 13*s, minHeight: 39*s, gap: 6*s, justifyContent: 'center' as const }];
  const metadata = [item.year || '', item.genre || item.kind, item.duration, entry?.label, entry && timecode(entry.position)].filter(Boolean).join('   ·   ');
  return <View testID="tv-preview" style={{ height, justifyContent: 'flex-end', paddingHorizontal: 24*s, paddingBottom: 17*s, backgroundColor: theme.bg }}>
    {!!(item.backdrop || item.poster) && <Art source={item.backdrop || item.poster} position="center" priority="high"
      style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: '85%' }} />}
    <LinearGradient pointerEvents="none" style={StyleSheet.absoluteFill} start={{ x: 0, y: .5 }} end={{ x: 1, y: .5 }}
      colors={[theme.bg, `${theme.bg}ed`, `${theme.bg}a8`, `${theme.bg}00`]} locations={[0, .2, .44, .77]} />
    <LinearGradient pointerEvents="none" style={StyleSheet.absoluteFill} colors={[`${theme.bg}00`, `${theme.bg}50`, theme.bg]} locations={[.48, .8, 1]} />
    <View style={{ width: '59%', gap: 4*s }}>
      <T role="header" weight="display" size={44*s} lines={2} style={{ lineHeight: 45*s }}>{item.title}</T>
      {!!metadata && <T size={13*s} weight="bold" color={theme.muted} lines={1}>{metadata}</T>}
      {!!item.description && <T size={15*s} lines={2} style={{ lineHeight: 20*s, marginTop: 2*s }}>{item.description}</T>}
    </View>
    <View style={[row, { gap: 8*s, marginTop: 11*s }]}>
      <StudioControl id={watch} left={rail} right={detail} down={cut.id} up={watch} onFocus={reveal} label={action.a11yLabel} onPress={action.play}
        style={[button, { backgroundColor: '#FFFFFF' }]}>
        <I name={action.label === 'Voir les épisodes' ? 'list' : 'play'} color="#101010" size={18*s} /><T color="#101010" size={15*s} weight="bold">{action.label}</T>
      </StudioControl>
      <StudioControl id={detail} left={watch} right={detail} up={detail} down={cut.id} onFocus={reveal} label="La fiche" onPress={() => open({ type: 'detail', item })}
        style={[button, { backgroundColor: theme.elevated }]}>
        <I name="information-circle-outline" size={18*s} /><T weight="bold" size={15*s}>La fiche</T>
      </StudioControl>
    </View>
  </View>;
}

function dimensions(s: number) {
  const px = (n: number) => Math.round(n*s);
  const card = px(127), poster = px(173), pad = px(24), gap = px(9), heading = px(34), bottom = px(12), hero = px(251);
  return { s, card, poster, pad, gap, heading, bottom, hero, rowHeight: heading + poster + bottom };
}
type Metrics = ReturnType<typeof dimensions>;

function Shelf({ shelf, above, below, active, first, preferred, metrics, onChoose }: {
  shelf: TvShelf; above?: TvShelf; below?: TvShelf; active: string; first: boolean; preferred: boolean;
  metrics: Metrics; onChoose: (id: string) => void;
}) {
  const { open, theme } = useApp();
  const scroller = useRef<ScrollView>(null), viewport = useRef(0), offset = useRef(0);
  const { card, poster, pad, gap, heading, rowHeight, s } = metrics;
  const at = (other: TvShelf | undefined, i: number) => other?.cuts[Math.min(i, other.cuts.length - 1)]?.id;
  function reveal(i: number) {
    const x = pad + i*(card + gap);
    // A shelf starts at its full inset, not at the smaller gap between posters.
    const next = i === 0 ? 0 : revealOffset(offset.current, viewport.current, x - gap,
      x + card + (i === shelf.cuts.length - 1 ? pad : gap));
    if (next !== offset.current) { offset.current = next; scroller.current?.scrollTo({ x: next, animated: false }); }
  }
  return <View style={{ height: rowHeight }}>
    <View style={{ height: heading, justifyContent: 'center', paddingHorizontal: pad }}><T role="header" size={21*s} weight="extra" lines={1}>{shelf.title}</T></View>
    <ScrollView horizontal ref={scroller} testID={first ? 'tv-titles' : `tv-shelf-${shelf.key}`} removeClippedSubviews={false} nestedScrollEnabled
      style={{ height: poster, flexGrow: 0 }} contentContainerStyle={{ gap, paddingHorizontal: pad }} showsHorizontalScrollIndicator={false}
      onLayout={e => { viewport.current = e.nativeEvent.layout.width; }} onScroll={e => { offset.current = e.nativeEvent.contentOffset.x; }} scrollEventThrottle={16}>
      {shelf.cuts.map(({ item, entry, id }, i) => {
        const selected = active === id;
        return <StudioControl key={id} id={id} selected={selected} alias={selected ? 'tv-home-entry' : undefined} initial={selected && preferred}
          label={`Voir ${item.title}`} left={shelf.cuts[i - 1]?.id ?? rail} right={shelf.cuts[i + 1]?.id ?? id} up={at(above, i) ?? watch} down={at(below, i) ?? id}
          onFocus={() => { reveal(i); onChoose(id); }} onPress={() => open({ type: 'detail', item })}
          style={{ width: card, height: poster, justifyContent: 'flex-end', backgroundColor: theme.surface }}>
          <View pointerEvents="none" style={{ flex: 1, overflow: 'hidden', borderRadius: 2*s, justifyContent: 'flex-end' }}>
            {item.poster || item.backdrop ? <Art source={item.poster || item.backdrop} style={StyleSheet.absoluteFill} /> : <T weight="bold" size={16*s} lines={3}>{item.title}</T>}
            {shelf.key === 'resume' && !!entry && entry.total > 0 && <View style={{ height: 4*s, backgroundColor: theme.elevated }}>
              <View style={{ height: '100%', width: `${Math.max(0, Math.min(100, 100*entry.position/entry.total))}%`, backgroundColor: theme.text }} />
            </View>}
          </View>
        </StudioControl>;
      })}
    </ScrollView>
  </View>;
}

export function TvHome() {
  const { profile } = useApp();
  const identity = JSON.stringify([profile.accountId, profile.profileId]);
  return <Home key={identity} identity={identity} />;
}

function Home({ identity }: { identity: string }) {
  const { items, history, overlay, theme, refresh, serviceError } = useApp();
  const path = usePathname(), { width, height } = useWindowDimensions();
  const metrics = dimensions(Math.min(2, Math.max(.75, Math.min(width/960, height/540))));
  const shelves = useMemo(() => tvShelves(items, homeSessions(history)), [items, history]);
  const [choice, choose] = useState(() => cardChoices.get(identity));
  const lead = shelves[0]?.cuts[0], cut = shelves.flatMap(shelf => shelf.cuts).find(c => c.id === choice) ?? lead;
  const scroller = useRef<ScrollView>(null), viewport = useRef(0), offset = useRef(0);
  function move(y: number) {
    if (offset.current !== y) { offset.current = y; scroller.current?.scrollTo({ y, animated: false }); }
  }
  const preferred = path === '/' && !overlay;
  return <View testID="tv-studio" style={[fill, { backgroundColor: theme.bg }]}>
    <ScrollView ref={scroller} testID="tv-home" style={fill} contentContainerStyle={{ flexGrow: 1 }} removeClippedSubviews={false} showsVerticalScrollIndicator={false}
      onLayout={e => { viewport.current = e.nativeEvent.layout.height; }} onScroll={e => { offset.current = e.nativeEvent.contentOffset.y; }} scrollEventThrottle={16}>
      {cut && lead ? <>
        <Hero cut={cut} lead={lead} s={metrics.s} height={metrics.hero} reveal={() => move(0)} />
        {shelves.map((shelf, r) => <Shelf key={shelf.key} shelf={shelf} above={shelves[r-1]} below={shelves[r+1]} first={r === 0} active={cut.id} preferred={preferred}
          metrics={metrics} onChoose={id => {
            cardChoices.set(identity, id); choose(id);
            const y = metrics.hero + r*metrics.rowHeight, end = y + metrics.rowHeight;
            move(!r && viewport.current >= end ? 0 : revealOffset(offset.current, viewport.current, y, end));
          }} />)}
      </> : <View style={{ flex: 1, justifyContent: 'center', alignItems: 'flex-start', padding: metrics.pad, gap: metrics.gap }}>
        <T role="header" size={32*metrics.s} weight="display">Aucun titre disponible</T>
        {!!serviceError && <T size={15*metrics.s} color={theme.muted}>{serviceError}</T>}
        <StudioControl id="tv-refresh" alias="tv-home-entry" label="Actualiser" left={rail} initial={preferred} onPress={refresh}
          style={{ padding: metrics.gap, backgroundColor: theme.elevated }}><T size={16*metrics.s} weight="bold">Actualiser</T></StudioControl>
      </View>}
    </ScrollView>
  </View>;
}
