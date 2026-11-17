import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../profile_basics.dart';
import '../profile_prompts.dart';

/// Hält bis zu drei gewählte Fragen und die Antworten dazu.
class PromptEditorController extends ChangeNotifier {
  PromptEditorController([List<PromptAnswer> initial = const []]) {
    for (var i = 0; i < initial.length && i < promptsPerProfile; i++) {
      keys[i] = initial[i].promptKey;
      answers[i].text = initial[i].answer;
    }
    for (final c in answers) {
      c.addListener(notifyListeners);
    }
  }

  final List<String?> keys = List.filled(promptsPerProfile, null);
  final List<TextEditingController> answers = List.generate(
    promptsPerProfile,
    (_) => TextEditingController(),
  );

  /// Gewählte Fragen in Reihenfolge (leere Plätze fallen weg).
  List<PromptAnswer> get value => [
    for (var i = 0; i < promptsPerProfile; i++)
      if (keys[i] != null) PromptAnswer(keys[i]!, answers[i].text.trim()),
  ];

  /// Fehlermeldung oder `null`, wenn alles passt (auch: keine Frage gewählt).
  String? get error => validatePromptSelection(value);

  void choose(int slot, String key) {
    keys[slot] = key;
    notifyListeners();
  }

  void remove(int slot) {
    keys[slot] = null;
    answers[slot].clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in answers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Drei Plätze für Fragen: auswählen, beantworten, tauschen, entfernen.
class PromptEditor extends StatelessWidget {
  const PromptEditor({super.key, required this.controller});

  final PromptEditorController controller;

  Future<void> _choose(BuildContext context, int slot) async {
    final taken = {
      for (var i = 0; i < promptsPerProfile; i++)
        if (i != slot && controller.keys[i] != null) controller.keys[i]!,
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
                trailing: controller.keys[slot] == p.key
                    ? const Icon(Icons.check, color: LovelColors.terracotta)
                    : null,
                onTap: () => Navigator.of(context).pop(p.key),
              ),
          ],
        ),
      ),
    );
    if (key != null) controller.choose(slot, key);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          for (var i = 0; i < promptsPerProfile; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PromptSlot(
                index: i,
                promptKey: controller.keys[i],
                controller: controller.answers[i],
                onChoose: () => _choose(context, i),
                onChanged: () {},
                onRemove: () => controller.remove(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromptSlot extends StatelessWidget {
  const _PromptSlot({
    required this.onRemove,
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
  final VoidCallback onRemove;

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
                IconButton(
                  tooltip: 'Frage entfernen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
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

class BasicsForm extends StatelessWidget {
  const BasicsForm({
    super.key,
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
