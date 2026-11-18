-- pgTAP: Quizduell 2 gegen 2
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

-- Zwei Paare (Teams) und eine Person, die mit beiden gematcht wäre.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', 'b2@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000a1', 'Anna', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000a2', 'Arne', current_date - interval '30 years', 'man'),
  ('00000000-0000-0000-0000-0000000000b1', 'Bea', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000b2', 'Ben', current_date - interval '30 years', 'man');
insert into public.matches (id, user_a, user_b) values
  ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b2'),
  ('00000000-0000-0000-0000-00000000abab', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2');

-- Testhelfer (läuft mit Admin-Rechten, kennt daher die Lösung):
-- spielt für p_user, was gerade ansteht. p_right: richtige Antworten geben?
create function public.t_act(p_user uuid, p_game uuid, p_right boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare st jsonb; a text; first_action text; i int; q int; c int; opts jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  st := public.quiz_game_state(p_game);
  a := st->>'action';
  first_action := a;
  if a = 'choose' then
    select x->'options' into opts from jsonb_array_elements(st->'rounds') x
     where (x->>'round')::int = (st->>'round')::int;
    perform public.quiz_choose_category(p_game, opts->>0);
    a := 'propose';
  end if;
  if a in ('propose', 'decide') then
    for i in 0..2 loop
      perform public.quiz_show_question(p_game, i);
      select r.question_ids[i + 1] into q from public.quiz_rounds r
       where r.game_id = p_game and r.round = (st->>'round')::int;
      c := private.quiz_correct_index(p_game, q);
      perform public.quiz_answer(p_game, i, case when p_right then c else (c + 1) % 4 end);
    end loop;
  end if;
  return first_action;
end $$;
grant execute on function public.t_act(uuid, uuid, boolean) to authenticated;

create temp table t (k text primary key, v uuid);
grant all on t to authenticated;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

-- Start: Team A sucht zufällige Gegner
insert into t values ('g', public.quiz_start('00000000-0000-0000-0000-00000000aaaa'));
select is(public.quiz_start('00000000-0000-0000-0000-00000000aaaa'), (select v from t where k = 'g'),
  'Zweiter Start gibt dieselbe offene Suche zurück');
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'choose',
  'Anna (Vorschlag in Runde 1) wählt die Kategorie');
select is(jsonb_array_length(public.quiz_game_state((select v from t where k = 'g'))
  ->'rounds'->0->'options'), 3, 'Drei Kategorien zur Wahl');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'wait_partner',
  'Arne wartet auf Anna');
select throws_ok($$ select public.quiz_choose_category((select v from t where k = 'g'), 'sport') $$,
  'P0001', null, 'Arne darf nicht wählen');

-- Fremde sehen das Spiel nicht
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select throws_ok($$ select public.quiz_game_state((select v from t where k = 'g')) $$,
  'P0002', null, 'Fremde sehen das Spiel nicht');
select is((select count(*)::int from public.quiz_games), 0, 'RLS: Spielzeile unsichtbar');
select throws_ok($$ select * from public.quiz_questions $$, '42501', null, 'Fragen nicht direkt lesbar');

-- Anna schlägt vor (richtig), Lösung bleibt verborgen
select is(public.t_act('00000000-0000-0000-0000-0000000000a1', (select v from t where k = 'g'), true),
  'choose', 'Anna wählt und schlägt vor');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select is(public.quiz_game_state((select v from t where k = 'g'))->'rounds'->0->'questions'->0->'review',
  'null'::jsonb, 'Nach dem Vorschlag noch keine Lösung');
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'wait_partner',
  'Anna wartet jetzt auf Arne');

-- Arne sieht Annas Vorschlag
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'decide', 'Arne entscheidet');
select ok((public.quiz_show_question((select v from t where k = 'g'), 0)->>'proposal') is not null,
  'Arne sieht den Vorschlag');
select throws_ok($$ select public.quiz_show_question((select v from t where k = 'g'), 2) $$,
  'P0001', null, 'Fragen nur der Reihe nach');
select is(public.quiz_answer((select v from t where k = 'g'), 0, -1)->>'done', 'false',
  'Keine eigene Antwort → Vorschlag zählt');
select public.quiz_show_question((select v from t where k = 'g'), 1);
-- Zeitlimit: Anzeige 40 s in die Vergangenheit verschieben → zählt als keine Antwort
reset role;
update public.quiz_answers set final_shown_at = now() - interval '40 seconds' where q_index = 1;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
select public.quiz_answer((select v from t where k = 'g'), 1, 3);
select public.quiz_show_question((select v from t where k = 'g'), 2);
select ok((public.quiz_answer((select v from t where k = 'g'), 2, -1)->'results') is not null,
  'Nach der letzten Frage gibt es die Auflösung');
select is((public.quiz_game_state((select v from t where k = 'g'))->>'my_score')::int, 3,
  'Alle drei richtig (zu spät → Vorschlag zählt)');
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'searching',
  'Team A hat gespielt und wartet auf Gegner');
select ok(public.quiz_game_state((select v from t where k = 'g'))->'rounds'->0->'questions'->0->'review' ? 'correct_index',
  'Jetzt mit Lösung zum Nachlesen');

-- Gemeinsame Person: Match a1+b2 darf nicht gegen a1+a2 antreten
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';
insert into t values ('g_ab', public.quiz_start('00000000-0000-0000-0000-00000000abab'));
select isnt((select v from t where k = 'g_ab'), (select v from t where k = 'g'),
  'Keine Paarung mit Überschneidung → eigene Suche');

-- Team B tritt bei und ist sofort dran
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select is(public.quiz_start('00000000-0000-0000-0000-00000000bbbb'), (select v from t where k = 'g'),
  'Team B findet das wartende Spiel');
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'propose',
  'Bea schlägt vor (Kategorie steht schon)');
select is(public.quiz_game_state((select v from t where k = 'g'))->'opponent'->'players'->0->>'name',
  'Anna', 'Gegner nur mit Vornamen');
select is((public.quiz_game_state((select v from t where k = 'g'))->>'opponent_score')::int, 0,
  'Gegnerpunkte erst sichtbar, wenn man die Runde selbst gespielt hat');

-- Rest des Spiels durchspielen: Team B immer falsch
select public.t_act('00000000-0000-0000-0000-0000000000b1', (select v from t where k = 'g'), false);
select public.t_act('00000000-0000-0000-0000-0000000000b2', (select v from t where k = 'g'), false);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select is((public.quiz_game_state((select v from t where k = 'g'))->>'round')::int, 2,
  'Runde 2 beginnt');
select is(public.quiz_game_state((select v from t where k = 'g'))->>'action', 'wait_partner',
  'Runde 2: Ben (gerade Runde) wählt für Team B');

do $$
declare
  g uuid := (select v from t where k = 'g');
  users uuid[] := array['00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000a2',
                        '00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000b2']::uuid[];
  u uuid; n int := 0;
begin
  loop
    n := n + 1;
    exit when n > 100;
    foreach u in array users loop
      perform public.t_act(u, g, u::text like '%a_');
    end loop;
    perform set_config('request.jwt.claim.sub', users[1]::text, true);
    exit when public.quiz_game_state(g)->>'status' = 'finished';
  end loop;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select is(public.quiz_game_state((select v from t where k = 'g'))->>'status', 'finished', 'Spiel beendet');
select is((public.quiz_game_state((select v from t where k = 'g'))->>'my_score')::int, 18, 'Team A: 18 Punkte');
select is((public.quiz_game_state((select v from t where k = 'g'))->>'opponent_score')::int, 0, 'Team B: 0');
select is((public.quiz_game_state((select v from t where k = 'g'))->>'won')::boolean, true, 'Team A gewinnt');
select is(jsonb_array_length(public.quiz_game_state((select v from t where k = 'g'))->'rounds'), 6, '6 Runden');
reset role;
select is((select count(distinct q) from public.quiz_rounds r, unnest(r.question_ids) q
            where r.game_id = (select v from t where k = 'g')), 18::bigint, '18 verschiedene Fragen');
select is((select count(*)::int from public.xp_events where reason = 'game_finished'), 4,
  'Alle vier bekommen XP');

-- Einladung per Code
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
insert into t values ('inv', public.quiz_start('00000000-0000-0000-0000-00000000aaaa', 'invite'));
insert into t select 'dummy', null; -- (Platzhalter)
create temp table t_code as
  select public.quiz_game_state((select v from t where k = 'inv'))->>'invite_code' as code;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select throws_ok($$ select public.quiz_join('00000000-0000-0000-0000-00000000bbbb', 'ZZZZZZ') $$,
  'P0002', null, 'Falscher Code');
select is(
  public.quiz_join('00000000-0000-0000-0000-00000000bbbb',
    (select lower(code) from t_code)),
  (select v from t where k = 'inv'), 'Beitritt per Code (Groß-/Kleinschreibung egal)');
select is(public.quiz_game_state((select v from t where k = 'inv'))->>'action', 'wait_opponent',
  'Team A muss erst Runde 1 spielen');

-- Blockieren beendet laufende Spiele
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
insert into public.blocks (blocked_id) values ('00000000-0000-0000-0000-0000000000a1');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select is(public.quiz_game_state((select v from t where k = 'inv'))->>'status', 'abandoned',
  'Spiel endet, wenn ein Team-Match endet');
select is((public.quiz_game_state((select v from t where k = 'inv'))->>'won')::boolean, true,
  'Das andere Team gewinnt');
select is(jsonb_array_length(public.quiz_my_games()), 2, 'Übersicht: beide Spiele');

reset role;
select * from finish();
rollback;
