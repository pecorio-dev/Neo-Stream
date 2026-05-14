import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'sub_accounts_screen.dart';

class ProfilePickerScreen extends StatefulWidget {
  final User mainUser;

  const ProfilePickerScreen({super.key, required this.mainUser});

  @override
  State<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends State<ProfilePickerScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _subAccounts = [];
  bool _isLoading = true;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: NeoTheme.durationHero,
    );
    _loadProfiles();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final subs = await _api.getSubAccounts();
      if (!mounted) return;
      setState(() {
        _subAccounts = subs;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fadeController.forward(from: 0);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, next) => const HomeScreen(),
        transitionDuration: NeoTheme.durationSplash,
        transitionsBuilder: (ctx, animation, next, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _selectSubAccount(Map<String, dynamic> sub) async {
    final username = sub['username']?.toString() ?? '';
    final requirePass = sub['require_password'];
    final hasPassword =
        requirePass == 1 || requirePass == true || requirePass == '1';

    if (!hasPassword) {
      await _loginSubAccount(username, '');
      return;
    }

    final password = await _showPasswordDialog(username);
    if (!mounted) return;
    if (password != null && password.isNotEmpty) {
      await _loginSubAccount(username, password);
    }
  }

  Future<void> _loginSubAccount(String username, String password) async {
    try {
      await _api.login(username, password);
      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: NeoTheme.errorRed,
        ),
      );
    }
  }

  Future<String?> _showPasswordDialog(String username) async {
    final controller = TextEditingController();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
              ),
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
              border: Border.all(
                color: NeoTheme.primaryRed.withValues(alpha: 0.15),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: NeoTheme.heroGradient,
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: NeoTheme.headlineMedium(ctx),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(username, style: NeoTheme.titleLarge(ctx)),
                const SizedBox(height: 4),
                Text(
                  'Entrez le mot de passe',
                  style: NeoTheme.bodySmall(ctx),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: NeoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  onSubmitted: (_) =>
                      Navigator.of(ctx).pop(controller.text),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(controller.text),
                        child: const Text('Continuer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProfiles = [
      {'username': widget.mainUser.username, 'isMain': true},
      ..._subAccounts.map((s) => {...s, 'isMain': false}),
    ];

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [Color(0xFF10102A), Color(0xFF080818), Color(0xFF06060C)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header compact
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qui regarde ?',
                          style: NeoTheme.headlineLarge(context).copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choisissez votre profil',
                          style: NeoTheme.bodySmall(context).copyWith(
                            color: NeoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Focus(
                      canRequestFocus: NeoTheme.needsFocusNavigation(context),
                      onKeyEvent: NeoTheme.needsFocusNavigation(context)
                          ? (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.select)) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SubAccountsScreen(),
                                  ),
                                );
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            }
                          : null,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubAccountsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.manage_accounts_rounded),
                        color: NeoTheme.textSecondary,
                        tooltip: 'Gérer les profils',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 0.5,
                  color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 16),
              // Profiles
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: NeoTheme.primaryRed,
                          strokeWidth: 2,
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeController,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                              shrinkWrap: true,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: allProfiles.length == 1 ? 1 : 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                mainAxisExtent: 160,
                              ),
                              itemCount: allProfiles.length,
                              itemBuilder: (context, index) {
                                final profile = allProfiles[index];
                                final isMain = profile['isMain'] == true;
                                final username =
                                    profile['username']?.toString() ?? 'Profil';
                                final requirePass = profile['require_password'];
                                final hasPassword = requirePass == 1 ||
                                    requirePass == true ||
                                    requirePass == '1';

                                return _ProfileTile(
                                  username: username,
                                  isMain: isMain,
                                  hasPassword: hasPassword && !isMain,
                                  index: index,
                                  onTap: isMain
                                      ? _navigateToHome
                                      : () => _selectSubAccount(
                                          Map<String, dynamic>.from(profile)),
                                  autofocus: index == 0,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  final String username;
  final bool isMain;
  final bool hasPassword;
  final int index;
  final VoidCallback onTap;
  final bool autofocus;

  const _ProfileTile({
    required this.username,
    required this.isMain,
    required this.hasPassword,
    required this.index,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _focused = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterOpacity;
  late final Animation<Offset> _enterSlide;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: NeoTheme.durationSlow,
    );
    _enterOpacity = CurvedAnimation(
        parent: _enterController, curve: NeoTheme.smoothOut);
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _enterController, curve: NeoTheme.smoothOut));

    Future.delayed(
      Duration(milliseconds: 60 * widget.index),
      () {
        if (mounted) _enterController.forward();
      },
    );
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final accent =
        widget.isMain ? NeoTheme.prestigeGold : NeoTheme.primaryRed;

    return FadeTransition(
      opacity: _enterOpacity,
      child: SlideTransition(
        position: _enterSlide,
        child: Focus(
          autofocus: widget.autofocus && useFocus,
          canRequestFocus: useFocus,
          onFocusChange: (f) {
            if (_focused != f) setState(() => _focused = f);
          },
          onKeyEvent: useFocus
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.space)) {
                    widget.onTap();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.96 : (_focused && useFocus ? 1.04 : 1.0),
              duration: NeoTheme.durationFast,
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                decoration: BoxDecoration(
                  gradient: NeoTheme.glassGradient,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
                  border: Border.all(
                    color: (_focused && useFocus)
                        ? accent
                        : accent.withValues(alpha: 0.18),
                    width: (_focused && useFocus) ? 2 : 0.5,
                  ),
                  boxShadow: [
                    ...NeoTheme.shadowLevel2,
                    if (_focused && useFocus)
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: widget.isMain
                                  ? NeoTheme.premiumGradient
                                  : NeoTheme.heroGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.username.isNotEmpty
                                    ? widget.username[0].toUpperCase()
                                    : '?',
                                style: NeoTheme.headlineMedium(context).copyWith(
                                  color: widget.isMain ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: NeoTheme.bgBase,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Icon(
                                widget.isMain
                                    ? Icons.workspace_premium_rounded
                                    : widget.hasPassword
                                        ? Icons.lock_outline_rounded
                                        : Icons.play_arrow_rounded,
                                size: 12,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: NeoTheme.labelMedium(context).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isMain ? 'Principal' : 'Profil',
                        style: NeoTheme.labelSmall(context).copyWith(
                          color: widget.isMain
                              ? NeoTheme.prestigeGold
                              : NeoTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
