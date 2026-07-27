import 'dart:async';

import 'package:flutter/material.dart';

enum TopNotificationType {
  success,
  error,
  info,
}

OverlayEntry? _activeTopNotification;
Timer? _activeTopNotificationTimer;

void showTopNotification(
  BuildContext context,
  String message, {
  TopNotificationType type = TopNotificationType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _removeActiveTopNotification();

  final mediaQuery = MediaQuery.of(context);
  final theme = Theme.of(context);
  final width = (mediaQuery.size.width * 0.25).clamp(280.0, 520.0).toDouble();
  final top = mediaQuery.padding.top + 16;

  final (backgroundColor, foregroundColor, borderColor, icon) = switch (type) {
    TopNotificationType.success => (
        const Color(0xFFEAF7ED),
        const Color(0xFF245C2E),
        const Color(0xFFB8DEBF),
        Icons.check_circle_outline,
      ),
    TopNotificationType.error => (
        const Color(0xFFFFECEC),
        const Color(0xFF8A2525),
        const Color(0xFFF0B9B9),
        Icons.error_outline,
      ),
    TopNotificationType.info => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        theme.colorScheme.outlineVariant,
        Icons.info_outline,
      ),
  };

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: width,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 6),
                    color: Color(0x26000000),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: foregroundColor, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close',
                    onPressed: () {
                      if (identical(_activeTopNotification, entry)) {
                        _removeActiveTopNotification();
                      }
                    },
                    icon: Icon(Icons.close, color: foregroundColor, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _activeTopNotification = entry;
  overlay.insert(entry);
  _activeTopNotificationTimer = Timer(duration, () {
    if (identical(_activeTopNotification, entry)) {
      _removeActiveTopNotification();
    }
  });
}

void _removeActiveTopNotification() {
  _activeTopNotificationTimer?.cancel();
  _activeTopNotificationTimer = null;
  final entry = _activeTopNotification;
  if (entry?.mounted == true) {
    entry!.remove();
  }
  _activeTopNotification = null;
}
