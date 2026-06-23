import 'package:flutter/material.dart';

const brandtGreen = Color(0xFF0A7354);
const brandtGreenAccent = Color(0xFF339A51);
const brandtBlue = Color(0xFF0F486E);
const darkForest = Color(0xFF061411);
const softBackground = Color(0xFFF4F8F6);
const borderSoft = Color(0xFFDCE7E3);
const textDark = Color(0xFF10231F);
const textMuted = Color(0xFF64756F);

ThemeData buildBrandtTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandtGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: softBackground,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: softBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textDark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: brandtGreen, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
