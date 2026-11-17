import 'dart:math' as math;

/// Regeln der Like-Ökonomie.
///
/// WICHTIG: Diese Werte müssen mit den SQL-Funktionen in
/// `supabase/migrations/*_initial_schema.sql` (`like_quota_rules`) übereinstimmen.
/// Die Datenbank ist die Quelle der Wahrheit – der Client zeigt nur an.
class LikeQuotaRules {
  const LikeQuotaRules._();

  /// Gratis-Likes pro Tag für alle.
  static const freeLikesPerDay = 20;

  /// Zusätzliche Likes pro angesehenem Rewarded Video.
  static const likesPerRewardedAd = 5;

  /// Maximal so viele Bonus-Videos pro Tag.
  static const maxRewardedAdsPerDay = 3;

  /// Premium bekommt den vollen Bonus ohne Videos – also genau so viel,
  /// wie Gratis-Nutzer mit Videos erreichen können (kein Pay-to-win).
  static const maxDailyLikes =
      freeLikesPerDay + likesPerRewardedAd * maxRewardedAdsPerDay;
}

/// Tagesstand des Like-Kontingents eines Nutzers.
class LikeQuota {
  const LikeQuota({
    this.likesUsed = 0,
    this.rewardedAdsWatched = 0,
    this.isPremium = false,
  });

  final int likesUsed;
  final int rewardedAdsWatched;
  final bool isPremium;

  int get dailyLimit {
    final bonusAds = isPremium
        ? LikeQuotaRules.maxRewardedAdsPerDay
        : rewardedAdsWatched;
    return LikeQuotaRules.freeLikesPerDay +
        bonusAds * LikeQuotaRules.likesPerRewardedAd;
  }

  int get remaining => math.max(0, dailyLimit - likesUsed);

  bool get canLike => remaining > 0;

  bool get canWatchAdForBonus =>
      !isPremium && rewardedAdsWatched < LikeQuotaRules.maxRewardedAdsPerDay;

  LikeQuota afterLike() {
    if (!canLike) {
      throw StateError('Kein Like mehr übrig für heute.');
    }
    return copyWith(likesUsed: likesUsed + 1);
  }

  LikeQuota afterRewardedAd() {
    if (!canWatchAdForBonus) {
      throw StateError('Heute kein Bonus-Video mehr möglich.');
    }
    return copyWith(rewardedAdsWatched: rewardedAdsWatched + 1);
  }

  LikeQuota copyWith({
    int? likesUsed,
    int? rewardedAdsWatched,
    bool? isPremium,
  }) {
    return LikeQuota(
      likesUsed: likesUsed ?? this.likesUsed,
      rewardedAdsWatched: rewardedAdsWatched ?? this.rewardedAdsWatched,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
