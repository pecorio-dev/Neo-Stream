/** Web previews follow the viewport; the native display's short edge is independent of the keyboard and rotation. */
export function isPhoneLayout(web: boolean, tv: boolean, width: number, height: number): boolean {
  const extent = web ? width : Math.min(width, height);
  return !tv && extent > 0 && extent < 600;
}

/** Only the icon strip participates in TV layout. Revealing its labels never resizes a shelf. */
export function tvRailWidth(available: number) {
  return Math.max(64, Math.min(112, Math.round(available * .072)));
}

export function sceneMetrics(available: number, phone = false, tv = false) {
  const railWidth = tv ? tvRailWidth(available) : phone ? 0 : available >= 1180 ? 212 : available >= 860 ? 84 : 0;
  const contentWidth = Math.max(1, available - railWidth);
  const compact = contentWidth < 600;
  const pad = tv ? Math.max(18, Math.min(52, Math.round(contentWidth * .033)))
    : Math.max(compact ? 16 : contentWidth < 940 ? 28 : 40, (contentWidth - 1480) / 2);
  const inner = Math.max(1, contentWidth - 2 * pad);
  const gap = compact ? 12 : 16;
  const cols = Math.min(7, Math.max(2, Math.floor((inner + gap) / (compact ? 152 : 186))));
  const posterWidth = Math.floor((inner - gap * (cols - 1)) / cols);
  return { railWidth, contentWidth, inner, compact, mobile: !railWidth, pad, gap, cols, posterWidth,
    shelfWidth: compact ? Math.round(Math.min(176, inner * 0.41)) : posterWidth };
}
