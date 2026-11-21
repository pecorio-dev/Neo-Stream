export type AsciiVariant = 'interference' | 'fold' | 'trace';

const palette = ['#54424F', '#A26E72', '#BE8C80', '#FFBD94', '#628F86', '#92DECA'] as const;
const cache = new Map<AsciiVariant, ReturnType<typeof compose>>();
const turn = 2 * Math.PI;

// A projected trefoil with a twisted, flattened cross-section. Each cell keeps
// only the nearest surface, so the ribbons pass in front of and behind one another.
function compose(variant: AsciiVariant) {
  const trace = variant === 'trace';
  const fold = variant === 'fold';
  const columns = 104;
  const rows = trace ? 11 : fold ? 39 : 47;
  const cells = new Uint8Array(columns * rows);
  const inks = new Uint8Array(cells.length);
  const depths = new Float32Array(cells.length).fill(-Infinity);

  function put(x: number, y: number, symbol: string, ink: number, depth = -16) {
    if (x < 0 || x >= columns || y < 0 || y >= rows) return;
    const index = y * columns + x;
    if (depth < depths[index]) return;
    cells[index] = symbol.charCodeAt(0);
    inks[index] = ink;
    depths[index] = depth;
  }

  const center = trace ? .49 : fold ? .54 : .37;
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < columns; x++) {
      const u = x / columns - center, v = y / rows - .5;
      const jitter = ((Math.imul(x + 19, 1103515245) ^ Math.imul(y + 41, 73244475)) >>> 17) % 101;
      if (trace) {
        // Variable-area optical print: two folded outlines with finer engraved
        // hatching at the crossings. A static graphic, not a live audio meter.
        const phase = 16 * u + .9 * Math.sin(10 * u);
        const ridge = .25 * Math.sin(phase) + .08 * Math.sin(3 * phase + .75);
        const mirror = -.67 * ridge + .11 * Math.cos(phase * .62);
        const a = Math.abs(v - ridge), b = Math.abs(v - mirror);
        if (a < .059) put(x, y, Math.cos(phase) < 0 ? '/' : '\\', 3);
        else if (b < .058) put(x, y, a < .15 ? '+' : ':', 5);
        else if ((v - ridge) * (v - mirror) < 0) {
          const hatch = (x + 2 * y) % 7;
          if (hatch < 4) put(x, y, '.:-='[hatch], hatch === 0 ? 2 : 4);
        } else if ((a < .16 || b < .16) && jitter > 67) put(x, y, '.', 0);
        continue;
      }
      // Broken diffraction lines are denser at the intersections, not a uniform noise fill.
      const r = Math.hypot(u * 1.64 + v * .32, v * 1.03);
      const wave = Math.abs(Math.sin(51 * r + 1.2 * Math.sin(24 * u - 13 * v)));
      const edge = Math.max(0, 1 - r * 1.65);
      if (wave < .16 && jitter < 64 * edge) put(x, y, jitter % 4 ? '.' : ':', 0);
      else if (edge > .3 && jitter > 98) put(x, y, '.', 0);
    }
  }

  if (!trace) {
    const tilt = fold ? .94 : .69;
    const spin = fold ? -.38 : -.62;
    const ct = Math.cos(tilt), st = Math.sin(tilt), cs = Math.cos(spin), ss = Math.sin(spin);
    const ramp = '.:-=+*#%@';
    for (let i = 0; i < 440; i++) {
      const t = i / 440 * turn;
      const a = 2 * t, b = 3 * t;
      const ca = Math.cos(a), sa = Math.sin(a), cb = Math.cos(b), sb = Math.sin(b);
      const radius = 1.08 + .48 * cb;
      const lift = .72 * sb;
      const twist = 1.5 * t + .43 * Math.sin(b);
      const c = Math.cos(twist), s = Math.sin(twist);
      for (let j = 0; j < 22; j++) {
        const q = j / 22 * turn;
        const wide = (.25 + .09 * cb) * Math.cos(q), thin = .075 * Math.sin(q);
        const offset = wide * c - thin * s;
        const z = lift + wide * s + thin * c;
        const x = (radius + offset) * ca, y = (radius + offset) * sa;
        const above = ct * y - st * z;
        const depth = st * y + ct * z;
        const sx = x * cs - above * ss, sy = x * ss + above * cs;
        const scale = 1 + .135 * depth;
        const gx = Math.round(center * columns + sx * scale * (fold ? 29 : 25));
        const gy = Math.round(rows * .5 + sy * scale * rows * (fold ? .27 : .255));
        const lobe = .5 + .5 * Math.cos(q + twist - .48);
        const glint = .5 + .5 * Math.cos(2 * t + q);
        const light = Math.max(0, Math.min(1, .08 + .48 * lobe + .28 * glint + .12 * depth));
        const warm = Math.sin(t + .62) > -.2;
        const ink = light > .56 ? (warm ? 3 : 5) : (warm ? 2 : 4);
        const mark = (i + 7 * j) % 19;
        const symbol = light > .7 && mark < 4 ? (sx < sy ? '/' : '\\') : ramp[Math.min(8, Math.floor(light * 9))];
        put(gx, gy, symbol, ink, depth);
      }
    }
  }

  const layers = palette.flatMap((color, ink) => {
    const lines: string[] = [];
    let used = false;
    for (let y = 0; y < rows; y++) {
      let line = '';
      for (let x = 0; x < columns; x++) {
        const index = y * columns + x;
        const lit = inks[index] === ink && cells[index] !== 0;
        line += lit ? String.fromCharCode(cells[index]) : ' ';
        if (lit) used = true;
      }
      lines.push(line.trimEnd());
    }
    // Keep interior blank lines while removing unused cells from the text payload.
    return used ? [{ color, text: lines.join('\n').trimEnd() }] : [];
  });
  return { columns, rows, layers };
}

export function asciiComposition(variant: AsciiVariant) {
  const previous = cache.get(variant);
  if (previous) return previous;
  const next = compose(variant);
  cache.set(variant, next);
  return next;
}
