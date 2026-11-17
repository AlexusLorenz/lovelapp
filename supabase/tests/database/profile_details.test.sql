-- pgTAP: Steckbrief und Profil-Fragen
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'anna@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'ben@test.local');

insert into public.profiles (id, display_name, birthdate, gender, interested_in, sensitive_consent_at)
values
  ('00000000-0000-0000-0000-0000000000a1', 'Anna', current_date - interval '28 years', 'woman', '{man}', now()),
  ('00000000-0000-0000-0000-0000000000b1', 'Ben', current_date - interval '30 years', 'man', '{woman}', now());

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

-- Steckbrief
select lives_ok(
  $$ update public.profiles
        set smoking = 'never', drinking = 'socially', children = 'want_someday',
            exercise = 'often', relationship_goal = 'long_term', height_cm = 172
      where id = auth.uid() $$,
  'Steckbrief selbst ausfüllbar');
select throws_ok(
  $$ update public.profiles set smoking = 'kette' where id = auth.uid() $$,
  '23514', null, 'Unbekannte Werte abgelehnt');
select throws_ok(
  $$ update public.profiles set height_cm = 300 where id = auth.uid() $$,
  '23514', null, 'Unplausible Größe abgelehnt');

-- Fragen
select lives_ok(
  $$ insert into public.profile_prompts (profile_id, position, prompt_key, answer) values
       (auth.uid(), 0, 'perfect_sunday', 'Brunch und Brettspiele'),
       (auth.uid(), 1, 'green_flag', 'Du fragst nach.'),
       (auth.uid(), 2, 'superpower', 'Parkplätze finden') $$,
  'Drei Fragen anlegen');
select throws_ok(
  $$ insert into public.profile_prompts (profile_id, position, prompt_key, answer)
     values (auth.uid(), 3, 'guilty_pleasure', 'zu viel') $$,
  '23514', null, 'Höchstens drei Fragen');
select throws_ok(
  $$ update public.profile_prompts set prompt_key = 'green_flag' where position = 0 $$,
  '23505', null, 'Jede Frage nur einmal');
select throws_ok(
  $$ insert into public.profile_prompts (profile_id, position, prompt_key, answer)
     values ('00000000-0000-0000-0000-0000000000b1', 0, 'perfect_sunday', 'Fake') $$,
  '42501', null, 'Keine Fragen in fremde Profile schreiben');

-- Als Ben: Annas Steckbrief und Fragen sehen
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select is(
  (select smoking from public.get_public_profiles(array['00000000-0000-0000-0000-0000000000a1'::uuid])),
  'never', 'Steckbrief für andere sichtbar');
select is(
  (select count(*)::int from public.profile_prompts
    where profile_id = '00000000-0000-0000-0000-0000000000a1'),
  3, 'Fragen für andere sichtbar');
select is(
  (select count(*)::int from public.profile_prompts
    where profile_id = '00000000-0000-0000-0000-0000000000a1'
      and answer = 'Hack'), 0, 'Vorbedingung');
update public.profile_prompts set answer = 'Hack'
 where profile_id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select count(*)::int from public.profile_prompts where answer = 'Hack'),
  0, 'Fremde Fragen nicht änderbar');

-- Blockiert → Fragen unsichtbar
insert into public.blocks (blocked_id) values ('00000000-0000-0000-0000-0000000000a1');
select is(
  (select count(*)::int from public.profile_prompts
    where profile_id = '00000000-0000-0000-0000-0000000000a1'),
  0, 'Nach Blockieren keine Fragen mehr sichtbar');

reset role;
select * from finish();
rollback;
