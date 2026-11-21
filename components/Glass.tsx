import React, { createContext, useContext, useEffect, useState } from 'react';
import { AccessibilityInfo, Platform, StyleSheet, View, type ViewProps } from 'react-native';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { palettes } from '../lib/theme';
import { useApp } from '../lib/store';
import { activePreset } from '../lib/displayPresets';

const Solid = createContext(false);
export const useSolidGlass = () => useContext(Solid);
export function GlassProvider({ children }: { children: React.ReactNode }) {
  const { prefs, phone, tv } = useApp();
  const [solid, setSolid] = useState(false);
  useEffect(() => {
    if (Platform.OS === 'web' && typeof window.matchMedia === 'function') {
      const query = window.matchMedia('(prefers-reduced-transparency: reduce), (forced-colors: active)');
      const sync = () => setSolid(query.matches);
      sync(); query.addEventListener('change', sync);
      return () => query.removeEventListener('change', sync);
    }
    if (Platform.OS === 'ios') {
      let live = true;
      void AccessibilityInfo.isReduceTransparencyEnabled().then(v => { if (live) setSolid(v); });
      const sub = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setSolid);
      return () => { live = false; sub.remove(); };
    }
  }, []);
  return <Solid.Provider value={phone || tv || solid || activePreset(prefs.display).matte}>{children}</Solid.Provider>;
}

type Material = { dark?: boolean; blur?: boolean; target?: React.RefObject<View | null> };
/** A specular face + an independently tinted backing. Blurring is opt-in on large planes only. */
export function GlassLayer({ dark, blur, target }: Material) {
  const { theme } = useApp();
  const material = dark && theme.light ? palettes.cinema : theme;
  const solid = useContext(Solid);
  const sample = blur && !solid && (Platform.OS !== 'android' || (!!target && Number(Platform.Version) >= 31));
  return <View pointerEvents="none" aria-hidden importantForAccessibility="no-hide-descendants" style={StyleSheet.absoluteFill}>
    {sample && <BlurView intensity={65} tint={material.light ? 'light' : 'dark'} style={StyleSheet.absoluteFill}
      {...(Platform.OS === 'android' ? { blurTarget: target, blurMethod: 'dimezisBlurViewSdk31Plus' as const } : {})} />}
    <View style={[StyleSheet.absoluteFill, { backgroundColor: solid ? material.surface : sample && !material.light ? 'rgba(8,8,8,.44)' : material.glassTint }]} />
    {!solid && <LinearGradient colors={[material.glassGlint, 'transparent', 'rgba(120,120,120,.05)']}
      locations={[0, .56, 1]} start={{ x: 0, y: 0 }} end={{ x: 1, y: .94 }} style={StyleSheet.absoluteFill} />}
  </View>;
}

export function Glass({ dark, blur, target, style, children, ...props }: ViewProps & Material) {
  const { theme, phone } = useApp();
  const material = dark && theme.light ? palettes.cinema : theme;
  return <View {...props} style={[{ borderRadius: phone ? 12 : 18, overflow: 'hidden', borderWidth: 1, borderColor: material.glassEdge }, style]}>
    <GlassLayer dark={dark} blur={blur} target={target} />{children}
  </View>;
}
