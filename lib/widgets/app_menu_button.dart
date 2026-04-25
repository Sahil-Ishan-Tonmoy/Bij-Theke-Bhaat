import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_settings.dart';
import '../services/app_colors.dart';

/// Drop-in AppBar action. Add to any screen's appBar actions:
///   actions: [const AppMenuButton()]
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.tune_rounded, color: AppColors.appBarText),
      tooltip: 'Settings',
      onPressed: () => _showSheet(context),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AppSettingsSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _AppSettingsSheet extends StatefulWidget {
  const _AppSettingsSheet();
  @override
  State<_AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends State<_AppSettingsSheet> {
  final _s = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _s.language.addListener(_rebuild);
    _s.themeMode.addListener(_rebuild);
    _s.landUnit.addListener(_rebuild);
  }

  @override
  void dispose() {
    _s.language.removeListener(_rebuild);
    _s.themeMode.removeListener(_rebuild);
    _s.landUnit.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = _s.isDark;
    final bgColor = isDark ? const Color(0xFF1E2E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A2B1A);
    final textSecondary = isDark ? Colors.white54 : Colors.black45;
    final accent = const Color(0xFF2D5A27);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),

              // Title
              Row(children: [
                Icon(Icons.tune_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Text(_s.translate('settings'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              ]),
              const SizedBox(height: 20),

              // ── Language ──────────────────────────────────────
              _sectionLabel(_s.translate('language'), textSecondary),
              const SizedBox(height: 8),
              _segmentRow(
                options: ['English', 'বাংলা'],
                selected: _s.isBengali ? 'বাংলা' : 'English',
                accent: accent,
                bgColor: bgColor,
                onTap: (v) {
                  _s.setLanguage(v == 'বাংলা' ? 'bn' : 'en');
                },
              ),
              const SizedBox(height: 20),

              // ── Theme ─────────────────────────────────────────
              _sectionLabel(_s.translate('theme'), textSecondary),
              const SizedBox(height: 8),
              _segmentRow(
                options: ['☀️  Light', '🌙  Dark'],
                selected: isDark ? '🌙  Dark' : '☀️  Light',
                accent: accent,
                bgColor: bgColor,
                onTap: (v) {
                  _s.setTheme(v.contains('Dark') ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              const SizedBox(height: 20),

              // ── Land Unit ─────────────────────────────────────
              _sectionLabel(_s.translate('unit'), textSecondary),
              const SizedBox(height: 8),
              _segmentRow(
                options: ['Bigha', 'Acre'],
                selected: _s.landUnit.value,
                accent: accent,
                bgColor: bgColor,
                onTap: (v) => _s.setUnit(v),
              ),
              const SizedBox(height: 8),
              Text(
                _s.isBigha
                    ? '1 Bigha ≈ 0.33 Acre  •  Used across calculator, irrigation & soil screens'
                    : '1 Acre ≈ 3.03 Bigha  •  Used across calculator, irrigation & soil screens',
                style: TextStyle(fontSize: 11, color: textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 12),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 1.2)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    FirebaseAuth.instance.signOut();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Close
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) =>
      Align(alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.4)));

  Widget _segmentRow({
    required List<String> options,
    required String selected,
    required Color accent,
    required Color bgColor,
    required void Function(String) onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive ? [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : accent,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
