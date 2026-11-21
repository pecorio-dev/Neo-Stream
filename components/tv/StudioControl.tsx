import React, { useLayoutEffect, useRef, useState, useSyncExternalStore } from 'react';
import { findNodeHandle, Platform, Pressable, type StyleProp, type ViewStyle } from 'react-native';
import { requestTvControlFocus, useTvStop } from './TvFocus';

// Tabs and its scene are siblings. Only share mounted Android view tags; a detached
// control unregisters itself. Never call findNodeHandle on an HTML element.
const tags = new Map<string, number>();
const listeners = new Set<() => void>();
const subscribe = (fn: () => void) => { listeners.add(fn); return () => { listeners.delete(fn); }; };
function register(id: string, tag: number) {
  tags.set(id, tag);
  listeners.forEach(fn => fn());
  return () => {
    // A moving alias may already belong to the newly selected card.
    if (tags.get(id) !== tag) return;
    tags.delete(id); listeners.forEach(fn => fn());
  };
}
const serverTag = () => undefined;
function useTag(id?: string) {
  return useSyncExternalStore(subscribe, () => id ? tags.get(id) : undefined, serverTag);
}

type Props = { id: string; alias?: string; label: string; onPress: () => void; onLongPress?: () => void;
  onFocus?: () => void; onBlur?: () => void; initial?: boolean; selected?: boolean; up?: string; down?: string; left?: string; right?: string;
  style?: StyleProp<ViewStyle>; children: React.ReactNode };

export function StudioControl({ id, alias, label, onPress, onLongPress, onFocus, onBlur, initial, selected,
  up, down, left, right, style, children }: Props) {
  const ref = useRef<React.ComponentRef<typeof Pressable>>(null);
  const remember = useTvStop(ref, id, !!initial, true);
  const [focused, setFocused] = useState(false);
  useLayoutEffect(() => {
    if (Platform.OS !== 'android' || !ref.current) return;
    const tag = findNodeHandle(ref.current);
    if (tag != null) return register(id, tag);
  }, [id]);
  useLayoutEffect(() => {
    if (Platform.OS !== 'android' || !alias || !ref.current) return;
    const tag = findNodeHandle(ref.current);
    if (tag != null) return register(alias, tag);
  }, [alias]);
  const nextFocusUp = useTag(up), nextFocusDown = useTag(down), nextFocusLeft = useTag(left), nextFocusRight = useTag(right);
  const webLinks = Platform.OS === 'web' ? { dataSet: { tvUp: up, tvDown: down, tvLeft: left, tvRight: right, tvAlias: alias, tvInitial: initial ? 'true' : undefined } } : {};
  return <Pressable ref={ref} focusable testID={id} accessibilityRole="button" accessibilityLabel={label}
    accessibilityState={selected === undefined ? undefined : { selected }} aria-pressed={selected}
    {...webLinks} {...(Platform.OS === 'android' && { nextFocusUp, nextFocusDown, nextFocusLeft, nextFocusRight })}
    onFocus={() => { remember(); setFocused(true); onFocus?.(); }} onBlur={() => { setFocused(false); onBlur?.(); }}
    onLongPress={onLongPress} onPress={() => {
      // Make pointer activation and remote activation remember the same modal opener.
      if (Platform.OS === 'web' || !focused) requestTvControlFocus(ref.current);
      onPress();
    }} style={({ pressed }) => [{ borderRadius: 5, borderWidth: 3, borderColor: 'transparent' }, style,
      focused && { borderColor: '#FFFFFF', outlineWidth: 2, outlineColor: '#151515', outlineOffset: -5 }, pressed && { opacity: .82 }]}>
    {children}
  </Pressable>;
}
