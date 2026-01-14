import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CyberGradientBackdrop extends StatefulWidget {
  const CyberGradientBackdrop({Key? key}) : super(key: key);

  @override
  State<CyberGradientBackdrop> createState() => _CyberGradientBackdropState();
}

class _CyberGradientBackdropState extends State<CyberGradientBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    
    _controller1 = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _controller2 = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    
    _controller3 = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cyberBlack,
                AppColors.cyberDark,
                AppColors.cyberBlack,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Animated gradient layer 1
        AnimatedBuilder(
          animation: _controller1,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -1.0 + (_controller1.value * 2.0),
                    -1.0 + (_controller1.value * 2.0),
                  ),
                  radius: 1.5,
                  colors: [
                    AppColors.neonBlue.withOpacity(0.1),
                    AppColors.neonBlue.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),
        
        // Animated gradient layer 2
        AnimatedBuilder(
          animation: _controller2,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    1.0 - (_controller2.value * 2.0),
                    -1.0 + (_controller2.value * 2.0),
                  ),
                  radius: 1.2,
                  colors: [
                    AppColors.neonPurple.withOpacity(0.08),
                    AppColors.neonPurple.withOpacity(0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        
        // Animated gradient layer 3
        AnimatedBuilder(
          animation: _controller3,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -1.0 + (_controller3.value * 2.0),
                    1.0 - (_controller3.value * 2.0),
                  ),
                  radius: 1.0,
                  colors: [
                    AppColors.neonGreen.withOpacity(0.06),
                    AppColors.neonGreen.withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            );
          },
        ),
        
        // Subtle grid pattern overlay
        CustomPaint(
          painter: CyberGridPainter(),
          size: Size.infinite,
        ),
      ],
    );
  }
}

class CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonBlue.withOpacity(0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 50.0;
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}