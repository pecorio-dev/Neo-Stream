import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/platform_service.dart';
import '../widgets/tv_focusable_card.dart';

// Intent pour la navigation TV (définis en premier)
class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _SelectIntent extends Intent {
  const _SelectIntent();
}

class PlatformSelectionScreen extends StatefulWidget {
  const PlatformSelectionScreen({Key? key}) : super(key: key);

  @override
  State<PlatformSelectionScreen> createState() => _PlatformSelectionScreenState();
}

class _PlatformSelectionScreenState extends State<PlatformSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _glowAnimationController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  
  PlatformType? _selectedPlatform;
  bool _isNavigating = false;
  
  // Focus nodes pour la navigation TV
  final FocusNode _tvFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();
  final FocusNode _continueFocusNode = FocusNode();
  
  int _currentFocusIndex = 0; // 0: TV, 1: Mobile, 2: Continue
  final List<PlatformType> _platforms = [PlatformType.tv, PlatformType.android];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
    
    // Auto-focus sur le premier élément après un délai
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _tvFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _glowAnimationController.dispose();
    _tvFocusNode.dispose();
    _mobileFocusNode.dispose();
    _continueFocusNode.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _glowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() async {
    _animationController.forward();
    _glowAnimationController.repeat(reverse: true);
  }

  // Méthodes de navigation TV
  void _navigatePrevious() {
    if (_isNavigating) return;
    
    setState(() {
      if (_currentFocusIndex > 0) {
        _currentFocusIndex--;
      } else {
        _currentFocusIndex = 2; // Boucle vers le bouton continuer
      }
    });
    
    _updateFocus();
    HapticFeedback.selectionClick();
  }
  
  void _navigateNext() {
    if (_isNavigating) return;
    
    setState(() {
      if (_currentFocusIndex < 2) {
        _currentFocusIndex++;
      } else {
        _currentFocusIndex = 0; // Boucle vers le premier élément
      }
    });
    
    _updateFocus();
    HapticFeedback.selectionClick();
  }
  
  void _updateFocus() {
    switch (_currentFocusIndex) {
      case 0:
        _tvFocusNode.requestFocus();
        break;
      case 1:
        _mobileFocusNode.requestFocus();
        break;
      case 2:
        _continueFocusNode.requestFocus();
        break;
    }
  }
  
  void _handleSelection() {
    if (_isNavigating) return;
    
    if (_currentFocusIndex < 2) {
      // Sélection d'une plateforme
      _selectPlatform(_platforms[_currentFocusIndex]);
    } else {
      // Bouton continuer
      _continueToProfileSelection();
    }
    
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 400;
    
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PreviousIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _SelectIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _SelectIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const _SelectIntent(),
      },
      child: Actions(
        actions: {
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (intent) {
              _navigatePrevious();
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (intent) {
              _navigateNext();
              return null;
            },
          ),
          _SelectIntent: CallbackAction<_SelectIntent>(
            onInvoke: (intent) {
              _handleSelection();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: AppTheme.backgroundPrimary,
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Color(0xFF1A1A24),
                  AppTheme.backgroundPrimary,
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                _buildHeader(isSmallScreen, isNarrowScreen),
                                Expanded(
                                  child: _buildPlatformOptions(isSmallScreen, isNarrowScreen),
                                ),
                                _buildBottomSection(isSmallScreen, isNarrowScreen),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen, bool isNarrowScreen) {
    final logoSize = isSmallScreen ? 80.0 : 100.0;
    final titleFontSize = isSmallScreen ? 22.0 : (isNarrowScreen ? 24.0 : 28.0);
    final subtitleFontSize = isSmallScreen ? 14.0 : 16.0;
    final padding = isSmallScreen ? 16.0 : (isNarrowScreen ? 20.0 : 32.0);
    final spacing = isSmallScreen ? 16.0 : 32.0;
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Logo avec effet glow
          AnimatedBuilder(
            animation: _glowAnimationController,
            builder: (context, child) {
              return Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentNeon.withOpacity(_glowAnimation.value * 0.6),
                      blurRadius: 30 * _glowAnimation.value,
                      spreadRadius: 10 * _glowAnimation.value,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        AppTheme.accentNeon.withOpacity(0.9),
                        AppTheme.accentSecondary.withOpacity(0.7),
                        AppTheme.backgroundPrimary,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    border: Border.all(
                      color: AppTheme.accentNeon.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.devices,
                    color: AppTheme.accentNeon,
                    size: logoSize * 0.48,
                  ),
                ),
              );
            },
          ),
          
          SizedBox(height: spacing),
          
          // Titre
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                AppTheme.accentNeon,
                AppTheme.accentSecondary,
              ],
            ).createShader(bounds),
            child: Text(
              'Choisissez votre plateforme',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: isNarrowScreen ? 1.0 : 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          Text(
            'Sélectionnez le type d\'appareil pour optimiser votre expérience',
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: AppTheme.textSecondary.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformOptions(bool isSmallScreen, bool isNarrowScreen) {
    final horizontalPadding = isNarrowScreen ? 16.0 : 32.0;
    final spacing = isSmallScreen ? 16.0 : 24.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Option TV
          TVFocusableCard(
            focusNode: _tvFocusNode,
            onPressed: () => _selectPlatform(PlatformType.tv),
            child: _buildPlatformCard(
              platform: PlatformType.tv,
              title: 'Mode TV',
              subtitle: 'Optimisé pour les téléviseurs et Android TV',
              icon: Icons.tv,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C5CE7),
                  Color(0xFFA29BFE),
                ],
              ),
              isSmallScreen: isSmallScreen,
              isNarrowScreen: isNarrowScreen,
            ),
          ),
          
          SizedBox(height: spacing),
          
          // Option Android
          TVFocusableCard(
            focusNode: _mobileFocusNode,
            onPressed: () => _selectPlatform(PlatformType.android),
            child: _buildPlatformCard(
              platform: PlatformType.android,
              title: 'Mode Mobile',
              subtitle: 'Optimisé pour smartphones et tablettes',
              icon: Icons.smartphone,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00B894),
                  Color(0xFF55A3FF),
                ],
              ),
              isSmallScreen: isSmallScreen,
              isNarrowScreen: isNarrowScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard({
    required PlatformType platform,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required bool isSmallScreen,
    required bool isNarrowScreen,
  }) {
    final isSelected = _selectedPlatform == platform;
    final cardPadding = isSmallScreen ? 16.0 : 24.0;
    final iconSize = isSmallScreen ? 36.0 : 48.0;
    final iconPadding = isSmallScreen ? 12.0 : 16.0;
    final titleFontSize = isSmallScreen ? 18.0 : (isNarrowScreen ? 20.0 : 22.0);
    final subtitleFontSize = isSmallScreen ? 12.0 : 14.0;
    final spacing = isSmallScreen ? 12.0 : 16.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: isSelected ? gradient : null,
        color: isSelected ? null : AppTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? Colors.white.withOpacity(0.8)
              : AppTheme.textSecondary.withOpacity(0.3),
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.white.withOpacity(0.2)
                  : AppTheme.accentNeon.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withOpacity(0.5)
                    : AppTheme.accentNeon.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isSelected ? Colors.white : AppTheme.accentNeon,
            ),
          ),
          
          SizedBox(height: spacing),
          
          // Titre
          Text(
            title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          SizedBox(height: isSmallScreen ? 4 : 8),
          
          // Sous-titre
          Text(
            subtitle,
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: isSelected 
                  ? Colors.white.withOpacity(0.8)
                  : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Indicateur de sélection
          if (isSelected) ...[
            SizedBox(height: spacing),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16, 
                vertical: isSmallScreen ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: isSmallScreen ? 16 : 20,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Sélectionné',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isSmallScreen, bool isNarrowScreen) {
    final padding = isSmallScreen ? 16.0 : (isNarrowScreen ? 20.0 : 32.0);
    final buttonPadding = isSmallScreen ? 12.0 : 16.0;
    final buttonFontSize = isSmallScreen ? 14.0 : 16.0;
    final noteFontSize = isSmallScreen ? 10.0 : 12.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Continuer
          SizedBox(
            width: double.infinity,
            child: TVFocusableCard(
              focusNode: _continueFocusNode,
              onPressed: _selectedPlatform != null && !_isNavigating
                  ? _continueToProfileSelection
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: buttonPadding),
                decoration: BoxDecoration(
                  color: _selectedPlatform != null 
                      ? AppTheme.accentNeon 
                      : AppTheme.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isNavigating
                    ? SizedBox(
                        width: isSmallScreen ? 20 : 24,
                        height: isSmallScreen ? 20 : 24,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward, 
                            size: iconSize,
                            color: _selectedPlatform != null 
                                ? Colors.white 
                                : AppTheme.textSecondary,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            'Continuer',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.w600,
                              color: _selectedPlatform != null 
                                  ? Colors.white 
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Note informative
          Text(
            'Vous pourrez modifier ce choix plus tard dans les paramètres',
            style: TextStyle(
              fontSize: noteFontSize,
              color: AppTheme.textSecondary.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _selectPlatform(PlatformType platform) {
    if (_isNavigating) return;
    
    setState(() {
      _selectedPlatform = platform;
      // Mettre à jour l'index de focus selon la sélection
      _currentFocusIndex = platform == PlatformType.tv ? 0 : 1;
    });
    
    HapticFeedback.lightImpact();
  }

  void _continueToProfileSelection() async {
    if (_selectedPlatform == null || _isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });
    
    try {
      // Sauvegarder le choix de plateforme
      await PlatformService.savePlatformChoice(_selectedPlatform!);
      
      // Attendre un peu pour l'animation
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        // Naviguer vers l'écran principal (pas de profile-selection pour l'instant)
        Navigator.pushReplacementNamed(context, '/movies');
      }
    } catch (e) {
      // Gérer l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  // Méthode statique pour vérifier si la configuration est terminée
  static Future<bool> isPlatformSetupCompleted() async {
    return await PlatformService.isPlatformSetupCompleted();
  }
}