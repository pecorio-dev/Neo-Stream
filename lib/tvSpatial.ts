/** Directional selection uses viewport coordinates (dp or CSS px), never DOM order wrapping. */
export type Box = { left: number; top: number; right: number; bottom: number };
export type Direction = 'ArrowLeft' | 'ArrowRight' | 'ArrowUp' | 'ArrowDown';
export type Stop = { key: string; rect: Box; disabled?: boolean; preferred?: boolean };

/** One native request. Separate the reset from the request so Fabric cannot batch away true. */
export function pulsePreference(set: (value: boolean) => void, afterCommit: (release: () => void) => void) {
  set(true);
  afterCommit(() => set(false));
}

/** One native Modal host, possibly several successive dialog scopes. */
export class ModalFocusGate {
  private host: object | null = null;
  private shown = false;
  private pending?: () => void;
  open(host: object) { this.host = host; }
  close(host: object) {
    if (this.host !== host) return;
    this.host = null; this.shown = false; this.pending = undefined;
  }
  show(host: object) {
    if (this.host !== host) return;
    this.shown = true;
    const run = this.pending; this.pending = undefined; run?.();
  }
  whenShown(run: () => void) {
    if (this.shown) run(); else this.pending = run;
    return () => { if (this.pending === run) this.pending = undefined; };
  }
}
export const androidTvModal = new ModalFocusGate();
const valid = (n: Stop) => !n.disabled && n.rect.right > n.rect.left && n.rect.bottom > n.rect.top;
const mid = (a: number, b: number) => (a + b) / 2;

export function neighbor<T extends Stop>(from: Box, nodes: readonly T[], direction: Direction): T | undefined {
  const horizontal = direction === 'ArrowLeft' || direction === 'ArrowRight';
  const reverse = direction === 'ArrowLeft' || direction === 'ArrowUp';
  function axes(r: Box) {
    const [a,b,c,d] = horizontal ? [r.left,r.right,r.top,r.bottom] : [r.top,r.bottom,r.left,r.right];
    return reverse ? [-b,-a,c,d] : [a,b,c,d];
  }
  const [a,b,c,d] = axes(from);
  let best: T | undefined, bestBeam = false, bestScore = Infinity;
  for (const node of nodes) {
    if (!valid(node)) continue;
    const [x,y,u,v] = axes(node.rect);
    if (x < a - 1 || y <= b + 1 || mid(x,y) <= mid(a,b)) continue;
    const beam = Math.min(d,v) - Math.max(c,u) > 1;
    const score = 9 * Math.max(0, x-b)**2 + (mid(c,d)-mid(u,v))**2 + .01 * (x-a)**2;
    if ((!bestBeam && beam) || (beam === bestBeam && score < bestScore)) {
      best = node; bestScore = score; bestBeam = beam;
    }
  }
  return best;
}

/** Store semantic snapshots, never a stale host/DOM ref. Object scope keys are overlay stack entries. */
export class FocusMemory {
  private pages = new Map<string, Stop>();
  private dialogs = new WeakMap<object, Stop>();
  remember(scope: string | object, n: Stop) {
    const snapshot = { key: n.key, rect: { left: n.rect.left, right: n.rect.right, top: n.rect.top, bottom: n.rect.bottom } };
    if (typeof scope === 'string') this.pages.set(scope, snapshot); else this.dialogs.set(scope, snapshot);
  }
  restore<T extends Stop>(scope: string | object, nodes: readonly T[]): T | undefined {
    const saved = typeof scope === 'string' ? this.pages.get(scope) : this.dialogs.get(scope);
    const enabled = nodes.filter(valid);
    if (!saved) return enabled.find(n => n.preferred) ?? enabled[0];
    const same = enabled.filter(n => n.key === saved.key);
    const distance = ({ rect: r }: Stop) => (r.left-saved.rect.left)**2 + (r.top-saved.rect.top)**2;
    return (same.length ? same : enabled).reduce<T | undefined>((best,n) => !best || distance(n) < distance(best) ? n : best, undefined);
  }
}
