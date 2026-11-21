import React, { useEffect, useRef, useState } from 'react';
import { Platform, View } from 'react-native';
import { useApp } from '../lib/store';
import type { Title } from '../lib/types';
import { Art, Click, fill, I, row, T, useLayout } from './UI';
import { Poster } from './Cards';

/** The catalogue, search and directory share a single column on touch, a contact sheet on TV. */
export function useIndexLayout() {
  const layout = useLayout();
  const { tv, phone } = useApp();
  const columns = phone ? 1 : tv ? Math.max(3, Math.min(5, Math.floor((layout.inner + layout.gap) / 270))) : layout.cols;
  return { ...layout, tv, phone, columns, cellWidth: Math.floor((layout.inner - layout.gap * (columns - 1)) / columns) };
}

/** Only the station/title which launched the native sheet requests its focus back. */
export function useResultFocus(activate: () => void) {
  const { overlay } = useApp();
  const opened = useRef(false);
  const [restore, setRestore] = useState(false);
  const [focused, setFocused] = useState(false);
  useEffect(() => {
    if (overlay || !opened.current) return;
    const frame = requestAnimationFrame(() => { opened.current = false; setRestore(true); });
    return () => cancelAnimationFrame(frame);
  }, [overlay]);
  return { focused, props: { focusBeforePress: true, autoFocus: restore, onFocus: () => setFocused(true),
    onBlur: () => { setFocused(false); setRestore(false); }, onPress: () => {
      opened.current = Platform.OS === 'android' && Platform.isTV;
      setRestore(false); activate();
    } } };
}

export function IndexTitle({ item, width, onPress }: { item: Title; width: number; onPress?: () => void }) {
  const { phone, tv, theme, open, favorites } = useApp();
  const { props, focused } = useResultFocus(onPress ?? (() => open({ type: 'detail', item })));
  if (!phone && !tv) return <Poster item={item} width={width} onPress={onPress} />;
  const image = item.backdrop || item.poster;
  const saved = favorites.includes(item.id);
  return <Click {...props} testID={`${phone ? 'title-index-row' : 'title-board-cell'}-${item.id}`} label={`Voir ${item.title}`} style={phone ?
    [row, { width, minHeight: 87, paddingVertical: 9, gap: width < 300 ? 8 : 12, borderBottomWidth: 1, borderColor: theme.border }] :
    { width, backgroundColor: focused ? theme.surface : theme.bg, borderRadius: 6, padding: 2, borderWidth: 3, borderColor: focused ? theme.accent : 'transparent' }}>
    <View style={{ width: phone ? Math.min(148, Math.round(width * .29)) : '100%', aspectRatio: phone ? 1.45 : 16 / 9,
      overflow: 'hidden', borderRadius: 4, backgroundColor: theme.elevated, alignItems: 'center', justifyContent: 'center' }}>
      {image ? <Art source={image} style={fill} /> : <I name="film-outline" color={theme.muted} />}
      {saved && <View style={{ position: 'absolute', top: 3, left: 3, backgroundColor: theme.bg, padding: 3, borderRadius: 3 }}><I name="bookmark" color={theme.accent} size={14} /></View>}
    </View>
    <View style={phone ? { flex: 1, gap: 4, minWidth: 0 } : { paddingVertical: 7, paddingHorizontal: 4, gap: 3 }}>
      <T size={phone ? 16 : 20} weight="bold" lines={phone ? 3 : 2}>{item.title}</T>
      <T size={phone ? 13 : 16} color={theme.muted} lines={phone ? 2 : 1}>{[item.kind, item.year || null, item.genre].filter(Boolean).join(' · ')}</T>
    </View>
    {phone && <I name="chevron-forward" size={18} color={theme.accent} />}
  </Click>;
}
