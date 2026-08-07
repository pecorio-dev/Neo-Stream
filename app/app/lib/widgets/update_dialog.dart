import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../config/neo.dart';
import '../config/tv_config.dart';
import '../models/github_release.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';
import '../utils/semver.dart';

/// Montre la popup de mise à jour disponible.
///
/// [isTV] : si true, utilise le thème sombre TV.
/// Sinon, utilise le thème Neo standard.
void showUpdateDialog(
  BuildContext context, {
  bool isTV = false,
}) {
  final update = context.read<UpdateProvider>();
  final release = update.lastResult?.release;
  if (release == null) return;

  final asset = release.assetForPlatform(UpdateService.currentPlatform);

  if (isTV) {
    _showTVDialog(context, update, release, asset);
  } else {
    _showMobileDialog(context, update, release, asset);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TV Dialog
// ═══════════════════════════════════════════════════════════════════════

void _showTVDialog(
  BuildContext context,
  UpdateProvider update,
  GithubRelease release,
  GithubAsset? asset,
) {
  showDialog(
    context: context,
    builder: (ctx) => ChangeNotifierProvider.value(
      value: update,
      child: _TVUpdateDialog(release: release, asset: asset),
    ),
  );
}

class _TVUpdateDialog extends StatelessWidget {
  final GithubRelease release;
  final GithubAsset? asset;

  const _TVUpdateDialog({required this.release, required this.asset});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: TVTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: TVTheme.accentRed.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: TVTheme.accentRed.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: TVTheme.heroGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: TVTheme.accentRed.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.white,
                size: 32,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),

            // ── Title ──
            const Text(
              'Mise à jour disponible',
              style: TextStyle(
                color: TVTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            // ── Version badge ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TVTheme.accentRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TVTheme.accentRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded,
                          color: TVTheme.accentRed, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'v${release.version}',
                        style: const TextStyle(
                          color: TVTheme.accentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (release.isPrerelease)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TVTheme.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: TVTheme.accentGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Pré-version',
                      style: TextStyle(
                        color: TVTheme.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Release notes ──
            if (release.body.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TVTheme.backgroundDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatNotes(release.body),
                      style: const TextStyle(
                        color: TVTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Download progress ──
            if (update.isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: update.downloadProgress,
                  backgroundColor: TVTheme.backgroundDark,
                  valueColor: const AlwaysStoppedAnimation(TVTheme.accentRed),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Téléchargement… ${(update.downloadProgress * 100).toInt()}%'
                '${asset?.readableSize != null ? ' · ${asset!.readableSize}' : ''}',
                style: const TextStyle(
                  color: TVTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Error ──
            if (update.status == UpdateStatus.error && update.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TVTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: TVTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  update.error!,
                  style: const TextStyle(
                    color: TVTheme.errorRed,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Actions ──
            Row(
              children: [
                if (!update.isDownloading)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        update.dismissUpdate();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: TVTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Plus tard',
                        style: TextStyle(
                          color: TVTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (!update.isDownloading) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: update.isDownloading
                        ? null
                        : () => update.downloadAndInstall(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TVTheme.accentRed,
                      disabledBackgroundColor:
                          TVTheme.accentRed.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (update.isDownloading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          const Icon(Icons.download_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Mettre à jour',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Voir sur GitHub ──
            TextButton(
              onPressed: () =>
                  launchUrl(AppConstants.githubReleasesPageUri),
              child: Text(
                'Voir sur GitHub',
                style: TextStyle(
                  color: TVTheme.textDisabled,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNotes(String body) {
    // Nettoyer le markdown basique pour un affichage en texte.
    return body
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .trim();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Mobile Dialog
// ═══════════════════════════════════════════════════════════════════════

void _showMobileDialog(
  BuildContext context,
  UpdateProvider update,
  GithubRelease release,
  GithubAsset? asset,
) {
  showDialog(
    context: context,
    builder: (ctx) => ChangeNotifierProvider.value(
      value: update,
      child: _MobileUpdateDialog(release: release, asset: asset),
    ),
  );
}

class _MobileUpdateDialog extends StatelessWidget {
  final GithubRelease release;
  final GithubAsset? asset;

  const _MobileUpdateDialog({required this.release, required this.asset});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFF7A0A12)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Mise à jour disponible',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v${release.version}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (release.isPrerelease) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Pré-version',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (asset != null) ...[
                const Spacer(),
                Text(
                  asset!.readableSize,
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (release.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  _formatNotes(release.body),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          if (update.isDownloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: update.downloadProgress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Téléchargement… ${(update.downloadProgress * 100).toInt()}%',
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (update.status == UpdateStatus.error && update.error != null) ...[
            const SizedBox(height: 12),
            Text(
              update.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        if (!update.isDownloading)
          TextButton(
            onPressed: () {
              update.dismissUpdate();
              Navigator.pop(context);
            },
            child: const Text('Plus tard'),
          ),
        if (!update.isDownloading)
          TextButton(
            onPressed: () =>
                launchUrl(AppConstants.githubReleasesPageUri),
            child: const Text('GitHub'),
          ),
        Builder(builder: (context) {
          final btnBg = Theme.of(context).colorScheme.primary;
          final onBtn = Neo.readableOn(btnBg);
          return FilledButton(
            onPressed:
                update.isDownloading ? null : () => update.downloadAndInstall(),
            style: FilledButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: onBtn,
            ),
            child: update.isDownloading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onBtn,
                    ),
                  )
                : const Text('Mettre à jour'),
          );
        }),
      ],
    );
  }

  String _formatNotes(String body) {
    return body
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .trim();
  }
}
