-- =============================================================================
-- Quizduell 2 gegen 2
--
-- Ein Team ist ein Match (zwei Personen). Zwei Teams spielen 6 Runden à
-- 3 Fragen. Abwechselnd wählt ein Team die Kategorie (aus 3 Vorschlägen),
-- spielt die Fragen, danach spielt das andere Team dieselben Fragen.
--
-- Teamentscheidung ohne Echtzeit: Pro Runde ist ein Teammitglied
-- „Vorschlag“ (wählt ggf. die Kategorie und schlägt Antworten vor), das
-- andere „Entscheidung“ (sieht die Vorschläge und legt die Antwort fest).
-- Die Rollen wechseln jede Runde.
--
-- Fairness: Lösungen verlassen den Server erst, wenn das eigene Team die Runde
-- beendet hat. Pro Frage 30 Sekunden ab dem Anzeigen (vom Server gemessen,
-- 3 s Kulanz für Netzwerk); zu spät = keine Antwort.
--
-- Werte, die der Client kennt (MÜSSEN synchron bleiben, siehe
-- lib/features/quiz/quiz_rules.dart): 6 Runden, 3 Fragen, 3 Kategorie-
-- Vorschläge, 30 s pro Frage, Aktionen der Funktion private.quiz_action.
-- =============================================================================

create table public.quiz_categories (
  key   text primary key check (key ~ '^[a-z_]{2,30}$'),
  emoji text not null,
  label text not null
);
alter table public.quiz_categories enable row level security;
revoke all on public.quiz_categories from anon, authenticated;
grant select on public.quiz_categories to authenticated;
create policy "Kategorien lesen" on public.quiz_categories
  for select to authenticated using (true);

-- answers[1] ist immer die richtige Antwort. Gezeigt werden sie gemischt.
-- Kein Zugriff für Clients – nur über die Spiel-RPCs.
create table public.quiz_questions (
  id       serial primary key,
  category text not null references public.quiz_categories (key),
  question text not null,
  answers  text[] not null check (cardinality(answers) = 4)
);
create index quiz_questions_category_idx on public.quiz_questions (category);
alter table public.quiz_questions enable row level security;
revoke all on public.quiz_questions from anon, authenticated;

create type public.quiz_status as enum ('searching', 'active', 'finished', 'abandoned');

create table public.quiz_games (
  id           uuid primary key default gen_random_uuid(),
  team_a       uuid not null references public.matches (id) on delete cascade,
  team_b       uuid references public.matches (id) on delete cascade,
  status       public.quiz_status not null default 'searching',
  -- null = Zufallsgegner, sonst Einladung per Code
  invite_code  text unique check (invite_code ~ '^[A-Z2-9]{6}$'),
  round        smallint not null default 1 check (round between 1 and 6),
  -- Team (Match-ID), das gerade dran ist; null = wartet auf Gegner / Ende
  turn         uuid,
  score_a      smallint not null default 0,
  score_b      smallint not null default 0,
  winner       uuid,
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  finished_at  timestamptz,
  check (team_b is null or team_b <> team_a)
);
create index quiz_games_team_a_idx on public.quiz_games (team_a);
create index quiz_games_team_b_idx on public.quiz_games (team_b);
create index quiz_games_search_idx on public.quiz_games (created_at)
  where status = 'searching' and team_b is null;

create table public.quiz_rounds (
  game_id      uuid not null references public.quiz_games (id) on delete cascade,
  round        smallint not null check (round between 1 and 6),
  chooser      uuid not null,
  options      text[] not null,
  category     text references public.quiz_categories (key),
  question_ids int[],
  primary key (game_id, round)
);

create table public.quiz_answers (
  game_id          uuid not null,
  round            smallint not null,
  team             uuid not null,
  q_index          smallint not null check (q_index between 0 and 2),
  proposer_id      uuid,
  decider_id       uuid,
  -- Index in der gezeigten Reihenfolge, -1 = keine Antwort (Zeit abgelaufen)
  proposal         smallint check (proposal between -1 and 3),
  proposal_shown_at timestamptz,
  proposed_at      timestamptz,
  final            smallint check (final between -1 and 3),
  final_shown_at   timestamptz,
  decided_at       timestamptz,
  correct          boolean,
  primary key (game_id, round, team, q_index),
  foreign key (game_id, round) references public.quiz_rounds (game_id, round) on delete cascade
);

-- Spielzustand nur über RPCs; Clients dürfen die Spieltabelle lesen, um per
-- Realtime von Änderungen zu erfahren (dann laden sie per RPC neu). Realtime
-- braucht dafür Leserechte auf die ganze Zeile; quiz_games enthält keine
-- Fragen oder Lösungen. Runden und Antworten bleiben komplett gesperrt.
alter table public.quiz_games enable row level security;
alter table public.quiz_rounds enable row level security;
alter table public.quiz_answers enable row level security;
revoke all on public.quiz_games, public.quiz_rounds, public.quiz_answers from anon, authenticated;
grant select on public.quiz_games to authenticated;
create policy "Eigene Quizspiele sehen" on public.quiz_games
  for select to authenticated
  using (private.is_match_member(team_a) or (team_b is not null and private.is_match_member(team_b)));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'quiz_games'
     ) then
    alter publication supabase_realtime add table public.quiz_games;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------

-- Gezeigte Reihenfolge der Antworten: Positionen 1..4 aus `answers`,
-- je Spiel und Frage fest gemischt.
create function private.quiz_order(p_game uuid, p_question int)
returns int[]
language sql
immutable
set search_path = ''
as $$
  select array_agg(i order by md5(p_game::text || ':' || p_question || ':' || i))
  from generate_series(1, 4) as i;
$$;

-- Index (0..3) der richtigen Antwort in der gezeigten Reihenfolge.
create function private.quiz_correct_index(p_game uuid, p_question int)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select (array_position(private.quiz_order(p_game, p_question), 1) - 1)::smallint;
$$;

-- Wer im Team in Runde r vorschlägt: ungerade Runden user_a, gerade user_b.
create function private.quiz_proposer(p_team uuid, p_round int)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_round % 2 = 1 then m.user_a else m.user_b end
  from public.matches m where m.id = p_team;
$$;

create function private.quiz_decider(p_team uuid, p_round int)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_round % 2 = 1 then m.user_b else m.user_a end
  from public.matches m where m.id = p_team;
$$;

-- Kategorie-Team einer Runde: ungerade Runden Team A, gerade Team B.
create function private.quiz_chooser(g public.quiz_games, p_round int)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case when p_round % 2 = 1 then g.team_a else g.team_b end;
$$;

-- Team des Nutzers in diesem Spiel (oder null).
create function private.quiz_team_of(g public.quiz_games, p_user uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id from public.matches m
  where m.id in (g.team_a, g.team_b) and p_user in (m.user_a, m.user_b)
  limit 1;
$$;

-- Hat das Team die Runde fertig (alle 3 Entscheidungen)?
create function private.quiz_team_done(p_game uuid, p_round int, p_team uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) = 3 from public.quiz_answers
  where game_id = p_game and round = p_round and team = p_team and final is not null;
$$;

-- Was soll dieser Nutzer jetzt tun?
--   searching      – Team wartet auf Gegner (hat seinen Teil gespielt)
--   choose         – Kategorie wählen (dann Vorschläge machen)
--   propose        – Antworten vorschlagen
--   decide         – Vorschläge ansehen und entscheiden
--   wait_partner   – Partner:in ist dran
--   wait_opponent  – das andere Team ist dran
--   finished / abandoned
create function private.quiz_action(g public.quiz_games, p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_team uuid := private.quiz_team_of(g, p_user);
  v_round public.quiz_rounds;
  v_open_proposals int;
begin
  if g.status in ('finished', 'abandoned') then
    return g.status::text;
  end if;
  if v_team is null then
    return null;
  end if;
  if g.turn is null then
    return 'searching';
  end if;
  if g.turn <> v_team then
    return case when g.team_b is null then 'searching' else 'wait_opponent' end;
  end if;

  select * into v_round from public.quiz_rounds where game_id = g.id and round = g.round;
  if v_round.category is null then
    return case when private.quiz_proposer(v_team, g.round) = p_user
                then 'choose' else 'wait_partner' end;
  end if;

  select 3 - count(*) into v_open_proposals from public.quiz_answers
   where game_id = g.id and round = g.round and team = v_team and proposal is not null;
  if v_open_proposals > 0 then
    return case when private.quiz_proposer(v_team, g.round) = p_user
                then 'propose' else 'wait_partner' end;
  end if;
  return case when private.quiz_decider(v_team, g.round) = p_user
              then 'decide' else 'wait_partner' end;
end;
$$;

-- Neue Runde mit drei zufälligen Kategorien (möglichst noch nicht gespielt).
create function private.quiz_open_round(g public.quiz_games, p_round int)
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
           order by (c.key in (select category from public.quiz_rounds
                               where game_id = g.id and category is not null)),
                    random()
           limit 3
         )
  on conflict do nothing;
end;
$$;

create function private.quiz_load(p_game uuid)
returns public.quiz_games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.quiz_games;
begin
  select * into g from public.quiz_games where id = p_game for update;
  if not found or private.quiz_team_of(g, (select auth.uid())) is null then
    raise exception 'Spiel nicht gefunden' using errcode = 'P0002';
  end if;
  return g;
end;
$$;

-- Sind zwei Teams als Gegner erlaubt? (keine gemeinsame Person, keine Blockade,
-- beide Matches aktiv)
create function private.quiz_teams_compatible(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.matches a, public.matches b
    where a.id = p_a and b.id = p_b
      and a.unmatched_at is null and b.unmatched_at is null
      and a.user_a not in (b.user_a, b.user_b)
      and a.user_b not in (b.user_a, b.user_b)
      and not private.is_blocked_between(a.user_a, b.user_a)
      and not private.is_blocked_between(a.user_a, b.user_b)
      and not private.is_blocked_between(a.user_b, b.user_a)
      and not private.is_blocked_between(a.user_b, b.user_b)
  );
$$;

-- -----------------------------------------------------------------------------
-- Spiel starten / beitreten
-- -----------------------------------------------------------------------------

-- p_mode: 'random' (Zufallsgegner) oder 'invite' (Code für befreundetes Paar)
create function public.quiz_start(p_match uuid, p_mode text default 'random')
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

  select count(*) into v_open from public.quiz_games
   where p_match in (team_a, team_b) and status in ('searching', 'active');
  if v_open >= 5 then
    raise exception 'Höchstens 5 laufende Quizduelle pro Match' using errcode = 'P0001';
  end if;

  if p_mode = 'random' then
    -- Schon eine eigene Suche offen? Dann die zurückgeben.
    select * into g from public.quiz_games
     where team_a = p_match and team_b is null and invite_code is null
       and status = 'searching'
     limit 1;
    if found then
      return g.id;
    end if;

    -- Wartendes Team suchen.
    select * into g from public.quiz_games q
     where q.status = 'searching' and q.team_b is null and q.invite_code is null
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

  insert into public.quiz_games (team_a, invite_code, turn, created_by)
  values (p_match, v_code, p_match, v_me)
  returning * into g;
  perform private.quiz_open_round(g, 1);
  return g.id;
end;
$$;

create function public.quiz_join(p_match uuid, p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.quiz_games;
begin
  if not private.is_match_active(p_match) then
    raise exception 'Kein aktives Match' using errcode = '42501';
  end if;
  select * into g from public.quiz_games
   where invite_code = upper(btrim(p_code)) and status = 'searching' and team_b is null
   for update;
  if not found then
    raise exception 'Code ungültig oder schon benutzt' using errcode = 'P0002';
  end if;
  if g.team_a = p_match then
    raise exception 'Das ist euer eigenes Spiel' using errcode = 'P0001';
  end if;
  if not private.quiz_teams_compatible(g.team_a, p_match) then
    raise exception 'Mit diesem Team geht es leider nicht' using errcode = 'P0001';
  end if;
  update public.quiz_games
     set team_b = p_match,
         status = 'active',
         turn = case when private.quiz_team_done(g.id, 1, g.team_a)
                     then p_match else g.team_a end,
         updated_at = now()
   where id = g.id;
  return g.id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Spielen
-- -----------------------------------------------------------------------------
create function public.quiz_choose_category(p_game uuid, p_category text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  g public.quiz_games := private.quiz_load(p_game);
  v_round public.quiz_rounds;
  v_ids int[];
begin
  if private.quiz_action(g, v_me) <> 'choose' then
    raise exception 'Du bist gerade nicht mit der Kategorie dran' using errcode = 'P0001';
  end if;
  select * into v_round from public.quiz_rounds where game_id = g.id and round = g.round;
  if not (p_category = any (v_round.options)) then
    raise exception 'Kategorie steht nicht zur Wahl' using errcode = '22023';
  end if;

  select array_agg(id) into v_ids from (
    select q.id from public.quiz_questions q
     where q.category = p_category
       and not exists (
         select 1 from public.quiz_rounds r
          where r.game_id = g.id and q.id = any (r.question_ids))
     order by random()
     limit 3
  ) as picked;
  if cardinality(v_ids) is distinct from 3 then
    raise exception 'Zu wenige Fragen in dieser Kategorie' using errcode = 'P0001';
  end if;

  update public.quiz_rounds
     set category = p_category, question_ids = v_ids
   where game_id = g.id and round = g.round;
  update public.quiz_games set updated_at = now() where id = g.id;
end;
$$;

-- Zeigt die nächste Frage (startet die 30 Sekunden). Ein erneuter Aufruf
-- (z. B. nach Neuladen) startet die Zeit NICHT neu.
create function public.quiz_show_question(p_game uuid, p_q_index int)
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
  v_order int[];
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
  v_order := private.quiz_order(g.id, v_q.id);

  return jsonb_build_object(
    'round', g.round,
    'q_index', p_q_index,
    'role', v_action,
    'category', v_round.category,
    'question', v_q.question,
    'answers', jsonb_build_array(
      v_q.answers[v_order[1]], v_q.answers[v_order[2]],
      v_q.answers[v_order[3]], v_q.answers[v_order[4]]),
    'seconds_left', greatest(0, 30 - extract(epoch from (now() - v_shown)))::int,
    'proposal', case when v_action = 'decide' then v_a.proposal end
  );
end;
$$;

-- Antwort (Vorschlag oder Entscheidung). p_choice: 0..3, -1 = keine.
create function public.quiz_answer(p_game uuid, p_q_index int, p_choice int)
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
  v_a public.quiz_answers;
  v_choice smallint;
  v_shown timestamptz;
  v_results jsonb;
begin
  if v_action not in ('propose', 'decide') then
    raise exception 'Du bist gerade nicht dran' using errcode = 'P0001';
  end if;
  if p_choice not between -1 and 3 then
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
  v_choice := case when now() > v_shown + interval '33 seconds' then -1 else p_choice end;
  select * into v_round from public.quiz_rounds where game_id = g.id and round = g.round;

  if v_action = 'propose' then
    update public.quiz_answers set proposal = v_choice, proposed_at = now()
     where game_id = g.id and round = g.round and team = v_team and q_index = p_q_index;
    update public.quiz_games set updated_at = now() where id = g.id;
    return jsonb_build_object('done', p_q_index = 2);
  end if;

  -- Entscheidung: ohne eigene Antwort gilt der Vorschlag.
  if v_choice = -1 then
    v_choice := v_a.proposal;
  end if;
  update public.quiz_answers
     set final = v_choice,
         decided_at = now(),
         correct = v_choice = private.quiz_correct_index(g.id, v_round.question_ids[p_q_index + 1])
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
           'correct', a.correct,
           'correct_index', private.quiz_correct_index(g.id, v_round.question_ids[a.q_index + 1])
         ) order by a.q_index)
    into v_results
    from public.quiz_answers a
   where a.game_id = g.id and a.round = g.round and a.team = v_team;

  v_other := case when v_team = g.team_a then g.team_b else g.team_a end;

  update public.quiz_games
     set score_a = (select count(*) from public.quiz_answers
                     where game_id = g.id and team = g.team_a and correct),
         score_b = (select count(*) from public.quiz_answers
                     where game_id = g.id and team = g.team_b and correct),
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

create function public.quiz_give_up(p_game uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.quiz_games := private.quiz_load(p_game);
  v_team uuid := private.quiz_team_of(g, (select auth.uid()));
begin
  if g.status not in ('searching', 'active') then
    return;
  end if;
  update public.quiz_games
     set status = 'abandoned',
         turn = null,
         finished_at = now(),
         winner = case when v_team = team_a then team_b else team_a end,
         updated_at = now()
   where id = g.id;
end;
$$;

-- Endet ein Match (Entmatchen/Blockieren), enden auch seine Quizduelle.
create function private.quiz_abandon_on_unmatch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.unmatched_at is not null and old.unmatched_at is null then
    update public.quiz_games
       set status = 'abandoned',
           turn = null,
           finished_at = now(),
           winner = case when team_a = new.id then team_b else team_a end,
           updated_at = now()
     where new.id in (team_a, team_b) and status in ('searching', 'active');
  end if;
  return new;
end;
$$;
create trigger matches_quiz_abandon
  after update of unmatched_at on public.matches
  for each row execute function private.quiz_abandon_on_unmatch();

-- -----------------------------------------------------------------------------
-- Lesen
-- -----------------------------------------------------------------------------

-- Teamnamen: nur Vornamen, keine weiteren Profildaten.
create function private.quiz_team_json(p_team uuid, p_me uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id,
    'players', jsonb_agg(jsonb_build_object(
      'id', p.id,
      'name', p.display_name,
      'is_me', p.id = p_me
    ) order by (p.id = p_me) desc, p.display_name)
  )
  from public.matches m
  join public.profiles p on p.id in (m.user_a, m.user_b)
  where m.id = p_team
  group by m.id;
$$;

-- Punkte des Gegners nur für Runden, die man selbst auch gespielt hat.
create function private.quiz_visible_opponent_score(g public.quiz_games, p_me uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.quiz_answers o
  where o.game_id = g.id
    and o.team <> private.quiz_team_of(g, p_me)
    and o.correct
    and (g.status in ('finished', 'abandoned')
         or private.quiz_team_done(g.id, o.round, private.quiz_team_of(g, p_me)));
$$;

create function public.quiz_my_games()
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

create function public.quiz_game_state(p_game uuid)
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
           -- Fortschritt im eigenen Team: so viele Vorschläge/Entscheidungen
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
                 'mine', (select jsonb_build_object('correct', a.correct,
                                                    'final', a.final, 'proposal', a.proposal)
                            from public.quiz_answers a
                           where a.game_id = g.id and a.round = r.round and a.team = v_team
                             and a.q_index = i and a.final is not null),
                 'opponent', case when reveal then (
                     select jsonb_build_object('correct', a.correct, 'final', a.final)
                       from public.quiz_answers a
                      where a.game_id = g.id and a.round = r.round and a.team = v_opp
                        and a.q_index = i and a.final is not null) end,
                 -- Frage & Lösung erst, wenn das eigene Team die Runde fertig hat.
                 'review', case when private.quiz_team_done(g.id, r.round, v_team) then (
                     select jsonb_build_object(
                       'question', q.question,
                       'answers', jsonb_build_array(
                         q.answers[o[1]], q.answers[o[2]], q.answers[o[3]], q.answers[o[4]]),
                       'correct_index', private.quiz_correct_index(g.id, q.id))
                     from public.quiz_questions q,
                          lateral (select private.quiz_order(g.id, q.id) as o) as ord
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

-- Rechte: nur angemeldete Nutzer:innen, nur über diese Funktionen.
revoke execute on function
  public.quiz_start(uuid, text), public.quiz_join(uuid, text),
  public.quiz_choose_category(uuid, text), public.quiz_show_question(uuid, int),
  public.quiz_answer(uuid, int, int), public.quiz_give_up(uuid),
  public.quiz_my_games(), public.quiz_game_state(uuid)
  from public, anon;
grant execute on function
  public.quiz_start(uuid, text), public.quiz_join(uuid, text),
  public.quiz_choose_category(uuid, text), public.quiz_show_question(uuid, int),
  public.quiz_answer(uuid, int, int), public.quiz_give_up(uuid),
  public.quiz_my_games(), public.quiz_game_state(uuid)
  to authenticated;
