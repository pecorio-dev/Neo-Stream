export type ObservedSourceInfo = {
  audioLanguages?: string[];
  subtitleLanguages?: string[];
  qualities?: number[];
};

type Version = 'VF' | 'VFF' | 'VFQ' | 'VO' | 'VOSTFR' | 'MULTI';
type InterlacedQuality = `${number}i`;
type Quality = number | 'Auto' | 'SD' | 'HD' | InterlacedQuality;

const MAX_LIST = 64;
const VERSIONS = new Set<string>(['VF', 'VFF', 'VFQ', 'VO', 'VOSTFR', 'MULTI']);
const HEIGHTS = new Set([144, 240, 288, 360, 480, 540, 576, 720, 900, 1080, 1440, 2160, 2880, 4320]);

// Use controlled French names even on runtimes without Intl.DisplayNames.
const LANGUAGES = new Map<string, string>();
const LANGUAGE_NAMES = new Map<string, string>();
for (const [name, codes, aliases] of [
  ['français', 'fr fra fre', 'french francais'],
  ['anglais', 'en eng', 'english'],
  ['espagnol', 'es spa', 'spanish español espanol castillan'],
  ['allemand', 'de deu ger', 'german deutsch'],
  ['italien', 'it ita', 'italian italiano'],
  ['portugais', 'pt por', 'portuguese português portugues'],
  ['japonais', 'ja jpn', 'japanese'],
  ['coréen', 'ko kor', 'korean coreen'],
  ['chinois', 'zh zho chi', 'chinese'],
  ['mandarin', 'cmn', ''],
  ['cantonais', 'yue', 'cantonese'],
  ['arabe', 'ar ara', 'arabic'],
  ['russe', 'ru rus', 'russian'],
  ['ukrainien', 'uk ukr', 'ukrainian'],
  ['néerlandais', 'nl nld dut', 'dutch neerlandais'],
  ['polonais', 'pl pol', 'polish'],
  ['turc', 'tr tur', 'turkish'],
  ['hindi', 'hi hin', ''],
  ['bengali', 'bn ben', 'bangla'],
  ['tamoul', 'ta tam', 'tamil'],
  ['télougou', 'te tel', 'telugu telougou'],
  ['ourdou', 'ur urd', 'urdu'],
  ['persan', 'fa fas per', 'persian farsi'],
  ['hébreu', 'he heb iw', 'hebrew hebreu'],
  ['grec', 'el ell gre', 'greek'],
  ['tchèque', 'cs ces cze', 'czech tcheque'],
  ['slovaque', 'sk slk slo', 'slovak'],
  ['hongrois', 'hu hun', 'hungarian'],
  ['roumain', 'ro ron rum', 'romanian'],
  ['bulgare', 'bg bul', 'bulgarian'],
  ['serbe', 'sr srp', 'serbian'],
  ['croate', 'hr hrv', 'croatian'],
  ['bosnien', 'bs bos', 'bosnian'],
  ['suédois', 'sv swe', 'swedish suedois'],
  ['danois', 'da dan', 'danish'],
  ['norvégien', 'no nor', 'norwegian norvegien'],
  ['norvégien bokmål', 'nb nob', 'bokmål bokmal'],
  ['norvégien nynorsk', 'nn nno', 'nynorsk'],
  ['finnois', 'fi fin', 'finnish'],
  ['islandais', 'is isl ice', 'icelandic'],
  ['thaï', 'th tha', 'thai'],
  ['vietnamien', 'vi vie', 'vietnamese'],
  ['indonésien', 'id ind in', 'indonesian indonesien'],
  ['malais', 'ms msa may', 'malay'],
  ['tagalog', 'tl tgl', ''],
  ['filipino', 'fil', ''],
  ['catalan', 'ca cat', 'català catala'],
  ['basque', 'eu eus baq', 'euskara'],
  ['galicien', 'gl glg', 'galician'],
  ['slovène', 'sl slv', 'slovenian slovene'],
  ['lituanien', 'lt lit', 'lithuanian'],
  ['letton', 'lv lav', 'latvian'],
  ['estonien', 'et est', 'estonian'],
  ['swahili', 'sw swa', ''],
]) {
  const [code, ...synonyms] = codes.split(' ');
  LANGUAGE_NAMES.set(code, name);
  for (const alias of [code, ...synonyms, name, ...aliases.split(' ').filter(Boolean)]) {
    LANGUAGES.set(alias, code);
  }
}

const REGIONS = new Map(Object.entries({
  '001': 'monde', '419': 'Amérique latine', ae: 'Émirats arabes unis', ar: 'Argentine', at: 'Autriche',
  au: 'Australie', be: 'Belgique', bg: 'Bulgarie', br: 'Brésil', ca: 'Canada', ch: 'Suisse', cl: 'Chili',
  cn: 'Chine', co: 'Colombie', cz: 'Tchéquie', de: 'Allemagne', dk: 'Danemark', dz: 'Algérie',
  eg: 'Égypte', es: 'Espagne', fi: 'Finlande', fr: 'France', gb: 'Royaume-Uni', gr: 'Grèce',
  hk: 'Hong Kong', hr: 'Croatie', hu: 'Hongrie', id: 'Indonésie', ie: 'Irlande', il: 'Israël',
  in: 'Inde', it: 'Italie', jp: 'Japon', kr: 'Corée du Sud', lu: 'Luxembourg', ma: 'Maroc',
  mo: 'Macao', mx: 'Mexique', my: 'Malaisie', nl: 'Pays-Bas', no: 'Norvège', nz: 'Nouvelle-Zélande',
  pe: 'Pérou', ph: 'Philippines', pk: 'Pakistan', pl: 'Pologne', pt: 'Portugal', ro: 'Roumanie',
  rs: 'Serbie', ru: 'Russie', sa: 'Arabie saoudite', se: 'Suède', sg: 'Singapour', sk: 'Slovaquie',
  th: 'Thaïlande', tn: 'Tunisie', tr: 'Turquie', tw: 'Taïwan', ua: 'Ukraine', us: 'États-Unis',
  vn: 'Viêt Nam', za: 'Afrique du Sud',
}));
const SCRIPTS = new Map(Object.entries({
  hans: 'simplifié', hant: 'traditionnel', latn: 'latin', cyrl: 'cyrillique', arab: 'arabe',
}));
const LANGUAGE_TITLES = new Map(Object.entries({
  'français (canada)': 'fr-CA', 'français (france)': 'fr-FR',
  'english (us)': 'en-US', 'english (uk)': 'en-GB',
  'portugais (brésil)': 'pt-BR', 'português (brasil)': 'pt-BR',
  'espagnol (amérique latine)': 'es-419', 'español (latinoamérica)': 'es-419',
  'mandarin chinese': 'cmn',
}));

function own(value: unknown, key: string | number): unknown {
  if (value === null || typeof value !== 'object') return undefined;
  try {
    // Ignore inherited properties and accessors, including those inside input arrays.
    return Object.getOwnPropertyDescriptor(value, key)?.value;
  } catch {
    return undefined;
  }
}

function text(value: unknown, max: number): string | undefined {
  if (typeof value !== 'string' || value.length > max || /[\p{Cc}\p{Cf}]/u.test(value)) return undefined;
  return value.trim() || undefined;
}

function list<T>(value: unknown, parse: (item: unknown) => T | undefined): T[] | undefined {
  try {
    if (!Array.isArray(value)) return undefined;
  } catch {
    return undefined;
  }
  const length = own(value, 'length');
  if (typeof length !== 'number' || !Number.isInteger(length) || length < 0 || length > MAX_LIST) return undefined;
  const result = new Set<T>();
  for (let i = 0; i < length; i++) {
    const item = parse(own(value, i));
    if (item !== undefined) result.add(item);
  }
  return [...result];
}

function version(value: unknown): Version | undefined {
  const token = text(value, 16)?.toUpperCase();
  return token && VERSIONS.has(token) ? token as Version : undefined;
}

function language(value: unknown): string | undefined {
  const token = text(value, 48)?.normalize('NFC').toLowerCase();
  if (!token) return undefined;
  const titledCode = LANGUAGE_TITLES.get(token)?.toLowerCase() ?? token;
  const direct = LANGUAGES.get(titledCode);
  if (direct) return LANGUAGE_NAMES.get(direct);

  const locale = /^([a-z]{2,3})(?:[-_]([a-z]{4}))?(?:[-_]([a-z]{2}|\d{3}))?$/.exec(titledCode);
  if (!locale) return undefined;
  const code = LANGUAGES.get(locale[1]);
  const name = code && LANGUAGE_NAMES.get(code);
  const script = SCRIPTS.get(locale[2]);
  const region = REGIONS.get(locale[3]);
  if (!name || (locale[2] && !script) || (locale[3] && !region)) return undefined;
  return `${name}${script ? ` (${script}${region ? `, ${region}` : ''})` : region ? ` (${region})` : ''}`;
}

function trackLanguage(value: unknown): string | undefined {
  return language(value) ?? language(own(value, 'language')) ?? language(own(value, 'lang')) ??
    language(own(value, 'srclang')) ?? language(own(value, 'label'));
}

/** Display a decoder-provided language, never an unchecked track name/URL. */
export const trackLanguageName = language;

function height(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 144 && value <= 4320;
}

function quality(value: unknown, inLabel = false): Quality | undefined {
  const token = text(value, 32)?.toUpperCase();
  // Unqualified values could be a year or bitrate, so accept only standard raster heights.
  if (!inLabel && (typeof value === 'number' || (token && /^\d{3,4}$/.test(token)))) {
    const n = typeof value === 'number' ? value : Number(token);
    return HEIGHTS.has(n) ? n : undefined;
  }
  if (token === 'AUTO') return 'Auto';
  if (token === 'SD' || token === 'HD') return token;
  if (token === 'FHD' || token === 'FULL HD') return 1080;
  if (token === 'UHD' || token === '4K') return 2160;
  if (token === '8K') return 4320;
  const raster = /^([1-9]\d{2,3})(P|I)$/.exec(token ?? '');
  if (raster) {
    const n = Number(raster[1]);
    return height(n) ? raster[2] === 'I' ? `${n}i` : n : undefined;
  }
  const dimensions = /^([1-9]\d{2,3})[ \u00a0]*[X×][ \u00a0]*([1-9]\d{2,3})$/.exec(token ?? '');
  if (dimensions) {
    const width = Number(dimensions[1]);
    const n = Number(dimensions[2]);
    if (height(n) && width >= 144 && width <= 8192 && width / n >= 0.25 && width / n <= 4) return n;
  }
  return undefined;
}

function catalogueQuality(value: unknown): Quality | undefined {
  const declaredHeight = own(value, 'height');
  const heightText = text(declaredHeight, 4);
  const n = heightText && /^[1-9]\d{2,3}$/.test(heightText) ? Number(heightText) : declaredHeight;
  const named = quality(own(value, 'quality')) ?? quality(own(value, 'label'), true);
  // Height has an explicit unit by field contract; a fallback label must be wholly recognizable.
  return quality(value) ?? (height(n) && named !== `${n}i` ? n : named);
}

function tokensInLabel(value: unknown): string[] {
  const label = text(value, 128)?.replace(/\s+\/\s+/gu, ' · ');
  // Reject path, URL, key/value and similar syntax rather than mining apparent tags in it.
  if (!label || /[/\\:.?=#%&@]/u.test(label)) return [];
  const segments = label.split(/[·•|,;()\[\]]|\s+[-–—]\s+/u);
  return segments.flatMap((segment) => {
    const part = segment.trim();
    return quality(part, true) !== undefined ? [part] : part.split(/\s+/u).filter((token) => token.toUpperCase() !== 'AUTO');
  });
}

function distinct<T>(items: (T | undefined)[]): T[] {
  return [...new Set(items.filter((item): item is T => item !== undefined))];
}

function qualityOrder(value: Quality): number {
  return value === 'Auto' ? -3 : value === 'SD' ? -2 : value === 'HD' ? -1 :
    typeof value === 'number' ? value : Number(value.slice(0, -1));
}

function declaredSourceVersion(source: unknown, legacyLanguage: unknown[], labelTokens: string[]): Version | undefined {
  const legacyVersions = distinct(legacyLanguage.map(version));
  const labelVersions = distinct(labelTokens.map(version));
  return version(own(source, 'version')) ?? (
    legacyVersions.length === 1 ? legacyVersions[0] :
      legacyVersions.length === 0 && labelVersions.length === 1 ? labelVersions[0] : undefined
  );
}

/** A version is a catalogue assertion, never an inference from the decoder's audio or subtitles. */
export function sourceVersion(source: unknown): Version | undefined {
  return declaredSourceVersion(source, [own(source, 'lang'), own(source, 'language')], tokensInLabel(own(source, 'label')));
}

/** Describe only this link; a language is not a version and announced subtitles need not be selectable. */
export function describeSource(source: unknown, observed?: ObservedSourceInfo, showMissing = false): string {
  const legacyLanguage = [own(source, 'lang'), own(source, 'language')];
  const labelTokens = tokensInLabel(own(source, 'label'));
  const declaredVersion = declaredSourceVersion(source, legacyLanguage, labelTokens);

  const audio = list(own(source, 'audioLanguages'), language);
  const audioTracks = list(own(source, 'audio_tracks'), trackLanguage);
  const legacyAudio = distinct(legacyLanguage.map(language));
  const audioLanguages = distinct([
    ...(audio?.length ? audio : audioTracks?.length ? audioTracks : legacyAudio.length === 1 ? legacyAudio : []),
    ...(list(own(observed, 'audioLanguages'), language) ?? []),
  ]);

  const qualities = list(own(source, 'qualities'), catalogueQuality);
  const singleQuality = quality(own(source, 'quality'));
  const catalogueQualities = qualities?.length ? qualities : singleQuality !== undefined ? [singleQuality] :
    distinct(labelTokens.map((token) => quality(token, true)));
  const allQualities = distinct([
    ...catalogueQualities,
    // An observed height does not tell us the scan type or contradict an explicit interlaced quality.
    ...(list(own(observed, 'qualities'), (value) => height(value) && !catalogueQualities.includes(`${value}i`) ? value : undefined) ?? []),
  ]).sort((a, b) => qualityOrder(a) - qualityOrder(b));

  const canonicalSubtitles = own(source, 'subtitleLanguages');
  const legacySubtitleInput = own(source, 'subtitles');
  const declaredSubtitles = list(canonicalSubtitles, language);
  const legacySubtitles = list(legacySubtitleInput, trackLanguage);
  // A literal empty list is an assertion; a nonempty list with no usable track is not.
  const explicitNone = own(canonicalSubtitles, 'length') === 0 && declaredSubtitles !== undefined;
  const legacyNone = canonicalSubtitles === undefined && legacySubtitles !== undefined &&
    own(legacySubtitleInput, 'length') === 0;
  const subtitleLanguages = distinct([
    ...(declaredSubtitles?.length || explicitNone ? declaredSubtitles ?? [] : legacySubtitles ?? []),
    ...(list(own(observed, 'subtitleLanguages'), language) ?? []),
  ]);
  const implicitFrench = declaredVersion === 'VOSTFR' &&
    !subtitleLanguages.some((name) => name === 'français' || name.startsWith('français ('));
  if (implicitFrench) subtitleLanguages.unshift('français (peut être incrusté)');

  const parts: string[] = [];
  if (declaredVersion) parts.push(declaredVersion);
  else if (showMissing) parts.push('Version non renseignée');
  if (allQualities.length) parts.push(allQualities.map((q) => typeof q === 'number' ? `${q}p` : q).join(' / '));
  else if (showMissing) parts.push('Qualité non renseignée');
  if (audioLanguages.length) parts.push(`Audio : ${audioLanguages.join(', ')}`);
  parts.push(`Sous-titres : ${subtitleLanguages.length ? subtitleLanguages.join(', ') :
    explicitNone || legacyNone ? 'aucun annoncé' : 'non renseignés'}`);
  return parts.join(' · ');
}
