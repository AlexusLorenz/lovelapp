import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../discover/profile_detail_screen.dart';
import 'own_profile_providers.dart';

/// „So sehen dich andere“: das eigene Profil in der Ansicht anderer.
class OwnPreviewScreen extends ConsumerWidget {
  const OwnPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(ownPublicProfileProvider);
    return ProfileDetailScreen(
      profileId: preview.value?.id ?? '',
      preview: preview,
    );
  }
}
