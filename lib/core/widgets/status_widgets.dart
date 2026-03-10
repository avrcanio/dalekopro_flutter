import 'package:flutter/material.dart';

enum StatusType { info, success, warning, error }

class InlineStatusMessage extends StatelessWidget {
  const InlineStatusMessage({
    super.key,
    required this.message,
    required this.type,
  });

  final String message;
  final StatusType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (type) {
      StatusType.success => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      StatusType.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.warning_amber_outlined,
      ),
      StatusType.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline,
      ),
      StatusType.info => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.info_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class FullScreenState extends StatelessWidget {
  const FullScreenState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
