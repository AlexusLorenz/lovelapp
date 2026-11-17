import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'like_quota.dart';

/// Hält das Like-Kontingent im Client.
///
/// TODO(backend): Stand per RPC `like_quota_status` laden; Likes per RPC
/// `like_profile` senden; Bonus erst nach serverseitiger AdMob-Verifizierung
/// (SSV-Callback → Edge Function) gutschreiben.
class LikeQuotaController extends Notifier<LikeQuota> {
  @override
  LikeQuota build() => const LikeQuota();

  bool tryUseLike() {
    if (!state.canLike) return false;
    state = state.afterLike();
    return true;
  }

  /// Demo: schreibt den Bonus sofort gut, ohne echte Werbung.
  void grantRewardedAdBonus() {
    if (state.canWatchAdForBonus) {
      state = state.afterRewardedAd();
    }
  }
}

final likeQuotaProvider = NotifierProvider<LikeQuotaController, LikeQuota>(
  LikeQuotaController.new,
);
