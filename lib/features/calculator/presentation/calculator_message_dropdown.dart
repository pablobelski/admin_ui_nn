import 'package:flutter/material.dart';

class CalculatorMessageGroup {
  const CalculatorMessageGroup({
    required this.label,
    required this.messages,
  });

  final String label;
  final List<String> messages;
}

class CalculatorMessagesDropdown extends StatelessWidget {
  const CalculatorMessagesDropdown({
    super.key,
    required this.groups,
    this.attention = false,
    this.width,
  });

  final List<CalculatorMessageGroup> groups;
  final bool attention;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = attention
        ? Icons.info_outline_rounded
        : Icons.warning_amber_rounded;
    final accentColor = attention
        ? colorScheme.onSurfaceVariant
        : colorScheme.error;
    final foregroundColor = attention
        ? colorScheme.onSurfaceVariant
        : colorScheme.onErrorContainer;
    final backgroundColor = attention
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : colorScheme.errorContainer.withValues(alpha: 0.55);
    final borderColor = attention
        ? colorScheme.outline.withValues(alpha: 0.5)
        : colorScheme.error.withValues(alpha: 0.5);
    final visibleGroups = groups
        .where((group) => group.messages.isNotEmpty)
        .toList(growable: false);
    final count = visibleGroups.fold<int>(
      0,
      (total, group) => total + group.messages.length,
    );

    Widget plate = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 17, color: accentColor),
            const SizedBox(width: 6),
            if (width == null)
              Text(
                '${attention ? 'Attention' : 'Warnings'}: $count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
              )
            else
              Expanded(
                child: Text(
                  '${attention ? 'Attention' : 'Warnings'}: $count',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: foregroundColor,
            ),
          ],
        ),
      ),
    );
    if (width != null) plate = SizedBox(width: width, child: plate);

    return PopupMenuButton<void>(
      tooltip: attention ? 'Show attention notes' : 'Show warnings',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(8),
      constraints: const BoxConstraints(
        minWidth: 280,
        maxWidth: 500,
      ),
      itemBuilder: (context) => [
        for (final group in visibleGroups) ...[
          if (group.label.trim().isNotEmpty)
            PopupMenuItem<void>(
              enabled: false,
              height: 0,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 3),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
            ),
          for (final message in group.messages)
            PopupMenuItem<void>(
              enabled: false,
              height: 0,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: SelectionArea(
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
      child: plate,
    );
  }
}
