#!/bin/bash
set -e

VERSION="1.4.0"
APP_DIR="/tmp/Neo-Stream.AppDir"
BUILD_DIR="/home/pecorio/neo-iptv-stream/app/app/build/linux/x64/release/bundle"
ICON_SRC="/home/pecorio/neo-iptv-stream/app/app/assets/icon.png"
OUT_DIR="/home/pecorio/neo-iptv-stream"

echo "=== Préparation AppDir ==="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"

echo "=== Copie des fichiers de l'application ==="
cp -r "$BUILD_DIR"/* "$APP_DIR/usr/bin/"
# L'exécutable principal reste dans bin
# Les bibliothèques et flutter_assets sont aussi dans le bundle

echo "=== Icône ==="
cp "$ICON_SRC" "$APP_DIR/usr/share/icons/hicolor/256x256/apps/neo-stream.png"
cp "$ICON_SRC" "$APP_DIR/neo-stream.png"

echo "=== Fichier .desktop ==="
cat > "$APP_DIR/neo-stream.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Neo Stream
Comment=IPTV & Streaming Platform
Exec=neo_stream
Icon=neo-stream
Terminal=false
Type=Application
Categories=Video;AudioVideo;Player;TV;
Keywords=iptv;streaming;tv;video;
DESKTOP
cp "$APP_DIR/neo-stream.desktop" "$APP_DIR/usr/share/applications/"

echo "=== AppRun ==="
cat > "$APP_DIR/AppRun" <<'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$LD_LIBRARY_PATH"
exec "$HERE/usr/bin/neo_stream" "$@"
APPRUN
chmod +x "$APP_DIR/AppRun"

echo "=== Génération AppImage ==="
ARCH=x86_64 /tmp/opencode/appimagetool --appimage-extract-and-run "$APP_DIR" \
    "$OUT_DIR/Neo-Stream_${VERSION}_x86_64.AppImage"

echo "=== AppImage créée : $OUT_DIR/Neo-Stream_${VERSION}_x86_64.AppImage ==="
ls -lh "$OUT_DIR/Neo-Stream_${VERSION}_x86_64.AppImage"
