import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'sub_accounts_screen.dart';
import 'tv/tv_shell.dart';

/// Unified profile selection screen.
///
/// Single source of truth = API sub-accounts. Works for both TV (D-pad /
/// remote) and phone (touch). After a profile is chosen it routes to the
/// TV home or the phone home depending on the viewport.
class ProfileSelectionScreen extends StatefulWidget {
  final User mainUser;

  ProfileSelectionScreen({super.key, required this.mainUser});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
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

  void _goHome() {
    final useTv = NeoTheme.isTV(context);
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_1, _2, _3) =>
            useTv ? TVShell() : HomeScreen(),
        transitionDuration: NeoTheme.durationSplash,
        transitionsBuilder: (_1, animation, _2, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _openManage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SubAccountsScreen()),
    );
    if (!mounted) return;
    // Refresh the list after managing profiles.
    setState(() => _isLoading = true);
    await _loadProfiles();
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
      _goHome();
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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
                ),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
                      gradient: Neo.heroGradient(ctx),
                    ),
                    child: Center(
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: Neo.headlineMedium(ctx).copyWith(
                          color: Neo.onHeroGradient(ctx),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(username, style: NeoTheme.titleLarge(ctx)),
                  SizedBox(height: 4),
                  Text('Entrez le mot de passe', style: NeoTheme.bodySmall(ctx)),
                  SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    style: TextStyle(color: Neo.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
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
                    onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Annuler'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(controller.text),
                          child: Text('Continuer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _columnsFor(double width, int count) {
    if (count <= 1) return 1;
    if (width >= 1400) return 6;
    if (width >= 1100) return 5;
    if (width >= 820) return 4;
    if (width >= 560) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final isTv = NeoTheme.isTV(context);

    // index 0 = main profile, then sub-accounts, last = "add / manage" tile.
    final tiles = <_TileData>[
      _TileData.main(widget.mainUser.username),
      ..._subAccounts.map((s) {
        final requirePass = s['require_password'];
        final hasPassword = requirePass == 1 ||
            requirePass == true ||
            requirePass == '1';
        return _TileData.sub(
          s['username']?.toString() ?? 'Profil',
          hasPassword,
          Map<String, dynamic>.from(s),
        );
      }),
      _TileData.add(),
    ];

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Container(
        decoration: BoxDecoration(
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
              Padding(
                padding: EdgeInsets.fromLTRB(24, isTv ? 40 : 24, 24, 0),
                child: Column(
                  children: [
                    Text(
                      'Qui regarde ?',
                      textAlign: TextAlign.center,
                      style: Neo.headlineLarge(context).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: isTv ? 40 : null,
                        // Écran toujours sombre → texte figé clair.
                        color: NeoTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choisissez votre profil',
                      textAlign: TextAlign.center,
                      style: Neo.bodySmall(context).copyWith(
                        color: NeoTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTv ? 40 : 24),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeController,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = _columnsFor(
                              constraints.maxWidth.clamp(0, 1200),
                              tiles.length,
                            );
                            return Center(
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: 1100),
                                child: GridView.builder(
                                  padding:
                                      EdgeInsets.fromLTRB(32, 0, 32, 40),
                                  shrinkWrap: true,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 18,
                                    crossAxisSpacing: 18,
                                    mainAxisExtent: isTv ? 190 : 160,
                                  ),
                                  itemCount: tiles.length,
                                  itemBuilder: (context, index) {
                                    final tile = tiles[index];
                                    return _ProfileTile(
                                      data: tile,
                                      index: index,
                                      autofocus: index == 0,
                                      onTap: () {
                                        switch (tile.kind) {
                                          case _TileKind.main:
                                            _goHome();
                                            break;
                                          case _TileKind.sub:
                                            _selectSubAccount(tile.raw!);
                                            break;
                                          case _TileKind.add:
                                            _openManage();
                                            break;
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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

enum _TileKind { main, sub, add }

class _TileData {
  final _TileKind kind;
  final String label;
  final bool hasPassword;
  final Map<String, dynamic>? raw;

  const _TileData._(this.kind, this.label, this.hasPassword, this.raw);

  factory _TileData.main(String name) =>
      _TileData._(_TileKind.main, name, false, null);
  factory _TileData.sub(String name, bool hasPassword,
          Map<String, dynamic> raw) =>
      _TileData._(_TileKind.sub, name, hasPassword, raw);
  factory _TileData.add() =>
      const _TileData._(_TileKind.add, 'Gérer', false, null);
}

class _ProfileTile extends StatefulWidget {
  final _TileData data;
  final int index;
  final VoidCallback onTap;
  final bool autofocus;

  _ProfileTile({
    required this.data,
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
    _enterOpacity =
        CurvedAnimation(parent: _enterController, curve: NeoTheme.smoothOut);
    _enterSlide = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _enterController, curve: NeoTheme.smoothOut));

    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _enterController.forward();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final isMain = widget.data.kind == _TileKind.main;
    final isAdd = widget.data.kind == _TileKind.add;
    final accent = isMain ? NeoTheme.prestigeGold : Theme.of(context).colorScheme.primary;

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
              scale: _pressed ? 0.96 : (_focused && useFocus ? 1.05 : 1.0),
              duration: NeoTheme.durationFast,
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                decoration: BoxDecoration(
                  gradient: Neo.glassGradient(context),
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
                  padding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _avatar(context, accent, isMain, isAdd),
                      SizedBox(height: 10),
                      Text(
                        widget.data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Neo.labelMedium(context).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isAdd
                            ? 'Profils'
                            : isMain
                                ? 'Principal'
                                : 'Profil',
                        style: Neo.labelSmall(context).copyWith(
                          color: isMain
                              ? NeoTheme.prestigeGold
                              : Neo.textSecondary(context),
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

  Widget _avatar(BuildContext context, Color accent, bool isMain, bool isAdd) {
    if (isAdd) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: Neo.textSecondary(context).withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.manage_accounts_rounded,
            color: Neo.textSecondary(context), size: 28),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                isMain ? NeoTheme.premiumGradient : Neo.heroGradient(context),
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
              widget.data.label.isNotEmpty
                  ? widget.data.label[0].toUpperCase()
                  : '?',
              style: Neo.headlineMedium(context).copyWith(
                color: isMain ? Colors.black : Neo.onHeroGradient(context),
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
              color: Neo.bgBase(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Icon(
              isMain
                  ? Icons.workspace_premium_rounded
                  : widget.data.hasPassword
                      ? Icons.lock_outline_rounded
                      : Icons.play_arrow_rounded,
              size: 12,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}
