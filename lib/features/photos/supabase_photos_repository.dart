import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/profile_image.dart';
import 'photos_repository.dart';

class SupabasePhotosRepository implements PhotosRepository {
  SupabasePhotosRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'profile-photos';

  /// Signierte URLs eine Stunde gültig; wir nutzen sie 50 Minuten lang
  /// wieder, damit Bilder im Cache bleiben.
  static const _urlLifetime = Duration(hours: 1);
  static const _urlReuse = Duration(minutes: 50);
  final _urlCache = <String, (String url, DateTime until)>{};

  StorageFileApi get _storage => _client.storage.from(bucket);

  /// Liefert signierte URLs für Pfade, aus dem Cache wo möglich.
  Future<Map<String, String>> _signedUrls(List<String> paths) async {
    final now = DateTime.now();
    final result = <String, String>{};
    final missing = <String>[];
    for (final p in paths) {
      final cached = _urlCache[p];
      if (cached != null && cached.$2.isAfter(now)) {
        result[p] = cached.$1;
      } else {
        missing.add(p);
      }
    }
    if (missing.isNotEmpty) {
      final signed = await _storage.createSignedUrlsResult(
        missing,
        _urlLifetime.inSeconds,
      );
      for (final s in signed.whereType<SignedUrlSuccess>()) {
        result[s.path] = s.signedUrl;
        _urlCache[s.path] = (s.signedUrl, now.add(_urlReuse));
      }
    }
    return result;
  }

  @override
  Future<List<OwnPhoto>> fetchOwn(String userId) async {
    try {
      final rows = await _client
          .from('profile_photos')
          .select('id, storage_path, position')
          .eq('profile_id', userId)
          .order('position', ascending: true);
      final urls = await _signedUrls([
        for (final r in rows) r['storage_path'] as String,
      ]);
      return [
        for (final r in rows)
          if (urls[r['storage_path']] != null)
            OwnPhoto(
              id: r['id'] as String,
              storagePath: r['storage_path'] as String,
              image: NetworkProfileImage(urls[r['storage_path']]!),
            ),
      ];
    } on Exception {
      throw const PhotoFailure('Fotos konnten nicht geladen werden.');
    }
  }

  @override
  Future<OwnPhoto> upload(
    String userId,
    Uint8List jpeg, {
    required int position,
  }) async {
    if (position >= maxPhotos) {
      throw const PhotoFailure('Höchstens $maxPhotos Fotos.');
    }
    final path = '$userId/${DateTime.now().toUtc().microsecondsSinceEpoch}.jpg';
    try {
      await _storage.uploadBinary(
        path,
        jpeg,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );
      final row = await _client
          .from('profile_photos')
          .insert({
            'profile_id': userId,
            'storage_path': path,
            'position': position,
          })
          .select('id')
          .single();
      final url = (await _signedUrls([path]))[path]!;
      return OwnPhoto(
        id: row['id'] as String,
        storagePath: path,
        image: NetworkProfileImage(url),
      );
    } on StorageException catch (e) {
      throw PhotoFailure(
        e.statusCode == '413'
            ? 'Das Bild ist zu groß.'
            : 'Upload hat nicht geklappt. Bitte versuch es noch einmal.',
      );
    } on PostgrestException {
      // Datei wieder wegräumen, wenn der Datenbank-Eintrag scheitert.
      await _storage.remove([path]).catchError((_) => <FileObject>[]);
      throw const PhotoFailure('Foto konnte nicht gespeichert werden.');
    } on Exception {
      throw const PhotoFailure('Keine Verbindung zum Server.');
    }
  }

  @override
  Future<void> delete(String userId, OwnPhoto photo) async {
    try {
      await _client.from('profile_photos').delete().eq('id', photo.id);
      if (photo.storagePath != null) {
        await _storage.remove([photo.storagePath!]);
        _urlCache.remove(photo.storagePath);
      }
    } on Exception {
      throw const PhotoFailure('Foto konnte nicht gelöscht werden.');
    }
  }

  @override
  Future<void> reorder(String userId, List<String> photoIds) async {
    try {
      await _client.rpc<void>(
        'reorder_profile_photos',
        params: {'p_ids': photoIds},
      );
    } on Exception {
      throw const PhotoFailure('Reihenfolge konnte nicht gespeichert werden.');
    }
  }

  @override
  Future<Map<String, List<ProfileImage>>> imagesFor(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return {};
    try {
      // RLS: nur freigegebene Fotos sichtbarer, nicht blockierter Profile.
      final rows = await _client
          .from('profile_photos')
          .select('profile_id, storage_path, position')
          .inFilter('profile_id', profileIds)
          .order('position', ascending: true);
      final urls = await _signedUrls([
        for (final r in rows) r['storage_path'] as String,
      ]);
      final result = <String, List<ProfileImage>>{};
      for (final r in rows) {
        final url = urls[r['storage_path']];
        if (url == null) continue;
        result
            .putIfAbsent(r['profile_id'] as String, () => [])
            .add(NetworkProfileImage(url));
      }
      return result;
    } on Exception {
      return {}; // Ohne Fotos weiter – Initialen statt Fehler
    }
  }
}
