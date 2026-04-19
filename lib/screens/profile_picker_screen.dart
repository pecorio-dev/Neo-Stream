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
    with TickerProviderStateMixin {
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
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: NeoTheme.durationSplash,
        transitionsBuilder: (_, animation, __, child) =>
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: NeoTheme.heroGradient,
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: NeoTheme.headlineMedium(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(username, style: NeoTheme.titleLarge(context)),
                const SizedBox(height: 4),
                Text(
                  'Entrez le mot de passe du profil',
                  style: NeoTheme.bodySmall(context),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: NeoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
                ),
                const SizedBox(height: 18),
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
                        onPressed: () => Navigator.of(ctx).pop(controller.text),
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
    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: Container(
        decoration: const BoxDecoration(gradient: NeoTheme.auroraGradient),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),
              Text(
                'NEO STREAM',
                style: NeoTheme.headlineLarge(
                  context,
                ).copyWith(letterSpacing: 3),
              ),
              const SizedBox(height: 24),
              Text(
                'Qui regarde ?',
                style: NeoTheme.displayMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez un profil pour reprendre la lecture instantanement.',
                textAlign: TextAlign.center,
                style: NeoTheme.bodyMedium(context),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: NeoTheme.primaryRed,
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeController,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: NeoTheme.screenPadding(context).left,
                            vertical: 16,
                          ),
                          child: FocusTraversalGroup(
                            policy: OrderedTraversalPolicy(),
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 24,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildProfileCard(
                                  username: widget.mainUser.username,
                                  subtitle: 'Compte principal',
                                  isMain: true,
                                  index: 0,
                                  onTap: _navigateToHome,
                                  autofocus: true,
                                ),
                                ..._subAccounts.asMap().entries.map((entry) {
                                  final sub = entry.value;
                                  final requirePass = sub['require_password'];
                                  final hasPassword =
                                      requirePass == 1 ||
                                      requirePass == true ||
                                      requirePass == '1';
                                  return _buildProfileCard(
                                    username:
                                        sub['username']?.toString() ?? 'Profil',
                                    subtitle: hasPassword
                                        ? 'Code demande'
                                        : 'Acces direct',
                                    isMain: false,
                                    hasPassword: hasPassword,
                                    index: entry.key + 1,
                                    onTap: () => _selectSubAccount(sub),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Focus(
                  canRequestFocus: NeoTheme.needsFocusNavigation(context),
                  onKeyEvent: NeoTheme.needsFocusNavigation(context)
                      ? (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.enter ||
                               event.logicalKey == LogicalKeyboardKey.select)) {
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
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubAccountsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_accounts_rounded),
                    label: const Text('Gerer les profils'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String username,
    required String subtitle,
    required bool isMain,
    bool hasPassword = false,
    required int index,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return _StaggeredProfileCard(
      delay: Duration(milliseconds: 60 * index),
      child: _ProfileCardContent(
        username: username,
        subtitle: subtitle,
        isMain: isMain,
        hasPassword: hasPassword,
        onTap: onTap,
        autofocus: autofocus,
      ),
    );
  }
}

class _StaggeredProfileCard extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _StaggeredProfileCard({required this.delay, required this.child});

  @override
  State<_StaggeredProfileCard> createState() => _StaggeredProfileCardState();
}

class _StaggeredProfileCardState extends State<_StaggeredProfileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NeoTheme.durationSlow,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: NeoTheme.smoothOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: NeoTheme.smoothOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _ProfileCardContent extends StatefulWidget {
  final String username;
  final String subtitle;
  final bool isMain;
  final bool hasPassword;
  final VoidCallback onTap;

  final bool autofocus;

  const _ProfileCardContent({
    required this.username,
    required this.subtitle,
    required this.isMain,
    required this.hasPassword,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_ProfileCardContent> createState() => _ProfileCardContentState();
}

class _ProfileCardContentState extends State<_ProfileCardContent> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isMain ? NeoTheme.prestigeGold : NeoTheme.primaryRed;
    final useFocus = NeoTheme.needsFocusNavigation(context);

    return Focus(
      autofocus: widget.autofocus && useFocus,
      canRequestFocus: useFocus,
      onFocusChange: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
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
          scale: _pressed ? 0.97 : (_focused && useFocus ? 1.05 : 1),
          duration: NeoTheme.durationFast,
          child: AnimatedContainer(
            duration: NeoTheme.durationFast,
            width: NeoTheme.isTV(context) ? 180 : 156,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: NeoTheme.glassGradient,
              borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
              border: Border.all(
                color: (_focused && useFocus)
                    ? accent
                    : accent.withValues(alpha: 0.2),
                width: (_focused && useFocus) ? 2.5 : 0.5,
              ),
              boxShadow: [
                ...NeoTheme.shadowLevel2,
                if (_focused && useFocus)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 4,
                  )
                else
                  BoxShadow(
                    color: accent.withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: 0,
                  ),
              ],
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isMain
                          ? NeoTheme.premiumGradient
                          : NeoTheme.heroGradient,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.username.isNotEmpty
                            ? widget.username[0].toUpperCase()
                            : '?',
                        style: NeoTheme.displayMedium(context).copyWith(
                          color: widget.isMain ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: NeoTheme.bgBase,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(
                        widget.isMain
                            ? Icons.workspace_premium_rounded
                            : widget.hasPassword
                            ? Icons.lock_outline_rounded
                            : Icons.play_arrow_rounded,
                        size: 16,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: NeoTheme.titleMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: NeoTheme.bodySmall(context).copyWith(
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
    );
  }
}
