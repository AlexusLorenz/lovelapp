import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../matches/matches_repository.dart';
import '../session/session_controller.dart';

/// Chat mit einem Match – Nachrichten kommen live (Supabase Realtime).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(matchesRepositoryProvider)
          .sendMessage(widget.matchId, text);
      _controller.clear();
      ref.invalidate(matchesProvider); // Vorschau in der Liste aktualisieren
    } on ChatFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final messages = ref.watch(messagesProvider(widget.matchId));
    MatchSummary? match;
    for (final m
        in ref.watch(matchesProvider).value ?? const <MatchSummary>[]) {
      if (m.matchId == widget.matchId) match = m;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(match?.profile.name ?? 'Chat'),
        actions: [
          if (match != null)
            IconButton(
              tooltip: 'Profil ansehen',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push(Routes.person(match!.profile.id)),
            ),
          IconButton(
            tooltip: 'Eisbrecher-Spiel',
            icon: const Icon(Icons.sports_esports),
            onPressed: () => context.push(Routes.games),
          ),
          PopupMenuButton<String>(
            // TODO(safety): Melden/Blockieren an `reports`/`blocks` anbinden.
            onSelected: (_) => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Danke, wir prüfen das.')),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Melden')),
              PopupMenuItem(value: 'block', child: Text('Blockieren')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Nachrichten konnten nicht geladen werden.'),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Schreib die erste Nachricht!'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      reverse: true, // neueste unten, Liste startet unten
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final msg = list[list.length - 1 - i];
                        final mine = msg.senderId == myId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? scheme.primary : scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg.body,
                              style: TextStyle(
                                color: mine
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 2000,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Nachricht schreiben',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Senden',
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
