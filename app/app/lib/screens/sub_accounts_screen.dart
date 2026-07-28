import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/sub_account.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';

class SubAccountsScreen extends StatefulWidget {
  SubAccountsScreen({super.key});

  @override
  State<SubAccountsScreen> createState() => _SubAccountsScreenState();
}

class _SubAccountsScreenState extends State<SubAccountsScreen> {
  final ApiService _api = ApiService();

  List<SubAccount> _subAccounts = <SubAccount>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubAccounts();
  }

  Future<void> _loadSubAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getSubAccounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _subAccounts = response.map(SubAccount.fromJson).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateDialog() async {
    await _showEditorDialog();
  }

  Future<void> _showEditDialog(SubAccount subAccount) async {
    await _showEditorDialog(existing: subAccount);
  }

  Future<void> _showEditorDialog({SubAccount? existing}) async {
    final usernameController = TextEditingController(
      text: existing?.username ?? '',
    );
    final passwordController = TextEditingController();
    bool requirePassword = existing?.requirePassword ?? true;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Color(0xFF18182A),
              title: Text(
                existing == null ? 'Nouveau profil' : 'Modifier le profil',
                style: Neo.titleLarge(context),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
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
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: NeoTheme.bodyLarge(
                        context,
                      ).copyWith(color: Neo.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: existing == null
                            ? 'Mot de passe'
                            : 'Nouveau mot de passe',
                        helperText: existing == null
                            ? 'Minimum 6 caracteres'
                            : 'Laisser vide pour conserver le mot de passe actuel',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: Neo.textTertiary(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      value: requirePassword,
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      title: Text(
                        'Mot de passe requis a la connexion',
                        style: NeoTheme.bodyMedium(
                          context,
                        ).copyWith(color: Neo.textPrimary(context)),
                      ),
                      onChanged: (value) {
                        setDialogState(() => requirePassword = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Annuler',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: Neo.textSecondary(context)),
                  ),
                ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final username = usernameController.text.trim();
                          final password = passwordController.text.trim();

                          if (username.isEmpty) {
                            _showSnack(
                              'Le nom utilisateur est requis.',
                              error: true,
                            );
                            return;
                          }

                          if (existing == null && password.length < 6) {
                            _showSnack(
                              'Le mot de passe doit contenir 6 caracteres minimum.',
                              error: true,
                            );
                            return;
                          }

                          if (existing != null &&
                              password.isNotEmpty &&
                              password.length < 6) {
                            _showSnack(
                              'Le nouveau mot de passe doit contenir 6 caracteres minimum.',
                              error: true,
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            if (existing == null) {
                              await _api.createSubAccount(
                                username,
                                password,
                                requirePassword: requirePassword,
                              );
                            } else {
                              await _api.updateSubAccount(
                                existing.id,
                                username: username != existing.username
                                    ? username
                                    : null,
                                password: password.isNotEmpty ? password : null,
                                requirePassword:
                                    requirePassword != existing.requirePassword
                                    ? requirePassword
                                    : null,
                              );
                            }

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop();
                            _showSnack(
                              existing == null
                                  ? 'Profil cree avec succes.'
                                  : 'Profil mis a jour.',
                            );
                            await _loadSubAccounts();
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            try { setDialogState(() => isSubmitting = false); } catch (_) {}
                            _showSnack('Erreur: $error', error: true);
                          }
                        },
                  child: Text(
                    existing == null ? 'Creer' : 'Enregistrer',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(SubAccount subAccount) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: Color(0xFF18182A),
              title: Text(
                'Supprimer ce profil ?',
                style: Neo.titleLarge(context),
              ),
              content: Text(
                'Le profil ${subAccount.username} sera retire definitivement.',
                style: Neo.bodyMedium(context),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Annuler',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: Neo.textSecondary(context)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Supprimer',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: NeoTheme.errorRed),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await _api.deleteSubAccount(subAccount.id);
      if (!mounted) {
        return;
      }
      _showSnack('Profil supprime.');
      await _loadSubAccounts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Erreur: $error', error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? NeoTheme.errorRed : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Jamais';
    }
    try {
      final date = DateTime.parse(value).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return value.split(' ').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final maxSubs = user?.maxSubAccounts ?? 4;
    final canAddMore = _subAccounts.length < maxSubs;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        backgroundColor: Neo.bgBase(context),
        title: Text('Profils', style: Neo.headlineMedium(context)),
        actions: [
          if (auth.isPremium && canAddMore)
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: Icon(Icons.add_rounded),
                label: Text('Ajouter'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          auth.isPremium && canAddMore && !NeoTheme.isTV(context)
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add_rounded),
              label: Text('Ajouter un profil'),
            )
          : null,
      body: !auth.isPremium
          ? _buildPremiumGate(context)
          : _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            )
          : _error != null
          ? _buildErrorState(context)
          : RefreshIndicator(
              onRefresh: _loadSubAccounts,
              color: Theme.of(context).colorScheme.primary,
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        NeoTheme.screenPadding(context).left,
                        12,
                        NeoTheme.screenPadding(context).right,
                        16,
                      ),
                      child: _buildSummary(context, maxSubs),
                    ),
                  ),
                  if (_subAccounts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, canAddMore),
                    )
                  else
                    _buildAccountsSliver(context),
                ],
              ),
            ),
    ),
    );
  }

  Widget _buildPremiumGate(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
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
                color: NeoTheme.prestigeGold.withValues(alpha: 0.15),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeoTheme.prestigeGold.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: NeoTheme.prestigeGold,
                    size: 40,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Fonction reservee au Premium',
                  textAlign: TextAlign.center,
                  style: Neo.headlineMedium(context),
                ),
                SizedBox(height: 10),
                Text(
                  'Creez jusqu a 4 profils supplementaires pour la famille, avec mot de passe optionnel et historique separe.',
                  textAlign: TextAlign.center,
                  style: Neo.bodyMedium(context),
                ),
                SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: NeoTheme.prestigeGold,
                    foregroundColor: Colors.black,
                  ),
                  icon: Icon(Icons.arrow_back_rounded),
                  label: Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: NeoTheme.errorRed,
              size: 48,
            ),
            SizedBox(height: 16),
            Text('Chargement impossible', style: Neo.titleLarge(context)),
            SizedBox(height: 8),
            Text(
              _error ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
              style: Neo.bodyMedium(context),
            ),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadSubAccounts,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, int maxSubs) {
    final remaining = (maxSubs - _subAccounts.length).clamp(0, maxSubs);

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
        ),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.prestigeGold.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final children = [
            _SummaryStat(
              icon: Icons.people_outline_rounded,
              label: 'Profils actifs',
              value: '${_subAccounts.length}/$maxSubs',
              color: Theme.of(context).colorScheme.primary,
            ),
            _SummaryStat(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Places libres',
              value: '$remaining',
              color: remaining > 0
                  ? NeoTheme.successGreen
                  : NeoTheme.warningOrange,
            ),
            _SummaryStat(
              icon: Icons.lock_outline_rounded,
              label: 'Protection',
              value: 'Controle par profil',
              color: NeoTheme.infoCyan,
            ),
          ];

          return wide
              ? Row(
                  children:
                      children
                          .expand(
                            (child) => [
                              Expanded(child: child),
                              SizedBox(width: 12),
                            ],
                          )
                          .toList()
                        ..removeLast(),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      children
                          .expand(
                            (child) => [child, SizedBox(height: 12)],
                          )
                          .toList()
                        ..removeLast(),
                );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool canAddMore) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Neo.surfaceGradient,
                  border: Border.all(
                    color: Neo.bgBorder(context).withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: Neo.textDisabled(context),
                  size: 40,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Aucun profil secondaire',
                style: Neo.titleLarge(context),
              ),
              SizedBox(height: 8),
              Text(
                'Ajoutez des espaces distincts pour la famille avec leur propre acces.',
                textAlign: TextAlign.center,
                style: Neo.bodyMedium(context),
              ),
              if (canAddMore) ...[
                SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _showCreateDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.add_rounded),
                  label: Text('Creer un profil'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsSliver(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final padding = NeoTheme.screenPadding(context);

    if (width >= 980) {
      final count = width >= 1400 ? 4 : width >= 1100 ? 3 : 2;
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 32),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _ProfileCard(
              subAccount: _subAccounts[index],
              onEdit: () => _showEditDialog(_subAccounts[index]),
              onDelete: () => _confirmDelete(_subAccounts[index]),
              formatDate: _formatDate,
            ),
            childCount: _subAccounts.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: NeoTheme.gridSpacing(context),
            mainAxisSpacing: NeoTheme.gridSpacing(context),
            childAspectRatio: 1.4,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _subAccounts.length - 1 ? 0 : 12,
            ),
            child: _ProfileCard(
              subAccount: _subAccounts[index],
              onEdit: () => _showEditDialog(_subAccounts[index]),
              onDelete: () => _confirmDelete(_subAccounts[index]),
              formatDate: _formatDate,
            ),
          );
        }, childCount: _subAccounts.length),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final SubAccount subAccount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String? value) formatDate;

  _ProfileCard({
    required this.subAccount,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Neo.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: Neo.bgBorder(context).withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: NeoTheme.heroGradient,
                ),
                child: Center(
                  child: Text(
                    subAccount.username.isNotEmpty
                        ? subAccount.username[0].toUpperCase()
                        : '?',
                    style: NeoTheme.headlineMedium(
                      context,
                    ).copyWith(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subAccount.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.titleLarge(context),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subAccount.email.isNotEmpty
                          ? subAccount.email
                          : 'Profil famille',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.bodySmall(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                icon: Icons.lock_outline_rounded,
                label: subAccount.requirePassword
                    ? 'Mot de passe'
                    : 'Acces rapide',
                color: subAccount.requirePassword
                    ? NeoTheme.warningOrange
                    : NeoTheme.successGreen,
              ),
              _MiniPill(
                icon: Icons.access_time_rounded,
                label: 'Connexion ${formatDate(subAccount.lastLogin)}',
                color: NeoTheme.infoCyan,
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Modifier'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NeoTheme.errorRed,
                    side: BorderSide(
                      color: NeoTheme.errorRed.withValues(alpha: 0.4),
                    ),
                  ),
                  icon: Icon(Icons.delete_outline_rounded),
                  label: Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Neo.labelMedium(context)),
                SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Neo.titleMedium(context).copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Neo.labelMedium(context).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
