import type { PresetBase, Theme } from "./types";

const smoke = { glassTint: 'rgba(15,15,16,.72)', glassEdge: 'rgba(246,246,248,.20)', glassGlint: 'rgba(255,255,255,.14)' };
export const palettes: Record<PresetBase, Theme> = {
  cinema: {
    bg: "#080808", surface: "#151515", elevated: "#272727", border: "#393939",
    text: "#F8F8F6", muted: "#C1C1BF", faint: "#A0A09F", accent: "#F1F1EE",
    onAccent: "#101010", soft: "#333333", danger: "#FFCF98", ...smoke, light: false,
  },
  salon: {
    bg: '#101010', surface: '#1A1A1A', elevated: '#303030', border: '#707070',
    text: '#FFFFFF', muted: '#E9E9E7', faint: '#CCCCCA', accent: '#FFFFFF',
    onAccent: '#080808', soft: '#393939', danger: '#FFCF98', glassTint: 'rgba(22,22,22,.9)',
    glassEdge: 'rgba(255,255,255,.48)', glassGlint: 'rgba(255,255,255,.19)', light: false,
  },
  minuit: {
    bg: "#000000", surface: "#0C0C0C", elevated: "#1D1D1D", border: "#303030",
    text: "#FFFFFF", muted: "#BEBEBC", faint: "#9D9D9C", accent: "#FFFFFF",
    onAccent: "#080808", soft: "#242424", danger: "#FFCF98", ...smoke, glassTint: 'rgba(4,4,4,.84)', light: false,
  },
};
const ink: Theme = {
  bg: '#100D14', surface: '#201924', elevated: '#302631', border: '#4B3D4A',
  text: '#F8F0E9', muted: '#CFBFCB', faint: '#B7A8B6', accent: '#FFC39A',
  onAccent: '#25170F', soft: '#3D2D33', danger: '#FFC3AF', light: false,
  glassTint: '#201924', glassEdge: '#4B3D4A', glassGlint: 'transparent',
};
export const phonePalettes: Record<PresetBase, Theme> = {
  cinema: ink,
  minuit: { ...ink, bg: '#000000', surface: '#151218', elevated: '#231E26', glassTint: '#151218' },
  salon: { ...ink, border: '#857382', glassEdge: '#857382', text: '#FFFFFF', muted: '#EADCE7', faint: '#D5C6D2', accent: '#FFDAAF' },
};
const television: Theme = {
  bg: '#101010', surface: '#191919', elevated: '#2B2B2B', border: '#434343',
  text: '#FAFAF8', muted: '#D1D1CF', faint: '#A9A9A7', accent: '#FFFFFF',
  onAccent: '#111111', soft: '#363636', danger: '#FFC3AE', light: false,
  glassTint: '#191919', glassEdge: '#434343', glassGlint: 'transparent',
};
export const tvPalettes: Record<PresetBase, Theme> = {
  cinema: television,
  minuit: { ...television, bg: '#000000', surface: '#0C0C0C', elevated: '#202020', glassTint: '#0C0C0C' },
  salon: { ...television, border: '#767676', glassEdge: '#767676', text: '#FFFFFF', faint: '#CACAC8' },
};
export const phoneControl = { min: 48, radius: 7, cardRadius: 6 } as const;
export const fonts = {
  regular: "Manrope", medium: "ManropeMedium", semibold: "ManropeSemibold", bold: "ManropeBold",
  extra: "ManropeExtra", display: "BarlowCondensedSemibold",
};
