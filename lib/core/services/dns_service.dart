import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';
import '../../data/services/dio_client.dart';

/// Service pour la gestion et configuration DNS
class DnsService {
  static const List<DnsServer> _recommendedServers = [
    DnsServer(
      name: 'Cloudflare',
      primary: '1.1.1.1',
      secondary: '1.0.0.1',
      description: 'Rapide et sécurisé',
      isRecommended: true,
    ),
    DnsServer(
      name: 'Google',
      primary: '8.8.8.8',
      secondary: '8.8.4.4',
      description: 'Fiable et stable',
      isRecommended: true,
    ),
    DnsServer(
      name: 'OpenDNS',
      primary: '208.67.222.222',
      secondary: '208.67.220.220',
      description: 'Filtrage de contenu',
      isRecommended: false,
    ),
    DnsServer(
      name: 'Quad9',
      primary: '9.9.9.9',
      secondary: '149.112.112.112',
      description: 'Sécurité renforcée',
      isRecommended: false,
    ),
  ];

  /// Affiche le dialogue d'information DNS
  static void showDnsInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DnsInfoDialog(),
    );
  }

  /// Obtient la liste des serveurs DNS recommandés
  static List<DnsServer> get recommendedServers => _recommendedServers;

  /// Copie une adresse DNS dans le presse-papiers
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

/// Modèle pour un serveur DNS
class DnsServer {
  final String name;
  final String primary;
  final String secondary;
  final String description;
  final bool isRecommended;

  const DnsServer({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.description,
    this.isRecommended = false,
  });
}

/// Dialogue d'information DNS
class DnsInfoDialog extends StatelessWidget {
  const DnsInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: AppColors.cyberDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.neonBlue,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonBlue.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDescription(),
                    const SizedBox(height: 20),
                    _buildServersList(context),
                    const SizedBox(height: 20),
                    _buildInstructions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neonBlue.withOpacity(0.2),
            AppColors.neonPurple.withOpacity(0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neonBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.dns,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration DNS',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optimiser votre connexion',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyberBlack.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.neonBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pourquoi changer de DNS ?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Changer vos serveurs DNS peut améliorer :\n'
            '• La vitesse de navigation\n'
            '• L\'accès aux sites de streaming\n'
            '• La sécurité de votre connexion\n'
            '• La résolution des problèmes de connectivité',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServersList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Serveurs DNS recommandés',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...DnsService.recommendedServers
            .map((server) => _buildServerCard(context, server)),
      ],
    );
  }

  Widget _buildServerCard(BuildContext context, DnsServer server) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyberBlack.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: server.isRecommended
              ? AppColors.neonGreen.withOpacity(0.5)
              : AppColors.neonBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  server.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (server.isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'RECOMMANDÉ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            server.description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDnsField(context, 'Primaire', server.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDnsField(context, 'Secondaire', server.secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDnsField(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _copyDns(context, value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cyberGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.neonBlue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Icon(
                  Icons.copy,
                  color: AppColors.neonBlue,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neonYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonYellow.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: AppColors.neonYellow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Comment configurer',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Android :\n'
            '1. Paramètres > Wi-Fi\n'
            '2. Appuyez longuement sur votre réseau\n'
            '3. Modifier le réseau > Avancé\n'
            '4. Changez DNS 1 et DNS 2\n\n'
            'iOS :\n'
            '1. Réglages > Wi-Fi\n'
            '2. Touchez le "i" de votre réseau\n'
            '3. Configurer DNS > Manuel\n'
            '4. Ajoutez les serveurs DNS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyDns(BuildContext context, String dns) async {
    await DnsService.copyToClipboard(dns);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('DNS $dns copié dans le presse-papiers'),
        backgroundColor: AppColors.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
