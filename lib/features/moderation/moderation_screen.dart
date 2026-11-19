import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../safety/safety_repository.dart';
import 'moderation_providers.dart';

String _reasonLabel(String key) {
  for (final r in ReportReason.values) {
    if (r.dbValue == key) return r.label;
  }
  return key;
}

String _statusLabel(String status) => switch (status) {
  'open' => 'Offen',
  'in_review' => 'In Prüfung',
  'resolved' => 'Erledigt',
  'dismissed' => 'Verworfen',
  _ => status,
};

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Moderation: Meldungen bearbeiten und Kennzahlen ansehen (nur Admins).
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider);
    if (admin.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (admin.value != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation')),
        body: const Center(child: Text('Nur für das Moderationsteam.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderation'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Meldungen'),
              Tab(text: 'Kennzahlen'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ReportsTab(), _StatsTab()]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Meldungen
// -----------------------------------------------------------------------------

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(modReportsProvider);
    final onlyOpen = ref.watch(modOnlyOpenProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(modReportsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Offen')),
              ButtonSegment(value: false, label: Text('Alle')),
            ],
            selected: {onlyOpen},
            onSelectionChanged: (s) =>
                ref.read(modOnlyOpenProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 12),
          ...reports.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text('Meldungen nicht ladbar: $e')],
            data: (list) => list.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Keine Meldungen. 🎉',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ]
                : [for (final r in list) _ReportCard(report: r)],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.report});

  final ModReport report;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(ModerationRepository) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(moderationRepositoryProvider));
      ref
        ..invalidate(modReportsProvider)
        ..invalidate(modStatsProvider);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hat nicht geklappt: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ban() async {
    final reason = TextEditingController(
      text: _reasonLabel(widget.report.reason),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.report.reported.name} sperren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Das Konto kann sich nicht mehr anmelden, ist für niemanden '
              'mehr sichtbar, alle Matches und Spiele enden. Offene '
              'Meldungen gegen die Person gelten als erledigt.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Grund (intern)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LovelColors.unread),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sperren'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    await _run((repo) => repo.ban(widget.report.reported.id, text));
  }

  Future<void> _removePhoto(ModPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Foto entfernen?'),
        content: const Text('Das Foto ist danach für niemanden mehr sichtbar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run((repo) => repo.removePhoto(photo.id));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final p = r.reported;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _reasonLabel(r.reason),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_statusLabel(r.status))),
              ],
            ),
            Text(
              '${_date(r.createdAt)} · gemeldet von '
              '${r.reporter?.name ?? 'gelöschtem Konto'}',
              style: theme.textTheme.bodySmall,
            ),
            if (r.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.details),
            ],
            if (r.message != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LovelColors.mist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Gemeldete Nachricht: „${r.message}“'),
              ),
            ],
            const Divider(height: 24),
            Text(
              '${p.name}${p.isTest ? ' (Test)' : ''}',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${p.reportCount} Meldung(en) insgesamt'
              '${p.isBanned ? ' · gesperrt seit ${_date(p.bannedAt!)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: p.isBanned ? LovelColors.unread : null,
              ),
            ),
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.bio, style: theme.textTheme.bodySmall),
            ],
            if (p.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final photo in p.photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PhotoThumb(
                          photo: photo,
                          onRemove: _busy || photo.isRemoved
                              ? null
                              : () => _removePhoto(photo),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (r.isOpen) ...[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            (repo) => repo.setReportStatus(r.id, 'dismissed'),
                          ),
                    child: const Text('Verwerfen'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            (repo) => repo.setReportStatus(r.id, 'resolved'),
                          ),
                    child: const Text('Erledigt'),
                  ),
                ],
                if (p.isBanned)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run((repo) => repo.unban(p.id)),
                    child: const Text('Entsperren'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LovelColors.unread,
                    ),
                    onPressed: _busy ? null : _ban,
                    child: const Text('Sperren'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onRemove});

  final ModPhoto photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photo.url == null
                ? const ColoredBox(color: LovelColors.mist)
                : Opacity(
                    opacity: photo.isRemoved ? 0.3 : 1,
                    child: Image.network(photo.url!, fit: BoxFit.cover),
                  ),
          ),
          if (photo.isRemoved)
            const Center(child: Icon(Icons.block, color: LovelColors.unread))
          else if (onRemove != null)
            Align(
              alignment: Alignment.topRight,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: 'Foto entfernen',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Kennzahlen
// -----------------------------------------------------------------------------

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(modStatsProvider);
    final withTest = ref.watch(modIncludeTestProvider);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(modStatsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Test-Accounts mitzählen'),
            value: withTest,
            onChanged: (v) => ref.read(modIncludeTestProvider.notifier).set(v),
          ),
          ...stats.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text('Kennzahlen nicht ladbar: $e')],
            data: (s) => [
              for (final (title, items) in describeStats(s)) ...[
                const SizedBox(height: 12),
                Text(title, style: theme.textTheme.titleMedium),
                Card(
                  child: Column(
                    children: [
                      for (final item in items)
                        ListTile(
                          dense: true,
                          title: Text(item.label),
                          subtitle: item.hint == null ? null : Text(item.hint!),
                          trailing: Text(
                            item.value,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
