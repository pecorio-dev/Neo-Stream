import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import '../../data/models/user_profile.dart';
import '../widgets/loading_widgets.dart';
import '../providers/user_profile_provider.dart';

class ProfileCreationScreen extends ConsumerStatefulWidget {
  const ProfileCreationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends ConsumerState<ProfileCreationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  // Profile customization
  Color _selectedColor = AppTheme.accentNeon;
  String _selectedAvatar = 'assets/avatars/avatar1.png';
  bool _isChildProfile = false;

  // Available colors
  final List<Color> _availableColors = [
    AppTheme.accentNeon,
    AppTheme.accentSecondary,
    AppTheme.warningColor,
    AppTheme.successColor,
    AppTheme.errorColor,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.indigo,
    Colors.teal,
  ];

  // Available avatars
  final List<String> _availableAvatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
    'assets/avatars/avatar6.png',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildAvatarSection(),
                  const SizedBox(height: 40),
                  _buildNameInput(),
                  const SizedBox(height: 40),
                  _buildColorPicker(),
                  const SizedBox(height: 40),
                  _buildOptions(),
                  const SizedBox(height: 60),
                  _buildCreateButton(),
                ],
              ),
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
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        ),
        const SizedBox(width: 16),
        const Text(
          'Créer un profil',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _selectedColor.withOpacity(0.2),
              border: Border.all(color: _selectedColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: _selectedColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choisissez votre avatar',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nom du profil',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Ex: Jean, Marie, Enfants...',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentNeon, width: 2),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Couleur du profil',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              final isSelected = _selectedColor == color;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ] : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Profil enfant',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          ),
          subtitle: const Text(
            'Contenu adapté aux plus jeunes',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          value: _isChildProfile,
          onChanged: (value) => setState(() => _isChildProfile = value),
          activeColor: AppTheme.accentNeon,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _createProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentNeon,
          foregroundColor: AppTheme.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: AppTheme.accentNeon.withOpacity(0.4),
        ),
        child: const Text(
          'CRÉER LE PROFIL',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  void _createProfile() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom pour le profil'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    // Show loading and create profile
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: NeonLoadingIndicator(),
      ),
    );

    // Create profile using ProfileProvider with persistence
    final profileName = _nameController.text.trim();
    final colorValue = _selectedColor.value;

    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final newProfile = UserProfile(
          id: const Uuid().v4(), // Générer un UUID unique
          name: profileName,
          avatarPath: _selectedAvatar,
          createdAt: DateTime.now(),
          lastUsed: DateTime.now(),
          isDefault: false,
          hasPassword: false,
          isLocked: false,
          isActive: true,
          color: colorValue,
          isMain: false,
          googleAccountEmail: null,
        );

        // Créer le profil via le provider
        final profileProvider = ref.read(userProfileProvider);
        final createdProfile = await profileProvider.createProfile(
          name: newProfile.name,
          avatarPath: newProfile.avatarPath,
        );
        final success = createdProfile != null;

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          if (success) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profil "$profileName" créé avec succès'),
                backgroundColor: AppTheme.successColor,
              ),
            );

            // Navigate back to profile selection
            Navigator.pop(context);
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur lors de la création du profil'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    });
  }

  Map<LogicalKeySet, Intent> _getTVShortcuts() {
    return {
      LogicalKeySet(LogicalKeyboardKey.escape): _BackIntent(),
      LogicalKeySet(LogicalKeyboardKey.goBack): _BackIntent(),
    };
  }

  Map<Type, Action<Intent>> _getTVActions() {
    return {
      _BackIntent: CallbackAction<_BackIntent>(
        onInvoke: (intent) {
          Navigator.pop(context);
          return null;
        },
      ),
    };
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

