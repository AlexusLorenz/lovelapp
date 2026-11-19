import 'push_platform_types.dart';

export 'push_platform_types.dart';

/// Ohne Browser: Push wird (noch) nicht unterstützt.
class PlatformDevicePush implements DevicePush {
  const PlatformDevicePush();

  @override
  DevicePushPermission get permission => DevicePushPermission.unsupported;

  @override
  Future<DevicePushSubscription?> current() async => null;

  @override
  Future<DevicePushSubscription?> subscribe(String vapidPublicKey) async =>
      null;

  @override
  Future<String?> unsubscribe() async => null;
}
