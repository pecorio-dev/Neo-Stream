const fs = require('node:fs/promises');
const path = require('node:path');
const { AndroidConfig, withAndroidManifest, withDangerousMod } = require('expo/config-plugins');

const MAIN = 'android.intent.action.MAIN';
const LAUNCHER = 'android.intent.category.LAUNCHER';
const LEANBACK = 'android.intent.category.LEANBACK_LAUNCHER';
const VIEW = 'android.intent.action.VIEW';
const DEFAULT = 'android.intent.category.DEFAULT';
const BROWSABLE = 'android.intent.category.BROWSABLE';
const BANNER = 'neo_stream_tv_banner';

function hasName(elements, name) {
  return elements?.some((element) => element.$?.['android:name'] === name);
}

function isolateSchemesFromVerifiedLinks(mod, filters) {
  const customSchemes = new Set([
    ...AndroidConfig.Scheme.getScheme(mod),
    ...AndroidConfig.Scheme.getScheme(mod.android ?? {}),
  ].filter(scheme => scheme !== 'http' && scheme !== 'https'));
  const isSchemeOnly = (data, scheme) =>
    data.$?.['android:scheme'] === scheme && Object.keys(data.$).length === 1;
  const moved = new Set();

  // Expo 57 can append configured schemes to an existing VIEW filter. Verified
  // Android App Links must only use HTTP(S); keep those filters intact.
  for (const filter of filters) {
    if (filter.$?.['android:autoVerify'] !== 'true' || !hasName(filter.action, VIEW)) continue;
    if (!filter.data?.some(data => ['http', 'https'].includes(data.$?.['android:scheme']))) continue;
    filter.data = filter.data.filter(data => {
      const scheme = data.$?.['android:scheme'];
      if (!customSchemes.has(scheme) || !isSchemeOnly(data, scheme)) return true;
      moved.add(scheme);
      return false;
    });
  }
  for (const scheme of moved) {
    if (filters.some(filter => filter.data?.length === 1 && isSchemeOnly(filter.data[0], scheme) &&
      hasName(filter.action, VIEW) && hasName(filter.category, DEFAULT) && hasName(filter.category, BROWSABLE))) continue;
    filters.push({
      action: [{ $: { 'android:name': VIEW } }],
      category: [DEFAULT, BROWSABLE].map(name => ({ $: { 'android:name': name } })),
      data: [{ $: { 'android:scheme': scheme } }],
    });
  }
}

module.exports = function withAndroidTv(config) {
  config = withAndroidManifest(config, (mod) => {
    const manifest = mod.modResults.manifest;
    const application = AndroidConfig.Manifest.getMainApplicationOrThrow(mod.modResults);
    const activity = AndroidConfig.Manifest.getMainActivityOrThrow(mod.modResults);
    const filters = activity['intent-filter'] ??= [];
    isolateSchemesFromVerifiedLinks(mod, filters);

    // Keep launcher filters independent of data-bearing URL filters.
    for (const category of [LAUNCHER, LEANBACK]) {
      if (!filters.some((filter) => hasName(filter.action, MAIN) && hasName(filter.category, category) && !filter.data?.length)) {
        filters.push({
          action: [{ $: { 'android:name': MAIN } }],
          category: [{ $: { 'android:name': category } }],
        });
      }
    }
    activity.$['android:exported'] = 'true';
    application.$['android:banner'] = `@drawable/${BANNER}`;

    const features = (manifest['uses-feature'] ??= []);
    for (const name of ['android.software.leanback', 'android.hardware.touchscreen']) {
      const [first, ...duplicates] = features.filter((feature) => feature.$?.['android:name'] === name);
      if (first) {
        first.$['android:required'] = 'false';
        for (const duplicate of duplicates) features.splice(features.indexOf(duplicate), 1);
      } else {
        features.push({ $: { 'android:name': name, 'android:required': 'false' } });
      }
    }
    return mod;
  });

  // A file asset has no structured Android mod; copying the same bytes is idempotent.
  return withDangerousMod(config, ['android', async (mod) => {
    const { platformProjectRoot, projectRoot } = mod.modRequest;
    const asset = `assets/brand/${BANNER}.png`;
    const target = path.join(platformProjectRoot, 'app/src/main/res/drawable-xhdpi');
    const bytes = await fs.readFile(path.join(projectRoot, asset)).catch((error) => {
      if (error.code !== 'ENOENT') throw error;
      throw new Error(`Missing Android TV banner: ${asset} (320×180 PNG, xhdpi).`, { cause: error });
    });
    await fs.mkdir(target, { recursive: true });
    await fs.writeFile(path.join(target, `${BANNER}.png`), bytes);
    return mod;
  }]);
};
