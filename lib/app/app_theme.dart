import 'package:flutter/material.dart';

ThemeData buildAdminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2457C5),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F8FC),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    ),
    navigationRailTheme: NavigationRailThemeData(
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: TextStyle(color: scheme.primary),
    ),
  );
}
