import React, { useLayoutEffect, useRef } from 'react';
import { router, usePathname } from 'expo-router';
import type { Pressable } from 'react-native';
import { useApp } from '../../lib/store';
import { FocusMemory, neighbor, type Direction } from '../../lib/tvSpatial';

type Host = React.ComponentRef<typeof Pressable>;
export function TvDialogScope({ children }: React.PropsWithChildren) { return <>{children}</>; }
export const TvEntryScope = TvDialogScope;
export function requestTvControlFocus(node: Host | null) { (node as unknown as HTMLElement | null)?.focus({ preventScroll: true }); }
const noop = () => {};
export function useTvStop(_ref: React.RefObject<Host | null>, _key: string | undefined, _preferred: boolean, _enabled: boolean) { return noop; }

const byId = (id: string) => `[data-testid="${id}"]`;
const routes: Record<string,string> = { '/': 'tv-home', '/catalogue': 'catalogue-grid', '/recherche': 'search-grid', '/direct': 'live-directory' };
const dialogSelector = '[aria-modal="true"],[role="dialog"]';
const controls = 'button,a[href],input:not([type="hidden"]),textarea,select,[role="button"],[role="tab"],[role="switch"],[role="slider"],[role="checkbox"],[contenteditable="true"]';
const hidden = '[inert],[hidden],[aria-hidden="true"],[aria-disabled="true"]';
const transparentControl = 'input[type="range"],input[role="switch"]';
function drawn(el: HTMLElement) {
  if (typeof el.checkVisibility === 'function') return el.checkVisibility({ visibilityProperty: true, opacityProperty: true, checkVisibilityCSS: true, checkOpacity: true });
  // Older TV browsers lack checkVisibility. A newly mounted RNW modal already
  // has a layout box but its ancestor is still transparent until the reveal.
  if (getComputedStyle(el).visibility !== 'visible') return false;
  for (let parent: HTMLElement | null = el; parent; parent = parent.parentElement) {
    const css = getComputedStyle(parent);
    if (css.opacity === '0' || css.display === 'none' || css.contentVisibility === 'hidden') return false;
  }
  return true;
}
function eligible(el: HTMLElement) {
  const visible = el.matches(transparentControl) ? el.parentElement : el;
  return el.tabIndex >= 0 && !el.matches(':disabled') && !el.closest(hidden) && !!visible && el.getClientRects().length > 0 && drawn(visible);
}
function describe(el: HTMLElement) {
  return { el, rect: el.getBoundingClientRect(), key: el.dataset.testid || el.getAttribute('aria-label') || el.textContent?.trim() || el.id || el.tagName,
    preferred: el.matches('[data-tv-initial="true"],[data-testid="film-stage"]') };
}
function move(el: HTMLElement) {
  el.focus({ preventScroll: true });
  if (document.activeElement !== el) return false;
  el.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'instant' });
  return true;
}

export function TvFocus({ entry = false }: { entry?: boolean } = {}) {
  const { tv, overlay, authStep } = useApp();
  const path = usePathname();
  const memory = useRef(new FocusMemory());
  const entryPhase = entry ? `entry:${authStep}` : null;
  useLayoutEffect(() => {
    if (!tv) return;
    const scope = entryPhase ?? overlay ?? path;
    let initial = true, frame = 0;
    function roots() {
      if (entry) {
        const gate = document.querySelector<HTMLElement>(byId('auth-gate'));
        return gate ? [gate] : [];
      }
      if (overlay) {
        // RNW keeps aria-modal on inactive portals, but only the active one has role=dialog.
        const modal = document.querySelector<HTMLElement>('[aria-modal="true"][role="dialog"]');
        const pane = modal?.querySelector<HTMLElement>(byId(overlay.type === 'watch' || overlay.type === 'channel' ? 'projection-room' : 'tv-dialog'));
        return pane ? [pane] : [];
      }
      if (document.querySelector(dialogSelector)) return [];
      const route = document.querySelector<HTMLElement>(byId(routes[path] ?? 'tv-home'));
      const nav = document.querySelector<HTMLElement>(byId('tv-navigation'));
      return [route, nav].filter((r): r is HTMLElement => !!r);
    }
    function stops() { return roots().flatMap(r => Array.from(r.querySelectorAll<HTMLElement>(controls)).filter(eligible).map(describe)); }
    function within(el: HTMLElement) { return el.matches(controls) && eligible(el) && roots().some(r => r.contains(el)); }
    function reconcile() {
      frame = 0;
      if (!initial && document.activeElement instanceof HTMLElement && within(document.activeElement)) return;
      const items = stops();
      // Prioritize an actual content action over navigation/dismissal and avoid opening a keyboard.
      const rank = (n: ReturnType<typeof describe>) => n.preferred ? 0 : n.el.matches('[data-testid^="tv-title-"]') ? 1
        : n.el.closest(byId('tv-navigation')) || /^(fermer|retour|supprimer|effacer|déconnexion)/i.test(n.key) ? 4 : n.el.matches('input,textarea') ? 3 : 2;
      const next = memory.current.restore(scope, items.sort((a,b) => rank(a)-rank(b)));
      if (next && move(next.el)) { initial = false; memory.current.remember(scope, next); }
    }
    function schedule() { if (!frame) frame = requestAnimationFrame(reconcile); }
    function revealed(e: TransitionEvent) {
      // The portal can still have computed opacity 0 on the frame after RNW
      // changes its class. The CSS transition then finishes without a DOM mutation.
      if (initial && e.propertyName === 'opacity' && e.target instanceof Element && roots().some(r => (e.target as Element).contains(r))) schedule();
    }
    function track(e: Event) {
      const el = e.target instanceof HTMLElement ? e.target.closest<HTMLElement>(controls) : null;
      if (!initial && el && within(el)) memory.current.remember(scope, describe(el));
      else if (overlay) schedule();
    }
    function key(e: KeyboardEvent) {
      if (e.isComposing || e.defaultPrevented || e.metaKey || e.altKey || e.ctrlKey) return;
      const el = document.activeElement as HTMLElement | null;
      // RNW Modal owns Escape on keyup, including the player menu's layered Back.
      if (e.key === 'Escape' && !entry && !overlay && path !== '/') { e.preventDefault(); if (router.canGoBack()) router.back(); else router.replace('/'); return; }
      // Browser checkboxes toggle on Space, not Enter. All buttons retain RNW's single activation.
      if (e.key === 'Enter' && el?.matches('input[type="checkbox"]') && within(el)) { e.preventDefault(); if (!e.repeat) el.click(); return; }
      if (!/^Arrow(Up|Down|Left|Right)$/.test(e.key)) return;
      const horizontal = e.key === 'ArrowLeft' || e.key === 'ArrowRight';
      if (el?.matches('select,textarea,[contenteditable="true"]') || (horizontal && el?.matches('input:not([type="checkbox"]):not([type="radio"]),[role="slider"]'))) return;
      if (el?.closest(`${byId('reader-drawer')},${byId('player-settings-drawer')}`)) return;
      if (el?.matches(byId('film-stage')) && (horizontal || e.key === 'ArrowDown')) return;
      const items = stops(), current = items.find(n => n.el === el);
      e.preventDefault(); e.stopPropagation();
      if (!current) { reconcile(); return; }
      const link = current.el.getAttribute(`data-tv-${e.key.slice(5).toLowerCase()}`);
      let next = link ? items.find(n => n.el.dataset.testid === link || n.el.dataset.tvAlias === link) : undefined;
      if (!next && !entry && !overlay && horizontal) {
        const railSelector = byId('tv-navigation');
        const rail = items.filter(n => n.el.closest(railSelector));
        const scene = items.filter(n => !n.el.closest(railSelector));
        if (rail.includes(current) && e.key === 'ArrowRight') {
          // The open rail visually overlaps the first column. Search from its icon edge,
          // not from the end of the overlaid label. Only current-route roots are eligible.
          const { left, top, bottom } = current.rect;
          next = neighbor({ left, right: left + 1, top, bottom }, scene, 'ArrowRight') ?? scene[0];
        } else if (scene.includes(current) && e.key === 'ArrowLeft') {
          const row = scene.filter(n => Math.min(n.rect.bottom, current.rect.bottom) - Math.max(n.rect.top, current.rect.top) > 1);
          next = neighbor(current.rect, row, 'ArrowLeft') ?? rail.find(n => n.el.getAttribute('aria-selected') === 'true' || n.el.getAttribute('aria-pressed') === 'true');
        }
      }
      if (!next && !link) next = neighbor(current.rect, items, e.key as Direction);
      if (next && next.el !== el) move(next.el);
    }
    // Window capture arbitrates the D-pad before the room's document shortcuts and range handler.
    window.addEventListener('keydown', key, true);
    document.addEventListener('focusin', track); document.addEventListener('click', track, true);
    document.addEventListener('transitionend', revealed);
    const changes = new MutationObserver(schedule);
    // RNW mounts a portal with an opacity:0 CSS class, then replaces the class
    // without changing inline styles. Wait for that visibility change rather
    // than treating the framework's transient focus on Close as the entry stop.
    changes.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['class','role','aria-hidden','aria-disabled','disabled','hidden','inert','tabindex','data-tv-initial','style'] });
    // A remote press immediately after opening must already start in this visit,
    // not on the close button transiently chosen by RNW's generic modal trap.
    // The observer and one frame also cover later portal/route attachments.
    reconcile(); schedule();
    return () => { changes.disconnect(); cancelAnimationFrame(frame); document.removeEventListener('transitionend', revealed); document.removeEventListener('focusin', track); document.removeEventListener('click', track, true); window.removeEventListener('keydown', key, true); };
  }, [tv, overlay, path, entry, entryPhase]);
  return null;
}
export default TvFocus;
