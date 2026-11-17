import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/widgets/profile_image.dart';
import '../../data/demo_data.dart';
import '../discover/public_profile.dart';
import '../photos/image_processing.dart';
import '../photos/photos_repository.dart';
import '../session/session_controller.dart';
import 'own_profile.dart';
import 'profile_completion.dart';

String? _userId(Ref ref) =>
    ref.watch(sessionProvider.select((s) => s.user?.id));

/// Eigenes Profil (Texte, Steckbrief, Fragen).
final ownProfileProvider = FutureProvider<OwnProfile?>((ref) async {
  final id = _userId(ref);
  if (id == null) return null;
  return ref.read(profileRepositoryProvider).fetchOwnProfile(id);
});

/// Eigene Fotos in Reihenfolge – mit Hochladen, Löschen, Sortieren.
class OwnPhotosController extends AsyncNotifier<List<OwnPhoto>> {
  String? get _id => ref.read(sessionProvider).user?.id;
  PhotosRepository get _repo => ref.read(photosRepositoryProvider);

  @override
  Future<List<OwnPhoto>> build() async {
    final id = _userId(ref);
    if (id == null) return const [];
    return _repo.fetchOwn(id);
  }

  /// Bereitet das Bild vor (verkleinern, Metadaten entfernen) und lädt es
  /// hinten an. Wirft [PhotoFailure] mit anzeigbarer Meldung.
  Future<void> add(Uint8List original) async {
    final id = _id;
    if (id == null) return;
    final current = state.value ?? const <OwnPhoto>[];
    if (current.length >= maxPhotos) {
      throw const PhotoFailure('Höchstens $maxPhotos Fotos.');
    }
    final Uint8List jpeg;
    try {
      jpeg = await compute(_prepare, original);
    } on FormatException {
      throw const PhotoFailure('Dieses Bildformat wird nicht unterstützt.');
    }
    final photo = await _repo.upload(id, jpeg, position: current.length);
    state = AsyncData([...current, photo]);
  }

  Future<void> remove(OwnPhoto photo) async {
    final id = _id;
    if (id == null) return;
    final before = state.value ?? const <OwnPhoto>[];
    final after = [
      for (final p in before)
        if (p.id != photo.id) p,
    ];
    state = AsyncData(after); // sofort aus der Liste
    try {
      await _repo.delete(id, photo);
      if (after.isNotEmpty) {
        await _repo.reorder(id, [for (final p in after) p.id]);
      }
    } on PhotoFailure {
      state = AsyncData(before);
      rethrow;
    }
  }

  /// Verschiebt ein Foto von [oldIndex] an [newIndex] (Zielindex nach dem
  /// Herausnehmen, wie `onReorderItem` ihn liefert).
  Future<void> move(int oldIndex, int newIndex) async {
    final id = _id;
    if (id == null) return;
    final before = state.value ?? const <OwnPhoto>[];
    final list = List.of(before);
    list.insert(newIndex, list.removeAt(oldIndex));
    state = AsyncData(list); // sofort anzeigen
    try {
      await _repo.reorder(id, [for (final p in list) p.id]);
    } on PhotoFailure {
      state = AsyncData(before);
      rethrow;
    }
  }
}

Uint8List _prepare(Uint8List bytes) => prepareProfileJpeg(bytes);

final ownPhotosProvider =
    AsyncNotifierProvider<OwnPhotosController, List<OwnPhoto>>(
      OwnPhotosController.new,
    );

/// So sehen andere mein Profil – aus den eigenen Daten zusammengesetzt.
final ownPublicProfileProvider = Provider<AsyncValue<PublicProfile?>>((ref) {
  final profile = ref.watch(ownProfileProvider);
  final photos = ref.watch(ownPhotosProvider);
  final id = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (profile.isLoading || photos.isLoading) return const AsyncLoading();
  final p = profile.value;
  if (p == null || id == null) return const AsyncData(null);
  return AsyncData(
    PublicProfile(
      id: id,
      name: p.displayName,
      age: p.age ?? 0,
      city: p.city,
      distanceKm: null,
      bio: p.bio,
      level: p.level,
      photos: [for (final ph in photos.value ?? const <OwnPhoto>[]) ph.image],
      prompts: p.prompts,
      basics: p.basics,
    ),
  );
});

/// Vervollständigung in Prozent plus nächster Tipp.
final profileCompletionProvider = Provider<ProfileCompletion?>((ref) {
  final p = ref.watch(ownProfileProvider).value;
  if (p == null) return null;
  final photos = ref.watch(ownPhotosProvider).value?.length ?? 0;
  return computeCompletion(
    photoCount: photos,
    bio: p.bio,
    city: p.city,
    promptCount: p.prompts.length,
    basics: p.basics,
  );
});

/// Eigenes Hauptbild (erstes Foto); im Demo-Modus ohne Upload der Platzhalter.
ProfileImage? myMainPhoto(WidgetRef ref) {
  final first = ref.read(ownPhotosProvider).value?.firstOrNull?.image;
  if (first != null) return first;
  return Env.hasSupabase ? null : demoMyPhoto;
}
