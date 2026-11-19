import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_platform.dart';

/// Push-Status dieses Geräts für das angemeldete Konto.
enum PushStatus {
  /// Browser/Plattform kann (noch) keinen Push.
  unsupported,

  /// Im Browser verboten – nur in den Browser-Einstellungen änderbar.
  blocked,
  off,
  on,
}

/// Push für das angemeldete Konto ein- und ausschalten.
abstract interface class PushRepository {
  Future<PushStatus> status();

  /// Fragt um Erlaubnis und meldet das Gerät an. Gibt den neuen Status zurück.
  Future<PushStatus> enable();
  Future<PushStatus> disable();
}

class PushFailure implements Exception {
  const PushFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SupabasePushRepository implements PushRepository {
  SupabasePushRepository(
    this._client, [
    this._device = const PlatformDevicePush(),
  ]);

  final SupabaseClient _client;
  final DevicePush _device;

  @override
  Future<PushStatus> status() async {
    switch (_device.permission) {
      case DevicePushPermission.unsupported:
        return PushStatus.unsupported;
      case DevicePushPermission.denied:
        return PushStatus.blocked;
      case DevicePushPermission.notAsked:
        return PushStatus.off;
      case DevicePushPermission.granted:
        final sub = await _device.current();
        if (sub == null) return PushStatus.off;
        // Abo dem aktuellen Konto zuordnen (z. B. nach Kontowechsel).
        await _register(sub);
        return PushStatus.on;
    }
  }

  @override
  Future<PushStatus> enable() async {
    if (_device.permission == DevicePushPermission.unsupported) {
      return PushStatus.unsupported;
    }
    final key = await _client.rpc<String?>('push_public_key');
    if (key == null || key.isEmpty) {
      throw const PushFailure(
        'Benachrichtigungen sind auf dem Server noch nicht eingerichtet.',
      );
    }
    final sub = await _device.subscribe(key);
    if (sub == null) {
      return _device.permission == DevicePushPermission.denied
          ? PushStatus.blocked
          : PushStatus.off;
    }
    await _register(sub);
    return PushStatus.on;
  }

  @override
  Future<PushStatus> disable() async {
    final endpoint = await _device.unsubscribe();
    if (endpoint != null) {
      await _client.rpc<void>(
        'push_unsubscribe',
        params: {'p_endpoint': endpoint},
      );
    }
    return status();
  }

  Future<void> _register(DevicePushSubscription sub) => _client.rpc<void>(
    'push_subscribe',
    params: {
      'p_endpoint': sub.endpoint,
      'p_p256dh': sub.p256dh,
      'p_auth': sub.auth,
    },
  );
}

/// Demo-Modus: Push gibt es nicht.
class DemoPushRepository implements PushRepository {
  const DemoPushRepository();

  @override
  Future<PushStatus> status() async => PushStatus.unsupported;

  @override
  Future<PushStatus> enable() async => PushStatus.unsupported;

  @override
  Future<PushStatus> disable() async => PushStatus.unsupported;
}
