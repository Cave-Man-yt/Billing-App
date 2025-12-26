// lib/utils/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
	AppTheme._();

	// Primary palette
	static const Color primaryColor = Color(0xFF0A6ED1);
	static const Color primaryLight = Color(0xFF62B0FF);
	static const Color accentColor = Color(0xFF00BFA6);

	// Backgrounds & surfaces
	static const Color background = Color(0xFFF6F8FB);
	static const Color backgroundLight = Color(0xFFFFFFFF);
	static const Color cardBackground = Color(0xFFFFFFFF);

	// Text
	static const Color textPrimary = Color(0xFF223043);
	static const Color textSecondary = Color(0xFF6B7280);
	static const Color textHint = Color(0xFF9CA3AF);

	// Status colors
	static const Color successColor = Color(0xFF16A34A);
	static const Color errorColor = Color(0xFFDC2626);
	static const Color warningColor = Color(0xFFF59E0B);
	static const Color creditColor = Color(0xFF6B21A8);

	static final ThemeData lightTheme = ThemeData(
		primaryColor: primaryColor,
		colorScheme: ColorScheme.fromSwatch().copyWith(
			secondary: accentColor,
			primary: primaryColor,
		),
		scaffoldBackgroundColor: background,
		cardColor: cardBackground,
		appBarTheme: const AppBarTheme(
			backgroundColor: primaryColor,
			foregroundColor: Colors.white,
		),
		floatingActionButtonTheme: const FloatingActionButtonThemeData(
			backgroundColor: accentColor,
		),
		textTheme: const TextTheme(
			bodyLarge: TextStyle(color: textPrimary),
			bodyMedium: TextStyle(color: textSecondary),
		),
	);
}
