-- pgTAP: Schätzduell, Emoji-Rätsel, Seelenverwandt
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.local'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1@test.local'),
  ('00000000-0000-0000-0000-0000000000d2', 'd2@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000c1', 'Clara', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000c2', 'Carl', current_date - interval '30 years', 'man'),
  ('00000000-0000-0000-0000-0000000000d1', 'Dana', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000d2', 'Dirk', current_date - interval '30 years', 'man');
insert into public.matches (id, user_a, user_b) values
  ('00000000-0000-0000-0000-00000000cccc', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2'),
  ('00000000-0000-0000-0000-00000000dddd', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2');

-- Punkte im Schätzduell
select is(private.quiz_estimate_points(330, 330, 'm'), 3::smallint, 'Exakt: 3');
select is(private.quiz_estimate_points(345, 330, 'm'), 3::smallint, '≤ 5 %: 3');
select is(private.quiz_estimate_points(390, 330, 'm'), 2::smallint, '≤ 20 %: 2');
select is(private.quiz_estimate_points(150, 330, 'm'), 0::smallint, '> 50 %: 0');
select is(private.quiz_estimate_points(1990, 1989, 'Jahr'), 3::smallint, 'Jahr ±1: 3');
select is(private.quiz_estimate_points(1980, 1989, 'Jahr'), 1::smallint, 'Jahr ±15: 1');
select is(private.quiz_estimate_points(1950, 1989, 'Jahr'), 0::smallint, 'Jahr daneben: 0');
select is(private.quiz_estimate_points(null, 1989, 'Jahr'), 0::smallint, 'Keine Schätzung: 0');

-- Inhalte
select ok((select count(*) from public.quiz_categories where kind = 'estimate') >= 3, 'Schätz-Kategorien');
select ok((select count(*) from public.quiz_categories where kind = 'emoji') >= 3, 'Emoji-Kategorien');
select ok((select count(*) from public.quiz_categories where kind = 'soulmate') >= 3, 'Seelenverwandt-Kategorien');
select is((select count(*)::int from public.quiz_questions q join public.quiz_categories c on c.key = q.category
            where c.kind = 'estimate' and q.number_answer is null), 0, 'Jede Schätzfrage hat eine Zahl');
select ok((select min(n) from (select count(*) n from public.quiz_questions group by category) x) >= 6,
  'Jede Kategorie reicht für zwei Runden');

create table public.t_g (k text primary key, v uuid);
grant all on public.t_g to authenticated;

-- Helfer (Admin-Rechte): spielt, was ansteht. p_right: gut spielen?
create function public.t_play(p_user uuid, p_game uuid, p_right boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare st jsonb; a text; first_action text; i int; q public.quiz_questions; k text;
        opts jsonb; c int; v jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  st := public.quiz_game_state(p_game);
  a := st->>'action'; first_action := a; k := st->>'kind';
  if a = 'choose' then
    select x->'options' into opts from jsonb_array_elements(st->'rounds') x
     where (x->>'round')::int = (st->>'round')::int;
    perform public.quiz_choose_category(p_game, opts->>0);
    a := 'propose';
  end if;
  if a in ('propose', 'decide') then
    for i in 0..2 loop
      v := public.quiz_show_question(p_game, i);
      select qq.* into q from public.quiz_questions qq, public.quiz_rounds r
       where r.game_id = p_game and r.round = (st->>'round')::int and qq.id = r.question_ids[i + 1];
      if k = 'estimate' then
        perform public.quiz_answer(p_game, i, null,
          case when p_right then q.number_answer else q.number_answer * 10 end);
      elsif k = 'soulmate' then
        perform public.quiz_answer(p_game, i, case when p_right or a = 'propose' then 0 else 1 end);
      else
        c := private.quiz_correct_index(p_game, q.id);
        perform public.quiz_answer(p_game, i, case when p_right then c else (c + 1) % 4 end);
      end if;
    end loop;
  end if;
  return first_action;
end $$;
grant execute on function public.t_play(uuid, uuid, boolean) to authenticated;

set local role authenticated;

-- Schätzduell: Clara schlägt vor, Carl sieht die Zahl
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
insert into public.t_g values ('est', public.quiz_start('00000000-0000-0000-0000-00000000cccc', 'random', 'estimate'));
select is(public.quiz_game_state((select v from public.t_g where k = 'est'))->>'kind', 'estimate', 'Spielart gespeichert');
select ok((select bool_and(c.kind = 'estimate')
             from jsonb_array_elements_text(public.quiz_game_state((select v from public.t_g where k = 'est'))
                    ->'rounds'->0->'options') o
             join public.quiz_categories c on c.key = o),
  'Nur Schätz-Kategorien zur Wahl');
select public.t_play('00000000-0000-0000-0000-0000000000c1', (select v from public.t_g where k = 'est'), true);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select ok((public.quiz_show_question((select v from public.t_g where k = 'est'), 0)->>'proposal_number') is not null,
  'Schätzung der Partnerin sichtbar');
select ok(public.quiz_show_question((select v from public.t_g where k = 'est'), 0)->>'unit' is not null,
  'Einheit wird mitgeschickt');
select is(public.quiz_answer((select v from public.t_g where k = 'est'), 0)->>'done', 'false',
  'Ohne eigene Zahl gilt der Vorschlag');
select public.quiz_show_question((select v from public.t_g where k = 'est'), 1);
select public.quiz_answer((select v from public.t_g where k = 'est'), 1, null, 0.0001);
select public.quiz_show_question((select v from public.t_g where k = 'est'), 2);
select is(jsonb_array_length(public.quiz_answer((select v from public.t_g where k = 'est'), 2)->'results'), 3,
  'Auflösung mit drei Ergebnissen');
select is((public.quiz_game_state((select v from public.t_g where k = 'est'))->>'my_score')::int, 6,
  '3 + 0 + 3 Punkte');
select is((public.quiz_game_state((select v from public.t_g where k = 'est'))->'rounds'->0->'questions'->0->'review'->>'number_answer') is not null,
  true, 'Richtige Zahl zum Nachlesen');

-- Team D sucht ein Quizduell → landet NICHT im Schätzduell
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
insert into public.t_g values ('quiz_d', public.quiz_start('00000000-0000-0000-0000-00000000dddd'));
select isnt((select v from public.t_g where k = 'quiz_d'), (select v from public.t_g where k = 'est'),
  'Gegner nur innerhalb derselben Spielart');
select is(public.quiz_start('00000000-0000-0000-0000-00000000dddd', 'random', 'estimate'),
  (select v from public.t_g where k = 'est'), 'Schätzduell-Suche findet das wartende Team');

-- Seelenverwandt: Vorschlag bleibt verborgen
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
insert into public.t_g values ('sm', public.quiz_start('00000000-0000-0000-0000-00000000cccc', 'random', 'soulmate'));
select public.t_play('00000000-0000-0000-0000-0000000000c1', (select v from public.t_g where k = 'sm'), true);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select is(public.quiz_show_question((select v from public.t_g where k = 'sm'), 0)->'proposal', 'null'::jsonb,
  'Seelenverwandt: Antwort der Partnerin bleibt verborgen');
reset role;
create temp table t_first as
  select q.answers[1] as a from public.quiz_questions q, public.quiz_rounds r
   where r.game_id = (select v from public.t_g where k = 'sm') and q.id = r.question_ids[1];
grant select on t_first to authenticated;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select is((public.quiz_show_question((select v from public.t_g where k = 'sm'), 0)->'answers'->>0),
  (select a from t_first), 'Antworten in natürlicher Reihenfolge');
select public.quiz_answer((select v from public.t_g where k = 'sm'), 0, 0);   -- gleich → Punkt
select public.quiz_show_question((select v from public.t_g where k = 'sm'), 1);
select public.quiz_answer((select v from public.t_g where k = 'sm'), 1, 1);   -- anders → kein Punkt
select public.quiz_show_question((select v from public.t_g where k = 'sm'), 2);
select public.quiz_answer((select v from public.t_g where k = 'sm'), 2, -1);  -- keine → kein Punkt
select is((public.quiz_game_state((select v from public.t_g where k = 'sm'))->>'my_score')::int, 1,
  'Nur Übereinstimmungen zählen, keine Antwort zählt nicht');

-- Team D tritt bei, spielt Runde 1 → sieht von Team C nur Treffer, keine Antworten
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
select is(public.quiz_start('00000000-0000-0000-0000-00000000dddd', 'random', 'soulmate'),
  (select v from public.t_g where k = 'sm'), 'Team D tritt bei');
select public.t_play('00000000-0000-0000-0000-0000000000d1', (select v from public.t_g where k = 'sm'), true);
select public.t_play('00000000-0000-0000-0000-0000000000d2', (select v from public.t_g where k = 'sm'), true);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
select is((public.quiz_game_state((select v from public.t_g where k = 'sm'))->>'my_score')::int, 3, 'Team D: 3 Treffer');
select is(public.quiz_game_state((select v from public.t_g where k = 'sm'))->'rounds'->0->'questions'->0->'opponent'->'final',
  'null'::jsonb, 'Antworten des anderen Paares bleiben privat');
select is((public.quiz_game_state((select v from public.t_g where k = 'sm'))->'rounds'->0->'questions'->0->'opponent'->>'correct')::boolean,
  true, 'Treffer des anderen Paares sichtbar');

-- Emoji-Rätsel: ganzes Spiel, Team C immer richtig
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
insert into public.t_g values ('emo', public.quiz_start('00000000-0000-0000-0000-00000000cccc', 'invite', 'emoji'));
reset role;
insert into public.t_g select 'emo_code', null;
set local role authenticated;
create temp table t_code as
  select public.quiz_game_state((select v from public.t_g where k = 'emo'))->>'invite_code' as code;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d2';
select is(public.quiz_join('00000000-0000-0000-0000-00000000dddd', (select code from t_code)),
  (select v from public.t_g where k = 'emo'), 'Einladung per Code auch für Emoji-Rätsel');

do $$
declare
  g uuid := (select v from public.t_g where k = 'emo');
  users uuid[] := array['00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000c2',
                        '00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000d2']::uuid[];
  u uuid; n int := 0;
begin
  loop
    n := n + 1;
    exit when n > 100;
    foreach u in array users loop
      perform public.t_play(u, g, u::text like '%c_');
    end loop;
    perform set_config('request.jwt.claim.sub', users[1]::text, true);
    exit when public.quiz_game_state(g)->>'status' = 'finished';
  end loop;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select is(public.quiz_game_state((select v from public.t_g where k = 'emo'))->>'status', 'finished', 'Emoji-Rätsel beendet');
select is((public.quiz_game_state((select v from public.t_g where k = 'emo'))->>'my_score')::int, 18, '18 von 18');
select is((public.quiz_game_state((select v from public.t_g where k = 'emo'))->>'won')::boolean, true, 'Team C gewinnt');
select is((select jsonb_agg(x->>'kind') from jsonb_array_elements(public.quiz_my_games()) x)
          @> '["estimate","soulmate","emoji"]'::jsonb, true, 'Übersicht kennt die Spielart');

reset role;
select is((select array_agg(distinct c.kind)
             from public.quiz_rounds r join public.quiz_categories c on c.key = r.category
            where r.game_id = (select v from public.t_g where k = 'emo')), array['emoji'],
  'Nur Emoji-Kategorien gespielt');
select * from finish();
rollback;
