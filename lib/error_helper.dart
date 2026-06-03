// Shared user-facing feedback helper for the Crew App.
//
// Every catch block in the UI should surface a message to the user instead of
// silently swallowing the error. Use:
//   AppFeedback.showError(context, e);            // red snackbar
//   AppFeedback.showSuccess(context, 'Saved!');   // green snackbar
//   AppFeedback.showInfo(context, '...');         // neutral snackbar
//
// All helpers no-op safely if the widget is no longer mounted.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crew_constants.dart';

class AppFeedback {
  /// Convert any thrown object into a friendly, human-readable message.
  static String messageFor(Object error, {String? fallback}) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      // Surface a clean message, hiding internal codes where possible.
      return error.message;
    }
    if (error is StorageException) {
      return error.message;
    }
    final raw = error.toString();
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection') ||
        raw.contains('Network is unreachable')) {
      return 'Network error. Check your connection and try again.';
    }
    if (fallback != null) return fallback;
    // Strip the noisy "Exception: " prefix Dart adds.
    return raw.replaceFirst('Exception: ', '');
  }

  static void showError(BuildContext context, Object error, {String? fallback}) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(messageFor(error, fallback: fallback)),
          backgroundColor: CrewConstants.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: CrewConstants.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: CrewConstants.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
