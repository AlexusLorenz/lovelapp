import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_platform_types.dart';

export 'push_platform_types.dart';

/// Web Push über einen eigenen Service Worker (`web/push-sw.js`).
class PlatformDevicePush implements DevicePush {
  const PlatformDevicePush();

  static const _worker = 'push-sw.js';

  bool get _supported =>
      globalContext.has('PushManager') &&
      globalContext.has('Notification') &&
      web.window.navigator.has('serviceWorker');

  @override
  DevicePushPermission get permission {
    if (!_supported) return DevicePushPermission.unsupported;
    return switch (web.Notification.permission) {
      'granted' => DevicePushPermission.granted,
      'denied' => DevicePushPermission.denied,
      _ => DevicePushPermission.notAsked,
    };
  }

  Future<web.ServiceWorkerRegistration> _registration() async {
    final container = web.window.navigator.serviceWorker;
    // Relativ zur Seite → Gültigkeitsbereich ist der Ordner der App.
    return container.register(_worker.toJS).toDart;
  }

  @override
  Future<DevicePushSubscription?> current() async {
    if (!_supported) return null;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration(_worker)
        .toDart;
    final sub = await reg?.pushManager.getSubscription().toDart;
    return sub == null ? null : _convert(sub);
  }

  @override
  Future<DevicePushSubscription?> subscribe(String vapidPublicKey) async {
    if (!_supported) return null;
    if (permission != DevicePushPermission.granted) {
      final answer = await web.Notification.requestPermission().toDart;
      if (answer.toDart != 'granted') return null;
    }
    final reg = await _registration();
    final existing = await reg.pushManager.getSubscription().toDart;
    if (existing != null) return _convert(existing);
    final sub = await reg.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlDecode(vapidPublicKey).toJS,
          ),
        )
        .toDart;
    return _convert(sub);
  }

  @override
  Future<String?> unsubscribe() async {
    final sub = await current();
    if (sub == null) return null;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration(_worker)
        .toDart;
    final live = await reg?.pushManager.getSubscription().toDart;
    await live?.unsubscribe().toDart;
    return sub.endpoint;
  }

  DevicePushSubscription _convert(web.PushSubscription sub) =>
      DevicePushSubscription(
        endpoint: sub.endpoint,
        p256dh: _key(sub, 'p256dh'),
        auth: _key(sub, 'auth'),
      );

  String _key(web.PushSubscription sub, String name) {
    final buffer = sub.getKey(name);
    if (buffer == null) return '';
    return base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
  }

  static Uint8List _base64UrlDecode(String s) =>
      base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
}
