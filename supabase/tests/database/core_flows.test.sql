-- pgTAP-Tests für Schema, RLS und RPCs.
-- Ausführen: `supabase test db`
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

-- ---------------------------------------------------------------------------
-- Testdaten (als Superuser)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'anna@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'ben@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'carla@test.local'),
  ('00000000-0000-0000-0000-00000000000d', 'dora@test.local');

-- Leipzig Zentrum und Umgebung (lon lat)
insert into public.profiles
  (id, display_name, birthdate, gender, interested_in, sensitive_consent_at, location, city)
values
  ('00000000-0000-0000-0000-00000000000a', 'Anna', current_date - interval '28 years',
   'woman', '{man}', now(), 'SRID=4326;POINT(12.37 51.34)', 'Leipzig'),
  ('00000000-0000-0000-0000-00000000000b', 'Ben', current_date - interval '30 years',
   'man', '{woman}', now(), 'SRID=4326;POINT(12.40 51.33)', 'Leipzig'),
  ('00000000-0000-0000-0000-00000000000d', 'Dora', current_date - interval '26 years',
   'woman', '{woman}', now(), 'SRID=4326;POINT(12.38 51.35)', 'Leipzig');

-- ---------------------------------------------------------------------------
-- Profilregeln
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.profiles (id, display_name, birthdate, gender)
     values ('00000000-0000-0000-0000-00000000000c', 'Carla',
             current_date - interval '17 years', 'woman') $$,
  '23514', null, 'Unter 18 wird abgelehnt');

select throws_ok(
  $$ insert into public.profiles (id, display_name, birthdate, gender, interested_in)
     values ('00000000-0000-0000-0000-00000000000c', 'Carla',
             current_date - interval '20 years', 'woman', '{man}') $$,
  '23514', null, 'Orientierung ohne Einwilligung wird abgelehnt');

select is(public.level_for_xp(0), 1, 'Level 1 bei 0 XP');
select is(public.level_for_xp(99), 1, 'Level 1 bei 99 XP');
select is(public.level_for_xp(100), 2, 'Level 2 bei 100 XP');
select is(public.level_for_xp(300), 3, 'Level 3 bei 300 XP');
select is(public.level_for_xp(600), 4, 'Level 4 bei 600 XP');

-- ---------------------------------------------------------------------------
-- Als Anna
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

select is((select count(*)::int from public.profiles), 1,
  'profiles: nur das eigene Profil lesbar');
select is((select display_name from public.get_public_profiles(
             array['00000000-0000-0000-0000-00000000000b'::uuid])), 'Ben',
  'get_public_profiles: andere sichtbar');
select is((select count(*)::int from public.get_public_profiles(
             array['00000000-0000-0000-0000-00000000000b'::uuid])), 1,
  'get_public_profiles: liefert genau ein Profil');
select hasnt_function('public', 'is_blocked_between', array['uuid', 'uuid'],
  'Hilfsfunktionen liegen nicht im API-Schema public');
select hasnt_view('public', 'public_profiles', 'Keine Security-Definer-View');
select throws_ok(
  $$ update public.profiles set xp = 9999 where id = auth.uid() $$,
  '42501', null, 'XP nicht selbst änderbar');
select throws_ok(
  $$ update public.profiles set is_premium = true where id = auth.uid() $$,
  '42501', null, 'Premium nicht selbst änderbar');

select results_eq(
  $$ select display_name from public.discover_profiles() $$,
  $$ values ('Ben'::text) $$,
  'Discovery: nur beidseitig passende Profile');

select is((select remaining from public.like_quota_status()), 20,
  'Startkontingent 20 Likes');

select is((public.like_profile('00000000-0000-0000-0000-00000000000b') ->> 'matched')::boolean,
  false, 'Erster Like: noch kein Match');
select is((select remaining from public.like_quota_status()), 19,
  'Like verbraucht Kontingent');
select is((public.like_profile('00000000-0000-0000-0000-00000000000b') ->> 'matched')::boolean,
  false, 'Doppelter Like ist harmlos');
select is((select remaining from public.like_quota_status()), 19,
  'Doppelter Like verbraucht nichts');
select is((select count(*)::int from public.discover_profiles()), 0,
  'Gelikte Profile verschwinden aus Discovery');

select throws_ok(
  $$ insert into public.likes (liker_id, likee_id)
     values (auth.uid(), '00000000-0000-0000-0000-00000000000d') $$,
  '42501', null, 'Likes nur über like_profile()');
select throws_ok(
  $$ select public.grant_rewarded_ad_bonus(auth.uid(), 'fake-tx') $$,
  '42501', null, 'Bonus nicht vom Client auslösbar');

-- ---------------------------------------------------------------------------
-- Als Ben: Like zurück → Match
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';

select is((select count(*)::int from public.likes
           where likee_id = '00000000-0000-0000-0000-00000000000b'), 1,
  'Wer mich geliked hat, ist gratis sichtbar');
select is((public.like_profile('00000000-0000-0000-0000-00000000000a') ->> 'matched')::boolean,
  true, 'Gegenseitiger Like ergibt Match');

reset role;
create temp table t_match as select id from public.matches;
grant select on t_match to authenticated;
set local role authenticated;

-- Anna schreibt, Ben antwortet → Ben bekommt XP
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select lives_ok(
  $$ insert into public.messages (match_id, body) select id, 'Hi Ben!' from t_match $$,
  'Anna kann im Match schreiben');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select lives_ok(
  $$ insert into public.messages (match_id, body) select id, 'Hi Anna!' from t_match $$,
  'Ben kann antworten');
select is((select xp from public.profiles where id = auth.uid()), 5,
  'Antwort bringt 5 XP');
select lives_ok(
  $$ insert into public.game_sessions (match_id, game_key)
     select id, 'this_or_that' from t_match $$,
  'Ben startet ein Minispiel');

-- Dora sieht nichts davon
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000d';
select is((select count(*)::int from public.messages), 0, 'Fremde lesen keine Nachrichten');
select is((select count(*)::int from public.matches), 0, 'Fremde sehen keine Matches');
select is((select count(*)::int from public.game_sessions), 0, 'Fremde sehen keine Spiele');
select throws_ok(
  $$ insert into public.messages (match_id, body) select id, 'Spam' from t_match $$,
  '42501', null, 'Fremde können nicht in fremde Matches schreiben');

-- ---------------------------------------------------------------------------
-- Kontingent & Rewarded Ads
-- ---------------------------------------------------------------------------
reset role;
update public.daily_like_usage set likes_used = 20
 where user_id = '00000000-0000-0000-0000-00000000000a';

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select throws_ok(
  $$ select public.like_profile('00000000-0000-0000-0000-00000000000d') $$,
  'P0001', 'Keine Likes mehr für heute.', 'Leeres Kontingent blockiert Likes');

reset role;
set local role service_role;
select is(public.grant_rewarded_ad_bonus('00000000-0000-0000-0000-00000000000a', 'tx-1'),
  true, 'Server schreibt Video-Bonus gut');
select is(public.grant_rewarded_ad_bonus('00000000-0000-0000-0000-00000000000a', 'tx-1'),
  false, 'Gleiche Transaktion nicht doppelt');
select is(public.grant_rewarded_ad_bonus('00000000-0000-0000-0000-00000000000a', 'tx-2'), true, '2. Video');
select is(public.grant_rewarded_ad_bonus('00000000-0000-0000-0000-00000000000a', 'tx-3'), true, '3. Video');
select is(public.grant_rewarded_ad_bonus('00000000-0000-0000-0000-00000000000a', 'tx-4'),
  false, 'Max. 3 Videos pro Tag');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select is((select remaining from public.like_quota_status()), 15,
  '3 Videos = 15 Bonus-Likes');

-- ---------------------------------------------------------------------------
-- Blockieren
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select lives_ok(
  $$ insert into public.blocks (blocked_id) values ('00000000-0000-0000-0000-00000000000a') $$,
  'Ben blockiert Anna');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select isnt((select unmatched_at from public.matches limit 1), null,
  'Blockieren beendet das Match');
select throws_ok(
  $$ insert into public.messages (match_id, body) select id, 'Hallo?' from t_match $$,
  '42501', null, 'Nach Blockieren keine Nachrichten mehr');
select is((select count(*)::int from public.get_public_profiles(
             array['00000000-0000-0000-0000-00000000000b'::uuid])), 0,
  'Blockierer ist unsichtbar');
select throws_ok(
  $$ select public.like_profile('00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'Profil nicht verfügbar.', 'Blockierte können nicht liken');

-- ---------------------------------------------------------------------------
-- Melden & anon
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.reports (reported_id, reason, details)
     values ('00000000-0000-0000-0000-00000000000b', 'harassment', 'Test') $$,
  'Melden funktioniert');

reset role;
set local role anon;
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon: kein Zugriff auf Profile');
select throws_ok($$ select public.discover_profiles() $$, '42501', null, 'anon: keine RPCs');

reset role;
select * from finish();
rollback;
