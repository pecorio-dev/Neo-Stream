import React from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Defs, G, LinearGradient, Path, Stop, Text, TextPath } from 'react-native-svg';
import { Emblem } from './Brand';

// Each run is typeset along a blade as one string, not one view per glyph.
const blades = [
  {
    id: 'launch-negative',
    edge: 'M20 266 C57 152 146 76 278 115 C305 123 322 138 332 149',
    back: 'C241 67 95 130 20 266 Z',
    glyphs: ". . . , , : : : ; ; /// /// :: :: : . .",
    light: '#FA8477', ink: '#682333', size: 10,
  },
  {
    id: 'launch-positive',
    edge: 'M137 307 C214 382 378 324 455 174',
    back: 'C399 317 231 405 137 307 Z',
    glyphs: "' . : :: /// /// ; ; : : , , . . .",
    light: '#E597A4', ink: '#572036', size: 11,
  },
  {
    id: 'launch-refraction',
    edge: 'M270 349 C334 338 406 295 445 224',
    glyphs: '.   .   .  :  :  / / : . .',
    light: '#D9AA81', size: 7,
  },
] as const;

function Aperture({ size }: { size: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 480 480" style={StyleSheet.absoluteFill}>
      <Defs>
        {blades.map(({ id, edge }) => <Path key={id} id={id} d={edge} />)}
        <LinearGradient id="launch-emulsion" x1="0%" y1="100%" x2="100%" y2="0%">
          <Stop offset="0" stopColor="#351520" stopOpacity={0.1} />
          <Stop offset="0.38" stopColor="#8F3443" stopOpacity={0.55} />
          <Stop offset="0.67" stopColor="#A64946" stopOpacity={0.4} />
          <Stop offset="1" stopColor="#351520" stopOpacity={0.1} />
        </LinearGradient>
      </Defs>
      {blades.map(blade => (
        <G key={blade.id}>
          {'back' in blade && <>
            <Path d={`${blade.edge} ${blade.back}`} fill="url(#launch-emulsion)" />
            <Path d={blade.edge} fill="none" stroke={blade.ink} strokeWidth={0.8} />
          </>}
          <Text fill={blade.light} fontSize={blade.size} fontFamily="monospace" letterSpacing={1.15}>
            <TextPath href={`#${blade.id}`} startOffset="6%">{blade.glyphs}</TextPath>
          </Text>
        </G>
      ))}
    </Svg>
  );
}

export function LaunchScene() {
  const { width, height } = useWindowDimensions();
  const size = Math.round(Math.min(width * 0.98, height * 0.82, 760));
  return (
    <SafeAreaView testID="launch-scene" style={styles.scene} accessible
      accessibilityRole="progressbar" accessibilityState={{ busy: true }}
      accessibilityLabel="Neo-stream, chargement en cours">
      <View pointerEvents="none" aria-hidden accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
        style={[styles.plate, { width: size, height: size }]}>
        <Aperture size={size} />
        <Emblem size={Math.round(size * 0.32)} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  scene: { flex: 1, backgroundColor: '#0E0A10', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  plate: { alignItems: 'center', justifyContent: 'center' },
});
