import 'package:flutter/material.dart';
import 'app_settings.dart';

/// Provides theme-aware colors based on AppSettings.instance.isDark.
/// Import this and use AppColors.* instead of hardcoded Color literals.
class AppColors {
  AppColors._();

  static bool get _d => AppSettings.instance.isDark;

  // ── Gradients ─────────────────────────────────────────────
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: _d
        ? const [Color(0xFF1A2B1A), Color(0xFF0D1A0D)]
        : const [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
  );

  static LinearGradient get skyGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.1, 0.9],
    colors: _d
        ? const [Color(0xFF1A2833), Color(0xFF1A2B1A)]
        : const [Color(0xFF81D4FA), Color(0xFFA5D6A7)],
  );

  // ── Glass cards ───────────────────────────────────────────
  static Color get glassFill =>
      _d ? const Color(0xFF243424).withOpacity(0.6) : Colors.white.withOpacity(0.45);

  static Color get glassBorder =>
      _d ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6);

  static Color get cardFill =>
      _d ? const Color(0xFF2A3D2A).withOpacity(0.9) : Colors.white.withOpacity(0.85);

  // ── Text ──────────────────────────────────────────────────
  static Color get primaryText => _d ? const Color(0xFF81C784) : const Color(0xFF2D5A27);
  static Color get secondaryText => _d ? Colors.white54 : Colors.black54;
  static Color get hintText => _d ? Colors.white38 : Colors.black38;
  static Color get bodyText => _d ? Colors.white.withOpacity(0.87) : Colors.black87;

  // ── Surfaces ──────────────────────────────────────────────
  static Color get inputFill => _d ? const Color(0xFF2A3D2A) : Colors.white.withOpacity(0.7);
  static Color get scaffoldBg => _d ? const Color(0xFF1A2B1A) : const Color(0xFFE8F5E9);

  // ── AppBar ────────────────────────────────────────────────
  static Color get appBarBg =>
      _d ? const Color(0xFF1A2B1A).withOpacity(0.95) : Colors.white.withOpacity(0.9);
  static Color get appBarText => _d ? const Color(0xFF81C784) : const Color(0xFF2D5A27);

  // ── Primary accent ────────────────────────────────────────
  static Color get accent => _d ? const Color(0xFF4CAF50) : const Color(0xFF2D5A27);
  static Color get accentLight => _d ? const Color(0xFF81C784) : const Color(0xFF4CAF50);

  // ── Dismissible delete bg ─────────────────────────────────
  static Color get deleteBg => Colors.redAccent;
}
