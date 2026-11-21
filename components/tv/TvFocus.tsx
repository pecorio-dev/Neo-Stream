import React, { createContext, useContext, useId, useLayoutEffect, useRef } from 'react';
import { Platform, Pressable } from 'react-native';
import { usePathname } from 'expo-router';
import { NavigationRouteContext } from 'expo-router/react-navigation';
import { useApp } from '../../lib/store';
import { androidTvModal, FocusMemory, pulsePreference } from '../../lib/tvSpatial';

type Host = React.ComponentRef<typeof Pressable>;
type Scope = string | object;
const dialog = createContext<object | null>(null);
const entryScope = Object.freeze({ name: 'account-entry' });
export function TvEntryScope({ children }: React.PropsWithChildren) {
  return <dialog.Provider value={entryScope}>{children}</dialog.Provider>;
}
export function TvDialogScope({ children }: React.PropsWithChildren) {
  const { overlay } = useApp();
  return <dialog.Provider value={overlay}>{children}</dialog.Provider>;
}

/** A deliberate focus hand-off on a mounted Android control, not an automatic touch-screen preference. */
export function requestTvControlFocus(node: Host | null) {
  if (node && Platform.OS === 'android') {
    // ReactViewManager requests actual focus on true; false releases the preference, not focus.
    pulsePreference(value => node.setNativeProps({ hasTVPreferredFocus: value }), requestAnimationFrame);
  }
}

type Entry = { ref: React.RefObject<Host | null>; scope: Scope; key: string; preferred: boolean; position: number };
const mounted = new Set<Entry>();
let active: Scope | null = null, awaiting = false, frame = 0, sequence = 0;
let cancelEntry: (() => void) | undefined;
let memory = new FocusMemory();
const matches = (entry: Entry) => entry.scope === active || (entry.scope === '*' && typeof active === 'string');
const stop = (entry: Entry) => ({ ...entry, rect: { left: entry.position, right: entry.position + 1, top: 0, bottom: 1 } });
function schedule() {
  if (!awaiting || frame) return;
  frame = requestAnimationFrame(() => {
    frame = 0;
    if (!awaiting || active === null) return;
    const eligible = Array.from(mounted).filter(e => matches(e) && e.ref.current);
    // Screen actions first; the persistent tab bar is still eligible for exact return.
    const rank = (e: Entry) => e.scope === '*' ? 3 : /^(fermer|retour|supprimer|effacer|déconnexion)/i.test(e.key) ? 2 : 0;
    const ordered = eligible.sort((a,b) => rank(a) - rank(b));
    const target = memory.restore(active, ordered.map(stop));
    if (target) { awaiting = false; requestTvControlFocus(target.ref.current); }
  });
}

/** Click/Button registration: no directional listener. FocusFinder owns every physical D-pad move. */
export function useTvStop(ref: React.RefObject<Host | null>, key: string | undefined, preferred: boolean, enabled: boolean) {
  const overlay = useContext(dialog), route = useContext(NavigationRouteContext);
  const fallback = useId();
  const scope = overlay ?? (route && ['index','catalogue','recherche','direct'].includes(route.name) ? (route.name === 'index' ? '/' : `/${route.name}`) : '*');
  const entry = useRef<Entry | null>(null);
  useLayoutEffect(() => {
    if (!enabled || Platform.OS !== 'android' || !Platform.isTV) return;
    const value = { ref, scope, key: key || fallback, preferred, position: ++sequence };
    entry.current = value; mounted.add(value); schedule();
    return () => { mounted.delete(value); entry.current = null; };
  }, [enabled, ref, scope, key, fallback, preferred]);
  return () => {
    const e = entry.current;
    if (!e || !matches(e) || active === null) return;
    if (typeof active === 'object') { cancelEntry?.(); cancelEntry = undefined; awaiting = false; }
    if (!awaiting) memory.remember(active, stop(e));
  };
}

export function TvFocus({ entry = false }: { entry?: boolean } = {}) {
  const { tv, overlay, authStep } = useApp();
  const path = usePathname();
  const scope = entry ? entryScope : overlay ?? path;
  const entryPhase = entry ? authStep : null;
  useLayoutEffect(() => {
    if (!tv) return;
    active = scope;
    // The theater has its own stage/menu entry and Back lifecycle.
    if (overlay?.type !== 'watch' && overlay?.type !== 'channel') {
      const enter = () => { awaiting = true; schedule(); };
      if (!entry && overlay && Platform.OS === 'android' && Platform.isTV) cancelEntry = androidTvModal.whenShown(enter);
      else enter();
    }
    return () => { cancelEntry?.(); cancelEntry = undefined; cancelAnimationFrame(frame); frame = 0; active = null; awaiting = false; };
  }, [tv, scope, overlay, entry, entryPhase]);
  useLayoutEffect(() => () => { memory = new FocusMemory(); }, []);
  return null;
}
export default TvFocus;
