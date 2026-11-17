import 'dart:typed_data';

import '../../core/widgets/profile_image.dart';

/// Höchstens so viele Fotos pro Profil (DB: Position 0–5).
const maxPhotos = 6;

/// Ein eigenes Foto in der Bearbeitung.
class OwnPhoto {
  const OwnPhoto({required this.id, required this.image, this.storagePath});

  final String id;
  final ProfileImage image;

  /// Pfad im Storage-Bucket (nur mit Supabase).
  final String? storagePath;
}

class PhotoFailure implements Exception {
  const PhotoFailure(this.message);

  final String message;

  @override
  String toString() => 'PhotoFailure: $message';
}

abstract interface class PhotosRepository {
  Future<List<OwnPhoto>> fetchOwn(String userId);

  /// Lädt ein fertig vorbereitetes JPEG hoch und hängt es hinten an.
  Future<OwnPhoto> upload(
    String userId,
    Uint8List jpeg, {
    required int position,
  });

  Future<void> delete(String userId, OwnPhoto photo);

  /// Neue Reihenfolge: [photoIds] enthält alle eigenen Fotos.
  Future<void> reorder(String userId, List<String> photoIds);

  /// Fotos anderer Profile (nur freigegebene), je Profil sortiert.
  Future<Map<String, List<ProfileImage>>> imagesFor(List<String> profileIds);
}

/// Demo-Modus: Fotos nur im Speicher.
class DemoPhotosRepository implements PhotosRepository {
  final _photos = <String, List<OwnPhoto>>{};
  var _counter = 0;

  @override
  Future<List<OwnPhoto>> fetchOwn(String userId) async =>
      List.of(_photos[userId] ?? const []);

  @override
  Future<OwnPhoto> upload(
    String userId,
    Uint8List jpeg, {
    required int position,
  }) async {
    final list = _photos.putIfAbsent(userId, () => []);
    if (list.length >= maxPhotos) {
      throw const PhotoFailure('Höchstens $maxPhotos Fotos.');
    }
    final photo = OwnPhoto(
      id: 'demo-${_counter++}',
      image: MemoryProfileImage(jpeg),
    );
    list.add(photo);
    return photo;
  }

  @override
  Future<void> delete(String userId, OwnPhoto photo) async =>
      _photos[userId]?.removeWhere((p) => p.id == photo.id);

  @override
  Future<void> reorder(String userId, List<String> photoIds) async {
    final byId = {for (final p in _photos[userId] ?? <OwnPhoto>[]) p.id: p};
    _photos[userId] = [
      for (final id in photoIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<Map<String, List<ProfileImage>>> imagesFor(
    List<String> profileIds,
  ) async => {};
}
