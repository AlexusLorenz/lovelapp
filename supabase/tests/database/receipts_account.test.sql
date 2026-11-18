-- pgTAP: Zustell-/Lesebestätigung, Blockieren/Melden, Konto löschen
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dora@test.local'),
  ('00000000-0000-0000-0000-0000000000d2', 'emil@test.local'),
  ('00000000-0000-0000-0000-0000000000d3', 'fritz@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000d1', 'Dora', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000d2', 'Emil', current_date - interval '30 years', 'man'),
  ('00000000-0000-0000-0000-0000000000d3', 'Fritz', current_date - interval '30 years', 'man');
insert into public.matches (user_a, user_b) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d3');
create temp table t_m as
  select id from public.matches where user_b = '00000000-0000-0000-0000-0000000000d2';
grant select on t_m to authenticated;

-- Dora schreibt Emil
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
insert into public.messages (match_id, body) select id, 'Hallo Emil' from t_m;
select is((select delivered_at from public.messages), null, 'Gesendet: noch nicht angekommen');
select is(public.mark_messages_delivered(), 0, 'Eigene Nachrichten zählen nicht als angekommen');

-- Emils App empfängt
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d2';
select is(public.mark_messages_delivered(), 1, 'Emil: eine Nachricht angekommen');
select isnt((select delivered_at from public.messages), null, 'Angekommen gesetzt');
select is((select read_at from public.messages), null, 'Noch nicht gelesen');

-- Vordatieren / zurücksetzen geht nicht
update public.messages set delivered_at = null, read_at = '2000-01-01';
select ok((select read_at > now() - interval '1 minute' from public.messages),
  'Gelesen-Zeit setzt der Server');
select isnt((select delivered_at from public.messages), null, 'Angekommen bleibt');
update public.messages set read_at = null;
select isnt((select read_at from public.messages), null, 'Gelesen lässt sich nicht zurücknehmen');
select throws_ok($$ update public.messages set body = 'gefälscht' $$,
  '42501', null, 'Text unveränderlich');

-- Fritz (anderes Match) markiert nichts
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d3';
select is(public.mark_messages_delivered(), 0, 'Fremde Nachrichten unberührt');

-- Melden + Blockieren
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d2';
select lives_ok($$ insert into public.reports (reported_id, reason, details)
  values ('00000000-0000-0000-0000-0000000000d1', 'harassment', 'Test') $$, 'Melden');
select lives_ok($$ insert into public.blocks (blocked_id)
  values ('00000000-0000-0000-0000-0000000000d1') $$, 'Blockieren');
reset role;
select isnt((select unmatched_at from public.matches m join t_m using (id)), null,
  'Blockieren beendet das Match');

-- Konto löschen
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
select lives_ok($$ select public.delete_own_account() $$, 'Eigenes Konto löschen');
reset role;
select is((select count(*)::int from auth.users where id = '00000000-0000-0000-0000-0000000000d1'),
  0, 'Auth-Konto weg');
select is((select count(*)::int from public.matches
  where '00000000-0000-0000-0000-0000000000d1' in (user_a, user_b)), 0, 'Matches weg');
select is((select count(*)::int from public.messages), 0, 'Nachrichten weg');
select is((select count(*)::int from public.reports where reported_id = '00000000-0000-0000-0000-0000000000d1'),
  0, 'Meldungen über gelöschtes Konto weg');
select is((select count(*)::int from auth.users where id = '00000000-0000-0000-0000-0000000000d2'),
  1, 'Andere Konten bleiben');

set local role anon;
select throws_ok($$ select public.delete_own_account() $$, '42501', null, 'Anonym nicht erlaubt');

reset role;
select * from finish();
rollback;
