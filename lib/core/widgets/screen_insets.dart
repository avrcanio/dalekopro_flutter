import 'package:flutter/material.dart';

EdgeInsets screenBodyPadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double bottomSpacing = 16,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    MediaQuery.viewPaddingOf(context).bottom + bottomSpacing,
  );
}
