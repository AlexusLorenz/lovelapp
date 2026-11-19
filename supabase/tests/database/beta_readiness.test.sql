-- pgTAP: Push-Auslöser, Inaktivität, Moderation
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', 'b2@test.local'),
  ('00000000-0000-0000-0000-0000000000ad', 'admin@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000a1', 'Anna', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000a2', 'Arne', current_date - interval '30 years', 'man'),
  ('00000000-0000-0000-0000-0000000000b1', 'Bea', current_date - interval '30 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000b2', 'Ben', current_date - interval '30 years', 'man'),
  ('00000000-0000-0000-0000-0000000000ad', 'Moni', current_date - interval '30 years', 'woman');
insert into public.admins (user_id) values ('00000000-0000-0000-0000-0000000000ad');

-- Alle außer Ben haben Push aktiviert.
insert into public.push_subscriptions (user_id, endpoint, p256dh, auth) values
  ('00000000-0000-0000-0000-0000000000a1', 'https://fcm.googleapis.com/fcm/send/a1', repeat('k', 40), repeat('s', 16)),
  ('00000000-0000-0000-0000-0000000000a2', 'https://fcm.googleapis.com/fcm/send/a2', repeat('k', 40), repeat('s', 16)),
  ('00000000-0000-0000-0000-0000000000b1', 'https://updates.push.services.mozilla.com/wpush/v2/b1', repeat('k', 40), repeat('s', 16));

create function public.t_outbox(p_user uuid, p_kind text)
returns int language sql security definer set search_path = '' as $$
  select count(*)::int from private.push_outbox where user_id = p_user and kind = p_kind;
$$;
create function public.t_last_body(p_user uuid)
returns text language sql security definer set search_path = '' as $$
  select body from private.push_outbox where user_id = p_user order by id desc limit 1;
$$;
-- Spielt für p_user, was ansteht (richtig).
create function public.t_act(p_user uuid, p_game uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare st jsonb; a text; first_action text; i int; q int; opts jsonb;
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
      perform public.quiz_answer(p_game, i, private.quiz_correct_index(p_game, q));
    end loop;
  end if;
  return first_action;
end $$;
grant execute on function public.t_outbox(uuid, text), public.t_last_body(uuid),
  public.t_act(uuid, uuid) to authenticated;

create temp table t (k text primary key, v uuid);
grant all on t to authenticated;

-- ---------------------------------------------------------------------------
-- Push-Abos
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';
select throws_ok($$ select public.push_subscribe('https://evil.example.com/x', repeat('k', 40), repeat('s', 16)) $$,
  '23514', null, 'Nur bekannte Push-Dienste');
select lives_ok($$ select public.push_subscribe('https://web.push.apple.com/b2tmp', repeat('k', 40), repeat('s', 16)) $$,
  'Abo anlegen');
select lives_ok($$ select public.push_unsubscribe('https://web.push.apple.com/b2tmp') $$, 'Abo löschen');
select throws_ok($$ select * from public.push_subscriptions $$, '42501', null, 'Abos nicht direkt lesbar');
select throws_ok($$ select public.push_claim() $$, '42501', null, 'Versand-RPC nur für den Server');
select throws_ok($$ select public.push_get_config() $$, '42501', null, 'Schlüssel nur für den Server');

-- ---------------------------------------------------------------------------
-- Match und Nachrichten
-- ---------------------------------------------------------------------------
reset role;
-- Match entsteht durch Annas Like → nur Arne bekommt Push.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
insert into public.matches (id, user_a, user_b) values
  ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a1', 'match'), 0, 'Wer das Match auslöst, bekommt keinen Push');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a2', 'match'), 1, 'Gegenüber bekommt Match-Push');

insert into public.messages (match_id, sender_id, body) values
  ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-0000000000a1', 'Hallo, geheim!'),
  ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-0000000000a1', 'Noch was');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a2', 'message'), 1, 'Nachrichten-Push gebündelt');
select is(public.t_last_body('00000000-0000-0000-0000-0000000000a2'), 'Anna hat dir geschrieben.',
  'Push ohne Nachrichtentext');

set local request.jwt.claim.sub = '';
insert into public.matches (id, user_a, user_b) values
  ('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b2');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000b2', 'match'), 0, 'Ohne Abo kein Push');

-- ---------------------------------------------------------------------------
-- Spielzüge
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
insert into t values ('g', public.quiz_start('00000000-0000-0000-0000-00000000aaaa'));
select is(public.t_act('00000000-0000-0000-0000-0000000000a1', (select v from t where k = 'g')), 'choose', 'Anna spielt vor');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a2', 'quiz_turn'), 1, 'Arne erfährt: du entscheidest');
select is(public.t_last_body('00000000-0000-0000-0000-0000000000a2'), 'Anna hat vorgelegt – jetzt entscheidest du.',
  'Text nennt die Partnerin');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a1', 'quiz_turn'), 0, 'Anna selbst bekommt nichts');
select is(public.t_act('00000000-0000-0000-0000-0000000000a2', (select v from t where k = 'g')), 'decide', 'Arne entscheidet');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select is(public.quiz_start('00000000-0000-0000-0000-00000000bbbb'), (select v from t where k = 'g'), 'Team B tritt bei');
select is(public.t_outbox('00000000-0000-0000-0000-0000000000a1', 'quiz_turn'), 0, 'Team A wartet – kein Push');

-- ---------------------------------------------------------------------------
-- Inaktivität
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claim.sub = '';  -- pg_cron läuft ohne Nutzer
update public.quiz_games set updated_at = now() - interval '50 hours' where id = (select v from t where k = 'g');
select private.quiz_inactivity();
select is(public.t_outbox('00000000-0000-0000-0000-0000000000b1', 'quiz_reminder'), 1, 'Erinnerung nach 48 h');
select private.quiz_inactivity();
select is(public.t_outbox('00000000-0000-0000-0000-0000000000b1', 'quiz_reminder'), 1, 'Nur einmal erinnern');
select is((select status::text from public.quiz_games where id = (select v from t where k = 'g')), 'active',
  'Nach 50 h noch aktiv');

update public.quiz_games set updated_at = now() - interval '73 hours' where id = (select v from t where k = 'g');
select private.quiz_inactivity();
select is((select status::text || ':' || (forfeit_team = '00000000-0000-0000-0000-00000000bbbb')::text
             || ':' || (winner = '00000000-0000-0000-0000-00000000aaaa')::text
             from public.quiz_games where id = (select v from t where k = 'g')),
  'abandoned:true:true', 'Nach 72 h verliert das Team am Zug');
select is((select count(*)::int from public.xp_events
            where reason = 'game_finished' and ref_id = 'quiz:' || (select v from t where k = 'g')),
  2, 'Gewinnerteam bekommt die XP');
select is(public.t_last_body('00000000-0000-0000-0000-0000000000a1'), 'Das andere Team hat aufgegeben – ihr gewinnt!',
  'Gewinner erfahren es');
select is(public.t_last_body('00000000-0000-0000-0000-0000000000b1'), 'Euer Spiel ist abgelaufen und zählt als verloren.',
  'Verlierer erfahren es');

-- Drei Aufgaben → keine Zufallsgegner mehr, Einladung geht.
insert into public.quiz_games (team_a, team_b, status, forfeit_team, finished_at)
select '00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-00000000bbbb', 'abandoned',
       '00000000-0000-0000-0000-00000000bbbb', now()
  from generate_series(1, 2);
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';
select throws_ok($$ select public.quiz_start('00000000-0000-0000-0000-00000000bbbb', 'random', 'estimate') $$,
  'P0001', null, 'Aussteiger bekommen keine Zufallsgegner');
select lives_ok($$ select public.quiz_start('00000000-0000-0000-0000-00000000bbbb', 'invite', 'estimate') $$,
  'Einladungen gehen weiter');

-- Aufgeben mit Gegner zählt als Aufgabe.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
insert into t values ('g2', public.quiz_start('00000000-0000-0000-0000-00000000aaaa', 'invite', 'emoji'));
reset role;
update public.quiz_games set team_b = '00000000-0000-0000-0000-00000000bbbb', status = 'active'
 where id = (select v from t where k = 'g2');
set local role authenticated;
select public.quiz_give_up((select v from t where k = 'g2'));
reset role;
select is((select forfeit_team from public.quiz_games where id = (select v from t where k = 'g2')),
  '00000000-0000-0000-0000-00000000aaaa'::uuid, 'Aufgeben wird als Aufgabe gezählt');

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------
insert into public.reports (reporter_id, reported_id, reason, details) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2', 'harassment', 'Beleidigend');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select is(public.am_i_admin(), false, 'Anna ist keine Admin');
select throws_ok($$ select public.mod_reports() $$, '42501', null, 'Meldungen nur für Admins');
select throws_ok($$ select public.mod_ban_user('00000000-0000-0000-0000-0000000000b2', 'x') $$,
  '42501', null, 'Sperren nur für Admins');
select throws_ok($$ select public.mod_stats() $$, '42501', null, 'Kennzahlen nur für Admins');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
select is(public.am_i_admin(), true, 'Moni ist Admin');
select is(jsonb_array_length(public.mod_reports()), 1, 'Admin sieht offene Meldung');
select is(public.mod_reports()->0->'reported'->>'name', 'Ben', 'mit gemeldeter Person');
select is((public.mod_stats()->>'games_forfeited')::int, 4, 'Kennzahlen zählen Aufgaben');
select is((public.mod_stats()->>'reports_open')::int, 1, 'Kennzahlen zählen offene Meldungen');

select lives_ok($$ select public.mod_ban_user('00000000-0000-0000-0000-0000000000b2', 'Belästigung') $$,
  'Admin sperrt Ben');
reset role;
select is((select banned_until is not null from auth.users where id = '00000000-0000-0000-0000-0000000000b2'),
  true, 'Anmeldung gesperrt');
select is((select unmatched_at is not null from public.matches where id = '00000000-0000-0000-0000-00000000bbbb'),
  true, 'Matches beendet');
select is((select status::text from public.reports where reported_id = '00000000-0000-0000-0000-0000000000b2'),
  'resolved', 'Meldung erledigt');
select is(private.is_blocked_between('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2'),
  true, 'Gesperrte gelten als blockiert');

-- Ben kann sich nicht selbst wieder sichtbar machen.
update public.profiles set is_visible = true where id = '00000000-0000-0000-0000-0000000000b2';
select is((select is_visible from public.profiles where id = '00000000-0000-0000-0000-0000000000b2'),
  false, 'Gesperrte bleiben unsichtbar');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b2';
select throws_ok($$ update public.profiles set banned_at = null where id = auth.uid() $$,
  '42501', null, 'Sperre nicht selbst aufhebbar');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
select lives_ok($$ select public.mod_unban_user('00000000-0000-0000-0000-0000000000b2') $$, 'Entsperren');
reset role;
select is((select banned_at is null and is_visible from public.profiles where id = '00000000-0000-0000-0000-0000000000b2'),
  true, 'Wieder sichtbar');

select * from finish();
rollback;
