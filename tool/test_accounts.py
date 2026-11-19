#!/usr/bin/env python3
"""Legt die 8 Test-Konten (4 Frauen, 4 Männer) in Supabase an.

Nur für die Testphase. Die Konten sind über `profiles.is_test` von echten
Nutzern getrennt (siehe Migration `test_accounts`). E-Mails und Namen müssen
zu `lib/features/auth/test_accounts.dart` passen.

Ablauf:
  1. python3 tool/test_accounts.py sql > /tmp/test_accounts.sql
     → mit Admin-Rechten ausführen (SQL-Editor bzw. MCP). Legt Konten,
       Profile, Steckbrief, Interessen, Matches, Likes und Chats neu an
       (vorhandene Test-Konten werden vorher gelöscht).
  2. flutter test tool/render_test_photos.dart
     → zeichnet die Profilbilder nach build/test_photos/.
  3. python3 tool/test_accounts.py extras
     → meldet sich als jedes Test-Konto an, lädt die Fotos hoch und wählt
       Lieblingsspiele/-musik über die echte Katalogsuche.

Löschen vor dem Launch:
  delete from auth.users where email like '%@test.lovel.app';

Das gemeinsame Passwort steht in config/supabase.json (TEST_LOGIN_PASSWORD)
und wird nie ausgegeben.
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "config" / "supabase.json").read_text())
DOMAIN = "test.lovel.app"

# Feste IDs, damit Matches/Likes reproduzierbar sind.
def uid(n: int) -> str:
    return f"7e570000-0000-4000-8000-{n:012d}"


# (Nr., Name, Alter, Geschlecht, Bio, Ort-Versatz, Steckbrief, Prompts,
#  Interessen, Spiele-Suchen, Künstler-Suchen)
ACCOUNTS = [
    dict(n=1, name="Lena", age=27, gender="woman",
         bio="Bouldern, Brettspiele und zu viele Zimmerpflanzen. Suche jemanden, der beim Quiz nicht schummelt.",
         basics=dict(relationship_goal="long_term", children="want_someday", smoking="never",
                     drinking="socially", exercise="often", height_cm=168),
         prompts=[("perfect_sunday", "Ausschlafen, Brunch, danach Bouldern."),
                  ("game_loser", "Siedler. Ich baue immer nur Straßen."),
                  ("green_flag", "Du gießt meine Pflanzen, wenn ich weg bin.")],
         interests=["sports.bouldern", "hobbies.brettspiele", "hobbies.pflanzen",
                    "food.brunch", "music.indie", "hobbies.quiz"],
         games=["Stardew Valley", "It Takes Two"], artists=["Bilderbuch", "Phoebe Bridgers"]),
    dict(n=2, name="Mia", age=31, gender="woman",
         bio="Architektin, Hobby-Fotografin, Ramen-Expertin. Ich verliere ungern – auch beim Schätzen.",
         basics=dict(relationship_goal="long_term", children="not_sure", smoking="never",
                     drinking="socially", exercise="sometimes", height_cm=172),
         prompts=[("nerd_about", "Brutalistische Architektur und warum sie schön ist."),
                  ("first_date", "Ramen und danach durch die Stadt laufen."),
                  ("two_truths", "Ich war in Japan, ich kann jonglieren, ich mag keinen Kaffee.")],
         interests=["creative.fotografie", "food.ramen", "travel.asien", "creative.design",
                    "music.jazz", "food.kaffee"],
         games=["Monument Valley", "The Witcher 3"], artists=["Nils Frahm", "Norah Jones"]),
    dict(n=3, name="Sophie", age=29, gender="woman",
         bio="Ärztin mit Hang zu Karaoke. Wenn ich nicht arbeite, bin ich am Wasser.",
         basics=dict(relationship_goal="open", children="want_someday", smoking="never",
                     drinking="socially", exercise="often", height_cm=165),
         prompts=[("weekend_plan", "Am See, mit Buch und Eis."),
                  ("guilty_pleasure", "ABBA in voller Lautstärke beim Putzen."),
                  ("superpower", "Ich finde in jeder Stadt das beste Eis.")],
         interests=["hobbies.karaoke", "sports.schwimmen", "sports.sup", "hobbies.lesen",
                    "music.pop", "food.pizza"],
         games=["Mario Kart 8", "Animal Crossing"], artists=["ABBA", "Dua Lipa"]),
    dict(n=4, name="Hannah", age=34, gender="woman",
         bio="Lehrerin, Wanderin, Hobbyköchin. Bei Pen & Paper bin ich die Spielleiterin.",
         basics=dict(relationship_goal="long_term", children="have_want_more", smoking="never",
                     drinking="never", exercise="sometimes", height_cm=175),
         prompts=[("cook_for_you", "Selbstgemachte Pasta mit Salbeibutter."),
                  ("looking_for", "… mit mir auf Berge steigt und unten Kuchen isst."),
                  ("unpopular_opinion", "Monopoly ist ein gutes Spiel.")],
         interests=["sports.wandern", "hobbies.kochen", "hobbies.pen_and_paper",
                    "books.fantasy", "music.folk", "food.pasta"],
         games=["Baldur's Gate 3", "Zelda Breath of the Wild"], artists=["Mumford & Sons", "AnnenMayKantereit"]),
    dict(n=5, name="Jonas", age=30, gender="man",
         bio="Softwareentwickler und Gitarrist. Gewinne jedes Quizduell (fast).",
         basics=dict(relationship_goal="long_term", children="want_someday", smoking="never",
                     drinking="socially", exercise="sometimes", height_cm=184),
         prompts=[("song_on_repeat", "Everlong von den Foo Fighters."),
                  ("game_loser", "Mario Kart, da bin ich immer Letzter."),
                  ("nerd_about", "Gitarren-Effektpedale.")],
         interests=["creative.gitarre", "music.rock", "hobbies.quiz", "hobbies.brettspiele",
                    "sports.bouldern", "food.burger"],
         games=["Zelda Ocarina of Time", "Hades"], artists=["Foo Fighters", "Nirvana"]),
    dict(n=6, name="Felix", age=28, gender="man",
         bio="Koch in einem kleinen Bistro. Surfe, wenn ich am Meer bin, sonst Skateboard.",
         basics=dict(relationship_goal="open", children="not_sure", smoking="sometimes",
                     drinking="socially", exercise="often", height_cm=179),
         prompts=[("cook_for_you", "Shakshuka zum Frühstück, egal wie spät."),
                  ("travel_story", "Mit dem Bulli bis nach Portugal – und zurück getrampt."),
                  ("green_flag", "Du isst alles, was ich koche.")],
         interests=["hobbies.kochen", "sports.surfen", "sports.skateboarden", "food.streetfood",
                    "music.hip_hop", "travel.roadtrips"],
         games=["Tony Hawk's Pro Skater", "Overcooked 2"], artists=["Kendrick Lamar", "Peter Fox"]),
    dict(n=7, name="Paul", age=33, gender="man",
         bio="Musiklehrer, Vinyl-Sammler und Schach-Liebhaber. Lieber ein langer Spaziergang als ein lautes Club-Date.",
         basics=dict(relationship_goal="long_term", children="dont_want", smoking="never",
                     drinking="socially", exercise="rarely", height_cm=181),
         prompts=[("perfect_sunday", "Plattenladen, Kaffee, Schach im Park."),
                  ("unpopular_opinion", "Jazz ist nicht anstrengend."),
                  ("first_date", "Ein Konzert, bei dem wir beide keine Band kennen.")],
         interests=["hobbies.schach", "music.jazz", "creative.klavier", "hobbies.vintage",
                    "food.specialty_coffee", "books.klassiker"],
         games=["Chess Ultra", "Disco Elysium"], artists=["Miles Davis", "Radiohead"]),
    dict(n=8, name="Tim", age=26, gender="man",
         bio="Student, Fußball am Wochenende, Döner-Tester unter der Woche.",
         basics=dict(relationship_goal="unsure", children="not_sure", smoking="never",
                     drinking="regularly", exercise="often", height_cm=187),
         prompts=[("weekend_plan", "Auf dem Bolzplatz und danach beim Döner."),
                  ("cant_live_without", "Kopfhörer."),
                  ("superpower", "Ich kenne jeden Song nach drei Sekunden.")],
         interests=["sports.fussball", "food.doener", "music.deutschrap", "hobbies.karaoke",
                    "going_out.festivals", "gaming.konsole"],
         games=["EA Sports FC 24", "Rocket League"], artists=["Kraftklub", "Apache 207"]),
]

# Berlin, auf ~1 km gerundet (Leitplanke), leicht verteilt.
LOCATIONS = [(13.40, 52.52), (13.42, 52.50), (13.38, 52.53), (13.45, 52.51),
             (13.41, 52.54), (13.37, 52.50), (13.43, 52.53), (13.39, 52.49)]

# Vorbereitete Beziehungen: zwei Paare (für 2-gegen-2-Spiele), ein drittes
# Match und ein paar offene Likes, damit „Wer hat mich geliked?“ etwas zeigt.
MATCHES = [(1, 5), (2, 6), (3, 7)]
LIKES = [(4, 5), (8, 1), (4, 7), (8, 3)]
CHATS = {
    (1, 5): [(5, "Hey Lena! Bouldern oder Brettspiele – was zuerst?"),
             (1, "Beides! Aber erst das Quizduell, ich will Revanche 😄"),
             (5, "Deal. Mia und Felix haben uns schon herausgefordert.")],
    (2, 6): [(6, "Du magst Ramen? Ich koche welche, wenn du verlierst."),
             (2, "Und wenn ich gewinne?"),
             (6, "Dann koche ich trotzdem.")],
    (3, 7): [(7, "Welches Eis ist das beste in Berlin? Ich brauche Expertise.")],
}


def sql_str(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def build_sql() -> str:
    import bcrypt

    password = CONFIG["TEST_LOGIN_PASSWORD"].encode()
    # Ein Hash für alle Konten (gleiches Passwort).
    pw_hash = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
    out = ["begin;",
           f"create temp table _pw on commit drop as select {sql_str(pw_hash)}::text h;",
           f"delete from auth.users where email like '%@{DOMAIN}';"]
    for a, (lng, lat) in zip(ACCOUNTS, LOCATIONS):
        i = uid(a["n"])
        email = f"{a['name'].lower()}@{DOMAIN}"
        out.append(f"""
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token)
values ('00000000-0000-0000-0000-000000000000', '{i}', 'authenticated', 'authenticated',
  {sql_str(email)}, (select h from _pw), now(),
  '{{"provider":"email","providers":["email"]}}', '{{}}', now(), now(),
  '', '', '', '', '', '', '', '');
insert into auth.identities (id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at)
values (gen_random_uuid(), '{i}', '{i}',
  jsonb_build_object('sub', '{i}', 'email', {sql_str(email)}, 'email_verified', true),
  'email', now(), now(), now());""")
        interested = "{man}" if a["gender"] == "woman" else "{woman}"
        b = a["basics"]
        out.append(f"""
insert into public.profiles (id, display_name, birthdate, bio, gender, interested_in,
  sensitive_consent_at, location, city, search_radius_km, age_min, age_max, is_test,
  relationship_goal, children, smoking, drinking, exercise, height_cm, xp)
values ('{i}', {sql_str(a['name'])}, (current_date - interval '{a['age']} years' - interval '{40 * a['n']} days')::date,
  {sql_str(a['bio'])}, '{a['gender']}', '{interested}', now(),
  'SRID=4326;POINT({lng} {lat})', 'Berlin', 50, 18, 45, true,
  '{b['relationship_goal']}', '{b['children']}', '{b['smoking']}', '{b['drinking']}',
  '{b['exercise']}', {b['height_cm']}, {150 * a['n']});""")
        for pos, (key, answer) in enumerate(a["prompts"]):
            out.append(f"insert into public.profile_prompts (profile_id, position, prompt_key, answer) "
                       f"values ('{i}', {pos}, '{key}', {sql_str(answer)});")
        for key in a["interests"]:
            out.append(f"insert into public.profile_interests (profile_id, interest_key) "
                       f"values ('{i}', '{key}');")

    for x, y in LIKES:
        out.append(f"insert into public.likes (liker_id, likee_id) values ('{uid(x)}', '{uid(y)}');")
    for x, y in MATCHES:
        a, b = sorted([uid(x), uid(y)])
        out.append(f"insert into public.likes (liker_id, likee_id) values ('{uid(x)}', '{uid(y)}'), ('{uid(y)}', '{uid(x)}') on conflict do nothing;")
        out.append(f"insert into public.matches (user_a, user_b) values ('{a}', '{b}') on conflict do nothing;")
        for k, (sender, body) in enumerate(CHATS.get((x, y), [])):
            out.append(
                f"insert into public.messages (match_id, sender_id, body, created_at) "
                f"select id, '{uid(sender)}', {sql_str(body)}, now() - interval '{60 - 10 * k} minutes' "
                f"from public.matches where user_a = '{a}' and user_b = '{b}';")
    out.append("commit;")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Fotos, Spiele, Musik – über die echte API als jeweiliges Test-Konto
# ---------------------------------------------------------------------------
URL = CONFIG["SUPABASE_URL"]
KEY = CONFIG["SUPABASE_PUBLISHABLE_KEY"]


def _ctx() -> ssl.SSLContext:
    for env in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE"):
        if os.environ.get(env):
            return ssl.create_default_context(cafile=os.environ[env])
    bundle = Path.home() / ".ccr" / "ca-bundle.crt"
    return ssl.create_default_context(cafile=str(bundle) if bundle.exists() else None)


def call(method: str, path: str, token: str | None = None, body=None,
         raw: bytes | None = None, content_type="application/json", extra=None):
    headers = {"apikey": KEY, "Content-Type": content_type}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    headers.update(extra or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(URL + path, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, context=_ctx(), timeout=60) as r:
        text = r.read().decode()
        return json.loads(text) if text else None


def extras() -> None:
    photos_dir = ROOT / "build" / "test_photos"
    for a in ACCOUNTS:
        email = f"{a['name'].lower()}@{DOMAIN}"
        token = call("POST", "/auth/v1/token?grant_type=password",
                     body={"email": email, "password": CONFIG["TEST_LOGIN_PASSWORD"]})["access_token"]
        i = uid(a["n"])
        # Alte Fotos wegräumen, dann neu hochladen.
        old = call("GET", f"/rest/v1/profile_photos?select=storage_path&profile_id=eq.{i}", token)
        if old:
            call("DELETE", "/storage/v1/object/profile-photos", token,
                 body={"prefixes": [o["storage_path"] for o in old]})
            call("DELETE", f"/rest/v1/profile_photos?profile_id=eq.{i}", token)
        for pos in range(3):
            jpg = (photos_dir / f"{a['name'].lower()}_{pos}.jpg").read_bytes()
            path = f"{i}/test_{pos}.jpg"
            call("POST", f"/storage/v1/object/profile-photos/{path}", token, raw=jpg,
                 content_type="image/jpeg", extra={"x-upsert": "true"})
            call("POST", "/rest/v1/profile_photos", token,
                 body={"profile_id": i, "storage_path": path, "position": pos})

        def first(kind: str, q: str):
            items = call("POST", "/functions/v1/catalog-search", token,
                         body={"type": kind, "q": q}).get("items", [])
            return items[0] if items else None

        games = [g for g in (first("games", q) for q in a["games"]) if g]
        artists = [x for x in (first("artists", q) for q in a["artists"]) if x]
        call("POST", "/rest/v1/rpc/set_profile_games", token, body={"p_games": games})
        call("POST", "/rest/v1/rpc/set_profile_artists", token, body={"p_artists": artists})
        print(f"{a['name']}: 3 Fotos, {len(games)} Spiele, {len(artists)} Künstler")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "sql":
        print(build_sql())
    elif cmd == "extras":
        extras()
    else:
        print(__doc__)
        sys.exit(1)
