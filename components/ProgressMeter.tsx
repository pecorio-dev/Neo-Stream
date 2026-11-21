import React from 'react';
import { View } from 'react-native';
import { timecode } from '../lib/resume';
import { useApp } from '../lib/store';
import type { Progress } from '../lib/types';
import { row, T } from './UI';

export function ProgressMeter({ entry, dark = false, compact = false }: { entry: Progress; dark?: boolean; compact?: boolean }) {
  const { theme } = useApp();
  const fg = dark ? '#F3F3F1' : theme.text;
  const percent = entry.total > 0 ? Math.round(Math.min(1, Math.max(0, entry.position / entry.total)) * 100) : null;
  return <View style={{ gap: 6 }}>
    {!compact && <View style={[row, { justifyContent: 'space-between', gap: 8 }]}>
      <T size={12} color={fg} weight="semibold" style={{ fontVariant: ['tabular-nums'] }}>{timecode(entry.position)}{entry.total > 0 && ` / ${timecode(entry.total)}`}</T>
      {!!entry.label && <T size={12} color={fg} lines={1}>{entry.label}</T>}
    </View>}
    {percent !== null && <View accessibilityRole="progressbar" accessibilityLabel="Progression de lecture" accessibilityValue={{ min: 0, max: 100, now: percent }}
      style={{ height: 4, borderRadius: 2, overflow: 'hidden', backgroundColor: dark ? 'rgba(255,255,255,.26)' : theme.border }}>
      <View style={{ height: '100%', width: `${percent}%`, backgroundColor: fg, borderRadius: 2 }} />
    </View>}
  </View>;
}
