// Shared constants for Crew App
//
// Central source of truth for trade types, experience levels, the Crew color
// palette, role identifiers, availability statuses, rating helpers and
// certification-expiry helpers. Screens should reference these instead of
// re-declaring hardcoded hex colors / magic strings.

import 'package:flutter/material.dart';

class CrewConstants {
  // ---------------------------------------------------------------------------
  // Trade types - Eve's full list
  // ---------------------------------------------------------------------------
  static const List<String> tradeTypes = [
    'Labourer',
    'Welder',
    'Welder Helper',
    'Pipefitter',
    'Pipefitter Helper',
    'Coater',
    'Zoom Boom Operator',
    'Hoe Hand',
    'Dozer Hand',
    'Boom Hand',
    'Bending Crew',
    'Scaffolder',
    'Rigger',
    'Millwright',
    'Electrician',
    'Instrument Tech',
    'Insulator',
    'Iron Worker',
    'Crane Operator',
    'Heavy Equipment Operator',
    'Safety Watch',
    'Fire Watch',
    'Other',
  ];

  // ---------------------------------------------------------------------------
  // Experience levels - no "Master" per Eve
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> experienceLevels = [
    {'value': 'apprentice_1st', 'label': '1st Year Apprentice'},
    {'value': 'apprentice_2nd', 'label': '2nd Year Apprentice'},
    {'value': 'apprentice_3rd', 'label': '3rd Year Apprentice'},
    {'value': 'apprentice_4th', 'label': '4th Year Apprentice'},
    {'value': 'journeyman', 'label': 'Journeyman'},
  ];

  /// Converts a stored experience value into a short UI label.
  /// Includes a legacy mapping: old 'master' data is shown as 'Journeyman'
  /// (per Eve, there is no Master tier).
  static String expToLabel(String exp) {
    switch (exp) {
      case 'apprentice_1st':
        return '1st Year';
      case 'apprentice_2nd':
        return '2nd Year';
      case 'apprentice_3rd':
        return '3rd Year';
      case 'apprentice_4th':
        return '4th Year';
      case 'journeyman':
        return 'Journeyman';
      case 'master':
        return 'Journeyman'; // map legacy master to journeyman
      // Job-posting "experience_required" vocabulary:
      case 'any':
        return 'Any Level';
      case 'apprentice':
        return 'Apprentice';
      default:
        return exp;
    }
  }

  static String labelToExp(String label) {
    switch (label) {
      case '1st Year':
        return 'apprentice_1st';
      case '2nd Year':
        return 'apprentice_2nd';
      case '3rd Year':
        return 'apprentice_3rd';
      case '4th Year':
        return 'apprentice_4th';
      case 'Journeyman':
        return 'journeyman';
      default:
        return 'All';
    }
  }

  // Filter labels for dropdowns
  static List<String> get experienceFilterLabels =>
      ['All', ...experienceLevels.map((e) => e['label']!)];

  static List<String> get tradeFilterLabels => ['All', ...tradeTypes];

  // ---------------------------------------------------------------------------
  // Roles
  // ---------------------------------------------------------------------------
  static const String roleHelper = 'helper';
  static const String roleJourneyman = 'journeyman';

  // ---------------------------------------------------------------------------
  // Crew color palette (mirrors the ThemeData in main.dart). Use these for
  // colors that are NOT exposed on ColorScheme (success/warning/danger,
  // borders, secondary text, panels). Prefer Theme.of(context) for the core
  // primary/surface/background colors where a BuildContext is available.
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color panel = Color(0xFF1a2235);
  static const Color border = Color(0xFF1e2d45);
  static const Color primary = Color(0xFFFF6B35);
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8896b0);
  static const Color accentBlue = Color(0xFF7eb3ff);
  static const Color success = Color(0xFF22c55e);
  static const Color warning = Color(0xFFfbbf24);
  static const Color danger = Color(0xFFef4444);

  // ---------------------------------------------------------------------------
  // Availability (stored on profiles.availability_status as text)
  // ---------------------------------------------------------------------------
  static const String availNow = 'available_now';
  static const String availSoon = 'available_soon';
  static const String unavailable = 'unavailable';

  static const List<String> availabilityStatuses = [
    availNow,
    availSoon,
    unavailable,
  ];

  static String availabilityLabel(String? status) {
    switch (status) {
      case availNow:
        return 'Available Now';
      case availSoon:
        return 'Available Soon';
      case unavailable:
        return 'Unavailable';
      default:
        return 'Not Set';
    }
  }

  static String availabilityShortLabel(String? status) {
    switch (status) {
      case availNow:
        return 'AVAILABLE';
      case availSoon:
        return 'SOON';
      case unavailable:
        return 'BUSY';
      default:
        return '';
    }
  }

  static Color availabilityColor(String? status) {
    switch (status) {
      case availNow:
        return success;
      case availSoon:
        return warning;
      case unavailable:
        return danger;
      default:
        return textSecondary;
    }
  }

  // ---------------------------------------------------------------------------
  // Ratings
  // ---------------------------------------------------------------------------
  static const int minRatingDays = 7; // a match must be this old to be ratable

  // ---------------------------------------------------------------------------
  // Certification expiry helpers
  // ---------------------------------------------------------------------------
  static const int certExpiryWarnDays = 30; // < 30 days => red
  static const int certExpirySoonDays = 60; // 30-60 days => yellow

  /// Days from now until [date] (expects 'YYYY-MM-DD' or ISO8601). Negative if
  /// already in the past. Returns null if the date can't be parsed.
  static int? daysUntil(String? date) {
    if (date == null || date.isEmpty) return null;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    return target.difference(today).inDays;
  }

  /// Color used to flag a certification based on how soon it expires.
  /// >60 days: green, 30-60: yellow, <30: red, expired: gray.
  static Color certExpiryColor(String? expiryDate) {
    final days = daysUntil(expiryDate);
    if (days == null) return textSecondary;
    if (days < 0) return textSecondary; // expired -> gray
    if (days < certExpiryWarnDays) return danger;
    if (days <= certExpirySoonDays) return warning;
    return success;
  }

  /// Short human label for a cert's expiry state.
  static String certExpiryLabel(String? expiryDate) {
    final days = daysUntil(expiryDate);
    if (days == null) return '';
    if (days < 0) return 'EXPIRED';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    if (days <= certExpirySoonDays) return 'Expires in $days days';
    return '';
  }

  /// True if a cert needs attention soon (expired or within the warning window).
  static bool certNeedsAttention(String? expiryDate) {
    final days = daysUntil(expiryDate);
    if (days == null) return false;
    return days < certExpiryWarnDays; // expired or < 30 days
  }
}
