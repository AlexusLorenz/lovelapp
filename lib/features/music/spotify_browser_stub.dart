// Außerhalb des Browsers gibt es (noch) keinen Spotify-Login.

String? readStorage(String key) => null;
void writeStorage(String key, String value) {}
void removeStorage(String key) {}
void redirectTo(String url) =>
    throw UnsupportedError('Spotify-Login gibt es nur in der Web-App.');
