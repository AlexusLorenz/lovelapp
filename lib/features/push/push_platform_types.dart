/// Ein Push-Abo dieses Geräts (Browser).
class DevicePushSubscription {
  const DevicePushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

/// Was der Browser zu Benachrichtigungen sagt.
enum DevicePushPermission { unsupported, notAsked, granted, denied }

/// Zugriff auf Push dieses Geräts.
abstract interface class DevicePush {
  DevicePushPermission get permission;

  /// Aktuelles Abo, falls vorhanden.
  Future<DevicePushSubscription?> current();

  /// Fragt (falls nötig) um Erlaubnis und abonniert. `null`, wenn abgelehnt.
  Future<DevicePushSubscription?> subscribe(String vapidPublicKey);

  /// Abo dieses Geräts beenden; gibt den bisherigen Endpunkt zurück.
  Future<String?> unsubscribe();
}
