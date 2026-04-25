import 'package:flutter/material.dart';
import '../services/app_settings.dart';

/// A wrapper widget that listens to global theme changes and rebuilds its child.
/// This ensures that screens using AppColors tokens update reactively 
/// when the user toggles Light/Dark mode from the AppMenuButton.
class ThemeAware extends StatelessWidget {
  final Widget Function(BuildContext) builder;

  const ThemeAware({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance.updateListener,
      builder: (context, _) {
        return builder(context);
      },
    );
  }
}
