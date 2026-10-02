import 'package:flutter/material.dart';

const zeiaBg = Color(0xFF0A0A0A);
const zeiaCard = Color(0xFF181818);
const zeiaCard2 = Color(0xFF121212);
const zeiaCard3 = Color(0xFF252525);
const zeiaMuted = Color(0xFFA7A7A7);
const zeiaBorder = Color(0x1AFFFFFF);
const zeiaAccent = Color(0xFFD0D0D0);

ThemeData zeiaTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: zeiaBg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: zeiaAccent,
        surface: zeiaBg,
      ),
      fontFamily: 'sans-serif',
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayColor: Colors.white10,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? const Color(0xFF222222) : const Color(0xFF2A2A2A)),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: const WidgetStatePropertyAll(Color(0xFF383838)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zeiaCard,
        hintStyle: const TextStyle(color: zeiaMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
    );
