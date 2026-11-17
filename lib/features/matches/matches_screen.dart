import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import 'matches_repository.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(matchesProvider.future),
        child: matches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MatchesMessage(
            text: e is ChatFailure ? e.message : 'Laden hat nicht geklappt.',
          ),
          data: (list) => list.isEmpty
              ? const MatchesMessage(
                  text: 'Noch keine Matches. Leg los im Entdecken-Feed!',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final match = list[i];
                    final p = match.profile;
                    return Card(
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () => context.push(Routes.person(p.id)),
                          child: CircleAvatar(
                            child: Text(p.name.characters.first),
                          ),
                        ),
                        title: Text('${p.name}, ${p.age}'),
                        subtitle: Text(
                          match.gamePending
                              ? 'Wartet auf dich: This or That'
                              : match.lastMessage ?? 'Sag Hallo!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Eisbrecher-Spiel',
                          icon: const Icon(Icons.sports_esports),
                          onPressed: () => context.push(Routes.games),
                        ),
                        onTap: () => context.go(Routes.chat(match.matchId)),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Hinweistext, der trotzdem „nach unten ziehen zum Aktualisieren“ erlaubt.
class MatchesMessage extends StatelessWidget {
  const MatchesMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
