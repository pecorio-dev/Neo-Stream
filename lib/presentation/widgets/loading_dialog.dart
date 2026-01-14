import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

class LoadingDialog extends StatelessWidget {
  final String message;

  const LoadingDialog({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
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
            // Loading animation
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.neonBlue,
                    AppColors.neonPurple,
                  ],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.cyberBlack,
                  strokeWidth: 3,
                ),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(),
            ).rotate(
              duration: const Duration(seconds: 2),
            ),
            
            const SizedBox(height: 24),
            
            // Message
            Text(
              message,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Veuillez patienter...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ).animate(
              onPlay: (controller) => controller.repeat(),
            ).fadeIn(
              duration: const Duration(milliseconds: 800),
            ).then().fadeOut(
              duration: const Duration(milliseconds: 800),
            ),
          ],
        ),
      ).animate().scale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
      ),
    );
  }
}