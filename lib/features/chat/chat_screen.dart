import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo_data.dart';
import '../discover/discover_providers.dart';
import '../matches/matches_repository.dart';
import '../session/session_controller.dart';
import '../profile/own_profile_providers.dart';
import 'chat_background.dart';
import '../../core/widgets/profile_image.dart';

/// Chat mit einem Match – Nachrichten kommen live (Supabase Realtime).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Der Senden-Button soll dem Eingabefeld nie den Fokus wegnehmen.
  final _sendButtonFocus = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _sendButtonFocus.dispose();
    super.dispose();
  }

  bool _marking = false;

  Future<void> _markRead() async {
    if (_marking) return;
    _marking = true;
    try {
      await ref.read(matchesRepositoryProvider).markRead(widget.matchId);
    } finally {
      _marking = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Beim Öffnen sofort als gelesen markieren.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markRead();
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    // Fokus sofort zurück ins Eingabefeld, damit man weiterschreiben kann.
    _focus.requestFocus();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref
          .read(matchesRepositoryProvider)
          .sendMessage(widget.matchId, text);
      ref.invalidate(matchesProvider); // Vorschau in der Liste aktualisieren
    } on ChatFailure catch (e) {
      // Text nicht verlieren: wieder ins Feld, falls dort nichts Neues steht.
      if (_controller.text.isEmpty) _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final myName = ref.watch(
      ownSummaryProvider.select((s) => s.value?.displayName ?? demoMyName),
    );
    final messages = ref.watch(messagesProvider(widget.matchId));
    // Sobald Nachrichten des Gegenübers sichtbar sind: als gelesen markieren.
    ref.listen(messagesProvider(widget.matchId), (_, next) {
      final list = next.value;
      if (list != null && list.any((m) => m.senderId != myId)) {
        _markRead();
      }
    });
    MatchSummary? match;
    for (final m
        in ref.watch(matchesProvider).value ?? const <MatchSummary>[]) {
      if (m.matchId == widget.matchId) match = m;
    }
    final partner = match?.profile;

    final me = _AvatarData(
      name: myName,
      photo:
          ref.watch(ownPhotosProvider).value?.firstOrNull?.image ??
          myMainPhoto(ref),
    );
    final them = _AvatarData(
      name: partner?.name ?? '?',
      photo: (partner?.photos.isEmpty ?? true) ? null : partner!.photos.first,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(data: them, radius: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(partner?.name ?? 'Chat')),
          ],
        ),
        actions: [
          if (partner != null)
            IconButton(
              tooltip: 'Profil ansehen',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push(Routes.person(partner.id)),
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
      body: ChatBackground(
        child: Column(
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
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        reverse: true, // neueste unten, Liste startet unten
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final index = list.length - 1 - i;
                          final msg = list[index];
                          final mine = msg.senderId == myId;
                          // Bild nur an der letzten Nachricht einer Folge
                          // desselben Absenders (wie in Messengern üblich).
                          final lastOfRun =
                              index == list.length - 1 ||
                              list[index + 1].senderId != msg.senderId;
                          return _MessageRow(
                            text: msg.body,
                            mine: mine,
                            avatar: lastOfRun ? (mine ? me : them) : null,
                          );
                        },
                      ),
              ),
            ),
            _InputBar(
              controller: _controller,
              focusNode: _focus,
              sendButtonFocus: _sendButtonFocus,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarData {
  const _AvatarData({required this.name, this.photo});

  final String name;
  final ProfileImage? photo;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.data, this.radius = 14});

  final _AvatarData data;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = data.photo;
    if (photo != null) {
      return ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: ProfileImageView(image: photo),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: LovelColors.slate,
      foregroundColor: LovelColors.cream,
      child: Text(
        data.name.isEmpty ? '?' : data.name.characters.first.toUpperCase(),
        style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: radius),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.text, required this.mine, this.avatar});

  final String text;
  final bool mine;

  /// `null` = Platz frei lassen (Nachricht mitten in einer Folge).
  final _AvatarData? avatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const avatarSlot = SizedBox(width: 28);
    final avatarWidget = avatar == null ? avatarSlot : _Avatar(data: avatar!);
    final bubble = Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(!mine && avatar != null ? 4 : 16),
            bottomRight: Radius.circular(mine && avatar != null ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: avatar != null ? 8 : 2),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [bubble, const SizedBox(width: 6), avatarWidget]
            : [avatarWidget, const SizedBox(width: 6), bubble],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sendButtonFocus,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode sendButtonFocus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: 2000,
                minLines: 1,
                maxLines: 5,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                // Verhindert, dass „Senden“ auf der Tastatur den Fokus nimmt.
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben',
                  filled: true,
                  fillColor: LovelColors.cream,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Senden',
              focusNode: sendButtonFocus,
              style: IconButton.styleFrom(
                backgroundColor: LovelColors.terracotta,
                foregroundColor: LovelColors.cream,
              ),
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
