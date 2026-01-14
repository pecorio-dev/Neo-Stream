import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/settings/settings_provider.dart';
import '../../widgets/settings_button.dart';
import '../../widgets/loading_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/app_settings.dart' hide ThemeMode;
import '../../../data/models/app_settings.dart' as AppSettings;
import '../../widgets/account_switcher_button.dart';
import '../../../core/services/file_sharing_service.dart';
import '../../../main.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Charger les paramètres au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider).loadSettings();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(settingsProvider);
    
    if (provider.isLoading) {
      return const Center(child: NeonLoadingIndicator());
    }

    if (provider.hasError) {
      return _buildErrorWidget(provider);
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(provider),
            _buildSettingsList(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(SettingsProvider provider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Paramètres',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentNeon, AppTheme.accentSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.backgroundPrimary.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (provider.hasUnsavedChanges)
          IconButton(
            icon: const Icon(Icons.save, color: AppTheme.accentNeon),
            onPressed: () => _saveSettings(provider),
            tooltip: 'Sauvegarder',
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          color: AppTheme.surface,
          onSelected: (value) => _handleMenuAction(provider, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.upload, color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 12),
                  Text('Exporter',
                      style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.download, color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 12),
                  Text('Importer',
                      style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restore, color: AppTheme.errorColor, size: 20),
                  SizedBox(width: 12),
                  Text('Réinitialiser',
                      style: TextStyle(color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: AccountSwitcherButton(
            isCompact: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList(SettingsProvider provider) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSection(
            'Lecture vidéo',
            Icons.play_circle_outline,
            [
              _buildSwitchTile(
                'Lecture automatique',
                'Démarre automatiquement la lecture des vidéos',
                provider.autoPlay,
                (value) => provider.setAutoPlay(value),
              ),
              _buildSwitchTile(
                'Accélération matérielle',
                'Utilise le GPU pour décoder les vidéos',
                provider.enableHardwareAcceleration,
                (value) => provider.setEnableHardwareAcceleration(value),
              ),
            ],
          ),
          _buildSection(
            'Interface',
            Icons.palette_outlined,
            [
              _buildSwitchTile(
                'Animations',
                'Active les animations et transitions',
                provider.enableAnimations,
                (value) => provider.setEnableAnimations(value),
              ),
              _buildSliderTile(
                'Taille de l\'interface',
                'Échelle des éléments de l\'interface',
                provider.uiScale,
                0.8,
                1.5,
                '${(provider.uiScale * 100).toInt()}%',
                (value) => provider.setUiScale(value),
              ),
            ],
          ),
          _buildSection(
            'Cache et stockage',
            Icons.storage_outlined,
            [
              _buildSwitchTile(
                'Cache des images',
                'Stocke les images pour un chargement plus rapide',
                provider.enableImageCache,
                (value) => provider.setEnableImageCache(value),
              ),
              _buildSliderTile(
                'Taille max du cache',
                'Espace disque maximum utilisé pour le cache',
                provider.maxCacheSize.toDouble(),
                100,
                2000,
                '${provider.maxCacheSize} MB',
                (value) => provider.setMaxCacheSize(value.toInt()),
              ),
              _buildListTile(
                'Vider le cache',
                'Libère l\'espace de stockage utilisé',
                Icons.cleaning_services,
                () => _clearCache(provider),
              ),
            ],
          ),
          _buildSection(
            'Avancé',
            Icons.settings_outlined,
            [
              _buildSliderTile(
                'Timeout des requêtes',
                'Délai d\'attente maximum pour les requêtes réseau',
                provider.requestTimeout.toDouble(),
                10,
                60,
                '${provider.requestTimeout}s',
                (value) => provider.setRequestTimeout(value.toInt()),
              ),
            ],
          ),

          _buildSection(
            'À propos',
            Icons.info_outline,
            [
              _buildListTile(
                'Version',
                'NeoStream v1.0.0',
                Icons.app_registration,
                null,
              ),
              _buildListTile(
                'Licences',
                'Licences des bibliothèques utilisées',
                Icons.description,
                () => showLicensePage(context: context),
              ),
              _buildListTile(
                'Effacer toutes les données',
                'Supprime tous les paramètres et favoris',
                Icons.delete_forever,
                () => _showClearDataDialog(provider),
                color: AppTheme.errorColor,
              ),
            ],
          ),
          const SizedBox(height: 100), // Espace pour le FAB
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accentNeon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.accentNeon,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accentNeon,
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    String displayValue,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    activeColor: AppTheme.accentNeon,
                    inactiveColor: AppTheme.textSecondary,
                    onChanged: onChanged,
                  ),
                ),
                Container(
                  width: 60,
                  alignment: Alignment.centerRight,
                  child: Text(
                    displayValue,
                    style: const TextStyle(
                      color: AppTheme.accentNeon,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    T value,
    List<T> items,
    String Function(T) getDisplayName,
    ValueChanged<T> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: DropdownButton<T>(
          value: value,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary),
          underline: Container(),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(getDisplayName(item)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.accentNeon),
        title: Text(
          title,
          style: TextStyle(color: color ?? AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildErrorWidget(SettingsProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: provider.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(SettingsProvider provider, String action) {
    switch (action) {
      case 'export':
        _exportSettings(provider);
        break;
      case 'import':
        _importSettings(provider);
        break;
      case 'reset':
        _showResetDialog(provider);
        break;
    }
  }

  void _saveSettings(SettingsProvider provider) async {
    final success = await provider.saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Paramètres sauvegardés' : 'Erreur de sauvegarde'),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _exportSettings(SettingsProvider provider) async {
    final jsonString = await provider.exportSettings();
    if (jsonString != null && mounted) {
      try {
        // Convert JSON string to Map
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final success = await FileSharingService.exportSettings(jsonData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Paramètres exportés avec succès'
                  : 'Erreur lors de l\'export'),
              backgroundColor:
                  success ? AppTheme.successColor : AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la conversion des paramètres'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _importSettings(SettingsProvider provider) async {
    final importedSettings = await FileSharingService.importSettings();
    if (importedSettings != null && mounted) {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Importer les paramètres',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'Cela remplacera tous vos paramètres actuels. Voulez-vous continuer ?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentNeon),
              child: const Text('Importer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await provider.importSettingsFromMap(importedSettings);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Paramètres importés avec succès'
                  : 'Erreur lors de l\'import'),
              backgroundColor:
                  success ? AppTheme.successColor : AppTheme.errorColor,
            ),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun fichier sélectionné ou fichier invalide'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  void _showResetDialog(SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Réinitialiser les paramètres',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Tous les paramètres seront remis à leurs valeurs par défaut. Cette action est irréversible.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.resetSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Paramètres réinitialisés'
                        : 'Erreur lors de la réinitialisation'),
                    backgroundColor:
                        success ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }


  void _clearCache(SettingsProvider provider) async {
    final success = await provider.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Cache vidé' : 'Erreur lors du vidage'),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _showClearDataDialog(SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Effacer toutes les données',
          style: TextStyle(color: AppTheme.errorColor),
        ),
        content: const Text(
          'Cette action supprimera tous vos paramètres, favoris et données de l\'application. Cette action est irréversible.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.clearAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Toutes les données ont été effacées'
                        : 'Erreur lors de l\'effacement'),
                    backgroundColor:
                        success ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Effacer tout'),
          ),
        ],
      ),
    );
  }
}
