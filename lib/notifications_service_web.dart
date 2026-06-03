// Web implementation of the notifications service.
//
// Push notifications via firebase_messaging + flutter_local_notifications are
// not wired up for web in this project, so this is a safe no-op that keeps
// `flutter build web` free of the mobile-only plugins.

import 'package:flutter/foundation.dart';

Future<void> initialize() async {
  debugPrint('Crew: notifications are a no-op on web.');
}

Future<void> syncTokenForCurrentUser() async {
  // No-op on web.
}
