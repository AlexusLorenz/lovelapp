import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../discover/discover_providers.dart';
import '../onboarding/profile_draft.dart';
import '../onboarding/profile_repository.dart';
import '../session/session_controller.dart';
import 'own_profile.dart';
import 'profile_basics.dart';
import 'widgets/profile_editors.dart';

final ownProfileProvider = FutureProvider.autoDispose<OwnProfile?>((ref) async {
  final id = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (id == null) return null;
  return ref.read(profileRepositoryProvider).fetchOwnProfile(id);
});

/// Eigenes Profil bearbeiten: Name, Über mich, Stadt, Steckbrief, Fragen.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Profil bearbeiten')),
        body: Center(
          child: Text(
            e is ProfileFailure ? e.message : 'Laden fehlgeschlagen.',
          ),
        ),
      ),
      data: (p) => p == null
          ? const Scaffold(body: Center(child: Text('Kein Profil gefunden.')))
          : _EditForm(initial: p),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.initial});

  final OwnProfile initial;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  final _heightKey = GlobalKey<FormFieldState<String>>();
  late final _name = TextEditingController(text: widget.initial.displayName);
  late final _bio = TextEditingController(text: widget.initial.bio);
  late final _city = TextEditingController(text: widget.initial.city);
  late final _height = TextEditingController(
    text: widget.initial.basics.heightCm?.toString() ?? '',
  );
  late final _prompts = PromptEditorController(widget.initial.prompts);
  late ProfileBasics _basics = widget.initial.basics;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _city.dispose();
    _height.dispose();
    _prompts.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = OwnProfile(
      displayName: _name.text,
      bio: _bio.text,
      city: _city.text,
      basics: _basics.copyWith(
        heightCm: () => int.tryParse(_height.text.trim()),
      ),
      prompts: _prompts.value,
    );
    final problem = updated.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateOwnProfile(userId, updated);
      ref
        ..invalidate(ownProfileProvider)
        ..invalidate(ownSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profil gespeichert.')));
        context.pop();
      }
    } on ProfileFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil bearbeiten'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              maxLength: maxDisplayNameLength,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vorname',
                border: OutlineInputBorder(),
              ),
              validator: validateDisplayName,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bio,
              maxLength: maxBioLength,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Über mich',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _city,
              maxLength: maxCityLength,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Stadt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Fragen über dich', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Freiwillig, bis zu drei.'),
            const SizedBox(height: 12),
            PromptEditor(controller: _prompts),
            const SizedBox(height: 8),
            Text('Steckbrief', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'Alles freiwillig. Nochmal tippen hebt eine Auswahl auf.',
            ),
            const SizedBox(height: 12),
            BasicsForm(
              basics: _basics,
              heightController: _height,
              heightKey: _heightKey,
              onChanged: (b) => setState(() => _basics = b),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
