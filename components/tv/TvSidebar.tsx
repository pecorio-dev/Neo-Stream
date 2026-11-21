import React, { useEffect, useState } from 'react';
import { Platform, useWindowDimensions, View } from 'react-native';
import type { Tabs } from 'expo-router';
import { tvRailWidth } from '../../lib/layout';
import { useApp } from '../../lib/store';
import { Avatar, Emblem } from '../Brand';
import { I, T, type IconName } from '../UI';
import { StudioControl } from './StudioControl';

type BottomTabBarProps = Parameters<NonNullable<React.ComponentProps<typeof Tabs>['tabBar']>>[0];
const routes = [
  ['index', 'Accueil', 'home-outline'], ['catalogue', 'Catalogue', 'grid-outline'],
  ['recherche', 'Recherche', 'search-outline'], ['direct', 'En direct', 'radio-outline'],
] as const;
const ids = [...routes.map(([name]) => `tv-tab-${name}`), 'tv-library', 'tv-settings'];
const centered = { alignItems: 'center', justifyContent: 'center' } as const;

export function TvSidebar({ state, navigation, insets }: BottomTabBarProps) {
  const { profile, open, overlay } = useApp();
  const { width, height } = useWindowDimensions();
  const [focus, setFocus] = useState<string | null>(null);
  const [hover, setHover] = useState(false);
  useEffect(() => {
    if (!hover || Platform.OS !== 'web') return;
    // A parked mouse must not hold the pane open during keyboard navigation.
    const clear = () => setHover(false);
    window.addEventListener('keydown', clear, true);
    return () => window.removeEventListener('keydown', clear, true);
  }, [hover]);
  const expanded = !overlay && (!!focus || hover);
  const rail = tvRailWidth(width);
  const scale = Math.min(1.6, Math.max(.75, width / 960), Math.max(0, height - insets.top - insets.bottom) / 410);
  const gutter = Math.round(8 * scale), size = Math.round(46 * scale);
  const pane = expanded ? rail + Math.max(110, Math.ceil(140 * scale)) : rail;
  const home = state.routes[state.index]?.name === 'index';

  function button(i: number, title: string, icon: IconName | null, press: () => void, selected?: boolean, longPress?: () => void) {
    const id = ids[i], label = i === 4 ? `${title} : ${profile.name}` : title;
    return <StudioControl key={id} id={id} label={label} selected={selected}
      up={ids[Math.max(0, i - 1)]} down={ids[Math.min(ids.length - 1, i + 1)]} left={id}
      right={home ? 'tv-home-entry' : undefined}
      onFocus={() => setFocus(id)} onBlur={() => { setFocus(old => old === id ? null : old); setHover(false); }}
      onPress={press} onLongPress={longPress}
      style={{ height: size, justifyContent: 'center', backgroundColor: focus === id ? '#353535' : selected ? '#222222' : 'transparent' }}>
      <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants"
        style={{ flexDirection: 'row', alignItems: 'center' }}>
        {selected && <View style={{ position: 'absolute', left: 1, width: Math.max(3, 3 * scale), height: size / 2, backgroundColor: '#EF3645', borderRadius: 2 }} />}
        <View style={[centered, { width: rail - 2 * gutter - 6 }]}>
          {icon ? <I name={icon} size={24 * scale} color={selected || focus === id ? '#FFFFFF' : '#CECECE'} />
            : <Avatar size={26 * scale} index={profile.color} portraitId={profile.portraitId} />}
        </View>
        {expanded && <T size={Math.max(14, 17 * scale)} color="#F5F5F5" lines={1} weight={selected || focus === id ? 'bold' : 'medium'}>{title}</T>}
      </View>
    </StudioControl>;
  }

  // A negative trailing margin offsets only the revealed pixels: the sibling scene always
  // starts at `rail`. Unlike a child painted outside its parent this remains hit-testable on Android.
  return <View testID="tv-navigation" role="navigation" accessibilityLabel="Navigation principale"
    onPointerMove={e => { if (!overlay && e.nativeEvent.pointerType === 'mouse') setHover(true); }} onPointerLeave={() => setHover(false)}
    style={{ width: pane, marginRight: rail - pane, flexShrink: 0, alignSelf: 'stretch', zIndex: 5,
      backgroundColor: '#101010', paddingHorizontal: gutter, paddingTop: insets.top + 14 * scale,
      paddingBottom: insets.bottom + 12 * scale, gap: 5 * scale }}>
    <View style={[centered, { width: rail - 2 * gutter, height: size }]}><Emblem size={37 * scale} /></View>
    <View style={{ flex: 1 }} />
    {routes.map(([name, title, icon], i) => {
      const route = state.routes.find(r => r.name === name);
      if (!route) return null;
      const active = route.key === state.routes[state.index]?.key;
      return button(i, title, icon, () => {
        const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
        if (!active && !event.defaultPrevented) navigation.navigate(route.name, route.params);
      }, active, () => navigation.emit({ type: 'tabLongPress', target: route.key }));
    })}
    {button(4, 'Mon espace', null, () => open({ type: 'library' }))}
    <View style={{ flex: 1 }} />
    {button(5, 'Paramètres', 'settings-outline', () => open({ type: 'settings' }))}
  </View>;
}
