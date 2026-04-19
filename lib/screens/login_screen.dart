import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import 'home_screen.dart';
import 'profile_picker_screen.dart';

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
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
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
        const SnackBar(
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
    final destination = user != null && user.premiumActive && !user.isSubAccount
        ? ProfilePickerScreen(mainUser: user)
        : const HomeScreen();

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => destination,
        transitionDuration: NeoTheme.durationSlow,
        transitionsBuilder: (_, animation, _, child) {
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
      backgroundColor: NeoTheme.bgBase,
      body: Container(
        decoration: const BoxDecoration(
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
                                    const SizedBox(width: 24),
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
                                  const SizedBox(height: 20),
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
    final isTV = NeoTheme.isTV(context);

    return Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14142C), Color(0xFF0A0A18)],
        ),
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: NeoTheme.primaryRed.withValues(alpha: 0.15),
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
                style: NeoTheme.displayLarge(context).copyWith(
                  color: NeoTheme.primaryRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'STREAM',
                style: NeoTheme.displayLarge(context).copyWith(
                  fontWeight: FontWeight.w200,
                  letterSpacing: 6,
                  color: NeoTheme.textPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              gradient: NeoTheme.heroGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            compact
                ? 'Cinema et series optimises pour mobile, tablette et TV.'
                : 'Une interface fluide, lisible et securisee sur tous les ecrans.',
            style: NeoTheme.bodyLarge(context).copyWith(
              color: NeoTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 28),
          _buildHeroMetric(
            context,
            icon: Icons.tv_rounded,
            title: 'Navigation TV',
            subtitle: 'Parcours clair et zones tactiles larges.',
          ),
          const SizedBox(height: 16),
          _buildHeroMetric(
            context,
            icon: Icons.shield_outlined,
            title: 'Acces protege',
            subtitle:
                'Connexion stable et protegee pendant toute la navigation.',
          ),
          const SizedBox(height: 16),
          _buildHeroMetric(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'Responsive natif',
            subtitle: 'Sans overflow sur telephone, tablette et grand ecran.',
          ),
          if (isTV) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: NeoTheme.infoCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: NeoTheme.infoCyan.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                'TV mode: utilisez les touches directionnelles et OK.',
                style: NeoTheme.labelMedium(
                  context,
                ).copyWith(color: NeoTheme.infoCyan),
              ),
            ),
          ],
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
            color: NeoTheme.primaryRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
            border: Border.all(
              color: NeoTheme.primaryRed.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: NeoTheme.primaryRed, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NeoTheme.titleMedium(context)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: NeoTheme.bodySmall(context).copyWith(
                  color: NeoTheme.textDisabled,
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
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.2),
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
              _isRegisterMode ? 'Creer un compte' : 'Connexion',
              style: NeoTheme.headlineLarge(context),
            ),
            const SizedBox(height: 8),
            Text(
              _isRegisterMode
                  ? 'Activez votre acces en quelques secondes.'
                  : 'Reprenez votre lecture sur n importe quel ecran.',
              style: NeoTheme.bodyMedium(context),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _usernameController,
              autofillHints: const [AutofillHints.username],
              style: NeoTheme.bodyLarge(
                context,
              ).copyWith(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nom utilisateur',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: NeoTheme.textTertiary,
                ),
              ),
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            if (_isRegisterMode) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                style: NeoTheme.bodyLarge(
                  context,
                ).copyWith(color: NeoTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: NeoTheme.textTertiary,
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              autofillHints: _isRegisterMode
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              obscureText: _obscurePassword,
              style: NeoTheme.bodyLarge(
                context,
              ).copyWith(color: NeoTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: NeoTheme.textTertiary,
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
                    color: NeoTheme.textTertiary,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
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
                    const Icon(
                      Icons.error_outline_rounded,
                      color: NeoTheme.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
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
            const SizedBox(height: 22),
            SizedBox(
              height: isTV ? 58 : 52,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeoTheme.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  ),
                  shadowColor: NeoTheme.primaryRed.withValues(alpha: 0.3),
                  overlayColor: NeoTheme.primaryRed.withValues(alpha: 0.3),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRegisterMode ? 'Creer mon compte' : 'Se connecter',
                        style: NeoTheme.titleMedium(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _toggleMode,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.25),
                  width: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                ),
              ),
              child: Text(
                _isRegisterMode
                    ? 'Deja un compte ? Connexion'
                    : 'Pas encore de compte ? Inscription',
                style: NeoTheme.labelLarge(
                  context,
                ).copyWith(color: NeoTheme.infoCyan),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Neo-Stream 2026',
              textAlign: TextAlign.center,
              style: NeoTheme.labelSmall(context),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
