import React, { useEffect, useState } from "react";
import { Dimensions, Platform, useWindowDimensions, View } from "react-native";
import { StatusBar } from "expo-status-bar";
import { useFonts } from "expo-font";
import * as NativeSplash from 'expo-splash-screen';
import { Slot } from 'expo-router';
import Ionicons from "@expo/vector-icons/Ionicons";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { AppProvider, useApp } from "./lib/store";
import { LaunchScene } from './components/LaunchScene';
import { AccountEntry } from './components/AccountEntry';
import { GlassProvider } from "./components/Glass";
import { isPhoneLayout } from './lib/layout';
import { TvEntryScope, TvFocus } from './components/tv/TvFocus';

// Keep the OS image only until React has painted a real surface, not until a
// remote request completes. A warm, confirmed session has no minimum intro time.
if (Platform.OS !== 'web') void NativeSplash.preventAutoHideAsync().catch(() => {});
let nativeCover = Platform.OS !== 'web';
function showRoot() {
  if (!nativeCover) return;
  nativeCover = false;
  void NativeSplash.hideAsync().catch(() => {});
}

function MemberScreens({ tv }: { tv: boolean }) {
  // Do not initialize the video/sheet tree for an anonymous launch.
  const { OverlayHost } = require('./components/Overlays') as typeof import('./components/Overlays');
  return <GlassProvider><Slot /><OverlayHost />{tv && <TvFocus />}</GlassProvider>;
}

function Application() {
  const { theme, accessState, authSessionId, ready, tv } = useApp();
  const [fontsLoaded, fontError] = useFonts({
    ...Ionicons.font,
    Manrope: require("./assets/fonts/Manrope-400.ttf"),
    ManropeMedium: require("./assets/fonts/Manrope-500.ttf"),
    ManropeSemibold: require("./assets/fonts/Manrope-600.ttf"),
    ManropeBold: require("./assets/fonts/Manrope-700.ttf"),
    ManropeExtra: require("./assets/fonts/Manrope-800.ttf"),
    BarlowCondensedSemibold: require("./assets/fonts/BarlowCondensed-SemiBold.ttf"),
  });
  const starting = (!fontsLoaded && !fontError) || !ready || accessState === 'checking';
  const background = starting || accessState !== 'granted' ? '#0E0A10' : theme.bg;
  useEffect(() => {
    if (Platform.OS === "web") {
      document.querySelector('meta[name="theme-color"]')?.setAttribute("content", background);
      const style = document.createElement("style");
      style.textContent = `body{background:${background};color-scheme:${theme.light ? 'light' : 'dark'}}*{scrollbar-width:thin;scrollbar-color:${theme.faint} transparent;-webkit-tap-highlight-color:transparent}input{caret-color:${theme.accent}}:focus-visible{outline:3px solid ${theme.accent}!important;outline-offset:-3px;box-shadow:inset 0 0 0 5px ${theme.onAccent}}::selection{background:${theme.accent};color:${theme.onAccent}}@media(prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:.01ms!important;transition-duration:.01ms!important;scroll-behavior:auto!important}}`;
      // The search console draws the input focus around its full glass face, not around the text alone.
      style.textContent += `@media(forced-colors:none){[data-testid="catalogue-query"]:focus-visible{outline:none!important;box-shadow:none}}`;
      document.head.appendChild(style);
      return () => style.remove();
    }
  }, [theme, background]);
  return (
    <View onLayout={showRoot} style={{ flex: 1, backgroundColor: background }}>
      <StatusBar style={!starting && theme.light ? "dark" : "light"} />
      {starting ? <LaunchScene /> : accessState === 'granted' ? (
        <MemberScreens key={authSessionId} tv={tv} />
      ) : (
        <GlassProvider key="entry"><TvEntryScope><AccountEntry /></TvEntryScope>{tv && <TvFocus entry />}</GlassProvider>
      )}
    </View>
  );
}

export default function App() {
  const viewport = useWindowDimensions();
  const web = Platform.OS === 'web';
  // The explicit browser preview lasts for this mount, even when a tab changes
  // the URL. A wide monitor alone must not turn into a television interface.
  const [tv] = useState(() => !!Platform.isTV || (web && typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('tv') === '1'));
  const { width, height } = web ? viewport : Dimensions.get('screen');
  const phone = isPhoneLayout(web, tv, width, height);
  return (
    <SafeAreaProvider>
      <AppProvider phone={phone} tv={tv}>
        <Application />
      </AppProvider>
    </SafeAreaProvider>
  );
}
