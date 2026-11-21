import React, { useEffect } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, View } from "react-native";
import { router, Tabs, usePathname } from 'expo-router';
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { useApp } from "../lib/store";
import { Avatar, Brand, Emblem } from "./Brand";
import { Glass, GlassLayer } from './Glass';
import { Click, I, IconButton, type IconName, row, T, useLayout } from "./UI";
import { PhoneDock, PhoneMasthead } from './phone/PhoneChrome';
import { TvSidebar } from './tv/TvSidebar';
type BottomTabBarProps = Parameters<NonNullable<React.ComponentProps<typeof Tabs>['tabBar']>>[0];
const labels: Record<string, string> = { index: 'Accueil', catalogue: 'Catalogue', recherche: 'Recherche', direct: 'En direct' };
const icons: Record<string, [IconName, IconName]> = {
  index: ["home-outline", "home"], catalogue: ["albums-outline", "albums"],
  recherche: ["search-outline", "search"], direct: ["radio-outline", "radio"],
};

function Destinations({ state, navigation }: BottomTabBarProps) {
  const { theme } = useApp();
  const { mobile, railWidth } = useLayout();
  const slim = railWidth === 84;
  return <View style={{ flexDirection: mobile ? 'row' : 'column', gap: mobile ? 0 : 6 }}>
    {state.routes.map((route, i) => {
      const active = i === state.index;
      const title = labels[route.name];
      const color = active ? theme.accent : theme.muted;
      return <Click key={route.key} label={title} selected={active} autoFocus={active}
        onPress={() => {
          const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
          if (!event.defaultPrevented) navigation.navigate(route.name);
        }}
        style={mobile ? { flex: 1, minHeight: 58, paddingVertical: 5, alignItems: 'center', justifyContent: 'center', gap: 1 } :
          { ...row, justifyContent: slim ? 'center' : 'flex-start', paddingHorizontal: slim ? 0 : 16, gap: 12, minHeight: 50,
            borderRadius: 12, overflow: 'hidden', borderWidth: 1, borderColor: active ? theme.glassEdge : 'transparent' }}>
        {active && !mobile && <GlassLayer />}
        <View style={mobile ? { width: 52, height: 28, alignItems: 'center', justifyContent: 'center', borderRadius: 15, backgroundColor: active ? theme.soft : 'transparent' } : undefined}>
          <I name={icons[route.name][active ? 1 : 0]} size={mobile ? 20 : 21} color={color} />
        </View>
        {!slim && <T size={mobile ? 11 : 14} weight={active ? 'bold' : 'medium'} color={color}>{title}</T>}
      </Click>;
    })}
  </View>;
}

function HomeLink({ slim = false }: { slim?: boolean }) {
  const { theme } = useApp();
  return <Click label="Neo-stream, accueil" onPress={() => router.navigate('/')}
    style={{ minHeight: 48, justifyContent: 'center', alignItems: 'center', alignSelf: slim ? 'center' : 'flex-start' }}>
    {slim ? <Emblem size={37} /> : <Brand color={theme.text} />}
  </Click>;
}
function PocketHeader() {
  const { theme, profile, open } = useApp();
  const { pad } = useLayout();
  return <View style={[row, { minHeight: 56, paddingHorizontal: pad, justifyContent: 'space-between', borderBottomWidth: 1, borderColor: theme.glassEdge }]}>
    <GlassLayer />
    <HomeLink />
    <View style={[row, { gap: 4 }]}>
      <IconButton icon="options-outline" size={44} label="Paramètres" onPress={() => open({ type: 'settings' })} style={{ borderWidth: 0, backgroundColor: 'transparent' }} />
      <Click label="Mon espace" onPress={() => open({ type: 'library' })} style={{ width: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}>
        <Avatar size={32} index={profile.color} portraitId={profile.portraitId} />
      </Click>
    </View>
  </View>;
}
function NavigationBar(props: BottomTabBarProps) {
  const { theme, open, profile } = useApp();
  const { railWidth } = useLayout();
  const { bottom } = useSafeAreaInsets();
  if (!railWidth) return <View pointerEvents="box-none" style={{ position: 'absolute', bottom: bottom + 8, left: 12, right: 12, alignItems: 'center' }}>
    <Glass blur testID="bottom-navigation" style={{ width: '100%', maxWidth: 460, paddingHorizontal: 4, borderRadius: 26 }}><Destinations {...props} /></Glass>
  </View>;
  const slim = railWidth === 84;
  return <View testID="navigation-rail" style={{ width: railWidth, borderRightWidth: 1, borderColor: theme.glassEdge }}>
    <GlassLayer />
    <ScrollView bounces={false} showsVerticalScrollIndicator={false} contentContainerStyle={{ flexGrow: 1, paddingHorizontal: slim ? 10 : 16, paddingTop: 24, paddingBottom: bottom + 14 }}>
      <View style={{ paddingHorizontal: slim ? 0 : 8, marginBottom: 38 }}><HomeLink slim={slim} /></View>
      <Destinations {...props} />
      <View style={{ flex: 1, minHeight: 24 }} />
      <Click label="Paramètres" onPress={() => open({ type: 'settings' })} style={[row, { minHeight: 48, justifyContent: slim ? 'center' : 'flex-start', gap: 12, paddingHorizontal: slim ? 0 : 12 }]}>
        <I name="options-outline" size={20} color={theme.muted} />{!slim && <T color={theme.muted}>Paramètres</T>}
      </Click>
      <Click label="Mon espace" onPress={() => open({ type: 'library' })} style={[row, { minHeight: 66, borderTopWidth: 1, borderColor: theme.border, gap: 9, justifyContent: slim ? 'center' : 'flex-start' }]}>
        <Avatar size={36} index={profile.color} portraitId={profile.portraitId} />
        {!slim && <><View style={{ flex: 1 }}><T weight="bold" lines={1}>{profile.name}</T><T size={12} color={theme.muted}>Mon espace</T></View><I name="chevron-forward" size={15} color={theme.muted} /></>}
      </Click>
    </ScrollView>
  </View>;
}
export function Navigation() {
  const { mobile, phone } = useLayout();
  const { theme, tv } = useApp();
  const path = usePathname();
  useEffect(() => { if (Platform.OS === 'web') document.title = `${labels[path.slice(1) || 'index'] ?? 'Accueil'} · Neo-stream`; }, [path]);
  const content = <>
      {phone ? <PhoneMasthead /> : !tv && mobile ? <PocketHeader /> : null}
      <Tabs screenOptions={{ headerShown: false, tabBarPosition: !tv && (phone || mobile) ? 'bottom' : 'left', animation: 'none', sceneStyle: { backgroundColor: theme.bg }, lazy: true }}
        tabBar={(props) => tv ? <TvSidebar {...props} /> : phone ? <PhoneDock {...props} /> : <NavigationBar {...props} />}>
        {Object.entries(labels).map(([name, title]) => <Tabs.Screen key={name} name={name} options={{ title: `${title} · Neo-stream` }} />)}
      </Tabs>
    </>;
  return <SafeAreaView edges={['top','left','right']} style={{ flex: 1, backgroundColor: theme.bg }}>
    {phone && Platform.OS === 'ios' ? <KeyboardAvoidingView behavior="padding" style={{ flex: 1 }}>{content}</KeyboardAvoidingView> : content}
  </SafeAreaView>;
}
