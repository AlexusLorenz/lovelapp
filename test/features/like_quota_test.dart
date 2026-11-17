import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/economy/like_quota.dart';

void main() {
  group('LikeQuota', () {
    test('startet mit den Gratis-Likes', () {
      const quota = LikeQuota();
      expect(quota.dailyLimit, LikeQuotaRules.freeLikesPerDay);
      expect(quota.remaining, LikeQuotaRules.freeLikesPerDay);
      expect(quota.canLike, isTrue);
    });

    test('verbraucht Likes und blockiert bei 0', () {
      var quota = const LikeQuota();
      for (var i = 0; i < LikeQuotaRules.freeLikesPerDay; i++) {
        quota = quota.afterLike();
      }
      expect(quota.remaining, 0);
      expect(quota.canLike, isFalse);
      expect(quota.afterLike, throwsStateError);
    });

    test('Rewarded Video gibt Bonus, begrenzt pro Tag', () {
      var quota = const LikeQuota();
      for (var i = 0; i < LikeQuotaRules.maxRewardedAdsPerDay; i++) {
        quota = quota.afterRewardedAd();
      }
      expect(quota.dailyLimit, LikeQuotaRules.maxDailyLikes);
      expect(quota.canWatchAdForBonus, isFalse);
      expect(quota.afterRewardedAd, throwsStateError);
    });

    test('Premium hat genau das Maximum – kein Pay-to-win', () {
      const premium = LikeQuota(isPremium: true);
      expect(premium.dailyLimit, LikeQuotaRules.maxDailyLikes);
      expect(premium.canWatchAdForBonus, isFalse);
    });
  });
}
