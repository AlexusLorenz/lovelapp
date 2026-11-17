// Spotify-Login per „Authorization Code mit PKCE“ – ohne Client-Secret,
// direkt aus dem Browser. Der Zugriffs-Token wird nur einmal benutzt, um die
// Top-Künstler:innen zu lesen, und danach verworfen (nichts wird gespeichert).
//
// Reine Logik ohne Flutter-Import.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../interests/profile_extras.dart';

const spotifyScopes = 'user-top-read';

/// Zwischenstand während des Logins (liegt im localStorage des Browsers).
class SpotifyPending {
  const SpotifyPending({required this.verifier, required this.state});

  factory SpotifyPending.create([Random? random]) {
    final r = random ?? Random.secure();
    String token(int length) {
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
      return List.generate(
        length,
        (_) => chars[r.nextInt(chars.length)],
      ).join();
    }

    return SpotifyPending(verifier: token(64), state: token(24));
  }

  factory SpotifyPending.fromJson(Map<String, Object?> json) => SpotifyPending(
    verifier: json['verifier']! as String,
    state: json['state']! as String,
  );

  final String verifier;
  final String state;

  Map<String, Object?> toJson() => {'verifier': verifier, 'state': state};

  /// S256-Challenge nach RFC 7636.
  String get challenge => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}

Uri spotifyAuthorizeUrl({
  required String clientId,
  required String redirectUri,
  required SpotifyPending pending,
}) => Uri.https('accounts.spotify.com', '/authorize', {
  'response_type': 'code',
  'client_id': clientId,
  'scope': spotifyScopes,
  'redirect_uri': redirectUri,
  'state': pending.state,
  'code_challenge_method': 'S256',
  'code_challenge': pending.challenge,
});

/// Ergebnis der Rücksprungseite.
class SpotifyCallback {
  const SpotifyCallback({this.code, this.state, this.error});

  factory SpotifyCallback.fromJson(Map<String, Object?> json) =>
      SpotifyCallback(
        code: json['code'] as String?,
        state: json['state'] as String?,
        error: json['error'] as String?,
      );

  final String? code;
  final String? state;
  final String? error;
}

class SpotifyFailure implements Exception {
  const SpotifyFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Tauscht den Code gegen einen Token und liest die Top-Künstler:innen.
Future<List<FavoriteArtist>> fetchSpotifyTopArtists({
  required SpotifyCallback callback,
  required SpotifyPending pending,
  required String clientId,
  required String redirectUri,
  http.Client? client,
}) async {
  if (callback.error != null) {
    throw SpotifyFailure(
      callback.error == 'access_denied'
          ? 'Spotify-Verbindung abgebrochen.'
          : 'Spotify hat die Verbindung abgelehnt.',
    );
  }
  if (callback.code == null || callback.state != pending.state) {
    throw const SpotifyFailure('Spotify-Antwort ungültig. Bitte noch mal.');
  }
  final c = client ?? http.Client();
  try {
    final tokenRes = await c.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': callback.code!,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': pending.verifier,
      },
    );
    if (tokenRes.statusCode != 200) {
      throw const SpotifyFailure('Spotify-Anmeldung fehlgeschlagen.');
    }
    final token =
        (jsonDecode(tokenRes.body) as Map<String, Object?>)['access_token']
            as String?;
    if (token == null) {
      throw const SpotifyFailure('Spotify-Anmeldung fehlgeschlagen.');
    }

    Future<List<FavoriteArtist>> top(String range) async {
      final res = await c.get(
        Uri.https('api.spotify.com', '/v1/me/top/artists', {
          'limit': '20',
          'time_range': range,
        }),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 403) {
        // Development Mode: Konto steht nicht auf der Liste der Testnutzer.
        throw const SpotifyFailure(
          'Dein Spotify-Konto ist für Lovel noch nicht freigeschaltet.',
        );
      }
      if (res.statusCode != 200) {
        throw const SpotifyFailure('Spotify-Daten nicht abrufbar.');
      }
      final items =
          (jsonDecode(res.body) as Map<String, Object?>)['items']
              as List<Object?>? ??
          const [];
      return [
        for (final i in items)
          FavoriteArtist.fromSpotify(Map<String, Object?>.from(i! as Map)),
      ];
    }

    final medium = await top('medium_term');
    return medium.isNotEmpty ? medium : await top('long_term');
  } finally {
    if (client == null) c.close();
  }
}
