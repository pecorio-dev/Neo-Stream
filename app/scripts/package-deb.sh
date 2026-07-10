#!/usr/bin/env bash
#
# Empaquette le bundle Flutter Linux en un .deb installable.
#
# Usage : package-deb.sh <version> <bundle_dir>
#   version     — ex. 1.2.0
#   bundle_dir  — ex. build/linux/x64/release/bundle
#
set -euo pipefail

VERSION="${1:?version manquante}"
BUNDLE="${2:?bundle dir manquant}"

if [ ! -d "$BUNDLE" ]; then
  echo "❌ Bundle introuvable : $BUNDLE" >&2
  exit 1
fi

APP_NAME="neo-stream"
PKG_NAME="Neo-Stream"
DEB_ROOT="$(mktemp -d)/${APP_NAME}_${VERSION}_amd64"

# ── Arborescence du paquet ─────────────────────────────────────────────
LIB_DIR="$DEB_ROOT/usr/lib/${APP_NAME}"
BIN_DIR="$DEB_ROOT/usr/bin"
SHARE_DIR="$DEB_ROOT/usr/share/applications"
ICON_DIR="$DEB_ROOT/usr/share/icons/hicolor/256x256/apps"
DOC_DIR="$DEB_ROOT/usr/share/doc/${APP_NAME}"

mkdir -p "$LIB_DIR" "$BIN_DIR" "$SHARE_DIR" "$ICON_DIR" "$DOC_DIR"

# ── Copie du bundle ────────────────────────────────────────────────────
cp -a "$BUNDLE/." "$LIB_DIR/"

# ── Lancer / wrapper ───────────────────────────────────────────────────
cat > "$BIN_DIR/$APP_NAME" <<EOF
#!/bin/sh
exec /usr/lib/$APP_NAME/$APP_NAME "\$@"
EOF
chmod +x "$BIN_DIR/$APP_NAME"

# ── Icône (si présente dans le bundle) ─────────────────────────────────
ICON_SRC="$BUNDLE/data/flutter_assets/assets/icon.png"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$ICON_DIR/$APP_NAME.png"
else
  # Fallback : icône générique depuis le projet.
  cp "$(dirname "$0")/../app/app/assets/icon.png" "$ICON_DIR/$APP_NAME.png" 2>/dev/null || true
fi

# ── Fichier .desktop ───────────────────────────────────────────────────
cat > "$SHARE_DIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Name=$PKG_NAME
Comment=Lecteur de streaming Neo-Stream
Exec=$APP_NAME %U
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=AudioVideo;Video;Player;
EOF

# ── copyright / doc ────────────────────────────────────────────────────
cat > "$DOC_DIR/copyright" <<EOF
$PKG_NAME
Copyright (C) $(date +%Y) pecorio-dev
Licence : propriétaire
EOF

# ── control ────────────────────────────────────────────────────────────
INSTALLED_SIZE="$(du -sk "$LIB_DIR" | cut -f1)"
mkdir -p "$DEB_ROOT/DEBIAN"
cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libglib2.0-0, liblzma5, libstdc++6, libc6
Installed-Size: $INSTALLED_SIZE
Maintainer: pecorio-dev <noreply@github.com>
Description: $PKG_NAME - lecteur de streaming premium
 Application de streaming Neo-Stream pour Linux (films, séries, anime, TV).
EOF

# ── Build du .deb ──────────────────────────────────────────────────────
OUTPUT="$(pwd)/${PKG_NAME}_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$DEB_ROOT" "$OUTPUT"

echo "✅ Paquet créé : $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
