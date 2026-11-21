import React, { useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Platform, Pressable, View } from 'react-native';
import { requestTvControlFocus } from './tv/TvFocus';
import { portraitById, portraits, type Portrait } from '../lib/portraits';
import { useApp } from '../lib/store';
import { fonts } from '../lib/theme';
import { Avatar } from './Brand';
import { Art, Button, Chip, Click, I, IconButton, row, useLayout, useTvInputFocus } from './UI';
import { SheetText as T } from './SheetText';
import { SheetInput } from './SheetInput';

const groups = ['Tous', 'Films', 'Séries', 'Animés'] as const;
const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().trim();
const lookup = portraits.map(p => ({ p, terms: fold(`${p.name} ${p.work}`) }));
const pageSize = 12;
const galleryLabel = `Choisir parmi ${portraits.length} avatars`;

type DraftPortrait = { id: string | null; color: number; disabled: boolean; choose: (id: string | null) => void };
export function PortraitChooser({ draft }: { draft?: DraftPortrait }) {
  const { theme, profile, choosePortrait, canChoosePortrait, notify } = useApp();
  const { windowWidth, phone, tv } = useLayout();
  const { focusProps, focusStyle } = useTvInputFocus();
  const [open, setOpen] = useState(false), [group, setGroup] = useState<typeof groups[number]>('Tous');
  const [query, setQuery] = useState(''), [page, setPage] = useState(0);
  // A new profile has no portrait yet, even when the active profile does.
  const id = draft ? draft.id : profile.portraitId;
  const selected = id ? portraitById.get(id) : null;
  const enabled = draft ? !draft.disabled : canChoosePortrait;
  const opener = useRef<View>(null);
  const toggle = useRef<React.ComponentRef<typeof Pressable>>(null);
  const moved = useRef(false);
  useLayoutEffect(() => {
    if (!tv || !moved.current) return;
    moved.current = false;
    const frame = requestAnimationFrame(() => requestTvControlFocus(toggle.current));
    return () => cancelAnimationFrame(frame);
  }, [tv, open]);
  const cols = windowWidth < 350 ? 2 : windowWidth < 560 ? 3 : 4;
  const list = useMemo(() => {
    const words = fold(query).split(/\s+/);
    return lookup.filter(({ p, terms }) => (group === 'Tous' || p.group === group) && words.every(w => terms.includes(w))).map(e => e.p);
  }, [group, query]);
  const total = Math.ceil(list.length / pageSize);
  const close = () => {
    moved.current = true;
    setOpen(false);
    if (!tv && Platform.OS === 'web') requestAnimationFrame(() => (opener.current as unknown as HTMLElement | null)?.querySelector<HTMLElement>('[data-testid="portrait-opener"]')?.focus({ preventScroll: true }));
  };
  const select = (p: Portrait | null) => {
    if (!enabled) return;
    if (draft) draft.choose(p?.id ?? null);
    else if (!choosePortrait(p?.id ?? null)) return;
    close(); notify(p ? `Avatar choisi : ${p.name}` : 'Avatar classique rétabli');
  };
  return <View ref={opener} style={{ gap: 12, marginBottom: 18 }}>
    {!open ? <Click controlRef={toggle} testID="portrait-opener" label={galleryLabel} disabled={!enabled}
      onPress={() => { moved.current = true; setOpen(true); setQuery(''); setGroup('Tous'); setPage(0); }}
      style={[row, { gap: 12, minHeight: 74, padding: 10, backgroundColor: theme.surface, borderColor: theme.glassEdge, borderWidth: 1, borderRadius: 12 }]}>
      <Avatar size={52} index={draft ? draft.color : profile.color} portraitId={selected?.id} />
      <View style={{ flex: 1, minWidth: 0, gap: 3 }}><T weight="bold">{galleryLabel}</T>
        <T size={12} color={theme.muted}>{selected ? `${selected.name} · ${selected.work}` : 'Films, séries et animés'}</T></View><I name="chevron-forward" size={17} />
    </Click> : <>
      <View style={[row, { justifyContent: 'space-between' }]}><T role="header" weight="display" size={phone ? 25 : 29} style={phone && { flexShrink: 1 }}>Choisir mon avatar</T>{tv ? <Click controlRef={toggle} label="Fermer la galerie" onPress={close} style={{ minWidth: 56, minHeight: 56, alignItems: 'center', justifyContent: 'center' }}><I name="close" size={26} /></Click> : <IconButton icon="close" label="Fermer la galerie" onPress={close} />}</View>
      <View style={[row, { gap: 8, borderWidth: 1, borderColor: theme.glassEdge, backgroundColor: theme.bg, borderRadius: 10, paddingHorizontal: 10 }]}><I name="search" size={17} color={theme.muted} />
        <SheetInput {...focusProps} testID="portrait-search" accessibilityLabel="Chercher un personnage ou une œuvre" placeholder="Personnage ou œuvre" placeholderTextColor={theme.faint} value={query}
          onChangeText={s => { setQuery(s); setPage(0); }} autoCorrect={false} returnKeyType="search" style={[{ flex: 1, minWidth: 0, minHeight: tv ? 56 : 46, color: theme.text, fontSize: tv ? 22 : 16, fontFamily: fonts.regular }, focusStyle]} />
        {!!query && <IconButton icon="close-circle-outline" label="Effacer la recherche d’avatar" onPress={() => { setQuery(''); setPage(0); }} />}</View>
      <View style={[row, { flexWrap: 'wrap', gap: 6 }]}>{groups.map(g => <Chip key={g} label={g} active={g === group} onPress={() => { setGroup(g); setPage(0); }} />)}</View>
      <View style={[row, { gap: 6 }]}><View accessibilityLiveRegion="polite" style={{ flex: 1 }}><T size={12} color={theme.muted}>{total > 1 ? `Page ${page + 1} sur ${total}` : `${list.length} résultat${list.length !== 1 ? 's' : ''}`}</T></View>
        {total > 1 && <><IconButton icon="chevron-back" label="Page de portraits précédente" disabled={page === 0} onPress={() => setPage(p => p - 1)} />
          <IconButton icon="chevron-forward" label="Page de portraits suivante" disabled={page >= total - 1} onPress={() => setPage(p => p + 1)} /></>}</View>
      {list.length === 0 && <T size={13} color={theme.muted}>Aucun personnage trouvé. Essayez un autre nom ou la catégorie « Tous ».</T>}
      <View testID="portrait-grid" style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: 10, marginHorizontal: -3 }}>
        {list.slice(page * pageSize, (page + 1) * pageSize).map(p => <View key={p.id} style={{ width: `${100 / cols}%`, paddingHorizontal: 3 }}>
          <Click label={`Utiliser ${p.name}, ${p.work}`} selected={p.id === selected?.id} disabled={!enabled} onPress={() => select(p)} style={{ minHeight: 44, borderRadius: 9, padding: 3, borderWidth: 1, borderColor: p.id === selected?.id ? theme.accent : 'transparent' }}>
            <Art source={p.image} style={{ width: '100%', aspectRatio: 1, borderRadius: 6 }} />
            {p.id === selected?.id && <View style={{ position: 'absolute', top: 6, right: 6, borderRadius: 10, backgroundColor: theme.accent }}><I name="checkmark" size={17} color={theme.onAccent} /></View>}
            <T size={12} weight="bold" lines={2} style={{ marginTop: 4 }}>{p.name}</T><T size={11} color={theme.muted} lines={1}>{p.work}</T>
          </Click></View>)}
      </View>
      {selected && <Button small variant="ghost" label="Rétablir l’avatar classique" onPress={() => select(null)} />}
    </>}
    {!open && <T size={12} color={theme.muted}>{draft ? 'Le portrait sera enregistré sur cet appareil à la création du profil.' : canChoosePortrait ? 'Ce portrait reste sur cet appareil pour ce profil.' : 'Le profil doit être chargé pour choisir son portrait.'}</T>}
  </View>;
}
