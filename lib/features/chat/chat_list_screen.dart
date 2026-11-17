import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../matches/matches_repository.dart';
import '../matches/matches_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(matchesProvider.future),
        child: matches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MatchesMessage(
            text: e is ChatFailure ? e.message : 'Laden hat nicht geklappt.',
          ),
          data: (list) => list.isEmpty
              ? const MatchesMessage(text: 'Hier erscheinen deine Chats.')
              : ListView(
                  children: [
                    for (final match in list)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(match.profile.name.characters.first),
                        ),
                        title: Text(match.profile.name),
                        subtitle: Text(
                          match.lastMessage ?? 'Noch keine Nachrichten',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => context.go(Routes.chat(match.matchId)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
