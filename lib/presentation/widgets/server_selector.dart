import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content.dart';
import '../../data/models/movie.dart';
import '../../data/services/watch_link_resolver.dart';

class ServerSelector extends StatelessWidget {
  final List<WatchLink> watchLinks;
  final Function(WatchLink) onServerSelected;

  const ServerSelector({
    super.key,
    required this.watchLinks,
    required this.onServerSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (watchLinks.isEmpty) {
      return _buildNoServersAvailable();
    }

    // Filtrer les serveurs supportés
    final supportedLinks = WatchLinkResolver.filterSupportedLinks(watchLinks);
    
    if (supportedLinks.isEmpty) {
      return _buildNoSupportedServers();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyberDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cyberGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            'Choisir un serveur',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            '${supportedLinks.length} serveur${supportedLinks.length > 1 ? 's' : ''} disponible${supportedLinks.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          // Server list
          ...supportedLinks.map((link) => _buildServerTile(link)),
          
          const SizedBox(height: 16),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppColors.cyberGray.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerTile(WatchLink link) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onServerSelected(link),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cyberBlack.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.neonBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Server icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getServerColor(link.server),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getServerIcon(link.server),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (link.server?.contains('UQLOAD') == true) ? 'UQLOAD' : (link.server ?? 'Unknown'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getServerDescription(link.server),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quality indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getQualityColor(link.server),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getQualityLabel(link.server),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                Icon(
                  Icons.play_arrow,
                  color: AppColors.neonBlue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoServersAvailable() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.laserRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun serveur disponible',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun lien de streaming n\'est disponible pour ce contenu.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSupportedServers() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: AppColors.neonYellow,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Serveurs non supportés',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les serveurs disponibles ne sont pas encore supportés par l\'application.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Serveurs disponibles: ${watchLinks.map((l) => l.server).join(', ')}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getServerColor(String server) {
    switch (server.toUpperCase()) {
      case 'UQLOAD':
        return AppColors.neonBlue;
      case 'STREAMTAPE':
        return AppColors.neonGreen;
      case 'DOODSTREAM':
        return AppColors.neonPurple;
      case 'MIXDROP':
        return AppColors.neonOrange;
      default:
        return AppColors.cyberGray;
    }
  }

  IconData _getServerIcon(String server) {
    switch (server.toUpperCase()) {
      case 'UQLOAD':
        return Icons.cloud_download;
      case 'STREAMTAPE':
        return Icons.videocam;
      case 'DOODSTREAM':
        return Icons.play_circle;
      case 'MIXDROP':
        return Icons.storage;
      default:
        return Icons.play_arrow;
    }
  }

  String _getServerDescription(String server) {
    switch (server.toUpperCase()) {
      case 'UQLOAD':
        return 'Streaming rapide et fiable';
      case 'STREAMTAPE':
        return 'Qualité HD disponible';
      case 'DOODSTREAM':
        return 'Streaming stable';
      case 'MIXDROP':
        return 'Téléchargement rapide';
      default:
        return 'Serveur de streaming';
    }
  }

  Color _getQualityColor(String server) {
    switch (server.toUpperCase()) {
      case 'UQLOAD':
        return AppColors.neonGreen;
      case 'STREAMTAPE':
        return AppColors.neonBlue;
      default:
        return AppColors.cyberGray;
    }
  }

  String _getQualityLabel(String server) {
    switch (server.toUpperCase()) {
      case 'UQLOAD':
        return 'HD';
      case 'STREAMTAPE':
        return 'HD';
      default:
        return 'SD';
    }
  }
}