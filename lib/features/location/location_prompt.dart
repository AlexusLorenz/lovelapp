import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../onboarding/profile_repository.dart';
import '../session/session_controller.dart';
import 'location_service.dart';

/// Bittet um den ungefähren Standort.
///
/// Ohne [onLocation] wird er direkt im eigenen Profil gespeichert (für den
/// Entdecken-Feed); mit [onLocation] nur zurückgegeben (fürs Onboarding).
class LocationPrompt extends ConsumerStatefulWidget {
  const LocationPrompt({
    super.key,
    this.onLocation,
    this.onSaved,
    this.compact = false,
  });

  final ValueChanged<ApproxLocation>? onLocation;
  final VoidCallback? onSaved;

  /// Ohne großes Symbol und Überschrift (eingebettet).
  final bool compact;

  @override
  ConsumerState<LocationPrompt> createState() => _LocationPromptState();
}

class _LocationPromptState extends ConsumerState<LocationPrompt> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = await ref
          .read(locationServiceProvider)
          .currentApproxLocation();
      if (widget.onLocation != null) {
        widget.onLocation!(location);
      } else {
        final user = ref.read(sessionProvider).user;
        if (user == null) return;
        await ref
            .read(profileRepositoryProvider)
            .updateLocation(user.id, location);
        widget.onSaved?.call();
      }
      if (mounted) setState(() => _done = true);
    } on LocationException catch (e) {
      setState(() => _error = e.message);
    } on ProfileFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          const Icon(
            Icons.near_me_outlined,
            size: 64,
            color: LovelColors.terracotta,
          ),
          const SizedBox(height: 16),
          Text(
            'Wo bist du ungefähr?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
        ],
        const Text(
          'Damit wir dir Menschen in deiner Nähe zeigen können. Wir speichern '
          'deinen Standort nur auf etwa einen Kilometer genau, und andere '
          'sehen nur die Entfernung.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_done)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: LovelColors.terracotta),
              SizedBox(width: 8),
              Text('Standort übernommen'),
            ],
          )
        else
          FilledButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: const Text('Standort freigeben'),
            onPressed: _busy ? null : _request,
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
    if (widget.compact) return content;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
      ),
    );
  }
}
