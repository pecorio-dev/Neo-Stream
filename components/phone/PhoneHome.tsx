import React from 'react';
import { View } from 'react-native';
import { useApp } from '../../lib/store';
import { Click, I, row, T, useLayout } from '../UI';
import { AsciiField } from './AsciiField';

export function PhoneHeading({ title, action, trace = false, variant = 'trace' }: { title: string; action?: React.ReactNode; trace?: boolean; variant?: 'trace' | 'fold' }) {
  return <View style={[row, { minHeight: 72, paddingVertical: 12, gap: 10, justifyContent: 'space-between' }]}>
    <T role="header" weight="extra" size={32} style={{ flexShrink: 1, letterSpacing: -1.2 }}>{title}</T>
    {trace && <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants" style={{ flex: 1, maxWidth: 160, height: 46, overflow: 'hidden' }}>
      <AsciiField variant={variant} />
    </View>}{action}
  </View>;
}

// The phone tab bar is in-flow: the last control needs no floating-bar clearance.
export function PhoneFooter() {
  const { theme, open } = useApp();
  const { pad } = useLayout();
  return <View style={{ marginHorizontal: pad, marginTop: 24, paddingBottom: 8, borderTopWidth: 1, borderColor: theme.border }}>
    <Click focusBeforePress label="À propos de Neo-stream" onPress={() => open({ type: 'credits' })} style={[row, { gap: 8, minHeight: 48, alignSelf: 'flex-start' }]}>
      <I name="information-circle-outline" size={16} color={theme.muted} /><T size={13} color={theme.muted}>À propos de Neo-stream</T>
    </Click>
  </View>;
}
