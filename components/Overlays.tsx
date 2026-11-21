import React, { useLayoutEffect, useMemo, useRef } from "react";
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  View,
} from "react-native";
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { useApp } from "../lib/store";
import { androidTvModal } from '../lib/tvSpatial';
import {
  AccountSheet,
  CollectionSheet,
  CreditsSheet,
  LibrarySheet,
  ProfileSheet,
  SettingsSheet,
} from "./AccountSheets";
import { DetailSheet, LiveSheet, WatchSheet } from "./MediaSheets";
import { Glass } from './Glass';
import { PlaybackBack } from './PlaybackRoom';
import { Avatar, Emblem } from './Brand';
import { SheetGrip } from './SheetGrip';
import { TvDialogScope } from './tv/TvFocus';
import { fill, I, IconButton, row, T, useLayout } from "./UI";

// A translucent native Modal has its own window. Its status bar and cutout
// can overlap the sheet even when the underlying screen reports zero insets.
function PhoneSheetWindow({ children }: React.PropsWithChildren) {
  const { theme } = useApp();
  return (
    <SafeAreaProvider style={{ backgroundColor: theme.bg }}>
      <SafeAreaView style={{ flex: 1 }}>{children}</SafeAreaView>
    </SafeAreaProvider>
  );
}

function Toast({ inside = false }: { inside?: boolean }) {
  const { toast, theme } = useApp();
  const { mobile } = useLayout();
  if (!toast) return null;
  return (
    <View
      pointerEvents="none"
      style={{
        position: "absolute",
        bottom: inside ? 20 : mobile ? 81 : 25,
        left: 20,
        right: 20,
        alignItems: "center",
        zIndex: 100,
      }}
    >
      <Glass blur
        accessibilityLiveRegion="polite"
        style={[
          row,
          {
            gap: 9,
            borderRadius: 24,
            paddingHorizontal: 16,
            paddingVertical: 11,
            maxWidth: 460,
          },
        ]}
      >
        <I name="checkmark-circle" size={17} color={theme.accent} />
        <T size={12} weight="semibold" style={{ flexShrink: 1 }}>
          {toast}
        </T>
      </Glass>
    </View>
  );
}
export function OverlayHost() {
  const playbackBack = useRef<(() => void) | null>(null);
  const { overlay, back, dismiss, canGoBack, theme, tv, account, profile } = useApp();
  const { windowWidth, height, phone } = useLayout();
  const insets = useSafeAreaInsets();
  const width = windowWidth - insets.left - insets.right;
  const compact = width < 600;
  const nativeWindow = !!overlay && tv && Platform.OS === 'android' && Platform.isTV;
  const host = useMemo(() => nativeWindow ? {} : null, [nativeWindow]);
  useLayoutEffect(() => {
    if (!host) return;
    androidTvModal.open(host);
    return () => androidTvModal.close(host);
  }, [host]);
  if (!overlay) return <Toast />;
  const theater = overlay.type === 'watch' || overlay.type === 'channel';
  const full = ["detail", "watch", "channel"].includes(overlay.type);
  const media =
    overlay.type === "detail" ? (
      <DetailSheet item={overlay.item} />
    ) : overlay.type === "watch" ? (
      <WatchSheet
        item={overlay.item}
        season={overlay.season}
        episode={overlay.episode}
        label={overlay.label}
        restart={overlay.restart}
      />
    ) : overlay.type === "channel" ? (
      <LiveSheet channel={overlay.channel} />
    ) : null;
  const key =
    "item" in overlay
      ? `${overlay.type}${overlay.item.id}${overlay.season ?? ""}:${overlay.episode ?? ""}`
      : "channel" in overlay
        ? overlay.channel.id
        : overlay.type;
  const content = media ?? (overlay.type === 'settings' ? <SettingsSheet /> : overlay.type === 'library' ? <LibrarySheet />
    : overlay.type === 'collection' ? <CollectionSheet section={overlay.section} /> : overlay.type === 'profile' ? <ProfileSheet />
    : overlay.type === 'account' ? <AccountSheet /> : <CreditsSheet />);
  const identity = ['account', 'profile', 'library'].includes(overlay.type);
  const SheetWindow = phone ? PhoneSheetWindow : React.Fragment;
  return (
    <Modal
      visible
      onShow={host ? () => androidTvModal.show(host) : undefined}
      transparent
      statusBarTranslucent
      animationType="none"
      supportedOrientations={phone && Platform.OS === 'ios' ? ['portrait', 'landscape-left', 'landscape-right'] : undefined}
      onRequestClose={() => { if (theater && playbackBack.current) playbackBack.current(); else back(); }}
      presentationStyle="overFullScreen"
    >
      <TvDialogScope>{theater ? <PlaybackBack.Provider value={playbackBack}>{media}</PlaybackBack.Provider> : phone || tv ? (
        <SheetWindow>
          <KeyboardAvoidingView key={key} testID={tv ? 'tv-dialog' : 'phone-sheet'} behavior={Platform.OS === 'ios' ? 'padding' : undefined}
            style={[{ flex: 1, backgroundColor: theme.bg }, tv && { paddingTop: insets.top + 20, paddingBottom: insets.bottom + 20,
              paddingLeft: insets.left + 30, paddingRight: insets.right + 30 }]}>
            <View style={[row, { flexShrink: 0, minHeight: tv ? 58 : 52, paddingHorizontal: phone ? 10 : 0, gap: 10, borderBottomWidth: phone ? 1 : 0, borderColor: theme.border }]}>
              {canGoBack ? <IconButton label="Retour" icon="arrow-back" onPress={back} /> : <Emblem size={tv ? 42 : 30} />}
              <View style={{ flex: 1, alignItems: 'center' }}>{phone && <SheetGrip onBack={back} />}</View>
              <IconButton label="Fermer" icon="close" onPress={dismiss} />
            </View>
            {tv && overlay.type === 'detail' ? content : <View style={{ flex: 1, minHeight: 0, flexDirection: 'row', gap: tv ? 30 : 0 }}>
              {tv && identity && width >= 740 && <View style={{ width: '30%', backgroundColor: theme.surface, justifyContent: 'center', padding: 24, gap: 16 }}>
                {overlay.type === 'account' || !profile.profileId ? <>
                  <Emblem size={76} />
                  <T size={28} weight="bold">Compte Neo-stream</T>
                </> : <>
                  <Avatar index={profile.color} portraitId={profile.portraitId} size={88} />
                  <T size={32} weight="bold">{profile.name}</T>
                  <T size={18} color={theme.muted}>Profil de visionnage{account && account.name !== profile.name ? ` de ${account.name}` : ''}</T>
                </>}
              </View>}
              <ScrollView style={{ flex: 1 }} keyboardShouldPersistTaps="handled" contentContainerStyle={{ width: '100%', maxWidth: tv ? 1040 : undefined, alignSelf: 'center' }}>{content}</ScrollView>
            </View>}
            <Toast inside />
          </KeyboardAvoidingView>
        </SheetWindow>
      ) : <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={{
          flex: 1,
          justifyContent: compact ? "flex-end" : "center",
          alignItems: "center",
          paddingLeft: insets.left,
          paddingRight: insets.right,
          paddingTop: insets.top + 12,
          paddingBottom: compact ? 0 : insets.bottom + 12,
        }}
      >
        {/* Le fond ne doit jamais entrer dans l'ordre du focus (TV + web). */}
        <Pressable
          focusable={false}
          {...({ tabIndex: -1 } as any)}
          accessibilityRole="button"
          accessibilityLabel="Fermer la fenêtre"
          onPress={dismiss}
          style={[fill, { backgroundColor: 'rgba(0,0,0,.65)' }]}
        />
        <Glass blur
          style={
            {
              width: compact ? width : Math.min(width - 64, full ? 768 : 540),
              maxHeight: compact
                ? height - insets.top - 35
                : Math.min(height * 0.89, 860),
              borderRadius: compact ? 21 : 22,
              borderBottomLeftRadius: compact ? 0 : 22,
              borderBottomRightRadius: compact ? 0 : 22,
              overflow: "hidden",
              paddingBottom: compact ? insets.bottom : 0,
            }
          }
        >
          {!phone && canGoBack && !full && (
            <View
              style={{
                minHeight: 54,
                justifyContent: "center",
                paddingLeft: 13,
                paddingTop: 7,
              }}
            >
              <IconButton
                label="Retour"
                icon="arrow-back"
                size={28}
                onPress={back}
              />
            </View>
          )}
          <ScrollView
            key={key}
            bounces={false}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={{ flexGrow: 0 }}
            style={{ flexGrow: 0 }}
          >
            {content}
          </ScrollView>
          {!phone && <View style={{ position: "absolute", top: 12, right: 12 }}>
            <IconButton
              glass={full}
              icon="close"
              label="Fermer"
              size={31}
              onPress={dismiss}
            />
          </View>}
          {!phone && canGoBack && full && (
            <View style={{ position: "absolute", top: 12, left: 12 }}>
              <IconButton
                glass
                icon="arrow-back"
                label="Retour"
                size={31}
                onPress={back}
              />
            </View>
          )}
        </Glass>
        <Toast inside />
      </KeyboardAvoidingView>}</TvDialogScope>
    </Modal>
  );
}
