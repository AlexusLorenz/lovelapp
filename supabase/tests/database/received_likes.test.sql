-- pgTAP: erhaltene Likes
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'cara@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'dan@test.local'),
  ('00000000-0000-0000-0000-0000000000c3', 'eli@test.local'),
  ('00000000-0000-0000-0000-0000000000c4', 'finn@test.local');

insert into public.profiles (id, display_name, birthdate, gender, interested_in, sensitive_consent_at, location)
values
  ('00000000-0000-0000-0000-0000000000c1', 'Cara', current_date - interval '27 years', 'woman', '{man}', now(), 'SRID=4326;POINT(12.37 51.34)'),
  ('00000000-0000-0000-0000-0000000000c2', 'Dan', current_date - interval '29 years', 'man', '{woman}', now(), 'SRID=4326;POINT(12.40 51.33)'),
  ('00000000-0000-0000-0000-0000000000c3', 'Eli', current_date - interval '31 years', 'man', '{woman}', now(), null),
  ('00000000-0000-0000-0000-0000000000c4', 'Finn', current_date - interval '26 years', 'man', '{woman}', now(), null);

-- Dan, Eli und Finn liken Cara
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select public.like_profile('00000000-0000-0000-0000-0000000000c1');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c3';
select public.like_profile('00000000-0000-0000-0000-0000000000c1');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c4';
select public.like_profile('00000000-0000-0000-0000-0000000000c1');

-- Als Cara
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select is((select count(*)::int from public.get_received_likes()), 3, 'Drei offene Likes');
select is(
  (select distance_km from public.get_received_likes() where display_name = 'Dan'),
  2, 'Entfernung gerundet, wenn beide einen Standort haben');
select is(
  (select distance_km from public.get_received_likes() where display_name = 'Eli'),
  null, 'Ohne Standort keine Entfernung');

-- Zurückliken → Match → verschwindet
select is((public.like_profile('00000000-0000-0000-0000-0000000000c2') ->> 'matched')::boolean,
  true, 'Zurückliken ergibt Match');
select is((select count(*)::int from public.get_received_likes()
  where display_name = 'Dan'), 0, 'Gematchte verschwinden');

-- Weggewischt → verschwindet
select public.pass_profile('00000000-0000-0000-0000-0000000000c3');
select is((select count(*)::int from public.get_received_likes()
  where display_name = 'Eli'), 0, 'Weggewischte verschwinden');

-- Blockiert → verschwindet
insert into public.blocks (blocked_id) values ('00000000-0000-0000-0000-0000000000c4');
select is((select count(*)::int from public.get_received_likes()), 0, 'Blockierte verschwinden');

-- Andere sehen Caras Likes nicht
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c4';
select is((select count(*)::int from public.get_received_likes()), 0, 'Nur eigene Likes');

reset role;
set local role anon;
select throws_ok($$ select public.get_received_likes() $$, '42501', null, 'anon: kein Zugriff');

reset role;
select * from finish();
rollback;
