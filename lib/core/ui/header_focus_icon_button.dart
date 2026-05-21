import 'package:flutter/material.dart';

class HeaderFocusIconButton extends StatelessWidget {
  const HeaderFocusIconButton({
    super.key,
    required this.focused,
    required this.onPressed,
  });

  final bool focused;
  final VoidCallback onPressed;

  static const double size = 56;
  static const double iconSize = 32;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: focused ? 'Restore layout' : 'Focus dependent layer',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: size,
          height: size,
        ),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          focused ? Icons.view_sidebar_outlined : Icons.vertical_split_outlined,
          size: iconSize,
        ),
      ),
    );
  }
}
