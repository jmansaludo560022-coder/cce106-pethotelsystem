import 'package:flutter/material.dart';

enum AppTextScale { small, medium, large }

/// Text-size preference (Q-23: text size kept; dark mode dropped for now).
/// Applied app-wide in main.dart through MediaQuery.textScaler.
class AccessibilityProvider extends ChangeNotifier {
  // Owner requirement: the default text size is Small (the compact base size).
  AppTextScale _textScale = AppTextScale.small;

  AppTextScale get textScale => _textScale;

  double get scaleFactor {
    switch (_textScale) {
      case AppTextScale.small:
        return 1.0;
      case AppTextScale.medium:
        return 1.1;
      case AppTextScale.large:
        return 1.2;
    }
  }

  void setTextScale(AppTextScale scale) {
    _textScale = scale;
    notifyListeners();
  }
}
