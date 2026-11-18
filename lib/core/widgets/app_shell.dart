import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/discover/discover_providers.dart';
import '../../features/session/session_controller.dart';
import '../theme/app_theme.dart';

/// Grundgerüst mit unterer Navigationsleiste und Zählern für Neues.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Zurück in der App (z. B. Tab/Handy wieder aktiv) → auf Stand bringen,
    // falls in der Zwischenzeit Live-Ereignisse verpasst wurden.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(matchesRepositoryProvider).markDelivered();
        ref
          ..invalidate(matchesProvider)
          ..invalidate(receivedLikesProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live-Abo auf Nachrichten, Likes und Matches aktiv halten.
    ref.watch(inboxListenerProvider);
    // Listen vorladen, damit die Zähler sofort stimmen.
    ref.watch(matchesProvider);
    ref.watch(receivedLikesProvider);
    final unread = ref.watch(unreadMessagesCountProvider);
    final likes = ref.watch(openLikesCountProvider);
    final shell = widget.shell;

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Entdecken',
          ),
          NavigationDestination(
            icon: CountBadge(
              count: likes,
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: CountBadge(
              count: likes,
              child: const Icon(Icons.favorite),
            ),
            label: 'Likes',
            tooltip: likes > 0 ? 'Likes, $likes neu' : 'Likes',
          ),
          NavigationDestination(
            icon: CountBadge(
              count: unread,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: CountBadge(
              count: unread,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chats',
            tooltip: unread > 0 ? 'Chats, $unread ungelesen' : 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Roter Zähler oben rechts am Symbol; bei 0 unsichtbar.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: LovelColors.unread,
      textColor: Colors.white,
      label: Text(count > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}
