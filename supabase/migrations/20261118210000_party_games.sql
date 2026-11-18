-- =============================================================================
-- Drei weitere 2-gegen-2-Spiele auf der Quizduell-Engine
--
--   quiz      – Quizduell (wie bisher)
--   estimate  – Schätzduell: Zahl schätzen, 0–3 Punkte je nach Nähe
--   emoji     – Emoji-Rätsel: Emoji-Folge erraten, 4 Antworten
--   soulmate  – Seelenverwandt: eine Person beantwortet ehrlich eine Frage
--               über sich, die andere rät – ohne den „Vorschlag“ zu sehen.
--               Punkt bei Übereinstimmung.
--
-- Ablauf (Runden, Rollen, Zeitlimit, Gegnersuche, Code) bleibt identisch.
-- Gegner werden nur innerhalb derselben Spielart gesucht.
--
-- MUSS synchron bleiben mit lib/features/quiz/quiz_rules.dart
-- (QuizKind, Punkte im Schätzduell).
-- =============================================================================

alter table public.quiz_categories
  add column kind text not null default 'quiz'
  check (kind in ('quiz', 'estimate', 'emoji', 'soulmate'));

alter table public.quiz_questions
  add column number_answer numeric,
  add column unit text;
alter table public.quiz_questions drop constraint quiz_questions_answers_check;
alter table public.quiz_questions add constraint quiz_questions_answers_check check (
  (cardinality(answers) between 2 and 4 and number_answer is null)
  or (cardinality(answers) = 0 and number_answer is not null)
);

alter table public.quiz_games
  add column kind text not null default 'quiz'
  check (kind in ('quiz', 'estimate', 'emoji', 'soulmate'));
drop index public.quiz_games_search_idx;
create index quiz_games_search_idx on public.quiz_games (kind, created_at)
  where status = 'searching' and team_b is null;

alter table public.quiz_answers
  add column proposal_num numeric,
  add column final_num numeric,
  add column points smallint check (points between 0 and 3);
update public.quiz_answers set points = case when correct then 1 else 0 end
 where final is not null;

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------

-- Reihenfolge der angezeigten Antworten (Positionen 1..n). Gemischt wird nur,
-- wo es eine richtige Antwort gibt; für n = 4 identisch mit quiz_order.
create function private.quiz_perm(p_game uuid, p_question int, p_n int, p_shuffle boolean)
returns int[]
language sql
immutable
set search_path = ''
as $$
  select case when p_n = 0 then '{}'::int[]
              when p_shuffle then (
                select array_agg(i order by md5(p_game::text || ':' || p_question || ':' || i))
                from generate_series(1, p_n) as i)
              else (select array_agg(i order by i) from generate_series(1, p_n) as i)
         end;
$$;

-- Gezeigte Antworten als JSON-Array.
create function private.quiz_presented(p_game uuid, q public.quiz_questions, p_kind text)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(q.answers[o] order by pos), '[]'::jsonb)
  from unnest(private.quiz_perm(p_game, q.id, cardinality(q.answers),
                                p_kind in ('quiz', 'emoji')))
       with ordinality as perm (o, pos);
$$;

-- Index der richtigen Antwort in der gezeigten Reihenfolge (nur Quiz/Emoji).
create or replace function private.quiz_correct_index(p_game uuid, p_question int)
returns smallint
language sql
stable
security definer
set search_path = ''
as $$
  select case when c.kind in ('quiz', 'emoji') then
           (array_position(private.quiz_perm(p_game, q.id, cardinality(q.answers), true), 1) - 1)::smallint
         end
  from public.quiz_questions q
  join public.quiz_categories c on c.key = q.category
  where q.id = p_question;
$$;

-- Schätzduell: 3 Punkte sehr nah, 2 nah, 1 grob, 0 daneben.
-- Jahreszahlen nach Jahren (±1 / ±5 / ±15), sonst relativ (5 % / 20 % / 50 %).
create function private.quiz_estimate_points(p_guess numeric, p_truth numeric, p_unit text)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_guess is null or p_truth is null then 0
    when p_unit = 'Jahr' then
      case when abs(p_guess - p_truth) <= 1 then 3
           when abs(p_guess - p_truth) <= 5 then 2
           when abs(p_guess - p_truth) <= 15 then 1
           else 0 end
    else
      case when abs(p_guess - p_truth) <= 0.05 * abs(p_truth) then 3
           when abs(p_guess - p_truth) <= 0.20 * abs(p_truth) then 2
           when abs(p_guess - p_truth) <= 0.50 * abs(p_truth) then 1
           else 0 end
  end::smallint;
$$;

-- Runden bekommen nur Kategorien der eigenen Spielart.
create or replace function private.quiz_open_round(g public.quiz_games, p_round int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.quiz_rounds (game_id, round, chooser, options)
  select g.id, p_round, coalesce(private.quiz_chooser(g, p_round), g.team_a),
         array(
           select c.key from public.quiz_categories c
           where c.kind = g.kind
           order by (c.key in (select category from public.quiz_rounds
                               where game_id = g.id and category is not null)),
                    random()
           limit 3
         )
  on conflict do nothing;
end;
$$;

-- Punkte des Gegners nur für Runden, die man selbst auch gespielt hat.
create or replace function private.quiz_visible_opponent_score(g public.quiz_games, p_me uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(o.points), 0)::int
  from public.quiz_answers o
  where o.game_id = g.id
    and o.team <> private.quiz_team_of(g, p_me)
    and (g.status in ('finished', 'abandoned')
         or private.quiz_team_done(g.id, o.round, private.quiz_team_of(g, p_me)));
$$;

-- -----------------------------------------------------------------------------
-- Starten (jetzt mit Spielart)
-- -----------------------------------------------------------------------------
drop function public.quiz_start(uuid, text);

create function public.quiz_start(
  p_match uuid,
  p_mode text default 'random',
  p_kind text default 'quiz'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_open int;
  g public.quiz_games;
  v_code text;
begin
  if v_me is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;
  if not private.is_match_active(p_match) then
    raise exception 'Kein aktives Match' using errcode = '42501';
  end if;
  if p_mode not in ('random', 'invite') then
    raise exception 'Unbekannter Modus' using errcode = '22023';
  end if;
  if p_kind not in ('quiz', 'estimate', 'emoji', 'soulmate') then
    raise exception 'Unbekanntes Spiel' using errcode = '22023';
  end if;

  select count(*) into v_open from public.quiz_games
   where p_match in (team_a, team_b) and status in ('searching', 'active');
  if v_open >= 8 then
    raise exception 'Höchstens 8 laufende Spiele pro Match' using errcode = 'P0001';
  end if;

  if p_mode = 'random' then
    -- Schon eine eigene Suche für dieses Spiel offen? Dann die zurückgeben.
    select * into g from public.quiz_games
     where team_a = p_match and team_b is null and invite_code is null
       and status = 'searching' and kind = p_kind
     limit 1;
    if found then
      return g.id;
    end if;

    -- Wartendes Team derselben Spielart suchen.
    select * into g from public.quiz_games q
     where q.status = 'searching' and q.team_b is null and q.invite_code is null
       and q.kind = p_kind
       and private.quiz_teams_compatible(q.team_a, p_match)
     order by q.created_at
     limit 1
     for update skip locked;
    if found then
      update public.quiz_games
         set team_b = p_match,
             status = 'active',
             turn = case when private.quiz_team_done(g.id, 1, g.team_a)
                         then p_match else g.team_a end,
             updated_at = now()
       where id = g.id;
      return g.id;
    end if;
  end if;

  if p_mode = 'invite' then
    loop
      v_code := (
        select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                                 1 + floor(random() * 32)::int, 1), '')
        from generate_series(1, 6)
      );
      exit when not exists (select 1 from public.quiz_games where invite_code = v_code);
    end loop;
  end if;

  insert into public.quiz_games (team_a, invite_code, turn, created_by, kind)
  values (p_match, v_code, p_match, v_me, p_kind)
  returning * into g;
  perform private.quiz_open_round(g, 1);
  return g.id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Frage zeigen
-- -----------------------------------------------------------------------------
create or replace function public.quiz_show_question(p_game uuid, p_q_index int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  g public.quiz_games := private.quiz_load(p_game);
  v_action text := private.quiz_action(g, v_me);
  v_team uuid := private.quiz_team_of(g, v_me);
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_a public.quiz_answers;
  v_shown timestamptz;
  v_next int;
begin
  if v_action not in ('propose', 'decide') then
    raise exception 'Du bist gerade nicht dran' using errcode = 'P0001';
  end if;
  select * into v_round from public.quiz_rounds where game_id = g.id and round = g.round;

  -- Fragen nur der Reihe nach.
  select coalesce(min(i), 3) into v_next
    from generate_series(0, 2) as i
   where not exists (
     select 1 from public.quiz_answers a
      where a.game_id = g.id and a.round = g.round and a.team = v_team and a.q_index = i
        and (case when v_action = 'propose' then a.proposal else a.final end) is not null);
  if p_q_index <> v_next then
    raise exception 'Fragen bitte der Reihe nach' using errcode = 'P0001';
  end if;

  insert into public.quiz_answers (game_id, round, team, q_index, proposer_id, decider_id)
  values (g.id, g.round, v_team, p_q_index,
          private.quiz_proposer(v_team, g.round), private.quiz_decider(v_team, g.round))
  on conflict do nothing;

  if v_action = 'propose' then
    update public.quiz_answers set proposal_shown_at = coalesce(proposal_shown_at, now())
     where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index
     returning * into v_a;
    v_shown := v_a.proposal_shown_at;
  else
    update public.quiz_answers set final_shown_at = coalesce(final_shown_at, now())
     where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index
     returning * into v_a;
    v_shown := v_a.final_shown_at;
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_ids[p_q_index + 1];

  return jsonb_build_object(
    'kind', g.kind,
    'round', g.round,
    'q_index', p_q_index,
    'role', v_action,
    'category', v_round.category,
    'question', v_q.question,
    'answers', private.quiz_presented(g.id, v_q, g.kind),
    'unit', v_q.unit,
    'seconds_left', greatest(0, 30 - extract(epoch from (now() - v_shown)))::int,
    -- Beim Entscheiden den Vorschlag zeigen – außer bei Seelenverwandt,
    -- da wäre das Raten sinnlos.
    'proposal', case when v_action = 'decide' and g.kind in ('quiz', 'emoji')
                     then v_a.proposal end,
    'proposal_number', case when v_action = 'decide' and g.kind = 'estimate'
                            then v_a.proposal_num end
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Antworten
-- -----------------------------------------------------------------------------
drop function public.quiz_answer(uuid, int, int);

-- p_choice: Index der Antwort (-1 = keine). p_number: Schätzung (Schätzduell).
create function public.quiz_answer(
  p_game uuid,
  p_q_index int,
  p_choice int default null,
  p_number numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  g public.quiz_games := private.quiz_load(p_game);
  v_action text := private.quiz_action(g, v_me);
  v_team uuid := private.quiz_team_of(g, v_me);
  v_other uuid;
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_a public.quiz_answers;
  v_choice smallint;
  v_number numeric;
  v_points smallint;
  v_shown timestamptz;
  v_results jsonb;
begin
  if v_action not in ('propose', 'decide') then
    raise exception 'Du bist gerade nicht dran' using errcode = 'P0001';
  end if;
  select * into v_round from public.quiz_rounds where game_id = g.id and round = g.round;
  select * into v_q from public.quiz_questions where id = v_round.question_ids[p_q_index + 1];

  if g.kind = 'estimate' then
    if p_number is not null and (p_number < 0 or p_number > 1e12) then
      raise exception 'Ungültige Zahl' using errcode = '22023';
    end if;
  elsif coalesce(p_choice, -1) not between -1 and cardinality(v_q.answers) - 1 then
    raise exception 'Ungültige Antwort' using errcode = '22023';
  end if;

  select * into v_a from public.quiz_answers
   where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index
   for update;
  v_shown := case when v_action = 'propose' then v_a.proposal_shown_at else v_a.final_shown_at end;
  if v_shown is null then
    raise exception 'Frage wurde noch nicht angezeigt' using errcode = 'P0001';
  end if;
  if (v_action = 'propose' and v_a.proposal is not null)
     or (v_action = 'decide' and v_a.final is not null) then
    raise exception 'Schon beantwortet' using errcode = 'P0001';
  end if;

  -- Zu spät (30 s + 3 s Kulanz) zählt als keine Antwort.
  if now() > v_shown + interval '33 seconds' then
    v_choice := -1;
    v_number := null;
  else
    v_choice := coalesce(p_choice, -1);
    v_number := p_number;
  end if;

  if v_action = 'propose' then
    update public.quiz_answers
       set proposal = case when g.kind = 'estimate'
                           then case when v_number is null then -1 else 0 end
                           else v_choice end,
           proposal_num = v_number,
           proposed_at = now()
     where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index;
    update public.quiz_games set updated_at = now() where id = g.id;
    return jsonb_build_object('done', p_q_index = 2);
  end if;

  -- Entscheidung
  if g.kind = 'estimate' then
    v_number := coalesce(v_number, v_a.proposal_num); -- ohne eigene Zahl gilt der Vorschlag
    v_choice := case when v_number is null then -1 else 0 end;
    v_points := private.quiz_estimate_points(v_number, v_q.number_answer, v_q.unit);
  elsif g.kind = 'soulmate' then
    -- Geraten wird ohne Vorschlag; keine Antwort = kein Punkt.
    v_points := case when v_choice >= 0 and v_choice = v_a.proposal then 1 else 0 end;
  else
    if v_choice = -1 then
      v_choice := v_a.proposal; -- ohne eigene Antwort gilt der Vorschlag
    end if;
    v_points := case when v_choice = private.quiz_correct_index(g.id, v_q.id) then 1 else 0 end;
  end if;

  update public.quiz_answers
     set final = v_choice,
         final_num = v_number,
         points = v_points,
         correct = v_points > 0,
         decided_at = now()
   where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index;

  if p_q_index < 2 then
    update public.quiz_games set updated_at = now() where id = g.id;
    return jsonb_build_object('done', false);
  end if;

  -- Runde fürs Team beendet → Ergebnis zeigen und weiterziehen.
  select jsonb_agg(jsonb_build_object(
           'q_index', a.q_index,
           'proposal', a.proposal,
           'final', a.final,
           'proposal_number', a.proposal_num,
           'final_number', a.final_num,
           'correct', a.correct,
           'points', a.points,
           'correct_index', private.quiz_correct_index(g.id, q.id),
           'number_answer', q.number_answer,
           'unit', q.unit
         ) order by a.q_index)
    into v_results
    from public.quiz_answers a
    join public.quiz_questions q on q.id = v_round.question_ids[a.q_index + 1]
   where a.game_id = g.id and a.round = g.round and a.team = v_team;

  v_other := case when v_team = g.team_a then g.team_b else g.team_a end;

  update public.quiz_games
     set score_a = (select coalesce(sum(points), 0) from public.quiz_answers
                     where game_id = g.id and team = g.team_a),
         score_b = (select coalesce(sum(points), 0) from public.quiz_answers
                     where game_id = g.id and team = g.team_b),
         updated_at = now()
   where id = g.id
   returning * into g;

  if v_team = private.quiz_chooser(g, g.round) or private.quiz_chooser(g, g.round) is null then
    -- Erstes Team der Runde: jetzt ist das andere dran (falls schon da).
    update public.quiz_games set turn = v_other where id = g.id;
  elsif g.round = 6 then
    update public.quiz_games
       set status = 'finished',
           turn = null,
           finished_at = now(),
           winner = case when score_a > score_b then team_a
                         when score_b > score_a then team_b end
     where id = g.id
     returning * into g;
    perform public.award_xp(u, 'game_finished', 'quiz:' || g.id)
       from (select unnest(array[m.user_a, m.user_b]) as u
               from public.matches m where m.id in (g.team_a, g.team_b)) as players;
  else
    -- Zweites Team: nächste Runde, dieses Team wählt die Kategorie.
    update public.quiz_games set round = round + 1, turn = v_team
     where id = g.id
     returning * into g;
    perform private.quiz_open_round(g, g.round);
  end if;

  return jsonb_build_object('done', true, 'results', v_results);
end;
$$;

-- -----------------------------------------------------------------------------
-- Lesen (jetzt mit Spielart und Punkten)
-- -----------------------------------------------------------------------------
create or replace function public.quiz_my_games()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_json order by sort_key desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
             'id', g.id,
             'kind', g.kind,
             'status', g.status,
             'round', g.round,
             'action', private.quiz_action(g, (select auth.uid())),
             'invite_code', case when private.quiz_team_of(g, (select auth.uid())) = g.team_a
                                 then g.invite_code end,
             'my_team', private.quiz_team_json(private.quiz_team_of(g, (select auth.uid())), (select auth.uid())),
             'opponent', case when g.team_b is not null then private.quiz_team_json(
                case when private.quiz_team_of(g, (select auth.uid())) = g.team_a
                     then g.team_b else g.team_a end, (select auth.uid())) end,
             'my_score', case when private.quiz_team_of(g, (select auth.uid())) = g.team_a
                              then g.score_a else g.score_b end,
             'opponent_score', private.quiz_visible_opponent_score(g, (select auth.uid())),
             'won', case when g.winner is null then null
                         else g.winner = private.quiz_team_of(g, (select auth.uid())) end,
             'updated_at', g.updated_at
           ) as row_json,
           g.updated_at as sort_key
    from public.quiz_games g
    join public.matches m on m.id in (g.team_a, g.team_b)
    where (select auth.uid()) in (m.user_a, m.user_b)
      and (g.status in ('searching', 'active') or g.updated_at > now() - interval '14 days')
  ) as rows;
$$;

create or replace function public.quiz_game_state(p_game uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  g public.quiz_games;
  v_team uuid;
  v_opp uuid;
  v_rounds jsonb;
begin
  select * into g from public.quiz_games where id = p_game;
  v_team := private.quiz_team_of(g, v_me);
  if not found or v_team is null then
    raise exception 'Spiel nicht gefunden' using errcode = 'P0002';
  end if;
  v_opp := case when v_team = g.team_a then g.team_b else g.team_a end;

  select coalesce(jsonb_agg(jsonb_build_object(
           'round', r.round,
           'chooser_is_me', r.chooser = v_team,
           'category', r.category,
           'options', case when r.round = g.round and r.category is null
                           and private.quiz_action(g, v_me) = 'choose'
                           then to_jsonb(r.options) end,
           'my_proposer', (select display_name from public.profiles
                            where id = private.quiz_proposer(v_team, r.round)),
           'my_done', private.quiz_team_done(g.id, r.round, v_team),
           'my_proposed', (select count(*) from public.quiz_answers a
                            where a.game_id = g.id and a.round = r.round
                              and a.team = v_team and a.proposal is not null),
           'my_decided', (select count(*) from public.quiz_answers a
                           where a.game_id = g.id and a.round = r.round
                             and a.team = v_team and a.final is not null),
           'opponent_done', v_opp is not null and private.quiz_team_done(g.id, r.round, v_opp),
           'questions', (
             select coalesce(jsonb_agg(item order by idx), '[]'::jsonb)
             from (
               select i as idx, jsonb_build_object(
                 'mine', (select jsonb_build_object(
                              'correct', a.correct, 'points', a.points,
                              'final', a.final, 'proposal', a.proposal,
                              'final_number', a.final_num, 'proposal_number', a.proposal_num)
                            from public.quiz_answers a
                           where a.game_id = g.id and a.round = r.round and a.team = v_team
                             and a.q_index = i and a.final is not null),
                 -- Beim Gegner nur Treffer/Punkte; was er über sich selbst
                 -- geantwortet hat (Seelenverwandt), bleibt privat.
                 'opponent', case when reveal then (
                     select jsonb_build_object(
                              'correct', a.correct, 'points', a.points,
                              'final', case when g.kind in ('quiz', 'emoji') then a.final end,
                              'final_number', a.final_num)
                       from public.quiz_answers a
                      where a.game_id = g.id and a.round = r.round and a.team = v_opp
                        and a.q_index = i and a.final is not null) end,
                 -- Frage & Lösung erst, wenn das eigene Team die Runde fertig hat.
                 'review', case when private.quiz_team_done(g.id, r.round, v_team) then (
                     select jsonb_build_object(
                       'question', q.question,
                       'answers', private.quiz_presented(g.id, q, g.kind),
                       'correct_index', private.quiz_correct_index(g.id, q.id),
                       'number_answer', q.number_answer,
                       'unit', q.unit)
                     from public.quiz_questions q
                     where q.id = r.question_ids[i + 1]) end
               ) as item
               from generate_series(0, 2) as i,
                    lateral (select g.status in ('finished', 'abandoned')
                                    or private.quiz_team_done(g.id, r.round, v_team) as reveal) as rv
               where r.category is not null
             ) as items
           )
         ) order by r.round), '[]'::jsonb)
    into v_rounds
    from public.quiz_rounds r
   where r.game_id = g.id;

  return jsonb_build_object(
    'id', g.id,
    'kind', g.kind,
    'status', g.status,
    'round', g.round,
    'action', private.quiz_action(g, v_me),
    'invite_code', case when v_team = g.team_a then g.invite_code end,
    'my_team', private.quiz_team_json(v_team, v_me),
    'opponent', case when v_opp is not null then private.quiz_team_json(v_opp, v_me) end,
    'my_score', case when v_team = g.team_a then g.score_a else g.score_b end,
    'opponent_score', private.quiz_visible_opponent_score(g, v_me),
    'won', case when g.winner is null then null else g.winner = v_team end,
    'rounds', v_rounds,
    'updated_at', g.updated_at
  );
end;
$$;

revoke execute on function
  public.quiz_start(uuid, text, text), public.quiz_answer(uuid, int, int, numeric)
  from public, anon;
grant execute on function
  public.quiz_start(uuid, text, text), public.quiz_answer(uuid, int, int, numeric)
  to authenticated;
