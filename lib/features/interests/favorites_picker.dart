import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'extras_repository.dart';

/// Gemeinsamer Aufbau für „Lieblingsspiele“ und „Lieblingsmusik“:
/// oben die Auswahl (antippen = entfernen), darunter Suche mit Ergebnissen.
class FavoritesPicker<T> extends StatefulWidget {
  const FavoritesPicker({
    super.key,
    required this.title,
    required this.initial,
    required this.max,
    required this.searchHint,
    required this.search,
    required this.nameOf,
    required this.thumbnail,
    required this.onSave,
    this.header,
    this.attribution,
    this.suggestions = const [],
    this.suggestionsTitle,
  });

  final String title;
  final List<T> initial;
  final int max;
  final String searchHint;
  final Future<List<T>> Function(String query) search;
  final String Function(T item) nameOf;
  final Widget Function(T item) thumbnail;
  final Future<void> Function(List<T> selected) onSave;

  /// Z. B. „Mit Spotify verbinden“.
  final Widget? header;

  /// Quellenangabe unten (Pflicht bei RAWG und Spotify).
  final Widget? attribution;

  /// Vorschläge, solange nichts gesucht wird (z. B. Spotify-Top-Liste).
  final List<T> suggestions;
  final String? suggestionsTitle;

  @override
  State<FavoritesPicker<T>> createState() => _FavoritesPickerState<T>();
}

class _FavoritesPickerState<T> extends State<FavoritesPicker<T>> {
  late final List<T> _selected = List.of(widget.initial);
  final _query = TextEditingController();
  Timer? _debounce;
  List<T> _results = const [];
  String? _searchError;
  bool _searching = false;
  bool _saving = false;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
    setState(() {});
  }

  Future<void> _run(String value) async {
    final id = ++_searchId;
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await widget.search(value);
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = found;
        _searchError = null;
      });
    } on ExtrasFailure catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() => _searchError = e.message);
    } finally {
      if (mounted && id == _searchId) setState(() => _searching = false);
    }
  }

  void _toggle(T item) {
    setState(() {
      if (_selected.remove(item)) return;
      if (_selected.length >= widget.max) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Höchstens ${widget.max}. Tippe oben eins an, um es zu entfernen.',
              ),
            ),
          );
        return;
      }
      _selected.add(item);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSave(List.of(_selected));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gespeichert.')));
      if (mounted) Navigator.of(context).maybePop();
    } on ExtrasFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _resultTile(T item) {
    final selected = _selected.contains(item);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 64, height: 48, child: widget.thumbnail(item)),
      ),
      title: Text(widget.nameOf(item)),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.add_circle_outline,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: () => _toggle(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.text.trim();
    final showSuggestions = query.length < 2 && widget.suggestions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Deine Auswahl (${_selected.length}/${widget.max})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_selected.isEmpty)
            Text('Noch nichts ausgewählt.', style: theme.textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _selected)
                  InputChip(
                    avatar: ClipOval(
                      child: SizedBox.square(
                        dimension: 24,
                        child: widget.thumbnail(item),
                      ),
                    ),
                    label: Text(widget.nameOf(item)),
                    onDeleted: () => _toggle(item),
                    deleteButtonTooltipMessage:
                        '${widget.nameOf(item)} entfernen',
                  ),
              ],
            ),
          if (widget.header != null) ...[
            const SizedBox(height: 16),
            widget.header!,
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_searchError!, style: theme.textTheme.bodyMedium),
            )
          else if (showSuggestions) ...[
            if (widget.suggestionsTitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.suggestionsTitle!,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            for (final item in widget.suggestions) _resultTile(item),
          ] else if (query.length >= 2 && !_searching && _results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nichts gefunden.'),
            )
          else
            for (final item in _results) _resultTile(item),
          if (widget.attribution != null) ...[
            const SizedBox(height: 24),
            widget.attribution!,
          ],
        ],
      ),
    );
  }
}
