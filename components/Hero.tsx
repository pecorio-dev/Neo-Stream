import React, { useRef } from 'react';
import { View } from 'react-native';
import { BlurTargetView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { useApp } from '../lib/store';
import type { Progress, Title } from '../lib/types';
import { useSessionAction } from '../lib/useSessionAction';
import { Glass } from './Glass';
import { ProgressMeter } from './ProgressMeter';
import { Art, Button, fill, row, T, useLayout } from './UI';

export function Hero({ item, entry }: { item: Title; entry?: Progress }) {
  const { compact, inner } = useLayout();
  const { open, favorites, toggleFavorite } = useApp();
  const { label, a11yLabel, play } = useSessionAction(item, entry);
  const photo = useRef<View>(null);
  const dune = item.id === 'tt15239678';
  const padding = compact ? 10 : inner < 900 ? 20 : 28;
  const saved = favorites.includes(item.id);
  const meta = [item.kind, item.year || null, item.genre || null, !entry && item.duration || null].filter(Boolean);
  // Even very long titles or enlarged system text may increase the plate's height.
  const typeSize = compact ? inner < 335 ? 36 : 42 : inner < 850 ? 50 : 64;
  return <View testID="home-projection" style={{ backgroundColor: '#191919', borderRadius: compact ? 18 : 24, overflow: 'hidden',
    minHeight: compact ? Math.min(425, inner * 1.05) : Math.min(492, Math.max(380, inner * .39)),
    padding, paddingTop: compact ? Math.min(205, Math.max(146, inner * .48)) : padding, justifyContent: 'flex-end' }}>
    <BlurTargetView ref={photo} style={fill}>
      <Art source={dune && !compact ? require('../assets/images/hero-dune.jpg') : item.backdrop || item.poster} priority="high"
        position={compact ? { left: '62%', top: '20%' } : 'center'} style={fill} />
      <LinearGradient colors={['rgba(0,0,0,.02)', 'transparent', 'rgba(0,0,0,.32)']} locations={[0,.53,1]} style={fill} />
    </BlurTargetView>
    <Glass dark blur target={photo} testID="session-plate" style={{ alignSelf: compact ? 'stretch' : 'flex-start',
      width: compact ? undefined : Math.min(500, Math.max(336, inner * .45)), borderRadius: compact ? 13 : 17, padding: compact ? 16 : 24 }}>
      <T role="header" color="#FFF" weight="display" size={typeSize} style={{ lineHeight: Math.ceil(typeSize * 1.04), letterSpacing: -0.6 }}>{item.title}</T>
      <View style={[row, { flexWrap: 'wrap', columnGap: 10, rowGap: 3, marginTop: 9 }]}>
        {meta.map((v, i) => <View key={`${i}:${v}`} style={[row, i > 0 && { paddingLeft: 10, borderLeftWidth: 1, borderColor: 'rgba(255,255,255,.35)' }]}>
          <T size={12} color="#E4E4E1" weight="semibold">{v}</T></View>)}
      </View>
      {entry ? <View style={{ marginTop: 18 }}><ProgressMeter entry={entry} dark /></View> : !!item.description && !compact &&
        <T size={14} color="#E6E6E3" lines={3} style={{ marginTop: 13, lineHeight: 21 }}>{item.description}</T>}
      <View style={[row, { flexWrap: 'wrap', gap: 8, marginTop: compact ? 16 : 20 }]}>
        <Button variant="silver" icon={label === 'Voir les épisodes' ? 'list' : 'play'} label={label} accessibilityLabel={a11yLabel} onPress={play} />
        {label === 'Voir les épisodes' ? <Button variant="glass" icon={saved ? 'checkmark' : 'add'} label={saved ? 'Dans ma liste' : 'Ma liste'} onPress={() => toggleFavorite(item.id)} /> :
          <Button variant="glass" icon="information-circle-outline" label="La fiche" onPress={() => open({ type: 'detail', item })} />}
      </View>
    </Glass>
  </View>;
}
