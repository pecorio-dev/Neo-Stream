import React, { createContext, useCallback, useContext, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, Platform, Pressable, ScrollView, View, type ViewStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { timecode } from '../lib/resume';
import { useApp } from '../lib/store';
import { androidTvModal } from '../lib/tvSpatial';
import type { Theme } from '../lib/types';
import { GlassLayer } from './Glass';
import { Button, Click, I, row, useLayout, type IconName } from './UI';
import { SheetText as T } from './SheetText';
import type { Engine, TrackSelection, Transport } from './playerTypes';
import type { LinkChoice } from './sourceMenu';
import TransportRange from './TransportRange';
import { requestTvControlFocus } from './tv/TvFocus';

export const PlaybackBack = createContext<React.RefObject<(() => void) | null> | null>(null);
const white = '#F4F4F1', grey = '#BDBDBA';
type Panel = 'readers' | 'settings';
const DeskTone = createContext<Theme | undefined>(undefined);
type KeyRef = React.RefObject<React.ComponentRef<typeof Pressable> | null>;

function Key({ icon, label, onPress, primary, text, disabled, id, buttonRef, expanded, autoFocus, onFocus, onBlur }: {
  icon: IconName; label: string; onPress: () => void; primary?: boolean; text?: string; disabled?: boolean; id?: string;
  buttonRef?: KeyRef; expanded?: boolean; autoFocus?: boolean; onFocus?: () => void; onBlur?: () => void;
}) {
  const [focused, setFocused] = useState(false);
  const tone = useContext(DeskTone);
  const { tv } = useApp();
  return <Pressable ref={buttonRef} testID={id} accessible focusable={!disabled} hasTVPreferredFocus={autoFocus} accessibilityRole="button" accessibilityLabel={label}
    accessibilityState={{ disabled, expanded }} aria-expanded={expanded} disabled={disabled} onPress={onPress}
    onFocus={() => { setFocused(true); onFocus?.(); }} onBlur={() => { setFocused(false); onBlur?.(); }}
    style={({ pressed }) => [row, { justifyContent: 'center', gap: 7, minWidth: 44, minHeight: 44, paddingHorizontal: text ? 12 : 0,
      borderRadius: primary ? 24 : 10, backgroundColor: primary ? white : pressed || expanded ? '#3A3A3A' : text ? '#292929' : 'transparent', opacity: disabled ? .4 : 1 },
      tone && { borderRadius: 7, backgroundColor: primary ? tone.accent : pressed || expanded ? tone.soft : text ? tone.elevated : 'transparent' },
      tv && { minHeight: 50, minWidth: 52, paddingHorizontal: text ? 16 : 4 },
      focused && { outlineColor: tone?.accent ?? white, outlineWidth: tv ? 4 : 2, outlineOffset: primary ? 1 : -2 }]}>
    <I name={icon} color={primary ? tone?.onAccent ?? '#101010' : tone?.text ?? white} size={tv ? 25 : primary ? 23 : 20} />{text && <T color={tone?.text ?? white} size={tv ? 18 : 13} weight="semibold" lines={1}>{text}</T>}
  </Pressable>;
}

const choiceRow = (selected: boolean, tone?: Theme) => [row, { minHeight: 44, gap: 12, paddingHorizontal: 9, borderRadius: 8, backgroundColor: selected ? tone?.soft ?? '#303030' : 'transparent' }];

function TrackOptions({ id, title, empty, selection, onSelect }: { id: string; title: string; empty: string; selection?: TrackSelection; onSelect?: (id: string) => void }) {
  const tone = useContext(DeskTone);
  return <View testID={id} style={{ gap: 3, flexBasis: 152, flexGrow: 1, flexShrink: 1, minWidth: 0 }}>
    <T role="header" color={white} weight="semibold">{title}</T>
    {selection?.options.length && onSelect ? selection.options.map(option => {
      const selected = selection.selected === option.id;
      return <Click key={option.id} label={`${title} : ${option.label}`} selected={selected} onPress={() => onSelect(option.id)} style={choiceRow(selected, tone)}>
        <I name={selected ? 'radio-button-on' : 'radio-button-off'} size={17} color={selected ? white : grey} />
        <T color={white} weight="semibold" style={{ flexShrink: 1 }}>{option.label}</T>
      </Click>;
    }) : <T size={13} color={grey} style={{ paddingBottom: 7 }}>{empty}</T>}
  </View>;
}

function useDesk(playing: boolean, pinned: boolean) {
  const [awake, setAwake] = useState(true);
  const [screenReader, setScreenReader] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => {
    if (Platform.OS === 'web') return;
    let active = true;
    void AccessibilityInfo.isScreenReaderEnabled().then(v => { if (active) setScreenReader(v); });
    const sub = AccessibilityInfo.addEventListener('screenReaderChanged', setScreenReader);
    return () => { active = false; sub.remove(); };
  }, []);
  const locked = !playing || pinned || screenReader;
  const wake = useCallback(() => { clearTimeout(timer.current); setAwake(true); if (!locked) timer.current = setTimeout(() => setAwake(false), 3000); }, [locked]);
  useEffect(() => { if (!locked) timer.current = setTimeout(() => setAwake(false), 3000); return () => clearTimeout(timer.current); }, [locked]);
  return { visible: locked || awake, wake, hide: () => { if (!locked) { clearTimeout(timer.current); setAwake(false); } } };
}

type Room = { children: React.ReactNode; title: string; subtitle?: string; credit?: string; state: Transport; engine: React.RefObject<Engine | null>;
  choices: LinkChoice[]; index: number; failed: number[]; exhausted: boolean; onSelect: (index: number) => void; onQuit: () => void; onRetry: () => void;
  onSelectQuality?: (id: string) => void; onSelectSubtitle?: (id: string) => void;
  onOpenMenu?: () => void; onTogglePlayback?: () => void; resolving: boolean; issue?: string; retryDisabled: boolean };

/** Both panels live in the desk, outside the picture; opening one never overlays the video. */
export function PlaybackRoom({ children, title, subtitle, credit, state, engine, choices, index, failed, exhausted, onSelect, onSelectQuality, onSelectSubtitle, onQuit, onRetry, onOpenMenu, onTogglePlayback, resolving, issue, retryDisabled }: Room) {
  const insets = useSafeAreaInsets();
  const { windowWidth, height, phone } = useLayout();
  const { theme, tv } = useApp();
  const tone = phone || tv ? theme : undefined;
  const backRef = useContext(PlaybackBack);
  const root = useRef<View>(null);
  // One choice: a window, or the largest picture this device allows. Never fullscreen the video alone.
  const [large, setLarge] = useState(tv || Platform.OS !== 'web');
  const switchingSize = useRef(false), ownedFullscreen = useRef(false);
  const [panel, setPanel] = useState<Panel | null>(null), [keyboard, setKeyboard] = useState(false);
  const [nativeFocus, setNativeFocus] = useState(false);
  const [stageFocus, setStageFocus] = useState(false);
  const stage = useRef<React.ComponentRef<typeof Pressable>>(null);
  const exitKey = useRef<React.ComponentRef<typeof Pressable>>(null);
  const cancelEntry = useRef<(() => void) | null>(null);
  useLayoutEffect(() => {
    if (!tv || Platform.OS !== 'android' || !Platform.isTV) return;
    let frame = 0;
    const cancelWait = androidTvModal.whenShown(() => {
      frame = requestAnimationFrame(() => {
        cancelEntry.current = null;
        requestTvControlFocus(stage.current ?? exitKey.current);
      });
    });
    const cancel = () => { cancelWait(); cancelAnimationFrame(frame); cancelEntry.current = null; };
    cancelEntry.current = cancel;
    return cancel;
  }, [tv]);
  const readersKey = useRef<React.ComponentRef<typeof Pressable>>(null);
  const settingsKey = useRef<React.ComponentRef<typeof Pressable>>(null);
  const panelCloseKey = useRef<React.ComponentRef<typeof Pressable>>(null);
  const focusAfterLayout = useRef<KeyRef | null>(null);
  const [seekPreview, setSeekPreview] = useState<number | null>(null), [volumePreview, setVolumePreview] = useState<number | null>(null);
  const [fullError, setFullError] = useState('');
  const { visible, wake, hide } = useDesk(state.playing && state.ready && !exhausted, !!panel || keyboard || nativeFocus || (tv && !stageFocus) || seekPreview !== null || volumePreview !== null);
  const usableWidth = windowWidth - insets.left - insets.right;
  const frameW = large ? usableWidth : Math.min(900, usableWidth - 16);
  const compact = frameW < 740;
  const navigating = useRef(false);
  const escapedFullscreen = useRef(0);
  const seekable = !state.live && state.duration > 0 && state.ready;
  const togglePlayback = () => { if (engine.current) { onTogglePlayback?.(); engine.current.toggle(); } };
  const move = (d: number) => { const e = engine.current; if (e) e.seek(e.read().position + d); wake(); };
  const closePanel = () => {
    focusAfterLayout.current = panel === 'readers' ? readersKey : settingsKey;
    setPanel(null); wake();
  };
  const openPanel = (next: Panel) => {
    focusAfterLayout.current = panelCloseKey;
    setPanel(next); wake();
  };
  const toggleReaders = () => {
    if (panel === 'readers') { closePanel(); return; }
    openPanel('readers');
    onOpenMenu?.();
  };
  const toggleSettings = () => {
    if (panel === 'settings') closePanel();
    else openPanel('settings');
  };
  useLayoutEffect(() => {
    if (!focusAfterLayout.current) return;
    const target = focusAfterLayout.current.current ?? settingsKey.current ?? exitKey.current;
    focusAfterLayout.current = null;
    if (tv || Platform.OS === 'android') requestTvControlFocus(target);
    else if (Platform.OS === 'web') (target as unknown as HTMLElement | null)?.focus({ preventScroll: true });
  });
  const previousSource = useRef({ index, exhausted });
  useLayoutEffect(() => {
    const previous = previousSource.current;
    previousSource.current = { index, exhausted };
    if (panel === 'settings' && (previous.index !== index || previous.exhausted !== exhausted)) closePanel();
  });
  const toggleSize = async () => {
    if (switchingSize.current) return;
    wake(); setFullError('');
    if (Platform.OS !== 'web') { setLarge(v => !v); return; }
    const el = root.current as unknown as HTMLElement | null;
    if (!el) return;
    const ownsScreen = document.fullscreenElement === el;
    switchingSize.current = true;
    try {
      if (ownsScreen) await document.exitFullscreen();
      else if (!large && document.fullscreenEnabled && el.requestFullscreen) await el.requestFullscreen();
      else setLarge(!large); // Includes browsers without an element fullscreen API.
    } catch {
      if (ownsScreen) setFullError('Appuyez sur Échap pour quitter le plein écran.');
      else setLarge(true); // Permission denied: still enlarge inside the app, with the same controls.
    } finally { switchingSize.current = false; }
  };
  useEffect(() => {
    if (Platform.OS !== 'web') return;
    const el = root.current as unknown as HTMLElement | null;
    const change = () => {
      const active = !!el && document.fullscreenElement === el;
      if (!active && !ownedFullscreen.current) return;
      ownedFullscreen.current = active;
      if (!active) escapedFullscreen.current = Date.now();
      setLarge(active); setFullError(''); wake();
    };
    document.addEventListener('fullscreenchange', change); return () => document.removeEventListener('fullscreenchange', change);
  }, [wake]);
  useLayoutEffect(() => {
    if (!backRef) return;
    backRef.current = () => {
      if (panel) closePanel();
      else if (Date.now() - escapedFullscreen.current >= 350) { if (large) void toggleSize(); else onQuit(); }
    };
    return () => { backRef.current = null; };
  });
  const shortcuts = useRef<(e: KeyboardEvent) => void>(() => {});
  useLayoutEffect(() => { shortcuts.current = e => {
    if (e.altKey || e.ctrlKey || e.metaKey || e.defaultPrevented) return;
    const target = e.target as HTMLElement | null;
    const rememberKeyboard = () => { navigating.current = true; setKeyboard(true); wake(); };
    if (e.key === 'Tab') { rememberKeyboard(); return; }
    if (target?.matches('input,textarea,select')) return;
    const isButton = target?.closest('button,[role="button"]');
    const trigger = isButton?.matches('[data-testid="reader-trigger"],[data-testid="player-settings"]');
    if ((panel || trigger) && ['Enter', ' ', 'Escape'].includes(e.key)) rememberKeyboard();
    if (!panel && e.key === 'ArrowDown' && isButton?.getAttribute('data-testid') === 'film-stage') {
      e.preventDefault();
      focusAfterLayout.current = settingsKey;
      rememberKeyboard();
      // An already-pinned desk doesn't need a render to focus its existing button.
      if (settingsKey.current) {
        (settingsKey.current as unknown as HTMLElement).focus();
        focusAfterLayout.current = null;
      }
      return;
    }
    if (panel) {
      const menu = target?.closest('[data-testid="reader-drawer"],[data-testid="player-settings-drawer"]');
      if (menu && /^Arrow(Up|Down|Left|Right)$/.test(e.key)) {
        const options = Array.from(menu.querySelectorAll<HTMLElement>('button:not([disabled]),[role="button"]:not([aria-disabled="true"])'));
        const current = options.indexOf(isButton as HTMLElement);
        if (current >= 0) {
          e.preventDefault(); rememberKeyboard();
          const offset = e.key === 'ArrowUp' || e.key === 'ArrowLeft' ? -1 : 1;
          options[current + offset]?.focus();
        }
      }
      // Don't run playback shortcuts while selecting an option; Escape goes through PlaybackBack.
      if (menu) return;
    }
    if (tv && /^Arrow/.test(e.key)) { rememberKeyboard(); return; }
    if ((e.key === ' ' && (!isButton || isButton.getAttribute('data-testid') === 'film-stage')) || e.key.toLowerCase() === 'k') { e.preventDefault(); if (!e.repeat) togglePlayback(); }
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') { e.preventDefault(); move(e.key === 'ArrowLeft' ? -10 : 10); }
    else if (e.key.toLowerCase() === 'm') { if (!e.repeat) engine.current?.mute(); }
    else if (e.key.toLowerCase() === 'f') { e.preventDefault(); if (!e.repeat) void toggleSize(); }
    else return;
    wake();
  }; });
  useEffect(() => {
    if (Platform.OS !== 'web') return;
    const keydown = (e: KeyboardEvent) => shortcuts.current(e);
    const pointer = () => { navigating.current = false; setKeyboard(false); };
    document.addEventListener('keydown', keydown, true); document.addEventListener('pointerdown', pointer, true);
    return () => { document.removeEventListener('keydown', keydown, true); document.removeEventListener('pointerdown', pointer, true); };
  }, []);

  const focusDesk = { onFocus: () => { if (Platform.OS !== 'web') setNativeFocus(true); }, onBlur: () => { if (Platform.OS !== 'web') setNativeFocus(false); } };
  const readerToggle = choices.length > 0 && <Key {...focusDesk} buttonRef={readersKey} id="reader-trigger" icon="layers-outline" text={!phone && frameW < 360 ? undefined : 'Lecteurs'}
    expanded={panel === 'readers'} label={panel === 'readers' ? 'Fermer les lecteurs' : 'Choisir le lecteur'} onPress={toggleReaders} />;
  const settingsToggle = <Key {...focusDesk} buttonRef={settingsKey} id="player-settings" icon="settings-outline" text={!compact || (phone && frameW >= 375) ? 'Réglages' : undefined}
    expanded={panel === 'settings'} label="Réglages du lecteur" onPress={toggleSettings} />;
  const exit = <Key {...focusDesk} buttonRef={exitKey} icon="close" label="Quitter la lecture" onPress={onQuit} />;
  const identity = <View style={{ flex: 1, minWidth: 0, gap: 1 }}><T role="header" color={white} weight="display" size={compact ? 23 : 28} lines={1}>{title}</T>
    {!!(subtitle || state.live) && <T color={grey} size={12} lines={1}>{[state.live ? 'En direct' : '', subtitle].filter(Boolean).join('  /  ')}</T>}</View>;
  const sizeToggle = <Key {...focusDesk} id="player-size-toggle" icon={large ? 'contract-outline' : 'expand-outline'} label={large ? 'Réduire le lecteur' : 'Agrandir le lecteur'} onPress={() => void toggleSize()} />;
  const gallery = { width: '100%' as const, maxWidth: 1380, alignSelf: 'center' as const, paddingHorizontal: compact ? 12 : 26 };
  const panelHeight = Math.min(186, Math.max(44, (height - insets.top - insets.bottom) * .27));
  const windowHeight = Math.max(255, frameW * 9 / 16 + (compact ? 135 : 86) + (panel ? panelHeight + 52 : 0));
  const position = seekPreview ?? state.position;
  return <View ref={root} testID="projection-room" onFocus={tv && Platform.OS === 'android' && Platform.isTV ? () => cancelEntry.current?.() : undefined} onPointerMove={e => { if (e.nativeEvent.pointerType === 'mouse') wake(); }}
    style={{ flex: 1, backgroundColor: large ? '#000' : 'rgba(0,0,0,.8)', alignItems: 'center', justifyContent: 'center', paddingTop: insets.top, paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right }}>
    <View testID="player-frame" style={{ width: frameW, height: large ? '100%' : Math.min(height - insets.top - insets.bottom - 16, windowHeight), maxHeight: '100%', minHeight: 0, backgroundColor: '#000', overflow: 'hidden', borderRadius: large ? 0 : 16, borderWidth: large ? 0 : 1, borderColor: '#3B3B3B' }}>
      {exhausted ? <View style={{ flex: 1, minHeight: 0, padding: 12, gap: 10, justifyContent: 'center', alignItems: 'center' }}>
        <T color={white} size={17} style={{ textAlign: 'center' }}>{issue ?? 'Aucune des sources disponibles n’a pu être lue.'}</T>
        <Button small autoFocus={!tv} variant="silver" disabled={retryDisabled} label={retryDisabled ? 'Réessayer plus tard' : 'Recharger les sources'} icon="refresh" onPress={onRetry} />
      </View> : <Pressable ref={stage} testID="film-stage" accessible focusable accessibilityRole="button" accessibilityLabel={visible && state.playing && !panel ? 'Masquer les commandes' : 'Afficher les commandes'}
        onBlur={() => setStageFocus(false)} onFocus={() => { setStageFocus(true); if (navigating.current || tv || Platform.OS === 'android') wake(); }} onPress={() => { if (visible && state.playing && !panel) hide(); else wake(); }}
        style={[{ flex: 1, minHeight: 0, backgroundColor: '#000', justifyContent: 'center' }, tv && stageFocus && visible && { outlineWidth: 3, outlineColor: theme.accent, outlineOffset: -3 }, Platform.OS === 'web' && !visible && ({ cursor: 'none' } as unknown as ViewStyle)]}>
        {children}
        {!state.ready && <View pointerEvents="none" style={{ position: 'absolute', alignSelf: 'center', alignItems: 'center', gap: 10 }}>
          <ActivityIndicator color={white} /><T color={grey} size={13}>{resolving ? 'Recherche des lecteurs…' : choices.length ? `Ouverture du lien ${index + 1}…` : 'Ouverture du lecteur…'}</T>
        </View>}
      </Pressable>}
      {visible && <DeskTone.Provider value={tone}><View testID="playback-desk" style={{ borderTopWidth: 1, borderColor: tone?.border ?? '#373737', backgroundColor: tone?.surface, paddingTop: 2, paddingBottom: compact ? 4 : 7 }}>
        {!tone && <GlassLayer dark />}
        <View style={gallery}>
          {tv && !compact && <View style={[row, { gap: 14, paddingTop: 10, marginBottom: 4 }]}>{identity}{readerToggle}{settingsToggle}{sizeToggle}{exit}</View>}
          {panel && <View key={panel} testID={panel === 'readers' ? 'reader-drawer' : 'player-settings-drawer'} style={{ borderBottomWidth: 1, borderColor: '#444', marginBottom: 3, paddingBottom: 4 }}>
            <View style={[row, { justifyContent: 'space-between' }]}>
              <T role="header" color={white} weight="display" size={22}>{panel === 'readers' ? 'Lecteurs disponibles' : 'Réglages'}</T>
              <Key buttonRef={panelCloseKey} id="player-panel-close" icon="close" label={panel === 'readers' ? 'Fermer le menu des lecteurs' : 'Fermer les réglages'} onPress={closePanel} />
            </View>
            <ScrollView style={{ maxHeight: panelHeight }} keyboardShouldPersistTaps="handled">
              {panel === 'readers' ? <>
                {choices.map(choice => { const unavailable = failed.includes(choice.index), active = index === choice.index && !unavailable && !exhausted;
                  return <Click key={choice.index} selected={active} disabled={unavailable} label={`${choice.label}${active ? ', en cours' : unavailable ? ', indisponible' : ''}`}
                    onPress={() => { if (!active && !unavailable) onSelect(choice.index); closePanel(); }} style={choiceRow(active, tone)}>
                    <I name={unavailable ? 'alert-circle-outline' : active ? 'checkmark-circle-outline' : 'ellipse-outline'} size={17} color={active ? white : grey} />
                    <T color={unavailable ? grey : tone?.text ?? white} weight="semibold" lines={phone ? undefined : 1} style={phone && { flexShrink: 1 }}>{choice.label}</T>
                  </Click>; })}
                {!!credit && <T size={12} color={grey} style={{ paddingVertical: 5 }}>{credit}</T>}
              </> : !state.ready && !exhausted ? <T color={grey} size={13} style={{ paddingVertical: 8 }}>Ouverture du lien…</T> : <>
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', columnGap: compact ? 10 : 24, rowGap: 10 }}>
                  <TrackOptions id="quality-menu" title="Qualité" empty="Qualité non réglable sur ce lien." selection={state.ready ? state.qualityMenu : undefined} onSelect={onSelectQuality} />
                  <TrackOptions id="subtitle-menu" title="Sous-titres" empty="Aucune piste sélectionnable." selection={state.ready ? state.subtitleMenu : undefined} onSelect={onSelectSubtitle} />
                </View>
                {state.ready && state.audio && <Button small variant="glass" label={`Audio : ${state.audio}`} icon="language-outline" onPress={() => engine.current?.nextAudio()} />}
              </>}
            </ScrollView>
          </View>}
          {compact && <View style={[row, { gap: 5, paddingTop: 3 }]}>{identity}{readerToggle}{exit}</View>}
          {seekable && <View style={[row, { gap: 12, height: Platform.OS === 'web' ? 32 : 44 }]}>
            <T size={12} weight="semibold" color={white} style={{ fontVariant: ['tabular-nums'] }}>{timecode(position)}</T>
            <TransportRange label="Position de lecture" max={state.duration} step={5} value={position} readValue={() => engine.current?.read().position ?? position} describe={timecode} onPreview={setSeekPreview} onCommit={n => engine.current?.seek(n)} />
            <T size={12} color={grey} style={{ fontVariant: ['tabular-nums'] }}>{timecode(state.duration)}</T>
          </View>}
          <View style={[row, { gap: compact ? 0 : 5 }]}>
            <Key {...focusDesk} primary icon={state.playing ? 'pause' : 'play'} label={state.playing ? 'Pause' : 'Lecture'} disabled={!state.ready || exhausted} onPress={togglePlayback} />
            {seekable && <><Key {...focusDesk} icon="play-back-outline" label="Reculer de 10 s" onPress={() => move(-10)} /><Key {...focusDesk} icon="play-forward-outline" label="Avancer de 10 s" onPress={() => move(10)} /></>}
            <Key {...focusDesk} icon={state.muted || !state.volume ? 'volume-mute-outline' : 'volume-high-outline'} label={state.muted || !state.volume ? 'Activer le son' : 'Couper le son'} disabled={!state.ready} onPress={() => engine.current?.mute()} />
            {!compact && state.ready && <View style={{ width: 66, height: 44, marginRight: 14 }}><TransportRange label="Volume" max={100} step={5} value={volumePreview ?? (state.muted ? 0 : state.volume * 100)}
              describe={n => `${Math.round(n)} %`} onPreview={setVolumePreview} onCommit={n => engine.current?.volume(n / 100)} /></View>}
            {(!tv || compact) && <>{compact ? <View style={{ flex: 1 }} /> : <>{identity}{readerToggle}</>}{settingsToggle}{sizeToggle}{!compact && exit}</>}
          </View>
          {!!fullError && <T color={grey} size={12}>{fullError}</T>}
        </View>
      </View></DeskTone.Provider>}
    </View>
  </View>;
}
