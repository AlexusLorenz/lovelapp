import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../session/session_controller.dart';
import 'extras_providers.dart';
import 'extras_repository.dart';
import 'interest_catalog.dart';

/// Interessen auswählen: nach Kategorien oder per Suche, max. 3 pro Kategorie.
class InterestPickerScreen extends ConsumerWidget {
  const InterestPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(ownExtrasProvider);
    return extras.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Interessen')),
        body: Center(child: Text('$e')),
      ),
      data: (e) => _InterestPicker(initial: e?.interests ?? const []),
    );
  }
}

class _InterestPicker extends ConsumerStatefulWidget {
  const _InterestPicker({required this.initial});

  final List<String> initial;

  @override
  ConsumerState<_InterestPicker> createState() => _InterestPickerState();
}

class _InterestPickerState extends ConsumerState<_InterestPicker> {
  // Unbekannte Schlüssel (neuere App-Version) bleiben erhalten.
  late final Set<String> _selected = {...widget.initial};
  final _search = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _countIn(String category) =>
      _selected.where((k) => k.split('.').first == category).length;

  void _toggle(Interest i) {
    setState(() {
      if (_selected.remove(i.key)) return;
      if (_countIn(i.category) >= maxPerCategory) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Höchstens $maxPerCategory in '
                '„${categoryByKey(i.category)!.label}“. '
                'Wähle erst eins ab.',
              ),
            ),
          );
        return;
      }
      _selected.add(i.key);
    });
  }

  Future<void> _save() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final keys = _selected.toList()..sort();
      await ref.read(extrasRepositoryProvider).saveInterests(userId, keys);
      ref.invalidate(profileExtrasProvider(userId));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Interessen gespeichert.')),
        );
      if (mounted) context.pop();
    } on ExtrasFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chip(Interest i) => FilterChip(
    label: Text(i.display),
    selected: _selected.contains(i.key),
    onSelected: (_) => _toggle(i),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = _query.trim().isNotEmpty;
    final results = searching ? searchInterests(_query) : const <Interest>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interessen'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Suchen, z. B. Bouldern, Jazz, Sushi …',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: 'Suche löschen',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      )
                    : null,
                filled: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.length} ausgewählt · '
                'bis zu $maxPerCategory pro Kategorie',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: searching
                ? (results.isEmpty
                      ? const Center(child: Text('Nichts gefunden.'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [for (final i in results) _chip(i)],
                            ),
                          ],
                        ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: interestCategories.length,
                    itemBuilder: (context, index) {
                      final c = interestCategories[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${c.emoji} ${c.label}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  '${_countIn(c.key)}/$maxPerCategory',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [for (final i in c.items) _chip(i)],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
