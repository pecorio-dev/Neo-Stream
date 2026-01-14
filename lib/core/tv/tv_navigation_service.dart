import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service de navigation pour TV avec support télécommande
class TVNavigationService {
  static bool _isTVMode = false;
  static FocusNode? _currentFocus;
  static final List<FocusNode> _focusHistory = [];
  
  /// Active/désactive le mode TV
  static void setTVMode(bool enabled) {
    _isTVMode = enabled;
    debugPrint('🖥️ Mode TV ${enabled ? 'activé' : 'désactivé'}');
  }
  
  /// Vérifie si le mode TV est actif
  static bool get isTVMode => _isTVMode;
  
  /// Configure les raccourcis clavier pour la télécommande
  static Map<LogicalKeySet, Intent> getTVShortcuts() {
    return {
      // Navigation directionnelle
      LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
      LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
      
      // Boutons de la télécommande
      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
      
      // Boutons média
      LogicalKeySet(LogicalKeyboardKey.mediaPlay): const TVPlayIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaPause): const TVPauseIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const TVPlayPauseIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaStop): const TVStopIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaFastForward): const TVFastForwardIntent(),
      LogicalKeySet(LogicalKeyboardKey.mediaRewind): const TVRewindIntent(),
      
      // Navigation
      LogicalKeySet(LogicalKeyboardKey.escape): const TVBackIntent(),
      LogicalKeySet(LogicalKeyboardKey.goBack): const TVBackIntent(),
      
      // Menu
      LogicalKeySet(LogicalKeyboardKey.contextMenu): const TVMenuIntent(),
      LogicalKeySet(LogicalKeyboardKey.f1): const TVMenuIntent(),
    };
  }
  
  /// Actions pour les raccourcis TV
  static Map<Type, Action<Intent>> getTVActions(BuildContext context) {
    return {
      TVPlayIntent: TVPlayAction(),
      TVPauseIntent: TVPauseAction(),
      TVPlayPauseIntent: TVPlayPauseAction(),
      TVStopIntent: TVStopAction(),
      TVFastForwardIntent: TVFastForwardAction(),
      TVRewindIntent: TVRewindAction(),
      TVBackIntent: TVBackAction(context),
      TVMenuIntent: TVMenuAction(),
    };
  }
  
  /// Enregistre le focus actuel
  static void setCurrentFocus(FocusNode? focus) {
    if (_currentFocus != focus) {
      if (_currentFocus != null && !_focusHistory.contains(_currentFocus)) {
        _focusHistory.add(_currentFocus!);
      }
      _currentFocus = focus;
    }
  }
  
  /// Retourne au focus précédent
  static void goToPreviousFocus() {
    if (_focusHistory.isNotEmpty) {
      final previousFocus = _focusHistory.removeLast();
      previousFocus.requestFocus();
      _currentFocus = previousFocus;
    }
  }
  
  /// Nettoie l'historique des focus
  static void clearFocusHistory() {
    _focusHistory.clear();
  }
}

// Intents personnalisés pour la télécommande
class TVPlayIntent extends Intent {
  const TVPlayIntent();
}

class TVPauseIntent extends Intent {
  const TVPauseIntent();
}

class TVPlayPauseIntent extends Intent {
  const TVPlayPauseIntent();
}

class TVStopIntent extends Intent {
  const TVStopIntent();
}

class TVFastForwardIntent extends Intent {
  const TVFastForwardIntent();
}

class TVRewindIntent extends Intent {
  const TVRewindIntent();
}

class TVBackIntent extends Intent {
  const TVBackIntent();
}

class TVMenuIntent extends Intent {
  const TVMenuIntent();
}

// Actions pour les intents
class TVPlayAction extends Action<TVPlayIntent> {
  @override
  Object? invoke(TVPlayIntent intent) {
    debugPrint('🎮 TV: Play pressed');
    // Sera géré par le lecteur vidéo
    return null;
  }
}

class TVPauseAction extends Action<TVPauseIntent> {
  @override
  Object? invoke(TVPauseIntent intent) {
    debugPrint('🎮 TV: Pause pressed');
    return null;
  }
}

class TVPlayPauseAction extends Action<TVPlayPauseIntent> {
  @override
  Object? invoke(TVPlayPauseIntent intent) {
    debugPrint('🎮 TV: Play/Pause pressed');
    return null;
  }
}

class TVStopAction extends Action<TVStopIntent> {
  @override
  Object? invoke(TVStopIntent intent) {
    debugPrint('🎮 TV: Stop pressed');
    return null;
  }
}

class TVFastForwardAction extends Action<TVFastForwardIntent> {
  @override
  Object? invoke(TVFastForwardIntent intent) {
    debugPrint('🎮 TV: Fast Forward pressed');
    return null;
  }
}

class TVRewindAction extends Action<TVRewindIntent> {
  @override
  Object? invoke(TVRewindIntent intent) {
    debugPrint('🎮 TV: Rewind pressed');
    return null;
  }
}

class TVBackAction extends Action<TVBackIntent> {
  final BuildContext context;
  
  TVBackAction(this.context);
  
  @override
  Object? invoke(TVBackIntent intent) {
    debugPrint('🎮 TV: Back pressed');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return null;
  }
}

class TVMenuAction extends Action<TVMenuIntent> {
  @override
  Object? invoke(TVMenuIntent intent) {
    debugPrint('🎮 TV: Menu pressed');
    // Ouvrir le menu contextuel
    return null;
  }
}