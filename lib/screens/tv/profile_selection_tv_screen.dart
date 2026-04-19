import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/tv_config.dart';
import '../../providers/tv_profile_provider.dart';
import '../../widgets/tv_focusable_card.dart';

class ProfileSelectionTVScreen extends StatefulWidget {
  final VoidCallback onProfileSelected;

  const ProfileSelectionTVScreen({
    super.key,
    required this.onProfileSelected,
  });

  @override
  State<ProfileSelectionTVScreen> createState() => _ProfileSelectionTVScreenState();
}

class _ProfileSelectionTVScreenState extends State<ProfileSelectionTVScreen> {
  static const List<String> _avatarEmojis = ['👤', '🎬', '🎭', '🔥', '⚡', '🌟', '🎮', '🚀'];
  static const List<Color> _avatarColors = [
    Color(0xFFE50914),
    Color(0xFFB81D24),
    Color(0xFF1E1E3A),
    Color(0xFF2D5BFF),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFF1ABC9C),
    Color(0xFFE91E63),
  ];

  void _selectProfile(TVProfile profile) {
    if (profile.pinCode != null && profile.pinCode!.isNotEmpty) {
      _showPinDialog(profile);
    } else {
      context.read<TVProfileProvider>().selectProfile(profile);
      widget.onProfileSelected();
    }
  }

  void _showPinDialog(TVProfile profile) {
    final pinController = TextEditingController();
    bool hasError = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: TVTheme.surfaceColor,
              title: const Text('Entrez le code PIN', style: TextStyle(color: TVTheme.textPrimary)),
              content: TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: TVTheme.textPrimary, fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  errorText: hasError ? 'Code PIN incorrect' : null,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.textSecondary)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.accentRed)),
                ),
                onSubmitted: (value) {
                  if (value == profile.pinCode) {
                    Navigator.of(ctx).pop();
                    context.read<TVProfileProvider>().selectProfile(profile);
                    widget.onProfileSelected();
                  } else {
                    setDialogState(() => hasError = true);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    if (pinController.text == profile.pinCode) {
                      Navigator.of(ctx).pop();
                      context.read<TVProfileProvider>().selectProfile(profile);
                      widget.onProfileSelected();
                    } else {
                      setDialogState(() => hasError = true);
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProfileDialog() {
    final usernameController = TextEditingController();
    final pinController = TextEditingController();
    String selectedEmoji = _avatarEmojis[0];
    int selectedColorIndex = 0;
    bool requirePin = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: TVTheme.surfaceColor,
              title: const Text('Nouveau profil', style: TextStyle(color: TVTheme.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _avatarColors[selectedColorIndex],
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(selectedEmoji, style: const TextStyle(fontSize: 36))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Avatar', style: TextStyle(color: TVTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(_avatarEmojis.length, (i) {
                        final isSelected = _avatarEmojis[i] == selectedEmoji;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedEmoji = _avatarEmojis[i]),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? _avatarColors[selectedColorIndex] : TVTheme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? TVTheme.accentRed : Colors.transparent, width: 2),
                            ),
                            child: Center(child: Text(_avatarEmojis[i], style: const TextStyle(fontSize: 24))),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Couleur', style: TextStyle(color: TVTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(_avatarColors.length, (i) {
                        final isSelected = i == selectedColorIndex;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColorIndex = i),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _avatarColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(color: TVTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nom du profil',
                        labelStyle: TextStyle(color: TVTheme.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.textSecondary)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.accentRed)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: requirePin,
                      onChanged: (value) => setDialogState(() => requirePin = value),
                      title: const Text('Proteger par PIN', style: TextStyle(color: TVTheme.textPrimary)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (requirePin) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        style: const TextStyle(color: TVTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Code PIN (4 chiffres)',
                          labelStyle: TextStyle(color: TVTheme.textSecondary),
                          counterText: '',
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.textSecondary)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TVTheme.accentRed)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final username = usernameController.text.trim();
                    if (username.isEmpty) return;
                    await context.read<TVProfileProvider>().createProfile(
                      username: username,
                      avatarEmoji: selectedEmoji,
                      avatarColor: _avatarColors[selectedColorIndex].value,
                      pinCode: requirePin ? pinController.text : null,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
                  child: const Text('Creer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TVTheme.backgroundDark,
      body: Container(
        decoration: TVTheme.screenDecoration,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                'QUI REGARDE ?',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: TVTheme.textPrimary,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selectionnez un profil pour continuer',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: TVTheme.textSecondary),
              ),
              const SizedBox(height: 60),
              Expanded(
                child: Consumer<TVProfileProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: TVTheme.accentRed));
                    }

                    final profiles = provider.profiles;

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.7,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                      ),
                      itemCount: profiles.length + 1,
                      itemBuilder: (context, index) {
                        if (index < profiles.length) {
                          final profile = profiles[index];
                          return _ProfileCard(
                            profile: profile,
                            onTap: () => _selectProfile(profile),
                          );
                        }
                        return _AddProfileCard(onTap: _showAddProfileDialog);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final TVProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = profile.avatarColor != null
        ? Color(profile.avatarColor!)
        : TVTheme.accentRed;

    return TVFocusableCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(profile.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.username,
            style: const TextStyle(color: TVTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (profile.pinCode != null && profile.pinCode!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 12, color: TVTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Protege', style: TextStyle(color: TVTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TVFocusableCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: TVTheme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: TVTheme.textSecondary, width: 2),
            ),
            child: const Center(child: Icon(Icons.add, color: TVTheme.textSecondary, size: 36)),
          ),
          const SizedBox(height: 16),
          const Text('Ajouter', style: TextStyle(color: TVTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Nouveau profil', style: TextStyle(color: TVTheme.textDisabled, fontSize: 11)),
        ],
      ),
    );
  }
}