import 'package:flutter/material.dart';

import 'zivotni_broj_digits.dart';

/// Naslov s naglaskom zadnjih [highlightDigitCount] znamenki (crveno, bold).
class ZivotniBrojHighlightTitle extends StatelessWidget {
  const ZivotniBrojHighlightTitle({
    super.key,
    required this.zbroj,
    this.highlightDigitCount = 4,
  });

  final String zbroj;
  final int highlightDigitCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final start = startIndexOfLastDigits(zbroj, highlightDigitCount);
    if (start >= zbroj.length) {
      return Text(zbroj, style: baseStyle);
    }
    final accent = baseStyle.copyWith(
      color: Colors.red.shade700,
      fontWeight: FontWeight.bold,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: zbroj.substring(0, start)),
          TextSpan(text: zbroj.substring(start), style: accent),
        ],
      ),
    );
  }
}
