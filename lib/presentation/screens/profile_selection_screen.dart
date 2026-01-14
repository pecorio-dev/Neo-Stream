import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import '../../data/models/user_profile.dart';
import '../widgets/loading_widgets.dart';
import '../providers/user_profile_provider.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // TV Navigation
  final List<FocusNode> _profileFocusNodes = [];
  int _selectedProfileIndex = 0;
  bool _isNavigatingWithKeyboard = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTVNavigation();
    
    // Charger les profils depuis le provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfiles();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  void _setupTVNavigation() {
    if (PlatformService.isTVMode) {
      // Les focus nodes seront créés dynamiquement dans _buildProfileGrid
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final node in _profileFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildProfileGrid(),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    // Add TV shortcuts if in TV mode
    if (PlatformService.isTVMode) {
      child = Shortcuts(
        shortcuts: _getTVShortcuts(),
        child: Actions(
          actions: _getTVActions(),
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Logo or app name
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentNeon, AppTheme.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentNeon.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Qui regarde ?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez votre profil pour continuer',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileGrid() {
    final profileProvider = ref.watch(userProfileProvider);
    final isLoading = profileProvider.isLoading;
    final profiles = profileProvider.profiles;
    
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add,
              size: 64,
              color: AppTheme.accentNeon,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun profil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _navigateToProfileCreation(context),
              child: const Text('Créer un profil'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: profiles.length + 1, // +1 for add profile button
          itemBuilder: (context, index) {
            if (index < profiles.length) {
              return _buildProfileCard(profiles[index], index);
            } else {
              return _buildAddProfileCard(index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, int index) {
    final isSelected = _selectedProfileIndex == index;
    final profileColor = Color(profile.color);

    Widget baseCard = GestureDetector(
      onTap: () => _selectProfile(profile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? profileColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: profileColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: profileColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: profileColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: profileColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                profile.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    // Add TV focus support
    if (PlatformService.isTVMode) {
      if (_profileFocusNodes.length <= index) {
        _profileFocusNodes.add(FocusNode());
      }
      final focusNode = _profileFocusNodes[index];
      
      return AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _selectProfile(profile);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedScale(
              scale: isFocused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: baseCard,
            ),
          );
        },
      );
    }

    return baseCard;
  }

  Widget _buildAddProfileCard(int index) {
    Widget baseCard = GestureDetector(
      onTap: _addNewProfile,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textSecondary.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add,
                color: AppTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajouter',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Add TV focus support
    if (PlatformService.isTVMode) {
      if (_profileFocusNodes.length <= index) {
        _profileFocusNodes.add(FocusNode());
      }
      final focusNode = _profileFocusNodes[index];
      return AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _addNewProfile();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedScale(
              scale: isFocused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: baseCard,
            ),
          );
        },
      );
    }

    return baseCard;
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (PlatformService.isTVMode)
            Text(
              'Utilisez les flèches directionnelles pour naviguer • Appuyez sur OK pour sélectionner',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/platform-selection'),
            child: Text(
              'Retour à la sélection de plateforme',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfileCreation(BuildContext context) {
    Navigator.pushNamed(context, '/profile-creation').then((success) {
      // Recharger les profils après la création
      if (mounted && success == true) {
        ref.read(userProfileProvider).loadProfiles();
      }
    });
  }

  void _selectProfile(UserProfile profile) {
    HapticFeedback.selectionClick();

    // Show loading and navigate to main screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: NeonLoadingIndicator(),
      ),
    );

    // Simulate profile loading
    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.of(context).pop(); // Close loading dialog
      Navigator.pushReplacementNamed(context, '/main');
    });
  }

  void _addNewProfile() {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, '/profile-creation');
  }

  Map<LogicalKeySet, Intent> _getTVShortcuts() {
    return {
      LogicalKeySet(LogicalKeyboardKey.arrowUp): _NavigateIntent(-3),
      LogicalKeySet(LogicalKeyboardKey.arrowDown): _NavigateIntent(3),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): _NavigateIntent(-1),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): _NavigateIntent(1),
      LogicalKeySet(LogicalKeyboardKey.escape): _BackIntent(),
      LogicalKeySet(LogicalKeyboardKey.goBack): _BackIntent(),
    };
  }

  Map<Type, Action<Intent>> _getTVActions() {
    return {
      _NavigateIntent: CallbackAction<_NavigateIntent>(
        onInvoke: (intent) {
          final profilesLength = ref.read(userProfileProvider).profiles.length;
          _navigateTV(intent.direction, profilesLength + 1);
          return null;
        },
      ),
      _BackIntent: CallbackAction<_BackIntent>(
        onInvoke: (intent) {
          Navigator.pushReplacementNamed(context, '/platform-selection');
          return null;
        },
      ),
    };
  }

  void _navigateTV(int direction, int totalItems) {
    setState(() {
      _selectedProfileIndex = (_selectedProfileIndex + direction)
          .clamp(0, totalItems - 1);
    });

    // Focus the selected profile
    if (_selectedProfileIndex < _profileFocusNodes.length) {
      _profileFocusNodes[_selectedProfileIndex].requestFocus();
    }

    HapticFeedback.selectionClick();
  }
}

// TV Navigation Intents
class _NavigateIntent extends Intent {
  final int direction;
  const _NavigateIntent(this.direction);
}

class _BackIntent extends Intent {
  const _BackIntent();
}

