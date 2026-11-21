const MAX_VERSION_CODE = 2_100_000_000;

module.exports = ({ config }) => {
  const env = process.env;
  const release = env.NEO_ANDROID_RELEASE === '1' ||
    (env.EAS_BUILD === 'true' && env.EAS_BUILD_PLATFORM === 'android');
  const versionCode = env.NEO_ANDROID_VERSION_CODE;

  if (release && !versionCode) {
    throw new Error('Android release requires NEO_ANDROID_VERSION_CODE. See docs/ANDROID_RELEASE.md.');
  }

  // One Android application for mobile and TV, including internal test builds.
  if (env.NEO_ANDROID_PACKAGE && env.NEO_ANDROID_PACKAGE !== config.android?.package) {
    throw new Error('NEO_ANDROID_PACKAGE conflicts with the Android package fixed in app.json.');
  }

  if (versionCode && (!/^[1-9]\d*$/.test(versionCode) || Number(versionCode) > MAX_VERSION_CODE)) {
    throw new Error(`NEO_ANDROID_VERSION_CODE must be a decimal integer between 1 and ${MAX_VERSION_CODE}.`);
  }

  return {
    ...config,
    android: {
      ...config.android,
      ...(versionCode ? { versionCode: Number(versionCode) } : {}),
    },
  };
};
