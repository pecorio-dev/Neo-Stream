import React, { useEffect, useImperativeHandle, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, Platform, RefreshControl, ScrollView, View } from 'react-native';
import { genreOptions } from '../../lib/genres';
import { explore } from '../../lib/navigation';
import { useApp } from '../../lib/store';
import { fonts } from '../../lib/theme';
import { useSessionAction } from '../../lib/useSessionAction';
import { ProgressMeter } from '../ProgressMeter';
import { Art, Button, Click, fill, I, type IconName, row, T, useLayout } from '../UI';
import { AsciiField } from './AsciiField';
import { PhoneFooter } from './PhoneHome';
import { reelSelection, type Frame } from './reelSelection';

function useSmoothScroll() {
  const [smooth, setSmooth] = useState(false);
  useEffect(() => {
    let mounted = true;
    const update = (reduced: boolean) => { if (mounted) setSmooth(!reduced); };
    AccessibilityInfo.isReduceMotionEnabled().then(update, () => {});
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', update);
    return () => { mounted = false; sub?.remove(); };
  }, []);
  return smooth;
}

function Transport({ item, entry, lead }: Frame & { lead: boolean }) {
  const { theme, open } = useApp();
  // Resolve the declared next episode for the primary resume slot only. Scrolling
  // through other frames never probes readers; an ambiguous episode opens its sheet.
  const { label, a11yLabel, play } = useSessionAction(item, entry, lead);
  const episodes = label === 'Voir les épisodes';
  return <View testID="session-plate" style={{ gap: 9 }}>
    <T role="header" size={42} weight="extra" style={{ fontFamily: fonts.display, letterSpacing: -.5 }}>{item.title}</T>
    <T color={theme.muted} size={14}>{[item.kind, item.year || null, item.genre, item.duration].filter(Boolean).join('   /   ')}</T>
    {entry && <ProgressMeter entry={entry} />}
    <View style={[row, { flexWrap: 'wrap', gap: 8, marginTop: 5 }]}>
      <Button label={label} accessibilityLabel={a11yLabel} icon={episodes ? 'list' : 'play'} onPress={play} style={{ flexGrow: 1 }} />
      <Button label="La fiche" accessibilityLabel={`La fiche : ${item.title}`} variant="secondary" icon="information-circle-outline" onPress={() => open({ type: 'detail', item })} />
    </View>
  </View>;
}

type ReelControl = { select: (index: number) => void };
function Reel({ frames, control, smooth }: { frames: Frame[]; control: React.Ref<ReelControl>; smooth: boolean }) {
  const { theme } = useApp();
  const { pad, contentWidth, height } = useLayout();
  const scroll = useRef<ScrollView>(null);
  const [active, setActive] = useState(0);
  const peek = frames.length > 1 ? Math.round(contentWidth * .12) : pad;
  const stride = contentWidth - peek;
  const frameHeight = Math.min(height < 480 ? 165 : 275, Math.round((stride - pad) * .59));
  const select = (i: number) => scroll.current?.scrollTo({ x: stride * i, animated: smooth });
  useImperativeHandle(control, () => ({ select }));
  const stepButton = (delta: number) => {
    const disabled = !frames[active + delta];
    return <Click disabled={disabled} label={delta < 0 ? 'Œuvre précédente' : 'Œuvre suivante'} onPress={() => select(active + delta)}
      style={{ width: 48, height: 48, alignItems: 'center', justifyContent: 'center' }}>
      <I name={delta < 0 ? 'arrow-back' : 'arrow-forward'} color={theme.accent} size={22} />
    </Click>;
  };
  return <View testID="home-projection">
    <View style={[row, { justifyContent: 'space-between', paddingHorizontal: pad, paddingVertical: 5, gap: 6 }]}>
      <T role="header" weight="bold" size={19} style={{ flexShrink: 1 }}>{frames[active].entry ? 'Reprendre la lecture' : 'À découvrir'}</T>
      <View style={row}>{stepButton(-1)}<View testID="phone-reel-position" accessibilityLiveRegion="polite">
        <T size={13} weight="bold" style={{ fontVariant: ['tabular-nums'] }}>{`${active + 1} / ${frames.length}`}</T>
      </View>{stepButton(1)}</View>
    </View>
    <ScrollView ref={scroll} testID="phone-reel" horizontal directionalLockEnabled nestedScrollEnabled
      showsHorizontalScrollIndicator={false} decelerationRate="fast" disableIntervalMomentum
      pagingEnabled={Platform.OS === 'web'} snapToInterval={stride} snapToAlignment="start"
      contentContainerStyle={{ paddingRight: peek }} scrollEventThrottle={16}
      onScroll={({ nativeEvent }) => setActive(Math.max(0, Math.min(frames.length - 1, Math.round(nativeEvent.contentOffset.x / stride))))}>
      {frames.map(({ item }, i) => <View key={item.id} aria-hidden accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
        style={{ width: stride, paddingLeft: pad, paddingVertical: 2 }}>
        <View style={{ height: frameHeight, overflow: 'hidden', backgroundColor: theme.surface, borderTopRightRadius: 8 }}>
          {item.backdrop || item.poster ? <Art source={item.backdrop || item.poster} style={fill} priority={i === 0 ? 'high' : 'normal'} /> : <AsciiField variant="fold" />}
        </View>
        <View style={{ height: 18, overflow: 'hidden', backgroundColor: theme.surface }}><AsciiField variant="trace" /></View>
      </View>)}
    </ScrollView>
    <View style={{ paddingHorizontal: pad, paddingTop: 8 }}><Transport key={frames[active].item.id} {...frames[active]} lead={active === 0} /></View>
  </View>;
}

function LinkRow({ title, icon, onPress, note }: { title: string; icon: IconName; onPress: () => void; note?: string }) {
  const { theme } = useApp();
  return <Click label={title} onPress={onPress} style={[row, { minHeight: 54, gap: 13, paddingVertical: 7, borderBottomWidth: 1, borderColor: theme.border }]}>
    <I name={icon} color={theme.accent} /><View style={{ flex: 1 }}><T weight="semibold" size={16}>{title}</T>{!!note && <T color={theme.muted} size={13}>{note}</T>}</View>
    <I name="chevron-forward" size={16} color={theme.muted} />
  </Click>;
}

export function PhoneReelHome() {
  const { theme, profile, items, history, open, refreshing, refresh, serviceError } = useApp();
  const { pad, contentWidth } = useLayout();
  const { frames, others } = useMemo(() => reelSelection(history, items), [history, items]);
  const genres = useMemo(() => genreOptions(items), [items]);
  const home = useRef<ScrollView>(null);
  const reel = useRef<ReelControl>(null);
  const smooth = useSmoothScroll();
  const [showGenres, setShowGenres] = useState(false);
  return <ScrollView ref={home} testID="home-screen" style={{ flex: 1, backgroundColor: theme.bg }} showsVerticalScrollIndicator={false}
    refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.accent} />}>
    {frames.length > 0 ? <Reel key={JSON.stringify([profile.accountId, profile.profileId, contentWidth, ...frames.map(v => v.item.id)])} frames={frames} control={reel} smooth={smooth} /> :
      <View style={{ padding: pad }}><T role="header" size={27} weight="bold">Aucun titre disponible</T></View>}
    <View style={{ marginHorizontal: pad, marginTop: 22 }}>
      <T role="header" size={23} weight="bold">Autres séances</T>
      {others.map(({ item, entry }, i) => <LinkRow key={item.id} title={item.title} icon="time-outline" note={entry?.label || item.kind} onPress={() => {
        reel.current?.select(i + 1);
        home.current?.scrollTo({ y: 0, animated: smooth });
      }} />)}
      <LinkRow title="Historique" icon="film-outline" onPress={() => open({ type: 'collection', section: 'history' })} />
      <LinkRow title="Ma liste" icon="bookmark-outline" onPress={() => open({ type: 'collection', section: 'favorites' })} />
      <LinkRow title="Par genre" icon="pricetags-outline" onPress={() => setShowGenres(v => !v)} />
      {showGenres && <View style={{ paddingLeft: 16 }}>{genres.length ? genres.map(g => <LinkRow key={g} title={g} icon="pricetag-outline" onPress={() => explore('Tout', g)} />) : <T color={theme.muted}>Aucun genre disponible.</T>}</View>}
      <LinkRow title="Tout le catalogue" icon="albums-outline" onPress={() => explore()} />
      {!!serviceError && <T color={theme.muted} style={{ marginTop: 12 }}>{serviceError}</T>}
      <LinkRow title="Actualiser" icon="refresh-outline" onPress={refresh} />
    </View>
    <PhoneFooter />
  </ScrollView>;
}
