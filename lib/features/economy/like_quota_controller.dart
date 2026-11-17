import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../session/session_controller.dart';
import 'like_quota.dart';

/// Hält das Like-Kontingent im Client.
///
/// Mit Supabase ist der Server die Quelle der Wahrheit: Der Stand kommt aus
/// `like_quota_status`, nach jedem Like aus der Antwort von `like_profile`.
/// TODO(ads): Bonus erst nach serverseitiger AdMob-Verifizierung
/// (SSV-Callback → Edge Function → grant_rewarded_ad_bonus) gutschreiben.
class LikeQuotaController extends Notifier<LikeQuota> {
  @override
  LikeQuota build() {
    // Bei neuer Anmeldung neu laden.
    ref.watch(sessionProvider.select((s) => s.user?.id));
    Future.microtask(_load);
    return const LikeQuota();
  }

  Future<void> _load() async {
    try {
      state = await ref.read(discoverRepositoryProvider).fetchQuota();
    } on Exception {
      // Anzeige bleibt beim Standard; der Server prüft ohnehin jeden Like.
    }
  }

  bool tryUseLike() {
    if (!state.canLike) return false;
    state = state.afterLike();
    return true;
  }

  /// Übernimmt den Stand, den der Server nach einem Like meldet.
  void applyServerRemaining(int remaining) {
    final used = state.dailyLimit - remaining;
    state = state.copyWith(likesUsed: used < 0 ? 0 : used);
  }

  /// Server sagt: aufgebraucht – Anzeige angleichen.
  void markExhausted() => state = state.copyWith(likesUsed: state.dailyLimit);

  /// Nur im Demo-Modus: Bonus sofort gutschreiben, ohne echte Werbung.
  bool get canGrantDemoBonus => !Env.hasSupabase && state.canWatchAdForBonus;

  void grantRewardedAdBonus() {
    if (canGrantDemoBonus) state = state.afterRewardedAd();
  }
}

final likeQuotaProvider = NotifierProvider<LikeQuotaController, LikeQuota>(
  LikeQuotaController.new,
);
