import React, { useRef, useState } from 'react';
import { Platform, View } from 'react-native';
import { useApp } from '../lib/store';

/** The header's small, dedicated drag target is a sibling of the buttons and scroll view. */
export function SheetGrip({ onBack }: { onBack: () => void }) {
  const { theme } = useApp();
  const drag = useRef<{ x: number; y: number; peak: number } | null>(null);
  const [held, setHeld] = useState(false);
  const cancel = () => { drag.current = null; setHeld(false); };
  const distance = (x: number, y: number) => {
    const d = drag.current;
    if (!d) return 0;
    const dy = y - d.y;
    if (Math.abs(x - d.x) > 28 || dy < d.peak - 16) { cancel(); return 0; }
    d.peak = Math.max(d.peak, dy);
    return dy;
  };
  return <View testID="sheet-grip" accessible={false} style={{ width: 100, height: 44, alignItems: 'center', justifyContent: 'center',
    ...(Platform.OS === 'web' ? { touchAction: 'none' as const } : {}) }}
    onStartShouldSetResponder={() => true}
    onResponderGrant={({ nativeEvent: e }) => { drag.current = { x: e.pageX, y: e.pageY, peak: 0 }; setHeld(true); }}
    onTouchStart={({ nativeEvent: e }) => { if (e.touches.length > 1) cancel(); }}
    onResponderMove={({ nativeEvent: e }) => { if (e.touches.length > 1) cancel(); else distance(e.pageX, e.pageY); }}
    onResponderTerminate={cancel} onTouchCancel={cancel}
    onResponderRelease={({ nativeEvent: e }) => { const go = distance(e.pageX, e.pageY) >= 56; cancel(); if (go) onBack(); }}>
    <View pointerEvents="none" style={{ width: held ? 58 : 48, height: 5, borderRadius: 3, backgroundColor: held ? theme.accent : theme.muted }} />
  </View>;
}
