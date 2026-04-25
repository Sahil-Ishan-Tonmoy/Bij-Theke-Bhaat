import 'package:flutter/material.dart';
import '../services/app_settings.dart';

/// A widget that automatically translates text using local dictionary OR API fallback.
class TranslateText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslateText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    return ValueListenableBuilder<String>(
      valueListenable: s.language,
      builder: (context, lang, _) {
        // 1. Check local dictionary first (Synchronous)
        final local = s.translate(text);
        if (local != text || lang == 'en') {
          return Text(
            local,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        // 2. Fallback to API for dynamic content
        return FutureBuilder<String>(
          future: s.translateAsync(text),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? text,
              style: style,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: overflow,
            );
          },
        );
      },
    );
  }
}
