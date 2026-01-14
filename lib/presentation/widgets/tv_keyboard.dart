import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'focus_selector_wrapper.dart';

/// Clavier virtuel optimisé pour la navigation TV
class TVKeyboard extends StatefulWidget {
  final String initialText;
  final Function(String) onTextChanged;
  final String title;
  final String placeholder;

  const TVKeyboard({
    Key? key,
    required this.initialText,
    required this.onTextChanged,
    this.title = 'Saisie de texte',
    this.placeholder = 'Tapez votre texte...',
  }) : super(key: key);

  @override
  State<TVKeyboard> createState() => _TVKeyboardState();
}

class _TVKeyboardState extends State<TVKeyboard> {
  late String _currentText;
  int _currentRow = 0;
  int _currentCol = 0;
  bool _isUpperCase = false;
  
  // Layout du clavier AZERTY avec support majuscules/minuscules
  List<List<String>> get _keyboardLayout => [
    _isUpperCase 
        ? ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']
        : ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    _isUpperCase
        ? ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M']
        : ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
    _isUpperCase
        ? ['W', 'X', 'C', 'V', 'B', 'N', '1', '2', '3', '0']
        : ['w', 'x', 'c', 'v', 'b', 'n', '1', '2', '3', '0'],
    ['MAJ', 'ESPACE', 'EFFACER', 'OK', 'ANNULER'],
  ];
  
  final List<FocusNode> _keyFocusNodes = [];
  
  @override
  void initState() {
    super.initState();
    _currentText = widget.initialText;
    _setupFocusNodes();
    _autoFocusFirstKey();
  }
  
  void _setupFocusNodes() {
    // Calculer le nombre total de touches
    int totalKeys = 0;
    for (final row in _keyboardLayout) {
      totalKeys += row.length;
    }
    
    // Créer les focus nodes
    for (int i = 0; i < totalKeys; i++) {
      _keyFocusNodes.add(FocusNode());
    }
  }
  
  void _autoFocusFirstKey() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _keyFocusNodes.isNotEmpty) {
        _keyFocusNodes[0].requestFocus();
      }
    });
  }
  
  @override
  void dispose() {
    for (final node in _keyFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): _MoveUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): _MoveDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): _MoveLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): _MoveRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): _SelectIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): _SelectIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): _CancelIntent(),
      },
      child: Actions(
        actions: {
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (intent) {
              _navigateKeyboard(-1, 0);
              return null;
            },
          ),
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(
            onInvoke: (intent) {
              _navigateKeyboard(1, 0);
              return null;
            },
          ),
          _MoveLeftIntent: CallbackAction<_MoveLeftIntent>(
            onInvoke: (intent) {
              _navigateKeyboard(0, -1);
              return null;
            },
          ),
          _MoveRightIntent: CallbackAction<_MoveRightIntent>(
            onInvoke: (intent) {
              _navigateKeyboard(0, 1);
              return null;
            },
          ),
          _SelectIntent: CallbackAction<_SelectIntent>(
            onInvoke: (intent) {
              _selectCurrentKey();
              return null;
            },
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (intent) {
              Navigator.of(context).pop();
              return null;
            },
          ),
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: AppColors.cyberBlack,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.neonGreen.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonGreen.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildTextDisplay(),
                  const SizedBox(height: 24),
                  _buildKeyboard(),
                  const SizedBox(height: 16),
                  _buildInstructions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.keyboard,
          color: AppColors.neonGreen,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isUpperCase 
                ? AppColors.neonGreen.withOpacity(0.3)
                : AppColors.cyberDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.neonGreen.withOpacity(0.5),
            ),
          ),
          child: Text(
            _isUpperCase ? 'MAJ' : 'min',
            style: TextStyle(
              color: _isUpperCase 
                  ? AppColors.neonGreen
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextDisplay() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyberDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentText.isEmpty ? widget.placeholder : _currentText,
            style: TextStyle(
              color: _currentText.isEmpty 
                  ? AppColors.textSecondary 
                  : AppColors.textPrimary,
              fontSize: 18,
              height: 1.4,
            ),
          ),
          if (_currentText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_currentText.length} caractères',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildKeyboard() {
    List<Widget> rows = [];
    int keyIndex = 0;
    
    for (int rowIndex = 0; rowIndex < _keyboardLayout.length; rowIndex++) {
      List<Widget> rowKeys = [];
      
      for (int colIndex = 0; colIndex < _keyboardLayout[rowIndex].length; colIndex++) {
        final key = _keyboardLayout[rowIndex][colIndex];
        final focusNode = _keyFocusNodes[keyIndex];
        final isCurrentFocus = _currentRow == rowIndex && _currentCol == colIndex;
        
        rowKeys.add(
          Expanded(
            flex: _getKeyFlex(key),
            child: Container(
              margin: const EdgeInsets.all(3),
              child: FocusSelectorWrapper(
                focusNode: focusNode,
                onPressed: () => _onKeyPressed(key),
                semanticLabel: _getKeyLabel(key),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 55,
                  decoration: BoxDecoration(
                    color: _getKeyColor(key),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrentFocus 
                          ? AppColors.neonGreen
                          : AppColors.neonGreen.withOpacity(0.3),
                      width: isCurrentFocus ? 2 : 1,
                    ),
                    boxShadow: isCurrentFocus ? [
                      BoxShadow(
                        color: AppColors.neonGreen.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      _getKeyDisplayText(key),
                      style: TextStyle(
                        color: _getKeyTextColor(key),
                        fontSize: _getKeyFontSize(key),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        keyIndex++;
      }
      
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: rowKeys),
        ),
      );
    }
    
    return Column(children: rows);
  }
  
  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cyberDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.navigation, color: AppColors.textSecondary, size: 16),
          SizedBox(width: 8),
          Text(
            'Flèches: Navigation • OK/Entrée: Sélection • Échap: Annuler',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  int _getKeyFlex(String key) {
    switch (key) {
      case 'ESPACE':
        return 4;
      case 'EFFACER':
      case 'ANNULER':
        return 2;
      case 'MAJ':
      case 'OK':
        return 2;
      default:
        return 1;
    }
  }
  
  Color _getKeyColor(String key) {
    switch (key) {
      case 'OK':
        return AppColors.neonGreen.withOpacity(0.3);
      case 'ANNULER':
        return AppColors.error.withOpacity(0.3);
      case 'EFFACER':
        return AppColors.neonBlue.withOpacity(0.3);
      case 'MAJ':
        return _isUpperCase 
            ? AppColors.neonGreen.withOpacity(0.3)
            : AppColors.cyberDark;
      case 'ESPACE':
        return AppColors.cyberGray.withOpacity(0.3);
      default:
        return AppColors.cyberDark;
    }
  }
  
  Color _getKeyTextColor(String key) {
    switch (key) {
      case 'OK':
        return AppColors.neonGreen;
      case 'ANNULER':
        return AppColors.error;
      case 'EFFACER':
        return AppColors.neonBlue;
      case 'MAJ':
        return _isUpperCase ? AppColors.neonGreen : AppColors.textSecondary;
      default:
        return AppColors.textPrimary;
    }
  }
  
  double _getKeyFontSize(String key) {
    switch (key) {
      case 'ESPACE':
      case 'EFFACER':
      case 'ANNULER':
      case 'MAJ':
      case 'OK':
        return 14;
      default:
        return 18;
    }
  }
  
  String _getKeyDisplayText(String key) {
    switch (key) {
      case 'ESPACE':
        return 'ESPACE';
      case 'EFFACER':
        return '⌫';
      case 'MAJ':
        return _isUpperCase ? 'MAJ ●' : 'MAJ ○';
      default:
        return key;
    }
  }
  
  String _getKeyLabel(String key) {
    switch (key) {
      case 'ESPACE':
        return 'Espace';
      case 'EFFACER':
        return 'Effacer';
      case 'OK':
        return 'Valider';
      case 'ANNULER':
        return 'Annuler';
      case 'MAJ':
        return _isUpperCase ? 'Désactiver majuscules' : 'Activer majuscules';
      default:
        return 'Lettre $key';
    }
  }
  
  void _navigateKeyboard(int deltaRow, int deltaCol) {
    setState(() {
      _currentRow = (_currentRow + deltaRow).clamp(0, _keyboardLayout.length - 1);
      _currentCol = (_currentCol + deltaCol).clamp(0, _keyboardLayout[_currentRow].length - 1);
    });
    
    // Calculer l'index du focus node
    int keyIndex = 0;
    for (int row = 0; row < _currentRow; row++) {
      keyIndex += _keyboardLayout[row].length;
    }
    keyIndex += _currentCol;
    
    if (keyIndex < _keyFocusNodes.length) {
      _keyFocusNodes[keyIndex].requestFocus();
    }
    
    HapticFeedback.selectionClick();
  }
  
  void _selectCurrentKey() {
    if (_currentRow < _keyboardLayout.length && 
        _currentCol < _keyboardLayout[_currentRow].length) {
      final key = _keyboardLayout[_currentRow][_currentCol];
      _onKeyPressed(key);
    }
  }
  
  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();
    
    setState(() {
      switch (key) {
        case 'ESPACE':
          _currentText += ' ';
          break;
        case 'EFFACER':
          if (_currentText.isNotEmpty) {
            _currentText = _currentText.substring(0, _currentText.length - 1);
          }
          break;
        case 'MAJ':
          _isUpperCase = !_isUpperCase;
          break;
        case 'OK':
          widget.onTextChanged(_currentText);
          Navigator.of(context).pop();
          return;
        case 'ANNULER':
          Navigator.of(context).pop();
          return;
        default:
          _currentText += key;
          break;
      }
    });
  }
}

// Intent classes pour la navigation clavier
class _MoveUpIntent extends Intent {}
class _MoveDownIntent extends Intent {}
class _MoveLeftIntent extends Intent {}
class _MoveRightIntent extends Intent {}
class _SelectIntent extends Intent {}
class _CancelIntent extends Intent {}

/// Fonction utilitaire pour afficher le clavier TV
Future<String?> showTVKeyboard({
  required BuildContext context,
  String initialText = '',
  String title = 'Saisie de texte',
  String placeholder = 'Tapez votre texte...',
}) async {
  String? result;
  
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return TVKeyboard(
        initialText: initialText,
        title: title,
        placeholder: placeholder,
        onTextChanged: (text) {
          result = text;
        },
      );
    },
  );
  
  return result;
}