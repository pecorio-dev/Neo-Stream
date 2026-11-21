type Level = { height: number; audioGroups?: (string | undefined)[] };
type Rendition = { lang?: string; name: string; characteristics?: string; forced: boolean; trackNode?: { track: TextTrack } };
export type WebSubtitle = { kind: 'hls'; track: Rendition } | { kind: 'html'; track: TextTrack } | { kind: 'off' };

const heightKey = (height: number) => `height:${height}`;
export function qualityChoices(levels: readonly Level[], manualLevel: number, audioGroup?: string) {
  const byHeight = new Map<number, number>();
  levels.forEach(({ height, audioGroups }, i) => {
    if (!Number.isInteger(height) || height <= 0 || height > 16384) return;
    const previous = byHeight.get(height);
    if (previous === undefined || (audioGroup !== undefined && audioGroups?.includes(audioGroup) && !levels[previous].audioGroups?.includes(audioGroup))) byHeight.set(height, i);
  });
  // A sole representation is not an adjustable resolution.
  const entries = byHeight.size > 1 ? [
    { key: 'auto', label: 'Auto', value: -1 },
    ...[...byHeight].sort(([a], [b]) => b - a).map(([height, index]) => ({ key: heightKey(height), label: `${height}p`, value: index })),
  ] : [];
  const selected = manualLevel === -1 ? 'auto' : levels[manualLevel] ? heightKey(levels[manualLevel].height) : null;
  return { entries, selected };
}

export function htmlSubtitles(list: ArrayLike<TextTrack> | undefined, hlsRenditions: readonly Rendition[]) {
  const managed = new Set(hlsRenditions.map(t => t.trackNode?.track));
  return Array.from(list ?? []).filter(t => (t.kind === 'captions' || t.kind === 'subtitles') && !managed.has(t));
}

export function subtitleChoices(renditions: readonly Rendition[], html: readonly TextTrack[], hlsIndex: number,
  keyFor: (track: object) => string, languageName: (value: unknown) => string | undefined) {
  const entries: { key: string; label: string; value: WebSubtitle }[] = [];
  renditions.forEach(track => entries.push({ key: keyFor(track), label: languageName(track.lang) ?? `Piste ${entries.length + 1}`, value: { kind: 'hls', track } }));
  html.forEach(track => entries.push({ key: keyFor(track), label: languageName(track.language) ?? `Piste ${entries.length + 1}`, value: { kind: 'html', track } }));
  const counts = new Map<string, number>();
  for (const { label } of entries) counts.set(label, (counts.get(label) ?? 0) + 1);
  const ordinal = new Map<string, number>();
  for (const entry of entries) {
    const { label } = entry;
    if ((counts.get(label) ?? 0) < 2) continue;
    const n = (ordinal.get(label) ?? 0) + 1;
    ordinal.set(label, n);
    entry.label = `${label} · ${n}`;
  }
  const current = html.find(t => t.mode === 'showing') ?? renditions[hlsIndex];
  if (entries.length) entries.unshift({ key: 'off', label: 'Désactivés', value: { kind: 'off' } });
  return { entries, selected: current ? keyFor(current) : 'off' };
}

/** Prefer exact identity, then a uniquely equivalent rendition across groups. */
export function matchingRendition(renditions: readonly Rendition[], requested: Rendition) {
  const exact = renditions.indexOf(requested);
  if (exact >= 0) return exact;
  const same = (track: Rendition) => track.lang === requested.lang && track.name === requested.name &&
    track.characteristics === requested.characteristics && track.forced === requested.forced;
  const match = renditions.findIndex(same);
  return match >= 0 && !renditions.slice(match + 1).some(same) ? match : -1;
}
