import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_image.dart';
import '../../photos/photos_repository.dart';
import '../own_profile_providers.dart';

/// Wählt bis zu [limit] Bilder aus der Fotomediathek (Mehrfachauswahl).
/// In Tests überschreibbar.
typedef PickImages = Future<List<Uint8List>> Function(int limit);

final pickImagesProvider = Provider<PickImages>(
  (ref) => (limit) async {
    final files = await ImagePicker().pickMultiImage(
      // Vorab grob verkleinern; Feinschliff + Metadaten entfernen danach.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
      limit: limit,
      requestFullMetadata: false,
    );
    return [for (final f in files.take(limit)) await f.readAsBytes()];
  },
);

/// Startet das Ziehen schon nach einem Drittel der üblichen Wartezeit.
class _QuickDragStartListener extends ReorderableDragStartListener {
  const _QuickDragStartListener({
    required super.key,
    required super.child,
    required super.index,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(
        delay: const Duration(milliseconds: 170), // statt 500 ms
        debugOwner: this,
      );
}

/// Eigene Fotos: hinzufügen, löschen, per Ziehen sortieren.
/// Das erste Foto ist das Hauptbild.
class PhotoEditor extends ConsumerStatefulWidget {
  const PhotoEditor({super.key});

  @override
  ConsumerState<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends ConsumerState<PhotoEditor> {
  bool _uploading = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final current = ref.read(ownPhotosProvider).value?.length ?? 0;
    final free = maxPhotos - current;
    if (free <= 0) return;
    final picked = await ref.read(pickImagesProvider)(free);
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      // Nacheinander, damit die Reihenfolge der Auswahl erhalten bleibt.
      for (final bytes in picked) {
        await ref.read(ownPhotosProvider.notifier).add(bytes);
      }
    } on PhotoFailure catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(OwnPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Foto löschen?'),
        content: const Text('Das Foto wird endgültig entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ownPhotosProvider.notifier).remove(photo);
    } on PhotoFailure catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    try {
      await ref.read(ownPhotosProvider.notifier).move(oldIndex, newIndex);
    } on PhotoFailure catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(ownPhotosProvider);
    final list = photos.value ?? const <OwnPhoto>[];
    final canAdd = list.length < maxPhotos && !_uploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 172,
          child: photos.isLoading && list.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: list.length,
                  onReorderItem: _move,
                  proxyDecorator: (child, _, _) => Material(
                    color: Colors.transparent,
                    elevation: 6,
                    child: child,
                  ),
                  itemBuilder: (context, i) => _QuickDragStartListener(
                    key: ValueKey(list[i].id),
                    index: i,
                    child: _PhotoTile(
                      photo: list[i],
                      index: i,
                      onRemove: () => _remove(list[i]),
                    ),
                  ),
                  footer: canAdd || _uploading
                      ? _AddTile(
                          uploading: _uploading,
                          onTap: canAdd ? _add : null,
                        )
                      : null,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          list.length < 2
              ? 'Bis zu $maxPhotos Fotos. Das erste ist dein Hauptbild.'
              : 'Foto gedrückt halten und ziehen, um die Reihenfolge zu ändern. '
                    'Das erste ist dein Hauptbild.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.onRemove,
  });

  final OwnPhoto photo;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 4),
      child: SizedBox(
        width: 124,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Semantics(
                label: 'Foto ${index + 1}${index == 0 ? ', Hauptbild' : ''}',
                image: true,
                child: ProfileImageView(image: photo.image),
              ),
            ),
            if (index == 0)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: LovelColors.terracotta,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Hauptbild',
                    style: TextStyle(color: LovelColors.cream, fontSize: 11),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                tooltip: 'Foto ${index + 1} löschen',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: LovelColors.cream,
                  foregroundColor: LovelColors.umber,
                ),
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.uploading, required this.onTap});

  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: 124,
        child: Material(
          color: LovelColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: LovelColors.slate, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: uploading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Lädt hoch …'),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: LovelColors.umber,
                          size: 32,
                        ),
                        SizedBox(height: 6),
                        Text('Foto hinzufügen', textAlign: TextAlign.center),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
