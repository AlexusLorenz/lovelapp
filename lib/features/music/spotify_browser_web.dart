import 'package:web/web.dart' as web;

String? readStorage(String key) => web.window.localStorage.getItem(key);
void writeStorage(String key, String value) =>
    web.window.localStorage.setItem(key, value);
void removeStorage(String key) => web.window.localStorage.removeItem(key);
void redirectTo(String url) => web.window.location.assign(url);
