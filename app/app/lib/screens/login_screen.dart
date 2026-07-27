import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../providers/providers.dart';
import 'home_screen.dart';
import 'payment_wall_screen.dart';
import 'profile_selection_screen.dart';
import 'tv/tv_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _obscurePassword = true;
  bool _isRegisterMode = false;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: NeoTheme.durationSlow,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: NeoTheme.smoothOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _introController, curve: NeoTheme.smoothOut),
        );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
    });
    context.read<AuthProvider>().clearError();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final email = _emailController.text.trim();

    if (username.isEmpty ||
        password.isEmpty ||
        (_isRegisterMode && email.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merci de remplir tous les champs requis.'),
        ),
      );
      return;
    }

    bool success;
    if (_isRegisterMode) {
      success = await auth.register(username, email, password);
    } else {
      success = await auth.login(username, password);
    }

    if (!mounted || !success) {
      return;
    }

    final user = auth.user;
    final Widget destination;
    if (user == null || !user.premiumActive) {
      destination = PaymentWallScreen();
    } else if (!user.isSubAccount) {
      destination = ProfileSelectionScreen(mainUser: user);
    } else {
      destination = NeoTheme.isTV(context) ? const TVShell() : HomeScreen();
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_1, animation, _2) => destination,
        transitionDuration: NeoTheme.durationSlow,
        transitionsBuilder: (_1, animation, _2, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final isTV = NeoTheme.isTV(context);

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF12122A), Color(0xFF0A0A18), Color(0xFF06060C)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  NeoTheme.screenPadding(context).horizontal / 2;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isTV ? 28 : 20,
                    horizontalPadding,
                    28,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 1180 : 460,
                        ),
                        child: isWide
                            ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: _buildHeroPanel(context),
                                    ),
                                    SizedBox(width: 24),
                                    Expanded(
                                      flex: 9,
                                      child: _buildFormPanel(context, auth),
                                    ),
                                  ],
                                )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeroPanel(context, compact: true),
                                  SizedBox(height: 20),
                                  _buildFormPanel(context, auth),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14142C), Color(0xFF0A0A18)],
        ),
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NEO',
                style: Neo.displayLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'STREAM',
                style: Neo.displayLarge(context).copyWith(
                  fontWeight: FontWeight.w200,
                  letterSpacing: 6,
                  color: Neo.textPrimary(context).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              gradient: NeoTheme.heroGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(height: 16),
          Text(
            compact
                ? 'Vos films, séries et anime — toujours là où vous êtes.'
                : 'Un catalogue vivant de films, séries et anime, en un accès à vie.',
            style: Neo.bodyLarge(context).copyWith(
              color: Neo.textTertiary(context),
              height: 1.5,
            ),
          ),
          SizedBox(height: 28),
          _buildHeroMetric(
            context,
            icon: Icons.collections_bookmark_rounded,
            title: 'Films, séries, anime',
            subtitle: 'Un catalogue organisé, sans publicité, sans bruit.',
          ),
          SizedBox(height: 16),
          _buildHeroMetric(
            context,
            icon: Icons.sync_rounded,
            title: 'Reprenez où vous étiez',
            subtitle: 'Votre avancement disponible sur tous vos appareils.',
          ),
          SizedBox(height: 16),
          _buildHeroMetric(
            context,
            icon: Icons.all_inclusive_rounded,
            title: 'Accès à vie',
            subtitle: 'Un paiement unique de 10€ — aucun abonnement mensuel.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Neo.titleMedium(context)),
              SizedBox(height: 3),
              Text(
                subtitle,
                style: Neo.bodySmall(context).copyWith(
                  color: Neo.textDisabled(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel(BuildContext context, AuthProvider auth) {
    final isTV = NeoTheme.isTV(context);

    return Container(
      padding: EdgeInsets.all(isTV ? 32 : 24),
      decoration: BoxDecoration(
        gradient: Neo.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: Neo.bgBorder(context).withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              _isRegisterMode ? 'Créer un compte' : 'Connexion',
              style: Neo.headlineLarge(context),
            ),
            SizedBox(height: 8),
            Text(
              _isRegisterMode
                  ? 'Votre compte, votre accès. Activez-le après inscription (10€ à vie).'
                  : 'Reprenez exactement là où vous vous êtes arrêté.',
              style: Neo.bodyMedium(context).copyWith(color: Neo.textTertiary(context)),
            ),
            SizedBox(height: 22),
            Focus(
              // Ne pas capter le focus : laisser le D-pad/OK atteindre
              // directement le TextField pour ouvrir le clavier.
              canRequestFocus: false,
              skipTraversal: true,
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return AnimatedContainer(
                    duration: NeoTheme.durationFast,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      border: Border.all(
                        color: isFocused ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: isFocused ? 2.0 : 0.0,
                      ),
                      boxShadow: isFocused ? NeoTheme.shadowLevel1 : null,
                    ),
                    child: TextField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      style: NeoTheme.bodyLarge(
                        context,
                      ).copyWith(color: Neo.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Nom utilisateur',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: Neo.textTertiary(context),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                    ),
                  );
                }
              ),
            ),
            if (_isRegisterMode) ...[
              SizedBox(height: 16),
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                child: Builder(
                  builder: (ctx) {
                    final isFocused = Focus.of(ctx).hasFocus;
                    return AnimatedContainer(
                      duration: NeoTheme.durationFast,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: isFocused ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: isFocused ? 2.0 : 0.0,
                        ),
                        boxShadow: isFocused ? NeoTheme.shadowLevel1 : null,
                      ),
                      child: TextField(
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        style: NeoTheme.bodyLarge(
                          context,
                        ).copyWith(color: Neo.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Neo.textTertiary(context),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    );
                  }
                ),
              ),
            ],
            SizedBox(height: 16),
            Focus(
              // Ne pas capter le focus : laisser le D-pad/OK atteindre
              // directement le TextField pour ouvrir le clavier.
              canRequestFocus: false,
              skipTraversal: true,
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return AnimatedContainer(
                    duration: NeoTheme.durationFast,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      border: Border.all(
                        color: isFocused ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: isFocused ? 2.0 : 0.0,
                      ),
                      boxShadow: isFocused ? NeoTheme.shadowLevel1 : null,
                    ),
                    child: TextField(
                      controller: _passwordController,
                      autofillHints: _isRegisterMode
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      obscureText: _obscurePassword,
                      style: NeoTheme.bodyLarge(
                        context,
                      ).copyWith(color: Neo.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: Neo.textTertiary(context),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Neo.textTertiary(context),
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  );
                }
              ),
            ),
            if (auth.error != null) ...[
              SizedBox(height: 18),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NeoTheme.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  border: Border.all(
                    color: NeoTheme.errorRed.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: NeoTheme.errorRed,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        auth.error!,
                        style: NeoTheme.bodySmall(
                          context,
                        ).copyWith(color: NeoTheme.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 22),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.space)) {
                  if (!auth.isLoading) _submit();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return AnimatedScale(
                    scale: isFocused ? 1.04 : 1.0,
                    duration: NeoTheme.durationFast,
                    child: SizedBox(
                      height: isTV ? 58 : 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFocused ? NeoTheme.primaryRedHover : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                            side: BorderSide(
                              color: isFocused ? Colors.white : Colors.transparent,
                              width: isFocused ? 2.0 : 0.0,
                            ),
                          ),
                          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        child: auth.isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isRegisterMode ? 'Creer mon compte' : 'Se connecter',
                                style: Neo.titleMedium(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  );
                }
              ),
            ),
            SizedBox(height: 14),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.space)) {
                  _toggleMode();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return AnimatedScale(
                    scale: isFocused ? 1.04 : 1.0,
                    duration: NeoTheme.durationFast,
                    child: OutlinedButton(
                      onPressed: _toggleMode,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isFocused ? Neo.bgHover(context) : Colors.transparent,
                        side: BorderSide(
                          color: isFocused ? Theme.of(context).colorScheme.primary : Neo.bgBorder(context).withValues(alpha: 0.25),
                          width: isFocused ? 2.0 : 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        ),
                      ),
                      child: Text(
                        _isRegisterMode
                            ? 'Déjà un compte ? Se connecter'
                            : 'Nouveau ? Créer un compte',
                        style: Neo.labelLarge(context).copyWith(color: isFocused ? Colors.white : NeoTheme.infoCyan),
                      ),
                    ),
                  );
                }
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 1,
                  color: Neo.bgBorder(context).withValues(alpha: 0.3),
                ),
                SizedBox(width: 10),
                Text(
                  'NEO-STREAM',
                  style: Neo.labelSmall(context).copyWith(
                    letterSpacing: 3,
                    color: Neo.textDisabled(context).withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  width: 24,
                  height: 1,
                  color: Neo.bgBorder(context).withValues(alpha: 0.3),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}
