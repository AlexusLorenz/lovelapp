import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_draft.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasOwnProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> createProfile(String userId, ProfileDraft draft) async {
    try {
      await _client.from('profiles').insert({
        'id': userId,
        ...draft.toInsertJson(),
      });
      // Zweiter Schritt. Schlägt er fehl, existiert das Profil schon ohne
      // Fragen. TODO(profile-edit): dort nachtragen lassen.
      await _client.from('profile_prompts').insert([
        for (final row in draft.promptRows()) {'profile_id': userId, ...row},
      ]);
    } on PostgrestException catch (e) {
      // 23514 = CHECK verletzt (z. B. unter 18), 23505 = Profil existiert schon
      throw ProfileFailure(switch (e.code) {
        '23514' =>
          e.message.contains('18')
              ? 'Lovel ist erst ab 18 Jahren.'
              : 'Bitte prüfe deine Angaben.',
        '23505' => 'Du hast schon ein Profil.',
        _ => 'Speichern hat nicht geklappt. Bitte versuch es noch einmal.',
      });
    } on Exception {
      throw const ProfileFailure(
        'Keine Verbindung zum Server. Bitte prüfe dein Internet.',
      );
    }
  }
}
