import React, { useState } from 'react';
import { View } from 'react-native';
import { useApp } from '../lib/store';
import { phoneControl } from '../lib/theme';
import type { Progress, Title } from '../lib/types';
import { timecode } from '../lib/resume';
import { useSessionAction } from '../lib/useSessionAction';
import { ProgressMeter } from './ProgressMeter';
import { GlassLayer } from './Glass';
import { Art, Click, fill, I, row, T } from './UI';

export function Poster({ item, width, onPress, autoFocus }: { item: Title; width: number; onPress?: () => void; autoFocus?: boolean }) {
  const { theme, phone, open, favorites, tv } = useApp();
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const active = hovered || focused;
  const saved = favorites.includes(item.id);
  return <Click testID={tv ? `tv-title-${item.id}` : undefined} label={`Voir ${item.title}`} focusBeforePress autoFocus={autoFocus} onPress={() => {
    if (onPress) onPress();
    else open({ type: 'detail', item });
  }} onHoverIn={() => setHovered(true)} onHoverOut={() => setHovered(false)} onFocus={() => {
    setFocused(true);
  }} onBlur={() => {
    setFocused(false);
  }}
    style={[{ width, borderRadius: 12 }, phone && { borderRadius: phoneControl.cardRadius, overflow: 'hidden', backgroundColor: theme.surface, borderWidth: 1, borderColor: active ? theme.accent : theme.border }]}>
    <View style={{ width: '100%', aspectRatio: 2 / 3, backgroundColor: theme.surface, borderRadius: phone ? 0 : 12, overflow: 'hidden', alignItems: 'center', justifyContent: 'center' }}>
      <I name="film-outline" size={25} color={theme.faint} />
      <Art source={item.poster || item.backdrop} style={fill} />
      {!phone && <View pointerEvents="none" style={{ ...fill, borderWidth: active ? 2 : 1, borderRadius: 12, borderColor: active ? theme.accent : 'rgba(155,155,155,.24)' }} />}
      {(saved || active) && <View pointerEvents="none" style={{ position: 'absolute', right: 8, bottom: 8, padding: 8, overflow: 'hidden', borderRadius: phone ? 8 : 20 }}><GlassLayer dark /><I name={saved ? 'bookmark' : 'information-circle-outline'} size={18} color={phone ? theme.accent : '#fff'} /></View>}
    </View>
    <T size={phone ? 15 : 14} weight="bold" lines={phone ? undefined : 2} style={[{ marginTop: 9, lineHeight: phone ? 21 : 19 }, phone && { paddingHorizontal: 10 }]}>{item.title}</T>
    <T size={12} color={theme.muted} lines={phone ? undefined : 1} style={[{ marginTop: 3 }, phone && { paddingHorizontal: 10, paddingBottom: 11 }]}>{[item.genre || item.kind, item.year || null].filter(Boolean).join(phone ? ' · ' : '  /  ')}</T>
  </Click>;
}

export function ResumeCard({ item, entry, width }: { item: Title; entry: Progress; width: number }) {
  const { theme, phone } = useApp();
  const { a11yLabel, play, resume } = useSessionAction(item, entry);
  return <Click label={a11yLabel} onPress={play} focusBeforePress style={{ width, borderRadius: phone ? phoneControl.cardRadius : 13, overflow: 'hidden', borderWidth: 1, borderColor: theme.glassEdge }}>
    <View style={{ aspectRatio: phone ? 1.85 : 2.15, backgroundColor: theme.surface }}>
      <Art source={item.backdrop || item.poster} style={fill} />
      <View style={{ position: 'absolute', bottom: 9, left: 10, overflow: 'hidden', borderRadius: phone ? 8 : 18, padding: 7 }}><GlassLayer dark /><I name="play" size={15} color={phone ? theme.accent : '#fff'} /></View>
    </View>
    <View style={{ gap: 6, padding: 12 }}><GlassLayer />
      <T weight="bold" size={15} lines={phone ? undefined : 1}>{item.title}</T>
      <View style={[row, { justifyContent: 'space-between', gap: 6 }, phone && { flexWrap: 'wrap' }]}><T size={12} color={theme.muted} lines={phone ? undefined : 1}>{resume?.label || item.kind}</T><T size={12} color={theme.text}>{timecode(entry.position)}</T></View>
      <ProgressMeter entry={entry} compact />
    </View>
  </Click>;
}
