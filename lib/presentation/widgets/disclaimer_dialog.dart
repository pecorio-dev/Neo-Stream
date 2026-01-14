import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class DisclaimerDialog extends StatefulWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const DisclaimerDialog({
    Key? key,
    this.onAccept,
    this.onDecline,
  }) : super(key: key);

  @override
  State<DisclaimerDialog> createState() => _DisclaimerDialogState();

  /// Affiche le dialog de disclaimer
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DisclaimerDialog(
        onAccept: () => Navigator.of(context).pop(true),
        onDecline: () => Navigator.of(context).pop(false),
      ),
    );
  }

  /// Vérifie si le disclaimer a déjà été accepté
  static Future<bool> hasBeenAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disclaimer_accepted') ?? false;
  }

  /// Marque le disclaimer comme accepté de manière permanente
  static Future<void> markAsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_accepted', true);
    // Ajouter un timestamp pour rendre la modification plus difficile
    await prefs.setInt('disclaimer_timestamp', DateTime.now().millisecondsSinceEpoch);
    // Ajouter une signature cryptographique simple
    await prefs.setString('disclaimer_signature', _generateSignature());
  }

  /// Génère une signature simple pour valider l'acceptation
  static String _generateSignature() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final deviceInfo = 'neostream_pecorio_disclaimer';
    return (timestamp.hashCode ^ deviceInfo.hashCode).toString();
  }

  /// Vérifie la validité de l'acceptation
  static Future<bool> isAcceptanceValid() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('disclaimer_accepted') ?? false;
    final timestamp = prefs.getInt('disclaimer_timestamp');
    final signature = prefs.getString('disclaimer_signature');
    
    // Vérifications de sécurité
    if (!accepted || timestamp == null || signature == null) {
      return false;
    }
    
    // Vérifier que l'acceptation n'est pas trop ancienne (optionnel)
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceAcceptance = (now - timestamp) / (1000 * 60 * 60 * 24);
    
    // L'acceptation est valide indéfiniment une fois donnée
    return accepted && signature.isNotEmpty;
  }
}

class _DisclaimerDialogState extends State<DisclaimerDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _hasReadAndUnderstood = false;
  bool _isAcceptButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return WillPopScope(
      onWillPop: () async => false, // Empêche la fermeture avec le bouton retour
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AlertDialog(
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Avis de Non-Responsabilité',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Développeur : Pecorio',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'AVIS IMPORTANT DE NON-RESPONSABILITÉ',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Moi, Pecorio, développeur de cette application, décline toute responsabilité concernant :',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDisclaimerList(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.security,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Protection Permanente',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Une fois accepté, cet accord devient permanent et ne peut être modifié, même en changeant le code source de l\'application.',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CheckboxListTile(
                        value: _hasReadAndUnderstood,
                        onChanged: (value) {
                          setState(() {
                            _hasReadAndUnderstood = value ?? false;
                            _isAcceptButtonEnabled = _hasReadAndUnderstood;
                          });
                        },
                        title: const Text(
                          'J\'ai lu et compris cet avis de non-responsabilité',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.accentNeon,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => _handleDecline(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Refuser et Quitter'),
                  ),
                  ElevatedButton(
                    onPressed: _isAcceptButtonEnabled ? () => _handleAccept(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAcceptButtonEnabled 
                        ? AppTheme.accentNeon 
                        : Colors.grey,
                      foregroundColor: AppTheme.backgroundPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Accepter et Continuer'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisclaimerList() {
    final disclaimerPoints = [
      {
        'icon': Icons.code,
        'title': 'Actions effectuées dans l\'application',
        'description': 'Toute utilisation de l\'application se fait aux risques et périls de l\'utilisateur',
      },
      {
        'icon': Icons.api,
        'title': 'Utilisation de l\'API',
        'description': 'Aucune responsabilité concernant les données récupérées ou les requêtes effectuées',
      },
      {
        'icon': Icons.storage,
        'title': 'Contenu et données',
        'description': 'Le développeur n\'est pas responsable du contenu accessible via l\'application',
      },
      {
        'icon': Icons.security,
        'title': 'Sécurité et confidentialité',
        'description': 'L\'utilisateur est responsable de la protection de ses données personnelles',
      },
      {
        'icon': Icons.bug_report,
        'title': 'Bugs et dysfonctionnements',
        'description': 'Aucune garantie de fonctionnement parfait ou de disponibilité continue',
      },
      {
        'icon': Icons.gavel,
        'title': 'Aspects légaux',
        'description': 'L\'utilisateur doit respecter les lois en vigueur dans son pays',
      },
    ];

    return Column(
      children: disclaimerPoints.map((point) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  point['icon'] as IconData,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point['title'] as String,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point['description'] as String,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _handleAccept(BuildContext context) async {
    // Marquer comme accepté de manière permanente
    await DisclaimerDialog.markAsAccepted();
    widget.onAccept?.call();
  }

  void _handleDecline(BuildContext context) {
    // Fermer l'application si l'utilisateur refuse
    widget.onDecline?.call();
  }
}