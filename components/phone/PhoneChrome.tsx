import React, { useRef } from 'react';
import { Platform, Pressable, View, type GestureResponderEvent } from 'react-native';
import { router, type Tabs } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../../lib/store';
import { Avatar, Emblem } from '../Brand';
import { Click, I, row, T, useLayout, type IconName } from '../UI';

type BottomTabBarProps = Parameters<NonNullable<React.ComponentProps<typeof Tabs>['tabBar']>>[0];
const tabs: Record<string, [string, IconName, IconName]> = {
  index: ['Accueil', 'home-outline', 'home'], catalogue: ['Catalogue', 'albums-outline', 'albums'],
  recherche: ['Recherche', 'search-outline', 'search'], direct: ['En direct', 'radio-outline', 'radio'],
};

export function PhoneMasthead() {
  const { profile, open, theme } = useApp();
  const { pad } = useLayout();
  return <View style={[row, { minHeight: 55, paddingHorizontal: pad, gap: 4, backgroundColor: theme.surface }]}>
    <Click label="Neo-stream, accueil" onPress={() => router.navigate('/')} style={[row, { gap: 8, flex: 1, minHeight: 48 }]}>
      <Emblem size={34} /><T weight="extra" size={20} style={{ letterSpacing: -.9, flexShrink: 1 }}>Neo-stream</T>
    </Click>
    <Click label="Paramètres" onPress={() => open({ type: 'settings' })} style={{ width: 48, height: 48, alignItems: 'center', justifyContent: 'center' }}>
      <I name="options-outline" size={22} />
    </Click>
    <Click label="Mon espace" onPress={() => open({ type: 'library' })} style={{ width: 48, height: 48, alignItems: 'center', justifyContent: 'center' }}>
      <Avatar size={32} index={profile.color} portraitId={profile.portraitId} />
    </Click>
  </View>;
}

export function PhoneDock({ state, navigation }: BottomTabBarProps) {
  const { theme } = useApp();
  const { bottom } = useSafeAreaInsets();
  const touch = useRef<{ x: number; y: number; vertical: boolean } | null>(null);
  const ignorePressUntil = useRef(0);
  function visit(index: number) {
    const route = state.routes[index];
    if (!route) return;
    const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
    if (!event.defaultPrevented) navigation.navigate(route.name);
  }
  // Observe only touches that begin on the dock. The child Pressables keep
  // ownership of taps, keyboard activation and long presses. A drag is not a tap.
  function track(event: GestureResponderEvent, end = false) {
    const origin = touch.current;
    const point = event.nativeEvent.changedTouches[0];
    if (!origin || !point) return;
    const dx = point.pageX - origin.x, dy = point.pageY - origin.y;
    if (Math.max(Math.abs(dx), Math.abs(dy)) > 10) ignorePressUntil.current = Date.now() + 500;
    if (Math.abs(dy) > 10 && Math.abs(dy) > Math.abs(dx)) origin.vertical = true;
    if (end) {
      touch.current = null;
      if (!origin.vertical && Math.abs(dx) >= 44 && Math.abs(dx) > 1.6 * Math.abs(dy)) visit(state.index + (dx < 0 ? 1 : -1));
    }
  }
  return <View testID="bottom-navigation" style={{ flexDirection: 'row', flexShrink: 0, paddingHorizontal: 4, paddingBottom: bottom,
    paddingTop: 4, borderTopWidth: 1, borderColor: theme.border, backgroundColor: theme.surface,
    ...(Platform.OS === 'web' ? { touchAction: 'pan-y' as const } : {}) }}
    onTouchStart={event => {
      const points = event.nativeEvent.touches;
      ignorePressUntil.current = points.length === 1 ? 0 : Date.now() + 500;
      touch.current = points.length === 1 ? { x: points[0].pageX, y: points[0].pageY, vertical: false } : null;
    }} onTouchMove={event => track(event)} onTouchEnd={event => track(event, true)} onTouchCancel={() => { touch.current = null; }}>
    {state.routes.map((route, i) => {
      const active = i === state.index;
      const [label, outline, solid] = tabs[route.name];
      const color = active ? theme.onAccent : theme.muted;
      return <Pressable key={route.key} accessibilityRole={Platform.OS === 'web' ? 'button' : 'tab'} accessibilityLabel={label}
        accessibilityState={{ selected: active }} aria-pressed={Platform.OS === 'web' ? active : undefined} focusable
        onPress={() => { if (Date.now() >= ignorePressUntil.current) visit(i); }}
        onLongPress={() => { if (Date.now() >= ignorePressUntil.current) navigation.emit({ type: 'tabLongPress', target: route.key }); }}
        style={({ pressed }) => ({ flex: active ? 1.12 : 1, minWidth: 48, minHeight: 52, paddingVertical: 5, marginBottom: 4, gap: 2,
          borderRadius: 8, alignItems: 'center', justifyContent: 'center', backgroundColor: active ? theme.accent : pressed ? theme.elevated : 'transparent' })}>
        <I name={active ? solid : outline} size={19} color={color} /><T weight={active ? 'bold' : 'medium'} color={color} size={11} style={{ textAlign: 'center' }}>{label}</T>
      </Pressable>;
    })}
  </View>;
}
