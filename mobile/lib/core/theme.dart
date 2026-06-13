import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  primaryColor: const Color(0xFF00E676),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00E676),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
);

final darkTheme = ThemeData(
  primaryColor: const Color(0xFF00E676),
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00E676),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);
