import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../session/session_controller.dart';
import '../location/location_prompt.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';
import 'date_input_formatter.dart';
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

enum _Step {
  name,
  birthdate,
  gender,
  interests,
  basics,
  prompts,
  location,
  about,
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _draft = ProfileDraft();
  final _name = TextEditingController();
  final _birthdate = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _height = TextEditingController();
  final _heightKey = GlobalKey<FormFieldState<String>>();

  /// Gewählte Fragen je Platz (oder `null`) und die Antworten dazu.
  final List<String?> _promptKeys = List.filled(promptsPerProfile, null);
  final List<TextEditingController> _promptAnswers = List.generate(
    promptsPerProfile,
    (_) => TextEditingController(),
  );
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
    _height.dispose();
    for (final c in _promptAnswers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    _Step.name => true,
    _Step.birthdate => true,
    _Step.gender => _draft.gender != null,
    _Step.interests =>
      _draft.interestedIn.isNotEmpty && _draft.sensitiveConsentAt != null,
    _Step.basics => true,
    _Step.prompts => validatePromptSelection(_currentPrompts) == null,
    _Step.location => true, // freiwillig, lässt sich später nachholen
    _Step.about => !_saving,
  };

  List<PromptAnswer> get _currentPrompts => [
    for (var i = 0; i < promptsPerProfile; i++)
      if (_promptKeys[i] != null)
        PromptAnswer(_promptKeys[i]!, _promptAnswers[i].text.trim()),
  ];

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
      case _Step.basics:
        if (!_heightKey.currentState!.validate()) return;
        final cm = int.tryParse(_height.text.trim());
        _draft.basics = _draft.basics.copyWith(heightCm: () => cm);
      case _Step.prompts:
        _draft.prompts = _currentPrompts;
      case _Step.location:
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

  Future<void> _choosePrompt(int slot) async {
    final taken = {
      for (var i = 0; i < promptsPerProfile; i++)
        if (i != slot && _promptKeys[i] != null) _promptKeys[i]!,
    };
    final key = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: LovelColors.cream,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Frage auswählen',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            for (final p in promptCatalog)
              ListTile(
                enabled: !taken.contains(p.key),
                title: Text(p.question),
                trailing: _promptKeys[slot] == p.key
                    ? const Icon(Icons.check, color: LovelColors.terracotta)
                    : null,
                onTap: () => Navigator.of(context).pop(p.key),
              ),
          ],
        ),
      ),
    );
    if (key != null && mounted) {
      setState(() => _promptKeys[slot] = key);
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
            keyboardType: TextInputType.number,
            inputFormatters: const [GermanDateInputFormatter()],
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
      case _Step.basics:
        return _StepLayout(
          title: 'Dein Steckbrief',
          hint: 'Alles freiwillig – lass weg, was du nicht teilen magst.',
          child: _BasicsForm(
            basics: _draft.basics,
            heightController: _height,
            heightKey: _heightKey,
            onChanged: (b) => setState(() => _draft.basics = b),
          ),
        );
      case _Step.prompts:
        return _StepLayout(
          title: 'Drei Fragen über dich',
          hint:
              'Such dir $promptsPerProfile Fragen aus. Die Antworten '
              'stehen auf deinem Profil – gute Eisbrecher!',
          child: Column(
            children: [
              for (var i = 0; i < promptsPerProfile; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PromptSlot(
                    index: i,
                    promptKey: _promptKeys[i],
                    controller: _promptAnswers[i],
                    onChoose: () => _choosePrompt(i),
                    onChanged: () => setState(() {}),
                  ),
                ),
            ],
          ),
        );
      case _Step.location:
        return _StepLayout(
          title: 'Wo bist du ungefähr?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationPrompt(
                compact: true,
                onLocation: (l) => setState(() => _draft.location = l),
              ),
              if (_draft.location == null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Du kannst das auch später nachholen – ohne Standort '
                  'zeigt dir der Entdecken-Feed aber niemanden.',
                  textAlign: TextAlign.center,
                ),
              ],
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

class _PromptSlot extends StatelessWidget {
  const _PromptSlot({
    required this.index,
    required this.promptKey,
    required this.controller,
    required this.onChoose,
    required this.onChanged,
  });

  final int index;
  final String? promptKey;
  final TextEditingController controller;
  final VoidCallback onChoose;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = promptKey == null ? null : promptByKey(promptKey!);
    if (prompt == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          foregroundColor: LovelColors.umber,
          side: const BorderSide(color: LovelColors.slate, width: 1.5),
        ),
        icon: const Icon(Icons.add),
        label: Text('Frage ${index + 1} auswählen'),
        onPressed: onChoose,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prompt.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: LovelColors.umber,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Andere Frage wählen',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: onChoose,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: controller,
                maxLength: maxPromptAnswerLength,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Deine Antwort',
                  labelText: 'Antwort ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasicsForm extends StatelessWidget {
  const _BasicsForm({
    required this.basics,
    required this.heightController,
    required this.heightKey,
    required this.onChanged,
  });

  final ProfileBasics basics;
  final TextEditingController heightController;
  final GlobalKey<FormFieldState<String>> heightKey;
  final ValueChanged<ProfileBasics> onChanged;

  Widget _section<T extends BasicOption>(
    BuildContext context,
    String title,
    List<T> options,
    T? selected,
    ValueChanged<T?> onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: selected == o,
                  // Nochmal tippen hebt die Auswahl auf.
                  onSelected: (on) => onSelect(on ? o : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          context,
          'Ich suche …',
          RelationshipGoal.values,
          basics.relationshipGoal,
          (v) => onChanged(basics.copyWith(relationshipGoal: () => v)),
        ),
        _section(
          context,
          'Kinder',
          ChildrenPlan.values,
          basics.children,
          (v) => onChanged(basics.copyWith(children: () => v)),
        ),
        _section(
          context,
          'Rauchen',
          Smoking.values,
          basics.smoking,
          (v) => onChanged(basics.copyWith(smoking: () => v)),
        ),
        _section(
          context,
          'Alkohol',
          Drinking.values,
          basics.drinking,
          (v) => onChanged(basics.copyWith(drinking: () => v)),
        ),
        _section(
          context,
          'Sport',
          Exercise.values,
          basics.exercise,
          (v) => onChanged(basics.copyWith(exercise: () => v)),
        ),
        TextFormField(
          key: heightKey,
          controller: heightController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: const InputDecoration(
            labelText: 'Größe (cm)',
            border: OutlineInputBorder(),
          ),
          validator: validateHeight,
        ),
      ],
    );
  }
}
