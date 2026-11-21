import React from 'react';
import type { RangeProps } from './TransportRange';
import { clamp } from './playerTypes';

/** A semantic range underneath our track and thumb; pointer capture, AT and keyboard work without browser video chrome. */
export default function TransportRange({ label, value, max, step, readValue, describe, onPreview, onCommit }: RangeProps) {
  const percent = max ? 100 * clamp(value / max, 1) : 0;
  return <div style={{ flex: 1, position: 'relative', height: '100%', minHeight: 30, display: 'flex', alignItems: 'center' }}>
    <div aria-hidden style={{ width: '100%', height: 3, background: '#585858', borderRadius: 2 }}>
      <div style={{ height: '100%', width: `${percent}%`, background: '#F4F4F1' }} />
    </div>
    <div aria-hidden style={{ position: 'absolute', left: `clamp(0px, calc(${percent}% - 5px), calc(100% - 10px))`, width: 10, height: 10, borderRadius: '50%', background: '#fff' }} />
    <input type="range" className="neo-transport-range" aria-label={label} aria-valuetext={describe(value)} min={0} max={max} step="any" value={clamp(value, max)}
      onPointerDown={e => { e.currentTarget.setPointerCapture(e.pointerId); onPreview(Number(e.currentTarget.value)); }}
      onChange={e => { const n = Number(e.currentTarget.value); onPreview(n); }}
      onPointerUp={e => { onCommit(Number(e.currentTarget.value)); onPreview(null); }} onPointerCancel={() => onPreview(null)} onBlur={() => onPreview(null)}
      onKeyDown={e => { const delta: Record<string, number> = { ArrowRight: step, ArrowUp: step, ArrowLeft: -step, ArrowDown: -step, PageUp: 10 * step, PageDown: -10 * step, Home: -max, End: max };
        if (e.key in delta) { e.preventDefault(); e.stopPropagation(); onCommit(clamp((readValue?.() ?? value) + delta[e.key], max)); onPreview(null); } }}
      style={{ position: 'absolute', inset: 0, cursor: 'pointer', width: '100%', height: '100%', opacity: 0, margin: 0 }} />
    <style>{'div:has(> .neo-transport-range:focus-visible){outline:2px solid #fff;outline-offset:2px;border-radius:5px}'}</style>
  </div>;
}
