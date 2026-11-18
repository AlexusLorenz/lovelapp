# Lovel – Projektregeln

Gamifizierte Dating-App (Flutter + Supabase). Sprache in UI, Kommentaren und Commits: **Deutsch**. Code-Bezeichner: Englisch.

## Leitplanken (nicht verhandelbar)

- **Kein Pay-to-win:** Matchen, Chatten und „Wer hat mich geliked?“ bleiben gratis. Premium = keine Werbung (+ Komfort), nie ein Vorteil, den Gratis-Nutzer nicht auch erreichen können.
- **XP belohnen gutes Verhalten** (antworten, Spiele beenden, Profil pflegen), nie bloßes Swipen.
- **18+** wird serverseitig durchgesetzt (Trigger `enforce_adult`).
- **DSGVO:** `interested_in` (sexuelle Orientierung) nur mit `sensitive_consent_at`. Geburtsdatum, Standort und Präferenzen anderer nie an den Client geben – nur Alter und gerundete Entfernung. Standort im Client auf ~1 km runden.
- **Sicherheit:** Jede neue Tabelle bekommt RLS und explizite Spalten-Grants. Spielrelevante Werte (Likes, XP, Premium, Foto-Freigabe) ändert nur der Server (RPC mit `security definer` + `set search_path = ''` oder `service_role`).

## Konventionen

- Feature-Ordner unter `lib/features/<feature>/`; reine Logik ohne Flutter-Import, damit sie unit-testbar ist.
- Material-Import: `package:material_ui/material_ui.dart` (Flutter 3.50).
- State: Riverpod `Notifier`/`Provider` ohne Codegen. Navigation: go_router, Pfade in `Routes`.
- Werte, die Client und DB teilen (Like-Kontingent, XP-Gründe, Level-Kurve, Spiel-Schlüssel, Quizduell-Regeln in `quiz_rules.dart`, Interessen-Kategorien), sind an beiden Stellen kommentiert und müssen synchron bleiben.
- Quizfragen nur in `tool/quiz_questions.py` pflegen (erzeugt JSON + Seed-Migration).
- Schemaänderungen nur als **neue** Datei in `supabase/migrations/` – bestehende Migrationen nie ändern, sobald sie deployt sind.

## Vor jedem Commit

```bash
dart format lib test
flutter analyze
flutter test
supabase test db   # bei DB-Änderungen
```
