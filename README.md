# Lovel

Gamifizierte, kostenlose Dating-App mit Minispielen als Eisbrecher.
Finanziert über freiwillige Werbung (Rewarded Videos); Premium entfernt Werbung.
**Kein Pay-to-win** bei Kernfunktionen: Matchen, Chatten und sehen, wer dich geliked hat, sind für alle gratis.

## Stack

| Bereich | Technik |
|---|---|
| App | Flutter 3.50 (Dart 3.14), iOS + Android |
| Minispiele | Flame (Game-Loop), einfache Spiele als normale Widgets |
| State & Navigation | Riverpod 3, go_router |
| Backend | Supabase (EU/Frankfurt): Postgres + PostGIS, Auth, Storage, Realtime |
| Werbung / Abos | AdMob Rewarded Ads, RevenueCat *(noch nicht eingebunden)* |

## Loslegen

```bash
flutter pub get
flutter run          # Demo-Modus mit Beispieldaten, ohne Backend
```

Mit dem Supabase-Projekt **Lovel** (Frankfurt, `eu-central-1`):

```bash
flutter run --dart-define-from-file=config/supabase.json
```

`config/supabase.json` enthält nur URL und *Publishable Key* – beide sind öffentlich und landen ohnehin in der App.
Den **Secret Key** (`service_role`) und das Datenbank-Passwort niemals ins Repo oder in die App.

### Web-Vorschau

Jeder Push auf `main` baut zwei Browser-Versionen (Workflow `.github/workflows/web-preview.yml`):

- https://alexuslorenz.github.io/lovelapp/ – Demo-Modus mit Beispieldaten, nichts wird gespeichert
- https://alexuslorenz.github.io/lovelapp/app/ – echte Datenbank, offene Registrierung.
  Auf dem iPhone in Safari öffnen → Teilen → „Zum Home-Bildschirm“.
  Für eine geschlossene Testphase mit `--dart-define=INVITE_ONLY=true` bauen und in Supabase
  „Allow new users to sign up“ ausschalten.

Supabase-Einstellungen dafür: Site URL `https://alexuslorenz.github.io/lovelapp/app/` und dieselbe
Adresse (mit `**`) unter Redirect URLs.

### Login mit Google und Apple einrichten

Die App nutzt Supabase OAuth. Rücksprung in die App per Deep Link
`de.lovelapp.lovelapp://login-callback` (in `AndroidManifest.xml` und `Info.plist` hinterlegt).

1. Supabase → Authentication → URL Configuration → **Redirect URLs**: `de.lovelapp.lovelapp://login-callback` eintragen.
2. Supabase → Authentication → Sign In / Providers → **Google**: Client-ID und Secret aus der Google Cloud Console
   (OAuth-Client „Webanwendung“, autorisierte Weiterleitungs-URI: `https://<projekt>.supabase.co/auth/v1/callback`).
3. Supabase → Authentication → Sign In / Providers → **Apple**: braucht ein Apple-Developer-Konto
   (Services ID, Key, Team ID). Pflicht im App Store, sobald Google-Login angeboten wird.

### Integrationstest gegen Supabase

`test_supabase/` prüft Anmeldung, Feed, Like, Match und Live-Chat gegen ein echtes Projekt.
Läuft nicht in der CI; Anleitung und benötigte Test-Konten stehen im Kopf der Datei.

### Datenbank lokal

Voraussetzung: [Supabase CLI](https://supabase.com/docs/guides/cli) und Docker.

```bash
supabase start        # startet Postgres, Auth, Storage … und spielt die Migrationen ein
supabase test db      # pgTAP-Tests in supabase/tests/
supabase db reset     # alles neu aufsetzen
```

## Projektstruktur

```
lib/
  app.dart, main.dart
  core/            Konfiguration, Router, Theme, App-Shell
  data/            Beispieldaten für den Demo-Modus
  features/
    auth/          Willkommen, Registrieren, Anmelden
    onboarding/    Profil anlegen (Name, 18+, Geschlecht, Einwilligung, Stadt, Bio)
    session/       Sitzungsstand → Weiterleitung im Router
    legal/         Platzhalter für AGB und Datenschutz
    discover/      Entdecken-Feed (Like / Weiter, Match-Overlay)
    matches/       Match-Liste
    chat/          Chat-Liste und Chat
    profile/       Profil, Level & XP
    games/         Spielekatalog, This or That, Flame-Szenen
    economy/       Like-Kontingent und Rewarded-Bonus
    progress/      Level-/XP-Berechnung
supabase/
  migrations/      Datenbankschema inkl. RLS und RPC-Funktionen
  tests/database/  pgTAP-Tests
test/              Unit- und Widget-Tests
```

## Datenmodell (Kurzfassung)

- `profiles` – eigenes Profil; andere sind nur über `get_public_profiles()` (ohne Geburtsdatum/Standort) und `discover_profiles()` sichtbar
- `profile_photos` – Fotos im privaten Bucket `profile-photos`, erst nach Freigabe für andere sichtbar
- `likes`, `passes`, `matches` – Likes nur über `like_profile()`, das Kontingent prüft und bei Gegenseitigkeit ein Match anlegt
- `messages` – Chat, nur in aktiven Matches
- `game_sessions`, `game_moves` – Minispiel-Runden (Realtime)
- `blocks`, `reports` – Blockieren (beendet Match automatisch) und Melden (DSA)
- `daily_like_usage`, `ad_rewards` – Like-Kontingent; Video-Bonus nur serverseitig nach AdMob-Verifizierung
- `xp_rewards`, `xp_events` – XP für gutes Verhalten (z. B. Antworten), mit Tageslimits
- Schema `private` – Hilfsfunktionen für die Zugriffsregeln, nicht über die API erreichbar

## Like-Ökonomie (Startwerte)

| | Likes pro Tag |
|---|---|
| Gratis | 20 |
| + Rewarded Video | +5 je Video, max. 3 Videos |
| Premium | 35 ohne Videos, keine Werbung |

Premium bekommt also genau das, was Gratis-Nutzer mit Videos auch erreichen.
Die Werte stehen in `lib/features/economy/like_quota.dart` **und** `public.like_quota_rules()` und müssen übereinstimmen.

## Offene nächste Schritte

- Passwort vergessen / zurücksetzen (braucht Deep Links und die Site-URL in Supabase)
- Melden/Blockieren im Chat an die Datenbank anschließen
- Profil bearbeiten (Fragen, Steckbrief, Standort-Freigabe widerrufen)
- Konto löschen (DSGVO)
- Foto-Upload und Moderation (Freigabe-Workflow)
- Edge Function für AdMob Server-Side Verification → `grant_rewarded_ad_bonus()`
- Echte Mehrspieler-Runden über Realtime
- iOS-Build in der CI (macOS-Runner)
