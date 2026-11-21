import type { DisplayPreset, DisplaySettings, Preferences, PresetBase } from './types';

export const presetBases: DisplayPreset[] = [
  { id: 'cinema', base: 'cinema', name: 'Verre fumé', matte: false },
  { id: 'minuit', base: 'minuit', name: 'Noir OLED', matte: false },
  { id: 'salon', base: 'salon', name: 'Contraste salon', matte: true },
];
export const presetNotes: Record<PresetBase, string> = { cinema: 'Surfaces translucides, reflets argentés.', minuit: 'Fond noir pur, reflets discrets.', salon: 'Surfaces mates, contours plus visibles.' };
export const customLimit = 12;
export const activePreset = (display: DisplaySettings) => [...presetBases, ...display.custom].find(p => p.id === display.selected) ?? presetBases[0];
export const presetName = (s: string) => s.trim().replace(/\s+/g, ' ').slice(0, 32);
export function availableName(s: string, customs: DisplayPreset[]) {
  const n = presetName(s).toLocaleLowerCase('fr');
  return !!n && ![...presetBases, ...customs].some(p => p.name.toLocaleLowerCase('fr') === n);
}
const record = (v: unknown): Record<string, unknown> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, unknown> : {};
/** All display data is device-local. Decode only known keys; discard retired quality/appearance settings. */
export function readPreferences(raw?: unknown, tv = false): Preferences {
  const value = record(raw), display = record(value.display), custom: DisplayPreset[] = [];
  for (const obj of Array.isArray(display.custom) ? display.custom : []) {
    const { id, base, name, matte } = record(obj);
    if (custom.length >= customLimit) break;
    if (typeof id !== 'string' || !/^local-[\w-]{1,56}$/.test(id) || custom.some(p => p.id === id) || typeof name !== 'string' || !availableName(name, custom) || !presetBases.some(p => p.id === base)) continue;
    custom.push({ id, base: base as PresetBase, name: presetName(name), matte: matte === true });
  }
  const fallback = value.appearance === 'minuit' ? 'minuit' : tv ? 'salon' : 'cinema';
  const selected = [...presetBases, ...custom].find(p => p.id === display.selected)?.id ?? fallback;
  return { display: { selected, custom }, history: value.history !== false, rememberSearch: value.rememberSearch !== false, autoplay: value.autoplay !== false };
}
