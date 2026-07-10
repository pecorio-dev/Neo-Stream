# ── Neo-Stream — R8 / ProGuard ─────────────────────────────────────────
# R8 full mode activé (android.enableR8.fullMode=true par défaut sur AGP 8).
# Flutter conserve automatiquement le code dart→native via ses propres règles ;
# on ne garde ici que les bibliothèques externes à réflexion/natives.

# ── Flutter core (généré par Flutter, rappelé par sécurité) ────────────
-dontwarn io.flutter.embedding.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }

# ── media_kit (libmpvia / mpv bindings natifs) ─────────────────────────
-keep class com.media_kit.** { *; }
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.media_kit.**
-dontwarn com.alexmercerind.**

# ── jniust / packages utilisant MethodChannel + réflexion ──────────────
-keep class com.rtoshiro.fullscreen.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# ── Plugins Flutter courants (sécurité reflection) ──────────────────────
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── flutter_secure_storage (bon package name) ──────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── http package (network) ────────────────────────────────────────────
-dontwarn dart.**
-dontwarn io.flutter.**

# ── WakelockPlus ──────────────────────────────────────────────────────
-keep class creativemaybeno.wakelockplus.** { *; }
-dontwarn creativemaybeno.wakelockplus.**
