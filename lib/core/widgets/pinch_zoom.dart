import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Zwei-Finger-Zoom wie in Foto-Apps: Mit zwei Fingern wird das Bild über
/// allem anderen vergrößert und verschoben, beim Loslassen springt es zurück.
///
/// Arbeitet mit rohen Zeigerereignissen ([Listener]) und nimmt deshalb nicht
/// an der Gestenerkennung teil – Scrollen und Wischen mit einem Finger
/// funktionieren unverändert.
class PinchZoom extends StatefulWidget {
  const PinchZoom({super.key, required this.child, this.maxScale = 4});

  final Widget child;
  final double maxScale;

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom>
    with SingleTickerProviderStateMixin {
  final _pointers = <int, Offset>{};
  final _zoom = ValueNotifier<_ZoomState?>(null);
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  OverlayEntry? _entry;
  Rect? _origin;
  double _startDistance = 1;
  Offset _startFocal = Offset.zero;
  _ZoomState? _releaseFrom;

  bool get _zooming => _entry != null;

  @override
  void dispose() {
    _removeOverlay();
    _release.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2 && !_zooming) _start();
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_zooming && _pointers.length >= 2 && !_release.isAnimating) {
      final (focal, distance) = _measure();
      final scale = (distance / _startDistance).clamp(1.0, widget.maxScale);
      _zoom.value = _ZoomState(scale: scale, offset: focal - _startFocal);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_zooming && _pointers.length < 2) _end();
  }

  (Offset, double) _measure() {
    final points = _pointers.values.take(2).toList();
    final focal = (points[0] + points[1]) / 2;
    final distance = math.max((points[0] - points[1]).distance, 1.0);
    return (focal, distance);
  }

  void _start() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _origin = box.localToGlobal(Offset.zero) & box.size;
    final (focal, distance) = _measure();
    _startFocal = focal;
    _startDistance = distance;
    _zoom.value = const _ZoomState(scale: 1, offset: Offset.zero);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {}); // Original ausblenden
  }

  Future<void> _end() async {
    _releaseFrom = _zoom.value;
    await _release.forward(from: 0);
    _removeOverlay();
    if (mounted) setState(() {});
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final origin = _origin!;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_zoom, _release]),
        builder: (context, _) {
          var state = _zoom.value ?? const _ZoomState.identity();
          if (_release.isAnimating || _release.isCompleted) {
            final t = Curves.easeOut.transform(_release.value);
            final from = _releaseFrom ?? state;
            state = _ZoomState(
              scale: 1 + (from.scale - 1) * (1 - t),
              offset: from.offset * (1 - t),
            );
          }
          // Hintergrund dunkelt je nach Zoomstufe ab.
          final dim = ((state.scale - 1) / 1.5).clamp(0.0, 0.6);
          final focalInBox = _startFocal - origin.topLeft;
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: dim)),
              ),
              Positioned.fromRect(
                rect: origin,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      state.offset.dx + focalInBox.dx,
                      state.offset.dy + focalInBox.dy,
                      0,
                      1,
                    )
                    ..scaleByDouble(state.scale, state.scale, 1, 1)
                    ..translateByDouble(-focalInBox.dx, -focalInBox.dy, 0, 1),
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Opacity(opacity: _zooming ? 0 : 1, child: widget.child),
    );
  }
}

class _ZoomState {
  const _ZoomState({required this.scale, required this.offset});
  const _ZoomState.identity() : scale = 1, offset = Offset.zero;

  final double scale;
  final Offset offset;
}
