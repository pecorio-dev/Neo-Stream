import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_handler.dart';

/// Widget d'erreur avec style cyberpunk et glow effect
class ErrorWidgetGlow extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;
  final IconData? customIcon;
  final bool showRetryButton;
  final bool showDetails;

  const ErrorWidgetGlow({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
    this.customIcon,
    this.showRetryButton = true,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = customMessage ?? ErrorHandler.handleError(error);
    final isRetryable = ErrorHandler.isRetryableError(error);
    final isNetworkError = ErrorHandler.isNetworkError(error);
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cyberDark.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.laserRed.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.laserRed.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildErrorIcon(isNetworkError),
            const SizedBox(height: 16),
            _buildErrorTitle(isNetworkError),
            const SizedBox(height: 12),
            _buildErrorMessage(errorMessage),
            if (showDetails) ...[
              const SizedBox(height: 16),
              _buildErrorDetails(),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(isRetryable),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIcon(bool isNetworkError) {
    IconData iconData;
    Color iconColor;
    
    if (customIcon != null) {
      iconData = customIcon!;
      iconColor = AppColors.laserRed;
    } else if (isNetworkError) {
      iconData = Icons.wifi_off;
      iconColor = AppColors.neonYellow;
    } else {
      iconData = Icons.error_outline;
      iconColor = AppColors.laserRed;
    }
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withOpacity(0.1),
        border: Border.all(
          color: iconColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(
        iconData,
        size: 40,
        color: iconColor,
      ),
    );
  }

  Widget _buildErrorTitle(bool isNetworkError) {
    String title;
    
    if (isNetworkError) {
      title = 'Problème de connexion';
    } else {
      title = 'Une erreur s\'est produite';
    }
    
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorMessage(String message) {
    return Text(
      message,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cyberBlack.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.cyberGray.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.textTertiary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Détails techniques',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Code: ${ErrorHandler.getErrorCode(error)}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Type: ${error.runtimeType}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isRetryable) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showRetryButton && isRetryable && onRetry != null) ...[
          _buildRetryButton(),
          const SizedBox(width: 12),
        ],
        _buildDismissButton(),
      ],
    );
  }

  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: Icon(
        Icons.refresh,
        size: 18,
        color: AppColors.cyberBlack,
      ),
      label: Text(
        'Réessayer',
        style: TextStyle(
          color: AppColors.cyberBlack,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonBlue,
        foregroundColor: AppColors.cyberBlack,
        elevation: 8,
        shadowColor: AppColors.neonBlue.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDismissButton() {
    return OutlinedButton.icon(
      onPressed: () {
        // Fermer le widget d'erreur ou naviguer vers l'écran précédent
      },
      icon: Icon(
        Icons.close,
        size: 18,
        color: AppColors.textSecondary,
      ),
      label: Text(
        'Fermer',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),
    );
  }
}

/// Widget d'erreur compact pour les listes
class CompactErrorWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const CompactErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = customMessage ?? ErrorHandler.handleError(error);
    final isRetryable = ErrorHandler.isRetryableError(error);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.laserRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.laserRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.laserRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erreur',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isRetryable && onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: Icon(
                Icons.refresh,
                color: AppColors.neonBlue,
              ),
              tooltip: 'Réessayer',
            ),
        ],
      ),
    );
  }
}

/// Widget d'erreur pour les images
class ImageErrorWidget extends StatelessWidget {
  final String? title;
  final double? width;
  final double? height;

  const ImageErrorWidget({
    super.key,
    this.title,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cyberGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.cyberGray.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: AppColors.textTertiary,
            size: 32,
          ),
          if (title != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title!,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}