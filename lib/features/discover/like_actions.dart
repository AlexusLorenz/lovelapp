import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../data/demo_data.dart';
import '../economy/like_quota_controller.dart';
import '../session/session_controller.dart';
import 'discover_providers.dart';
import 'discover_repository.dart';
import 'match_overlay.dart';
import 'public_profile.dart';

/// Liked [profile] (Kontingent prüft der Server) und feiert ein Match mit dem
/// Overlay. Gemeinsam genutzt von Entdecken und Likes.
Future<void> likeProfile(
  BuildContext context,
  WidgetRef ref,
  PublicProfile profile,
) async {
  final quota = ref.read(likeQuotaProvider.notifier);
  if (!ref.read(likeQuotaProvider).canLike) {
    _snack(context, 'Für heute sind deine Likes aufgebraucht.');
    return;
  }
  try {
    final result = await ref.read(discoverRepositoryProvider).like(profile.id);
    if (result.remaining != null) {
      quota.applyServerRemaining(result.remaining!);
    } else {
      quota.tryUseLike();
    }
    ref.invalidate(receivedLikesProvider);
    if (result.matched) {
      ref.invalidate(matchesProvider);
      if (context.mounted) await _celebrate(context, ref, profile);
    }
  } on DiscoverFailure catch (e) {
    if (e.quotaExhausted) quota.markExhausted();
    if (context.mounted) _snack(context, e.message);
  }
}

/// Wischt [profile] weg (kein Like). Fehler stören hier nicht.
Future<void> passProfile(WidgetRef ref, PublicProfile profile) async {
  try {
    await ref.read(discoverRepositoryProvider).pass(profile.id);
  } on Exception {
    // Schlimmstenfalls taucht das Profil später noch einmal auf.
  }
  ref.invalidate(receivedLikesProvider);
}

Future<void> _celebrate(
  BuildContext context,
  WidgetRef ref,
  PublicProfile profile,
) async {
  final me = ref.read(ownSummaryProvider).value;
  final result = await showMatchOverlay(
    context,
    myName: me?.displayName ?? demoMyName,
    myPhoto: Env.hasSupabase ? null : demoMyPhoto,
    matchName: profile.name,
    matchPhoto: profile.photos.isEmpty ? null : profile.photos.first,
  );
  if (result == MatchOverlayResult.playGame && context.mounted) {
    context.push(Routes.games);
  }
}

void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
