import 'package:flutter/material.dart';
import '../../data/services/platform_service.dart';
import '../../core/theme/app_theme.dart';

/// Indicateur visuel du mode TV
class TVModeIndicator extends StatefulWidget {
  final bool showAlways;
  final Duration autoHideDuration;

  const TVModeIndicator({
    Key? key,
    this.showAlways = false,
    this.autoHideDuration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<TVModeIndicator> createState() => _TVModeIndicatorState();
}

class _TVModeIndicatorState extends State<TVModeIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    if (!widget.showAlways) {
      _startAutoHideTimer();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  void _startAutoHideTimer() {
    Future.delayed(widget.autoHideDuration, () {
      if (mounted && !widget.showAlways) {
        _hide();
      }
    });
  }

  void _hide() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _show() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();
      
      if (!widget.showAlways) {
        _startAutoHideTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformService.isTVMode || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 20,
      child: GestureDetector(
        onTap: _show,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentNeon.withOpacity(0.9),
                        AppTheme.accentSecondary.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentNeon.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tv,
                        size: 16,
                        color: AppTheme.backgroundPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mode TV',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.backgroundPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget d'aide pour les contrôles TV
class TVControlsHelp extends StatefulWidget {
  final bool showOnStart;

  const TVControlsHelp({
    Key? key,
    this.showOnStart = true,
  }) : super(key: key);

  @override
  State<TVControlsHelp> createState() => _TVControlsHelpState();
}

class _TVControlsHelpState extends State<TVControlsHelp>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    if (widget.showOnStart && PlatformService.isTVMode) {
      _showHelp();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _showHelp() {
    setState(() {
      _isVisible = true;
    });
    _animationController.forward();
    
    // Auto-hide après 5 secondes
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _hideHelp();
      }
    });
  }

  void _hideHelp() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformService.isTVMode || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentNeon.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.backgroundPrimary.withOpacity(0.8),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.accentNeon,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Contrôles TV',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _hideHelp,
                        child: Icon(
                          Icons.close,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildControlItem('Flèches', 'Navigation'),
                  _buildControlItem('Entrée/Sélection', 'Activer'),
                  _buildControlItem('Retour/Échap', 'Retour'),
                  _buildControlItem('Menu', 'Options'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlItem(String control, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentNeon.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              control,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.accentNeon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            action,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}