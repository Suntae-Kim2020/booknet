import 'package:flutter/material.dart';

final ThemeData booknetLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A6FA5),
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true),
);

final ThemeData booknetDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A6FA5),
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(centerTitle: true),
);
