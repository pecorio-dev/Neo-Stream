import 'package:flutter/material.dart';

/// Global focus tracking for TV navigation
class FocusProvider extends ChangeNotifier {
  FocusNode? _currentFocus;
  final List<FocusNode> _focusHistory = [];
  
  FocusNode? get currentFocus => _currentFocus;
  List<FocusNode> get focusHistory => List.unmodifiable(_focusHistory);

  /// Track focus changes globally
  void trackFocusChange(FocusNode? newFocus) {
    if (newFocus == _currentFocus) return;
    
    _currentFocus = newFocus;
    
    // Keep history limited to last 20 items
    if (newFocus != null && !_focusHistory.contains(newFocus)) {
      _focusHistory.add(newFocus);
      if (_focusHistory.length > 20) {
        _focusHistory.removeAt(0);
      }
    }
    
    notifyListeners();
  }

  /// Reset focus (e.g., on screen navigation)
  void reset() {
    _currentFocus = null;
    _focusHistory.clear();
    notifyListeners();
  }

  /// Get previous focus node
  FocusNode? getPreviousFocus() {
    if (_focusHistory.length > 1) {
      return _focusHistory[_focusHistory.length - 2];
    }
    return null;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Global focus listener widget
class GlobalFocusListener extends StatefulWidget {
  final Widget child;

  const GlobalFocusListener({
    super.key,
    required this.child,
  });

  @override
  State<GlobalFocusListener> createState() => _GlobalFocusListenerState();
}

class _GlobalFocusListenerState extends State<GlobalFocusListener> {
  late FocusManager _focusManager;

  @override
  void initState() {
    super.initState();
    _focusManager = FocusManager.instance;
    _focusManager.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Notify provider about focus changes
    if (mounted) {
      final focusProvider = FocusProvider();
      focusProvider.trackFocusChange(_focusManager.primaryFocus);
    }
  }

  @override
  void dispose() {
    _focusManager.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
