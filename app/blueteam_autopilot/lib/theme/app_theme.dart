import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 dark security dashboard theme.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Severity colors
  // ---------------------------------------------------------------------------
  static const Color criticalColor = Color(0xFFEF4444); // red-500
  static const Color highColor = Color(0xFFF97316); // orange-500
  static const Color mediumColor = Color(0xFFFBBF24); // amber-400
  static const Color lowColor = Color(0xFF3B82F6); // blue-500

  static Color severityColor(String severity) {
    return switch (severity.toUpperCase()) {
      'CRITICAL' => criticalColor,
      'HIGH' => highColor,
      'MEDIUM' => mediumColor,
      'LOW' => lowColor,
      _ => Colors.grey,
    };
  }

  // ---------------------------------------------------------------------------
  // Status colors
  // ---------------------------------------------------------------------------
  static const Color openColor = Color(0xFFEF4444);
  static const Color investigatingColor = Color(0xFFFBBF24);
  static const Color resolvedColor = Color(0xFF22C55E);
  static const Color dismissedColor = Color(0xFF6B7280);

  static Color statusColor(String status) {
    return switch (status.toUpperCase()) {
      'OPEN' => openColor,
      'INVESTIGATING' => investigatingColor,
      'RESOLVED' => resolvedColor,
      'DISMISSED' => dismissedColor,
      _ => Colors.grey,
    };
  }

  // ---------------------------------------------------------------------------
  // Risk level colors
  // ---------------------------------------------------------------------------
  static Color riskColor(String risk) {
    return switch (risk.toUpperCase()) {
      'HIGH' => criticalColor,
      'MEDIUM' => mediumColor,
      'LOW' => resolvedColor,
      _ => Colors.grey,
    };
  }

  // ---------------------------------------------------------------------------
  // Recommendation status colors
  // ---------------------------------------------------------------------------
  static Color recommendationStatusColor(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => investigatingColor,
      'APPROVED' => const Color(0xFF3B82F6),
      'REJECTED' => dismissedColor,
      'APPLIED' => resolvedColor,
      'FAILED' => criticalColor,
      _ => Colors.grey,
    };
  }

  // ---------------------------------------------------------------------------
  // Theme data
  // ---------------------------------------------------------------------------
  static ThemeData get dark => _buildTheme();

  static ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6), // blue accent
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // slate-900
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B), // slate-800
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B), // slate-800
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8), // slate-400
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFE2E8F0), // slate-200
        ),
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFF1E293B),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF334155);
          }
          return Colors.transparent;
        }),
        dividerThickness: 1,
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: colorScheme.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.inter(fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
