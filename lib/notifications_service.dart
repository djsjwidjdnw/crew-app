// Notifications service (public facade).
//
// Builds the push-notification infrastructure (FCM + local notifications).
// NOTE: Firebase is NOT fully configured yet — firebase_options.dart and
// google-services.json must be generated via `flutterfire configure` against a
// real Firebase project. Until then initialize() fails gracefully (the app is
// unaffected) but all the wiring is in place.
//
// SQL MIGRATION (fcm_token column on profiles):
//   alter table public.profiles add column if not exists fcm_token text;
//
// This facade uses a conditional import so the web build never pulls in the
// mobile-only plugins (firebase_messaging / flutter_local_notifications),
// keeping `flutter build web` green. The web build uses the no-op stub.

import 'notifications_service_io.dart'
    if (dart.library.html) 'notifications_service_web.dart' as impl;

class NotificationsService {
  /// Initialize Firebase Messaging + local notifications. Safe to call on web
  /// (no-op) and safe to call before Firebase is configured (fails gracefully).
  static Future<void> initialize() => impl.initialize();

  /// Fetch the current FCM token and store it on the signed-in user's profile
  /// row (profiles.fcm_token). Call after a successful login/registration.
  /// Best-effort: never throws into the auth flow.
  static Future<void> syncTokenForCurrentUser() => impl.syncTokenForCurrentUser();
}
