-- =============================================================================
-- Beta-Vorbereitung
--
-- 1. Push-Benachrichtigungen (Web Push): Abos, Ausgangskorb, Auslöser für
--    neue Matches, Nachrichten und Spielzüge. Versand per Edge Function
--    `push-send`, angestoßen über pg_net. Die VAPID-Schlüssel erzeugt die
--    Edge Function beim ersten Aufruf selbst und legt sie hier ab.
-- 2. Inaktivität in 2-gegen-2-Spielen: Erinnerung nach 48 h, nach 72 h gilt
--    der Zug als aufgegeben. Wer oft aufgibt, bekommt keine Zufallsgegner.
-- 3. Moderation: Admins sehen Meldungen, sperren Konten, entfernen Fotos und
--    sehen Kennzahlen.
--
-- Zahlen, die der Client kennt (48/72 h, Aufgabe-Grenze), stehen auch in
-- lib/features/quiz/quiz_rules.dart – synchron halten.
-- =============================================================================

-- pg_net (HTTP aus der Datenbank) und pg_cron (Zeitpläne), wenn vorhanden.
-- Lokal in den Tests fehlen sie; dann bleibt der Versand einfach aus.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
  end if;
end;
$$;

-- =============================================================================
-- 1. Push
-- =============================================================================

-- Nur bekannte Push-Dienste der Browser, damit der Server keine beliebigen
-- Adressen aufruft.
create table public.push_subscriptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  endpoint        text not null unique check (
    char_length(endpoint) <= 1000
    and endpoint ~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)/'
  ),
  p256dh          text not null check (char_length(p256dh) between 20 and 200),
  auth            text not null check (char_length(auth) between 10 and 100),
  created_at      timestamptz not null default now(),
  last_success_at timestamptz
);
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon, authenticated;

create table private.push_config (
  id            boolean primary key default true check (id),
  -- URL der Edge Function push-send; wird nach dem Deploy gesetzt.
  function_url  text check (function_url ~ '^https://'),
  vapid_public  text,
  vapid_private text
);
insert into private.push_config default values;
revoke all on private.push_config from public, anon, authenticated;

create table private.push_outbox (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('match', 'message', 'quiz_turn', 'quiz_reminder', 'quiz_result')),
  ref        text not null default '',
  title      text not null,
  body       text not null,
  url        text not null default '/',
  created_at timestamptz not null default now(),
  attempts   smallint not null default 0,
  sent_at    timestamptz
);
create index push_outbox_pending_idx on private.push_outbox (created_at) where sent_at is null;
create index push_outbox_recent_idx on private.push_outbox (user_id, kind, ref, created_at);
revoke all on private.push_outbox from public, anon, authenticated;

-- Versand anstoßen (asynchron; schlägt nie fehl).
create function private.push_kick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
begin
  select function_url into v_url from private.push_config;
  if v_url is null or to_regnamespace('net') is null then
    return;
  end if;
  execute 'select net.http_post(url := $1, body := ''{}''::jsonb, '
          'headers := ''{"Content-Type": "application/json"}''::jsonb)'
    using v_url;
exception when others then
  -- Push ist Komfort: niemals deswegen eine Aktion scheitern lassen.
  null;
end;
$$;

-- Benachrichtigung einreihen. Nie an die Person, die gerade handelt, und nur,
-- wenn sie überhaupt Push aktiviert hat.
create function private.push_enqueue(
  p_user uuid, p_kind text, p_ref text, p_title text, p_body text, p_url text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null or p_user = (select auth.uid()) then
    return;
  end if;
  if not exists (select 1 from public.push_subscriptions where user_id = p_user) then
    return;
  end if;
  insert into private.push_outbox (user_id, kind, ref, title, body, url)
  values (p_user, p_kind, coalesce(p_ref, ''), p_title, p_body, coalesce(p_url, '/'));
end;
$$;

create function private.push_outbox_kick()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.push_kick();
  return null;
end;
$$;
create trigger push_outbox_kick
  after insert on private.push_outbox
  for each statement execute function private.push_outbox_kick();

-- --- Auslöser ----------------------------------------------------------------

create function private.display_name(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select display_name from public.profiles where id = p_user), 'Jemand');
$$;

-- Neues Match → beide (außer der Person, die gerade geliked hat).
create function private.push_on_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.push_enqueue(new.user_a, 'match', new.id::text, 'Neues Match 🎉',
    'Du und ' || private.display_name(new.user_b) || ' habt ein Match!', '/chats/' || new.id);
  perform private.push_enqueue(new.user_b, 'match', new.id::text, 'Neues Match 🎉',
    'Du und ' || private.display_name(new.user_a) || ' habt ein Match!', '/chats/' || new.id);
  return null;
end;
$$;
create trigger matches_push
  after insert on public.matches
  for each row execute function private.push_on_match();

-- Neue Nachricht → Empfänger:in. Ohne Nachrichtentext (Sperrbildschirm) und
-- höchstens eine Benachrichtigung pro Chat alle 2 Minuten.
create function private.push_on_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_to uuid;
begin
  select case when m.user_a = new.sender_id then m.user_b else m.user_a end
    into v_to
    from public.matches m where m.id = new.match_id;
  if exists (
    select 1 from private.push_outbox o
    where o.user_id = v_to and o.kind = 'message' and o.ref = new.match_id::text
      and o.created_at > now() - interval '2 minutes'
  ) then
    return null;
  end if;
  perform private.push_enqueue(v_to, 'message', new.match_id::text,
    'Neue Nachricht',
    private.display_name(new.sender_id) || ' hat dir geschrieben.',
    '/chats/' || new.match_id);
  return null;
end;
$$;
create trigger messages_push
  after insert on public.messages
  for each row execute function private.push_on_message();

-- Spielzüge: Wer neu etwas tun muss (oder ein Ergebnis bekommt), erfährt es
-- genau einmal.
create table private.quiz_notified (
  game_id uuid not null references public.quiz_games (id) on delete cascade,
  user_id uuid not null,
  round   smallint not null,
  action  text not null,
  primary key (game_id, user_id, round, action)
);
revoke all on private.quiz_notified from public, anon, authenticated;

create function private.quiz_kind_title(p_kind text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'estimate' then 'Schätzduell'
    when 'emoji' then 'Emoji-Rätsel'
    when 'soulmate' then 'Seelenverwandt'
    else 'Quizduell' end;
$$;

alter table public.quiz_games
  add column reminded_at  timestamptz,
  -- Team (Match), das durch Aufgeben oder Zeitablauf verloren hat.
  add column forfeit_team uuid references public.matches (id) on delete set null;

create function private.push_on_quiz()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_partner uuid;
  v_team uuid;
  v_action text;
  v_rows int;
  v_title text := private.quiz_kind_title(new.kind);
  v_body text;
  v_kind text;
begin
  for v_user, v_partner, v_team in
    select x.u, x.p, m.id
      from public.matches m,
           lateral (values (m.user_a, m.user_b), (m.user_b, m.user_a)) as x (u, p)
     where m.id in (new.team_a, new.team_b)
  loop
    v_action := private.quiz_action(new, v_user);
    if v_action not in ('choose', 'propose', 'decide', 'finished', 'abandoned') then
      continue;
    end if;
    insert into private.quiz_notified (game_id, user_id, round, action)
    values (new.id, v_user,
            case when v_action in ('finished', 'abandoned') then 0 else new.round end,
            v_action)
    on conflict do nothing;
    get diagnostics v_rows = row_count;
    if v_rows = 0 then
      continue;
    end if;

    v_kind := 'quiz_turn';
    v_body := case v_action
      when 'choose' then 'Du bist dran: Wähle eine Kategorie für dich und '
                         || private.display_name(v_partner) || '.'
      when 'propose' then 'Du bist dran – danach entscheidet '
                         || private.display_name(v_partner) || '.'
      when 'decide' then private.display_name(v_partner)
                         || ' hat vorgelegt – jetzt entscheidest du.'
      else null end;
    if v_action in ('finished', 'abandoned') then
      v_kind := 'quiz_result';
      v_body := case
        when new.forfeit_team = v_team then
          'Euer Spiel ist abgelaufen und zählt als verloren.'
        when new.forfeit_team is not null then
          'Das andere Team hat aufgegeben – ihr gewinnt!'
        when new.winner = v_team then 'Gewonnen! Schau dir das Ergebnis an.'
        when new.winner is null and v_action = 'finished' then 'Unentschieden! Schau dir das Ergebnis an.'
        when v_action = 'finished' then 'Das Ergebnis ist da.'
        else 'Das Spiel wurde beendet.' end;
    end if;
    perform private.push_enqueue(v_user, v_kind, new.id::text, v_title, v_body,
                                 '/games/quiz/' || new.id);
  end loop;
  return null;
end;
$$;
create trigger quiz_games_push
  after update on public.quiz_games
  for each row execute function private.push_on_quiz();

-- --- RPCs für die App ----------------------------------------------------------

create function public.push_public_key()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select vapid_public from private.push_config;
$$;

create function public.push_subscribe(p_endpoint text, p_p256dh text, p_auth text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
begin
  if v_me is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;
  -- Gerät wechselt das Konto → Abo geht mit.
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
  values (v_me, p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth,
        created_at = now();
  -- Höchstens 10 Geräte pro Konto.
  delete from public.push_subscriptions
   where user_id = v_me
     and id not in (select id from public.push_subscriptions
                     where user_id = v_me order by created_at desc limit 10);
end;
$$;

create function public.push_unsubscribe(p_endpoint text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.push_subscriptions
   where endpoint = p_endpoint and user_id = (select auth.uid());
$$;

-- --- RPCs nur für die Edge Function (service_role) -----------------------------

create function public.push_get_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('public', vapid_public, 'private', vapid_private)
    from private.push_config;
$$;

-- Schlüssel einmalig setzen (nie überschreiben, sonst verfallen alle Abos).
create function public.push_init_keys(p_public text, p_private text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  update private.push_config
     set vapid_public = coalesce(vapid_public, p_public),
         vapid_private = coalesce(vapid_private, p_private);
  select public.push_get_config();
$$;

-- Offene Benachrichtigungen samt Geräten holen (und als Versuch zählen).
create function public.push_claim(p_limit int default 200)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids bigint[];
begin
  select array_agg(id) into v_ids from (
    select id from private.push_outbox
     where sent_at is null and attempts < 3 and created_at > now() - interval '1 day'
     order by id
     limit p_limit
     for update skip locked
  ) s;
  if v_ids is null then
    return '[]'::jsonb;
  end if;
  update private.push_outbox set attempts = attempts + 1 where id = any (v_ids);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id, 'title', o.title, 'body', o.body, 'url', o.url,
      'tag', o.kind || ':' || o.ref,
      'subscriptions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'endpoint', s.endpoint, 'keys', jsonb_build_object('p256dh', s.p256dh, 'auth', s.auth)))
          from public.push_subscriptions s where s.user_id = o.user_id), '[]'::jsonb)
    ) order by o.id)
    from private.push_outbox o where o.id = any (v_ids)
  ), '[]'::jsonb);
end;
$$;

-- Ergebnis melden: zugestellt / Gerät existiert nicht mehr.
create function public.push_done(p_sent bigint[], p_gone text[])
returns void
language sql
security definer
set search_path = ''
as $$
  update private.push_outbox set sent_at = now() where id = any (p_sent);
  update public.push_subscriptions s set last_success_at = now()
    where s.user_id in (select user_id from private.push_outbox where id = any (p_sent))
      and s.endpoint <> all (coalesce(p_gone, '{}'));
  delete from public.push_subscriptions where endpoint = any (coalesce(p_gone, '{}'));
  delete from private.push_outbox where created_at < now() - interval '7 days';
$$;

-- Liegengebliebenes erneut anstoßen (pg_cron).
create function private.push_retry()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from private.push_outbox
              where sent_at is null and attempts < 3
                and created_at > now() - interval '1 day') then
    perform private.push_kick();
  end if;
end;
$$;

-- =============================================================================
-- 2. Inaktivität
-- =============================================================================

-- Ab 3 Aufgaben in 30 Tagen keine Zufallsgegner mehr (Einladungen gehen).
create function private.quiz_quitter(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) >= 3
    from public.quiz_games g
    join public.matches m on m.id = g.forfeit_team
   where p_user in (m.user_a, m.user_b)
     and g.finished_at > now() - interval '30 days';
$$;

create function private.quiz_team_quitter(p_match uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.matches m
     where m.id = p_match
       and (private.quiz_quitter(m.user_a) or private.quiz_quitter(m.user_b))
  );
$$;

-- Aufgeben zählt als Aufgabe, sobald ein Gegnerteam da ist.
create or replace function public.quiz_give_up(p_game uuid)
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
         forfeit_team = case when team_b is not null then v_team end,
         updated_at = now()
   where id = g.id;
end;
$$;

-- Läuft per pg_cron alle 15 Minuten.
create function private.quiz_inactivity()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.quiz_games;
  v_user uuid;
begin
  -- Nach 48 h ohne Zug: einmal erinnern.
  for g in
    select * from public.quiz_games
     where status = 'active' and team_b is not null and turn is not null
       and updated_at < now() - interval '48 hours'
       and updated_at >= now() - interval '72 hours'
       and (reminded_at is null or reminded_at < updated_at)
  loop
    for v_user in
      select u from public.matches m, unnest(array[m.user_a, m.user_b]) u
       where m.id = g.turn
    loop
      if private.quiz_action(g, v_user) in ('choose', 'propose', 'decide') then
        perform private.push_enqueue(v_user, 'quiz_reminder', g.id::text,
          private.quiz_kind_title(g.kind) || ': Euer Zug wartet',
          'Noch 24 Stunden – danach zählt das Spiel als verloren.',
          '/games/quiz/' || g.id);
      end if;
    end loop;
    update public.quiz_games set reminded_at = now() where id = g.id;
  end loop;

  -- Nach 72 h ohne Zug: Team am Zug verliert, das andere bekommt die XP.
  for g in
    update public.quiz_games
       set status = 'abandoned',
           forfeit_team = turn,
           winner = case when turn = team_a then team_b else team_a end,
           turn = null,
           finished_at = now(),
           updated_at = now()
     where status = 'active' and team_b is not null and turn is not null
       and updated_at < now() - interval '72 hours'
    returning *
  loop
    perform public.award_xp(u, 'game_finished', 'quiz:' || g.id)
       from public.matches m, unnest(array[m.user_a, m.user_b]) u
      where m.id = g.winner;
  end loop;
end;
$$;

-- quiz_start: wie bisher, aber Aussteiger bekommen keine Zufallsgegner.
create or replace function public.quiz_start(
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
    if private.quiz_team_quitter(p_match) then
      raise exception 'Zu viele abgebrochene Spiele in den letzten 30 Tagen. Zufallsgegner gibt es später wieder – mit Einladungscode könnt ihr weiterspielen.'
        using errcode = 'P0001';
    end if;

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
       and not private.quiz_team_quitter(q.team_a)
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

-- =============================================================================
-- 3. Moderation
-- =============================================================================

create table public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;

create function public.am_i_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin();
$$;

create function private.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Nur für Moderation' using errcode = '42501';
  end if;
end;
$$;

-- Gesperrte Konten: nur der Server setzt das (keine Spalten-Grants).
alter table public.profiles
  add column banned_at  timestamptz,
  add column ban_reason text check (char_length(ban_reason) <= 500);

-- Gesperrte bleiben unsichtbar, auch wenn sie is_visible selbst umstellen.
create function private.keep_banned_hidden()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.banned_at is not null then
    new.is_visible := false;
  end if;
  return new;
end;
$$;
create trigger profiles_keep_banned_hidden
  before insert or update on public.profiles
  for each row execute function private.keep_banned_hidden();

-- Gesperrte gelten mit allen als blockiert (zusätzlich zur Test-Trennung).
create or replace function private.is_blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  )
  or exists (
    select 1 from public.profiles p
    where p.id in (a, b) and p.banned_at is not null
  )
  or coalesce((select p.is_test from public.profiles p where p.id = a), false)
     <> coalesce((select p.is_test from public.profiles p where p.id = b), false);
$$;

-- Admins dürfen alle Profilfotos ansehen (für Meldungen).
create policy "Moderation sieht alle Fotos" on storage.objects
  for select to authenticated
  using (bucket_id = 'profile-photos' and private.is_admin());

create function public.mod_reports(p_status text default 'open')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'reason', r.reason,
      'details', r.details,
      'status', r.status,
      'created_at', r.created_at,
      'message', msg.body,
      'reporter', case when rp.id is not null then
        jsonb_build_object('id', rp.id, 'name', rp.display_name) end,
      'reported', jsonb_build_object(
        'id', p.id,
        'name', p.display_name,
        'bio', p.bio,
        'is_test', p.is_test,
        'banned_at', p.banned_at,
        'report_count', (select count(*) from public.reports x where x.reported_id = p.id),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', f.id, 'path', f.storage_path,
                                              'status', f.status) order by f.position)
            from public.profile_photos f where f.profile_id = p.id), '[]'::jsonb)
      )
    ) order by r.created_at desc)
    from public.reports r
    join public.profiles p on p.id = r.reported_id
    left join public.profiles rp on rp.id = r.reporter_id
    left join public.messages msg on msg.id = r.message_id
    where p_status = 'all' or r.status::text = p_status
  ), '[]'::jsonb);
end;
$$;

create function public.mod_set_report_status(p_report uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  update public.reports
     set status = p_status::public.report_status,
         resolved_at = case when p_status in ('resolved', 'dismissed') then now() end
   where id = p_report;
end;
$$;

create function public.mod_ban_user(p_user uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if p_user = (select auth.uid()) then
    raise exception 'Sich selbst sperren geht nicht' using errcode = 'P0001';
  end if;
  update public.profiles
     set banned_at = now(), ban_reason = left(btrim(coalesce(p_reason, '')), 500)
   where id = p_user;
  -- Anmelden verhindern und laufende Sitzungen beenden.
  update auth.users set banned_until = now() + interval '100 years' where id = p_user;
  if to_regclass('auth.sessions') is not null then
    execute 'delete from auth.sessions where user_id = $1' using p_user;
  end if;
  -- Matches beenden (beendet auch laufende Spiele).
  update public.matches
     set unmatched_at = now(), unmatched_by = p_user
   where p_user in (user_a, user_b) and unmatched_at is null;
  update public.reports
     set status = 'resolved', resolved_at = now()
   where reported_id = p_user and status in ('open', 'in_review');
  delete from public.push_subscriptions where user_id = p_user;
end;
$$;

create function public.mod_unban_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  update public.profiles set banned_at = null, ban_reason = null, is_visible = true
   where id = p_user;
  update auth.users set banned_until = null where id = p_user;
end;
$$;

create function public.mod_remove_photo(p_photo uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  update public.profile_photos set status = 'rejected' where id = p_photo;
end;
$$;

-- Kennzahlen für die Beta (nur Summen, keine Einzelpersonen).
create function public.mod_stats(p_include_test boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform private.require_admin();
  with
    pr as (select * from public.profiles where p_include_test or not is_test),
    ma as (
      select m.* from public.matches m
       where exists (select 1 from pr where pr.id = m.user_a)
         and exists (select 1 from pr where pr.id = m.user_b)
    ),
    ga as (
      select g.* from public.quiz_games g where g.team_a in (select id from ma)
    ),
    first_game as (
      select t.match_id, min(g.created_at) as at
        from ga g, lateral (values (g.team_a), (g.team_b)) t (match_id)
       where t.match_id is not null
       group by t.match_id
    )
  select jsonb_build_object(
    'users', (select count(*) from pr),
    'users_new_7d', (select count(*) from pr where created_at > now() - interval '7 days'),
    'users_active_7d', (select count(*) from pr where last_active_at > now() - interval '7 days'),
    'banned', (select count(*) from pr where banned_at is not null),
    'likes_7d', (select count(*) from public.likes l
                  where l.created_at > now() - interval '7 days'
                    and l.liker_id in (select id from pr)),
    'matches', (select count(*) from ma),
    'matches_7d', (select count(*) from ma where created_at > now() - interval '7 days'),
    'matches_with_chat', (select count(*) from ma
                           where exists (select 1 from public.messages x where x.match_id = ma.id)),
    'matches_with_game', (select count(*) from first_game),
    'matches_chat_after_game', (
      select count(*) from first_game f
       where exists (select 1 from public.messages x
                      where x.match_id = f.match_id and x.created_at > f.at)),
    'games', (select count(*) from ga),
    'games_running', (select count(*) from ga where status in ('searching', 'active')),
    'games_finished', (select count(*) from ga where status = 'finished'),
    'games_forfeited', (select count(*) from ga where forfeit_team is not null),
    'games_by_kind', coalesce((select jsonb_object_agg(kind, n)
                                 from (select kind, count(*) n from ga group by kind) k), '{}'::jsonb),
    'messages_7d', (select count(*) from public.messages x
                     where x.created_at > now() - interval '7 days'
                       and x.match_id in (select id from ma)),
    'push_devices', (select count(*) from public.push_subscriptions s
                      where s.user_id in (select id from pr)),
    'reports_open', (select count(*) from public.reports where status in ('open', 'in_review'))
  ) into v;
  return v;
end;
$$;

-- =============================================================================
-- Rechte
-- =============================================================================
revoke execute on function
  private.push_kick(), private.push_enqueue(uuid, text, text, text, text, text),
  private.push_outbox_kick(), private.display_name(uuid), private.push_on_match(),
  private.push_on_message(), private.quiz_kind_title(text), private.push_on_quiz(),
  private.push_retry(), private.quiz_quitter(uuid), private.quiz_team_quitter(uuid),
  private.quiz_inactivity(), private.is_admin(), private.require_admin(),
  private.keep_banned_hidden()
from public, anon, authenticated;
-- Für die Storage-Richtlinie muss is_admin für angemeldete Nutzer ausführbar sein.
grant execute on function private.is_admin() to authenticated;

revoke execute on function
  public.push_public_key(), public.push_subscribe(text, text, text),
  public.push_unsubscribe(text), public.push_get_config(),
  public.push_init_keys(text, text), public.push_claim(int), public.push_done(bigint[], text[]),
  public.am_i_admin(), public.mod_reports(text), public.mod_set_report_status(uuid, text),
  public.mod_ban_user(uuid, text), public.mod_unban_user(uuid), public.mod_remove_photo(uuid),
  public.mod_stats(boolean)
from public, anon, authenticated;

grant execute on function
  public.push_public_key(), public.push_subscribe(text, text, text),
  public.push_unsubscribe(text),
  public.am_i_admin(), public.mod_reports(text), public.mod_set_report_status(uuid, text),
  public.mod_ban_user(uuid, text), public.mod_unban_user(uuid), public.mod_remove_photo(uuid),
  public.mod_stats(boolean)
to authenticated;

grant execute on function
  public.push_get_config(), public.push_init_keys(text, text),
  public.push_claim(int), public.push_done(bigint[], text[])
to service_role;

-- =============================================================================
-- Zeitpläne
-- =============================================================================
do $$
begin
  if to_regnamespace('cron') is not null then
    perform cron.schedule('lovel-quiz-inactivity', '*/15 * * * *',
                          'select private.quiz_inactivity()');
    perform cron.schedule('lovel-push-retry', '*/5 * * * *',
                          'select private.push_retry()');
  end if;
end;
$$;
