import 'package:supabase_flutter/supabase_flutter.dart';

import '../location/approx_location.dart';
import '../discover/public_profile.dart';
import '../profile/own_profile.dart';
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
      final prompts = draft.promptRows();
      if (prompts.isNotEmpty) {
        await _client.from('profile_prompts').insert([
          for (final row in prompts) {'profile_id': userId, ...row},
        ]);
      }
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

  @override
  Future<OwnProfileSummary?> fetchOwnSummary(String userId) async {
    final row = await _client
        .from('profiles')
        .select('display_name, location')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return OwnProfileSummary(
      displayName: row['display_name'] as String,
      hasLocation: row['location'] != null,
    );
  }

  @override
  Future<void> updateLocation(String userId, ApproxLocation location) async {
    try {
      await _client
          .from('profiles')
          .update({'location': location.toEwkt()})
          .eq('id', userId);
    } on Exception {
      throw const ProfileFailure('Standort konnte nicht gespeichert werden.');
    }
  }

  @override
  Future<OwnProfile?> fetchOwnProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select(
            'display_name, birthdate, xp, bio, city, relationship_goal, '
            'children, smoking, drinking, exercise, height_cm',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      final promptRows = await _client
          .from('profile_prompts')
          .select('profile_id, position, prompt_key, answer')
          .eq('profile_id', userId);
      return OwnProfile.fromRow(
        row,
        prompts: groupPromptRows(promptRows)[userId] ?? const [],
      );
    } on Exception {
      throw const ProfileFailure('Profil konnte nicht geladen werden.');
    }
  }

  @override
  Future<void> updateOwnProfile(String userId, OwnProfile profile) async {
    try {
      await _client
          .from('profiles')
          .update(profile.toUpdateJson())
          .eq('id', userId);
      // Fragen ersetzen: erst löschen, dann neu anlegen (wegen eindeutiger
      // Position und Frage je Profil).
      await _client.from('profile_prompts').delete().eq('profile_id', userId);
      final rows = profile.promptRows();
      if (rows.isNotEmpty) {
        await _client.from('profile_prompts').insert([
          for (final row in rows) {'profile_id': userId, ...row},
        ]);
      }
    } on PostgrestException {
      throw const ProfileFailure('Bitte prüfe deine Angaben.');
    } on Exception {
      throw const ProfileFailure('Speichern hat nicht geklappt.');
    }
  }
}
