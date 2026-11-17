import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../session/session_controller.dart';
import 'profile_draft.dart';
import 'profile_repository.dart';

/// Schritt für Schritt zum eigenen Profil.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.clock = DateTime.now});

  /// Für Tests austauschbar.
  final DateTime Function() clock;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { name, birthdate, gender, interests, about }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _draft = ProfileDraft();
  final _name = TextEditingController();
  final _birthdate = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _nameKey = GlobalKey<FormFieldState<String>>();
  final _birthdateKey = GlobalKey<FormFieldState<String>>();

  _Step _step = _Step.name;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _birthdate.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    _Step.name => true,
    _Step.birthdate => true,
    _Step.gender => _draft.gender != null,
    _Step.interests =>
      _draft.interestedIn.isNotEmpty && _draft.sensitiveConsentAt != null,
    _Step.about => !_saving,
  };

  void _back() {
    if (_step.index == 0) return;
    setState(() => _step = _Step.values[_step.index - 1]);
  }

  Future<void> _next() async {
    switch (_step) {
      case _Step.name:
        if (!_nameKey.currentState!.validate()) return;
        _draft.displayName = _name.text.trim();
      case _Step.birthdate:
        if (!_birthdateKey.currentState!.validate()) return;
        _draft.birthdate = parseGermanDate(_birthdate.text);
      case _Step.gender:
      case _Step.interests:
        break;
      case _Step.about:
        await _save();
        return;
    }
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  Future<void> _save() async {
    _draft
      ..city = _city.text
      ..bio = _bio.text;
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).createProfile(user.id, _draft);
      await ref.read(sessionProvider.notifier).reload();
      // Der Router leitet jetzt in die App weiter.
    } on ProfileFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step.index + 1) / _Step.values.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dein Profil'),
        leading: _step.index > 0
            ? IconButton(
                tooltip: 'Zurück',
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Abmelden'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: LovelColors.cream,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(context),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _canContinue ? _next : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == _Step.about ? 'Los geht’s' : 'Weiter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    final today = widget.clock();
    switch (_step) {
      case _Step.name:
        return _StepLayout(
          title: 'Wie heißt du?',
          hint: 'So sehen dich andere. Der Vorname reicht völlig.',
          child: TextFormField(
            key: _nameKey,
            controller: _name,
            autofocus: true,
            maxLength: maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Vorname',
              border: OutlineInputBorder(),
            ),
            validator: validateDisplayName,
            onFieldSubmitted: (_) => _next(),
          ),
        );
      case _Step.birthdate:
        return _StepLayout(
          title: 'Wann hast du Geburtstag?',
          hint:
              'Andere sehen nur dein Alter, nie das Datum. '
              'Lovel ist ab $minAge Jahren.',
          child: TextFormField(
            key: _birthdateKey,
            controller: _birthdate,
            autofocus: true,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Geburtsdatum',
              hintText: 'TT.MM.JJJJ',
              border: OutlineInputBorder(),
            ),
            validator: (v) => validateBirthdate(v, today: today),
            onFieldSubmitted: (_) => _next(),
          ),
        );
      case _Step.gender:
        return _StepLayout(
          title: 'Ich bin …',
          child: Column(
            children: [
              for (final g in Gender.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChoiceTile(
                    label: g.label,
                    selected: _draft.gender == g,
                    onTap: () => setState(() => _draft.gender = g),
                  ),
                ),
            ],
          ),
        );
      case _Step.interests:
        return _StepLayout(
          title: 'Wen möchtest du kennenlernen?',
          hint: 'Mehrfachauswahl möglich.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in Gender.values)
                    FilterChip(
                      label: Text(g.pluralLabel),
                      selected: _draft.interestedIn.contains(g),
                      onSelected: (on) => setState(() {
                        on
                            ? _draft.interestedIn.add(g)
                            : _draft.interestedIn.remove(g);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: CheckboxListTile(
                  value: _draft.sensitiveConsentAt != null,
                  onChanged: (on) => setState(() {
                    _draft.sensitiveConsentAt = (on ?? false)
                        ? DateTime.now()
                        : null;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Ich willige ausdrücklich ein, dass Lovel diese Angabe '
                    'speichert und für passende Vorschläge nutzt.',
                  ),
                  subtitle: const Text(
                    'Aus der Angabe kann sich deine sexuelle Orientierung '
                    'ergeben. Sie ist für andere nicht sichtbar. Du kannst '
                    'die Einwilligung jederzeit widerrufen '
                    '(Art. 9 Abs. 2 lit. a DSGVO).',
                  ),
                ),
              ),
            ],
          ),
        );
      case _Step.about:
        return _StepLayout(
          title: 'Fast fertig!',
          hint: 'Beides ist freiwillig und lässt sich später ändern.',
          child: Column(
            children: [
              TextField(
                controller: _city,
                maxLength: maxCityLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Stadt',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bio,
                maxLength: maxBioLength,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Über mich',
                  hintText: 'Was sollte man über dich wissen?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.title, this.hint, required this.child});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (hint != null) ...[const SizedBox(height: 8), Text(hint!)],
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LovelColors.blush : LovelColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? LovelColors.terracotta : LovelColors.mist,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? LovelColors.terracotta : LovelColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
