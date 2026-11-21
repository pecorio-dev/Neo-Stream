import React, { useCallback, useId, useRef, useState } from 'react';
import { Platform, TextInput, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Circle, Defs, LinearGradient as Metal, Path, Stop } from 'react-native-svg';
import { useApp } from '../lib/store';
import { fonts } from '../lib/theme';
import type { Category } from '../lib/types';
import { ControlFrame, OptionBand, plural } from './Browse';
import { Glass, useSolidGlass } from './Glass';
import { Click, I, row, T, useLayout } from './UI';

const scopes: Category[] = ['Tout', 'Film', 'Série', 'Animé'];

/** A polished lens on the glass face; a single flat stroke in matte or high-contrast mode. */
function Lens({ size, solid, focused }: { size: number; solid: boolean; focused: boolean }) {
  const { theme } = useApp();
  const metal = `lens-${useId().replace(/[^\w-]/g, '')}`;
  const stroke = solid ? theme.text : `url(#${metal})`;
  return <Svg width={size} height={size} viewBox="0 0 40 40">
    {!solid && <Defs><Metal id={metal} x1="0%" y1="0%" x2="80%" y2="100%">
      <Stop offset="0" stopColor={theme.accent} /><Stop offset="0.37" stopColor={theme.muted} />
      <Stop offset="0.64" stopColor={theme.faint} /><Stop offset="1" stopColor={theme.accent} />
    </Metal></Defs>}
    <Path d="M24 24l10 10" stroke={stroke} strokeWidth={4.5} strokeLinecap="round" />
    <Circle cx={16.5} cy={16.5} r={11.8} fill={solid ? theme.surface : theme.elevated} stroke={stroke} strokeWidth={2.8} />
    {!solid && <Path d="M9.3 16.4a7.4 7.4 0 0 1 7.3-7.3" fill="none" stroke={focused ? theme.accent : theme.faint} strokeWidth={1.5} strokeLinecap="round" />}
  </Svg>;
}

type Props = { query: string; onChange: (query: string) => void; onSubmit: () => void; scope: Category; onScope: (s: Category) => void };
export function SearchConsole({ query, onChange, onSubmit, scope, onScope }: Props) {
  const { theme, overlay, tv } = useApp();
  const { phone, inner, fontScale } = useLayout();
  const inline = !phone && inner >= 800 * Math.max(1, fontScale);
  const narrow = phone || inner < 560;
  const solid = useSolidGlass();
  const input = useRef<TextInput>(null);
  const [focused, setFocused] = useState(false), [shortcut, setShortcut] = useState('');

  useFocusEffect(useCallback(() => {
    if (Platform.OS !== 'web' || overlay) return;
    const mq = window.matchMedia('(hover: hover) and (pointer: fine)');
    const mac = /Mac|iPhone|iPad/.test(navigator.platform);
    const updateHint = () => setShortcut(mq.matches ? (mac ? '⌘ K' : 'Ctrl K') : '');
    updateHint(); mq.addEventListener('change', updateHint);
    const toSearch = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() !== 'k' || !(mac ? e.metaKey : e.ctrlKey) || e.altKey || e.shiftKey || e.defaultPrevented || e.isComposing) return;
      e.preventDefault(); input.current?.focus();
    };
    document.addEventListener('keydown', toSearch);
    return () => { mq.removeEventListener('change', updateHint); document.removeEventListener('keydown', toSearch); };
  }, [overlay]));

  const hint = !tv && !query && !narrow && shortcut;
  const h = Math.max(phone ? 56 : tv || narrow ? 62 : 76, Math.ceil(fontScale * 31) + 16);
  const field = <View testID="query-field" style={[{ flex: inline ? 1 : undefined, minWidth: 0, minHeight: h, justifyContent: 'center' },
    (phone || tv) && { borderRadius: 6, borderWidth: 2, backgroundColor: theme.surface, borderColor: focused ? theme.accent : theme.border }]}>
      <TextInput ref={input} testID="catalogue-query" accessibilityLabel="Rechercher un film, une série ou un animé" placeholder={narrow ? 'Chercher un titre…' : 'Un film, une série, un animé…'}
        placeholderTextColor={theme.muted} selectionColor={Platform.OS === 'web' ? undefined : theme.faint} cursorColor={theme.accent} underlineColorAndroid="transparent"
        value={query} onChangeText={onChange} onSubmitEditing={onSubmit} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
        returnKeyType="search" maxLength={120} autoCorrect={false} autoCapitalize="none" clearButtonMode="never"
        style={{ width: '100%', minHeight: h, paddingLeft: phone ? 49 : narrow ? 62 : 78, paddingRight: query ? 59 : hint ? 76 : 17,
          fontFamily: fonts.medium, fontSize: narrow ? 18 : 23, letterSpacing: narrow ? -.2 : -.55, color: theme.text }} />
      <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants" style={{ position: 'absolute', left: narrow ? 17 : 21, top: 0, bottom: 0, justifyContent: 'center' }}>
        {phone || tv ? <I name="search-outline" size={tv ? 30 : 22} color={focused ? theme.accent : theme.muted} /> : <Lens size={narrow ? 31 : 39} solid={solid} focused={focused} />}
      </View>
      {hint ? <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants" style={{ position: 'absolute', right: 15, borderRadius: 7, paddingHorizontal: 7, paddingVertical: 3, borderWidth: 1, borderColor: theme.glassEdge, backgroundColor: theme.surface }}>
        <T size={12} weight="semibold" color={theme.muted}>{hint}</T>
      </View> : null}
      {!!query && <Click label="Effacer la recherche" onPress={() => { onChange(''); input.current?.focus(); }} style={{ position: 'absolute', right: 7, width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center' }}>
        <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: theme.soft, alignItems: 'center', justifyContent: 'center' }}><I name="close" size={16} color={theme.text} /></View>
      </Click>}
    </View>;
  if (phone || tv) return <ControlFrame testID="search-console"><View style={{ flexDirection: inline ? 'row' : 'column', alignItems: inline ? 'center' : 'stretch', gap: 8 }}>{field}
    <View style={inline ? { width: 372 } : undefined}>
    <OptionBand name="Types de titres" testID="search-scopes" options={scopes} value={scope} display={plural} onChange={onScope} />
    </View></View></ControlFrame>;
  return <Glass blur testID="search-console" style={{ flexDirection: inline ? 'row' : 'column', alignItems: inline ? 'center' : 'stretch',
    borderRadius: narrow ? 19 : 23, borderWidth: 2, borderColor: focused ? theme.accent : solid ? theme.faint : theme.glassEdge }}>
    {!solid && <View pointerEvents="none" aria-hidden style={{ position: 'absolute', top: 0, left: 12, right: 12, height: 1 }}>
      <LinearGradient colors={['transparent', 'rgba(255,255,255,.48)', 'rgba(255,255,255,.08)', 'transparent']} locations={[0, .14, .65, 1]}
        start={{ x: 0, y: .5 }} end={{ x: 1, y: .5 }} style={{ flex: 1 }} />
    </View>}{field}
    <View testID="search-scopes" style={[row, { marginRight: inline ? 10 : 8, marginLeft: inline ? 0 : 8, borderColor: theme.glassEdge,
      borderLeftWidth: inline ? 1 : 0, borderTopWidth: inline ? 0 : 1, paddingLeft: inline ? 10 : 0, paddingVertical: inline ? 0 : 5, gap: inline ? 3 : 2, flexWrap: 'wrap' }]}>
      {scopes.map(c => <Click key={c} label={plural(c)} selected={scope === c} onPress={() => onScope(c)}
        style={{ flexGrow: inline ? 0 : 1, minWidth: 48, minHeight: 48, paddingHorizontal: inline ? 14 : 8, justifyContent: 'center', alignItems: 'center', borderRadius: phone ? 8 : 13,
          backgroundColor: scope === c ? (phone ? theme.soft : theme.accent) : 'transparent' }}>
        <T size={14} weight={scope === c ? 'bold' : 'medium'} color={scope === c ? (phone ? theme.accent : theme.onAccent) : theme.muted}>{plural(c)}</T>
      </Click>)}
    </View>
  </Glass>;
}
