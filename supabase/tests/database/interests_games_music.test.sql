-- pgTAP: Interessen, Lieblingsspiele, Lieblingskünstler:innen
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'fan@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'leserin@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000c1', 'Fan', current_date - interval '25 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000c2', 'Leserin', current_date - interval '25 years', 'man');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';

-- Interessen
select lives_ok($$ select public.set_profile_interests(array[
  'music.indie', 'music.jazz', 'music.rock', 'sports.climbing', 'sports.climbing']) $$,
  'Interessen speichern (Doppelte werden zusammengefasst)');
select is((select count(*)::int from public.profile_interests), 4, 'Vier Interessen');
select is((select category from public.profile_interests where interest_key = 'sports.climbing'),
  'sports', 'Kategorie wird abgeleitet');
select throws_ok($$ select public.set_profile_interests(array[
  'music.indie', 'music.jazz', 'music.rock', 'music.pop']) $$,
  '22023', null, 'Höchstens drei pro Kategorie');
select throws_ok($$ select public.set_profile_interests(array['religion.x']) $$,
  '22023', null, 'Nur bekannte Kategorien');
select is((select count(*)::int from public.profile_interests), 4, 'Fehler ändert nichts');
select lives_ok($$ select public.set_profile_interests(array[]::text[]) $$, 'Alles abwählen');
select is((select count(*)::int from public.profile_interests), 0, 'Leer');
select public.set_profile_interests(array['books.fantasy']);
select throws_ok($$ insert into public.profile_interests (profile_id, interest_key)
  values (auth.uid(), 'music.pop') $$, '42501', null, 'Kein direktes Schreiben');

-- Spiele
select lives_ok($$ select public.set_profile_games('[
  {"id": 3328, "name": "The Witcher 3", "cover": "https://media.rawg.io/media/games/618/abc.jpg"},
  {"id": 22511, "name": "Zelda: Breath of the Wild", "cover": null}]'::jsonb) $$,
  'Spiele speichern');
select is((select name from public.profile_games where position = 1),
  'Zelda: Breath of the Wild', 'Reihenfolge bleibt');
select throws_ok($$ select public.set_profile_games('[
  {"id": 1, "name": "X", "cover": "https://evil.example/pixel.gif"}]'::jsonb) $$,
  '23514', null, 'Nur Cover vom RAWG-CDN');
select throws_ok($$ select public.set_profile_games((
  select jsonb_agg(jsonb_build_object('id', i, 'name', 'Spiel ' || i))
  from generate_series(1, 7) i)) $$, '22023', null, 'Höchstens sechs Spiele');
select is((select count(*)::int from public.profile_games), 2, 'Fehler ändert nichts');

-- Künstler:innen
select lives_ok($$ select public.set_profile_artists('[
  {"id": "4Z8W4fKeB5YxbusRsdQVPb", "name": "Radiohead", "image": "https://i.scdn.co/image/ab6761610000e5eb"}]'::jsonb) $$,
  'Künstler speichern');
select throws_ok($$ select public.set_profile_artists('[
  {"id": "4Z8W4fKeB5YxbusRsdQVPb", "name": "X", "image": "https://evil.example/a.png"}]'::jsonb) $$,
  '23514', null, 'Nur Bilder vom Spotify-CDN');

-- Andere sehen alles, können aber nichts ändern
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select is((select count(*)::int from public.profile_interests), 1, 'Fremde Interessen sichtbar');
select is((select count(*)::int from public.profile_games), 2, 'Fremde Spiele sichtbar');
select is((select count(*)::int from public.profile_artists), 1, 'Fremde Künstler sichtbar');
select public.set_profile_games('[]'::jsonb);
reset role;
select is((select count(*)::int from public.profile_games
  where profile_id = '00000000-0000-0000-0000-0000000000c1'), 2,
  'Eigene Liste leeren betrifft nur das eigene Profil');

-- Unsichtbares Profil
update public.profiles set is_visible = false where id = '00000000-0000-0000-0000-0000000000c1';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select is((select count(*)::int from public.profile_interests), 0, 'Unsichtbar → nichts zu sehen');

set local role anon;
select throws_ok($$ select public.set_profile_interests(array['music.pop']) $$,
  '42501', null, 'Anonym kein Zugriff');

reset role;
select * from finish();
rollback;
