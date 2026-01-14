import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/user_profile_provider.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/profile_security_service.dart';
import '../../core/design_system/animation_system.dart';
import '../../core/design_system/color_system.dart';
import '../widgets/animations/animated_card.dart';

class EnhancedProfileSelectionScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;

  const EnhancedProfileSelectionScreen({
    Key? key,
    this.isInitialSetup = false,
  }) : super(key: key);

  @override
  ConsumerState<EnhancedProfileSelectionScreen> createState() => _EnhancedProfileSelectionScreenState();
}

class _EnhancedProfileSelectionScreenState extends ConsumerState<EnhancedProfileSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadProfiles();
  }

  void _setupAnimations() {
    _headerController = AnimationController(
      duration: AnimationSystem.long,
      vsync: this,
    );

    _contentController = AnimationController(
      duration: AnimationSystem.veryLong,
      vsync: this,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
  }

  void _loadProfiles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider).loadProfiles();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSystem.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildProfileGrid(),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildSpectacularHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildSpectacularHeader() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorSystem.neonCyan.withOpacity(0.3),
              ColorSystem.backgroundPrimary,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ColorSystem.neonCyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ColorSystem.neonCyan.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_circle_fill,
                size: 60,
                color: ColorSystem.neonCyan,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Qui regarde aujourd\'hui ?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ColorSystem.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez votre profil pour continuer',
              style: TextStyle(
                fontSize: 16,
                color: ColorSystem.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileGrid() {
    final provider = ref.watch(userProfileProvider);
    final profiles = provider.profiles;

    if (provider.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: ColorSystem.neonCyan)),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == profiles.length) {
              return _buildAddProfileCard();
            }
            return _buildProfileCard(profiles[index], index);
          },
          childCount: profiles.length + 1,
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, int index) {
    return AnimatedNeonCard(
      onTap: () => _onProfileSelected(profile),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: profile.isMain ? ColorSystem.neonCyan : ColorSystem.textTertiary,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: profile.avatarPath != null
                  ? Image.file(File(profile.avatarPath!), fit: BoxFit.cover)
                  : Icon(Icons.person, size: 60, color: ColorSystem.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColorSystem.textPrimary,
            ),
          ),
          if (profile.isMain)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ColorSystem.neonCyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRINCIPAL',
                style: TextStyle(fontSize: 10, color: ColorSystem.neonCyan),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCard() {
    return AnimatedNeonCard(
      onTap: _onAddNewProfile,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ColorSystem.textTertiary, width: 2),
            ),
            child: const Icon(Icons.add, size: 40, color: ColorSystem.textTertiary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ajouter un profil',
            style: TextStyle(
              fontSize: 16,
              color: ColorSystem.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            TextButton.icon(
              onPressed: () {}, // Gérer les profils
              icon: const Icon(Icons.edit, color: ColorSystem.textSecondary),
              label: const Text(
                'GÉRER LES PROFILS',
                style: TextStyle(color: ColorSystem.textSecondary, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onProfileSelected(UserProfile profile) async {
    // Set current profile
    final profileProvider = ref.read(userProfileProvider);
    await profileProvider.switchProfile(profile.id);
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _onAddNewProfile() {
    Navigator.of(context).pushNamed('/profile-creation');
  }
}
