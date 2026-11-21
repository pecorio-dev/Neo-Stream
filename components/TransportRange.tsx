import React, { useRef } from 'react';
import { View, type GestureResponderEvent } from 'react-native';
import { clamp } from './playerTypes';

export type RangeProps = { label: string; value: number; max: number; step: number; readValue?: () => number; describe: (n: number) => string; onPreview: (n: number | null) => void; onCommit: (n: number) => void };
export default function TransportRange({ label, value, max, step, readValue, describe, onPreview, onCommit }: RangeProps) {
  const width = useRef(1);
  const fraction = max > 0 ? clamp(value / max, 1) : 0;
  const at = (e: GestureResponderEvent) => clamp(e.nativeEvent.locationX / width.current, 1) * max;
  return <View accessible accessibilityRole="adjustable" accessibilityLabel={label} accessibilityValue={{ min: 0, max: Math.round(max), now: Math.round(value), text: describe(value) }}
    accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]} onAccessibilityAction={e => onCommit(clamp((readValue?.() ?? value) + (e.nativeEvent.actionName === 'increment' ? step : -step), max))}
    onLayout={e => { width.current = Math.max(1, e.nativeEvent.layout.width); }} onStartShouldSetResponder={() => true}
    onResponderGrant={e => onPreview(at(e))} onResponderMove={e => onPreview(at(e))} onResponderRelease={e => { onCommit(at(e)); onPreview(null); }}
    onResponderTerminate={() => onPreview(null)} style={{ flex: 1, height: 44, justifyContent: 'center' }}>
    <View pointerEvents="none" style={{ height: 3, backgroundColor: '#5A5A5A', borderRadius: 2 }}>
      <View style={{ width: `${fraction * 100}%`, height: 3, backgroundColor: '#F5F5F2', borderRadius: 2 }} />
      <View style={{ position: 'absolute', left: `${fraction * 100}%`, top: -4, marginLeft: -5, width: 11, height: 11, borderRadius: 6, backgroundColor: '#F5F5F2' }} />
    </View>
  </View>;
}
