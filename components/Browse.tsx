import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../lib/store';
import type { Category } from '../lib/types';
import { Click, I, row, T, useLayout } from './UI';

export const plural = (category: Category) => ({ Tout: 'Tout', Film: 'Films', Série: 'Séries', Animé: 'Animés' })[category];

/** Touch strips scroll natively; a local disclosure exposes overflowing options without dragging.
 * TV lays the same choices out in reading order so all rows are reachable by D-pad. */
export function OptionBand<S extends string>({ options, value, onChange, display, testID, name }: {
  options: readonly S[]; value: S; onChange: (s: S) => void; display?: (s: S) => string; testID: string; name: string;
}) {
  const { theme, tv } = useApp();
  const [expanded, setExpanded] = useState(false);
  const [width, setWidth] = useState(0), [content, setContent] = useState(0);
  const choices = options.map(s => <Click key={s} label={display ? display(s) : s} selected={value === s} onPress={() => onChange(s)}
    style={{ minHeight: 48, minWidth: 48, justifyContent: 'center', alignItems: 'center', paddingHorizontal: tv ? 15 : 12,
      backgroundColor: s === value ? (tv ? theme.text : theme.soft) : 'transparent', borderRadius: tv ? 4 : 0,
      borderBottomWidth: tv ? 0 : 2, borderColor: s === value ? theme.accent : theme.border }}>
    <T size={tv ? 19 : 14} color={s === value ? (tv ? theme.onAccent : theme.accent) : theme.muted} weight={s === value ? 'bold' : 'medium'}>{display ? display(s) : s}</T>
  </Click>);
  return <View testID={testID} style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 4 }}>
    {tv || expanded ? <View style={[row, { flex: 1, gap: 4, flexWrap: 'wrap' }]}>{choices}</View> :
      <ScrollView horizontal nestedScrollEnabled keyboardShouldPersistTaps="handled" showsHorizontalScrollIndicator={false} style={{ flex: 1 }}
        onLayout={e => setWidth(e.nativeEvent.layout.width)} onContentSizeChange={w => setContent(w)} contentContainerStyle={{ gap: 4 }}>{choices}</ScrollView>}
    {!tv && (expanded || width > 0 && content > width + 1) && <Click label={`${expanded ? 'Replier' : 'Déployer'} : ${name}`} onPress={() => setExpanded(v => !v)}
      style={{ minWidth: 48, minHeight: 48, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.surface }}>
      <I name={expanded ? 'chevron-up' : 'chevron-down'} color={theme.accent} />
    </Click>}
  </View>;
}

export function ControlFrame({ children, testID }: { children: React.ReactNode; testID?: string }) {
  const { theme, tv } = useApp();
  return <View testID={testID} style={tv ? { paddingVertical: 6, gap: 12, backgroundColor: theme.bg } : { gap: 8 }}>{children}</View>;
}
export function Footer() {
  const { theme, open, tv } = useApp();
  const { pad, mobile, phone } = useLayout();
  const { bottom } = useSafeAreaInsets();
  return <View style={{ marginTop: 32, paddingHorizontal: pad, paddingBottom: bottom + (mobile && !tv ? 90 : 24) }}>
    <View style={[row, { minHeight: 58, justifyContent: 'space-between', gap: 12, borderTopWidth: 1, borderColor: theme.border }]}>
      <T size={tv ? 18 : 13} color={theme.muted} weight="bold">Neo-stream</T>
      <Click focusBeforePress label="À propos de Neo-stream" onPress={() => open({ type: 'credits' })} style={[row, { minHeight: phone || tv ? 48 : 44, gap: 6 }]}>
        <T size={tv ? 18 : 12} color={theme.muted}>À propos</T><I name="information-circle-outline" size={16} color={theme.muted} />
      </Click>
    </View>
  </View>;
}
