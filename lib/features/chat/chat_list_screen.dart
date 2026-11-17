import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';
import '../discover/discover_providers.dart';
import '../discover/public_profile.dart';
import '../matches/matches_repository.dart';

/// Oben neue Matches (noch ohne Nachricht) als Profilbilder,
/// darunter alle Unterhaltungen.
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
          error: (e, _) => _Hint(
            text: e is ChatFailure ? e.message : 'Laden hat nicht geklappt.',
          ),
          data: (list) {
            final fresh = [
              for (final m in list)
                if (m.lastMessage == null) m,
            ];
            final chats = [
              for (final m in list)
                if (m.lastMessage != null) m,
            ];
            if (list.isEmpty) {
              return const _Hint(
                text:
                    'Noch keine Matches. Leg los im Entdecken-Feed '
                    'oder schau, wer dich geliked hat!',
              );
            }
            return ListView(
              children: [
                if (fresh.isNotEmpty) ...[
                  const _SectionTitle('Neue Matches'),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: fresh.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _NewMatchAvatar(
                        match: fresh[i],
                        onTap: () => context.go(Routes.chat(fresh[i].matchId)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const _SectionTitle('Nachrichten'),
                if (chats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      'Noch keine Unterhaltungen. Tipp oben auf ein neues '
                      'Match und sag Hallo!',
                    ),
                  ),
                for (final match in chats)
                  ListTile(
                    leading: ProfileAvatar(profile: match.profile, radius: 24),
                    title: Text(match.profile.name),
                    subtitle: Text(
                      match.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.go(Routes.chat(match.matchId)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rundes Profilbild: erstes Foto bzw. Platzhalter, sonst die Initiale.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  final PublicProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (profile.photos.isNotEmpty) {
      return ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: PlaceholderPhoto(art: profile.photos.first),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: LovelColors.slate,
      foregroundColor: LovelColors.cream,
      child: Text(
        profile.name.isEmpty
            ? '?'
            : profile.name.characters.first.toUpperCase(),
        style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: radius),
      ),
    );
  }
}

class _NewMatchAvatar extends StatelessWidget {
  const _NewMatchAvatar({required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Nur das Profilbild – der Name ist für Screenreader trotzdem da.
    return Semantics(
      button: true,
      label: 'Neues Match: ${match.profile.name}. Chat öffnen',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [LovelColors.terracotta, LovelColors.umber],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LovelColors.mist,
            ),
            child: ProfileAvatar(profile: match.profile, radius: 38),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 80),
      Text(text, textAlign: TextAlign.center),
    ],
  );
}
