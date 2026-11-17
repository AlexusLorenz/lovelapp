import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../data/demo_data.dart';

/// Chat mit einem Match.
///
/// TODO(backend): Nachrichten aus `messages` laden und per Supabase Realtime
/// abonnieren; Senden per Insert (RLS prüft Match-Mitgliedschaft).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  const _ChatMessage(this.text, {required this.mine});

  final String text;
  final bool mine;
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  late final List<_ChatMessage> _messages;
  DemoMatch? _match;

  @override
  void initState() {
    super.initState();
    for (final m in demoMatches) {
      if (m.id == widget.matchId) _match = m;
    }
    _messages = [
      if (_match != null) _ChatMessage(_match!.lastMessage, mine: false),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(_ChatMessage(text, mine: true)));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_match?.profile.name ?? 'Chat'),
        actions: [
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: msg.mine ? scheme.primary : scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.mine ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
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
                    onPressed: _send,
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
