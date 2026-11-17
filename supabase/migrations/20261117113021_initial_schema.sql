-- =============================================================================
-- Lovel – initiales Datenbankschema (Supabase / Postgres + PostGIS)
--
-- Grundsätze
--   * Row Level Security (RLS) auf jeder Tabelle. Clients sprechen nur über
--     erlaubte Spalten oder über RPC-Funktionen mit der Datenbank.
--   * Spielrelevante Werte (Likes, XP, Premium) ändert nur der Server.
--   * Datensparsamkeit (DSGVO): Geburtsdatum, Standort und Präferenzen anderer
--     Nutzer:innen sind nie direkt lesbar – nur Alter, Entfernung (gerundet).
--   * `interested_in` verrät die sexuelle Orientierung (Art. 9 DSGVO) und
--     darf nur mit ausdrücklicher Einwilligung gespeichert werden.
-- =============================================================================

create extension if not exists postgis with schema extensions;

-- -----------------------------------------------------------------------------
-- Typen
-- -----------------------------------------------------------------------------
create type public.photo_status as enum ('pending', 'approved', 'rejected');
create type public.game_status as enum ('waiting', 'active', 'finished', 'abandoned');
create type public.report_status as enum ('open', 'in_review', 'resolved', 'dismissed');
create type public.report_reason as enum (
  'fake_profile', 'harassment', 'inappropriate_content', 'underage', 'spam', 'other'
);

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Like-Ökonomie. MUSS zu lib/features/economy/like_quota.dart passen.
create function public.like_quota_rules(
  out free_likes_per_day int,
  out likes_per_rewarded_ad int,
  out max_rewarded_ads_per_day int
)
language sql
immutable
set search_path = ''
as $$ select 20, 5, 3 $$;

-- Ein „Tag“ endet um Mitternacht deutscher Zeit.
create function public.current_app_day()
returns date
language sql
stable
set search_path = ''
as $$ select (now() at time zone 'Europe/Berlin')::date $$;

-- Level aus XP. MUSS zu lib/features/progress/level.dart passen:
-- Level n ab 50 · n · (n − 1) XP.
create function public.level_for_xp(xp int)
returns int
language sql
immutable
set search_path = ''
as $$ select floor((1 + sqrt(1 + 0.08 * greatest(xp, 0))) / 2)::int $$;

-- -----------------------------------------------------------------------------
-- Profile
-- -----------------------------------------------------------------------------
create table public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  display_name         text not null check (char_length(display_name) between 1 and 40),
  birthdate            date not null,
  bio                  text not null default '' check (char_length(bio) <= 500),
  gender               text not null check (gender in ('woman', 'man', 'nonbinary')),
  -- Wen möchte ich sehen? Besondere Datenkategorie → nur mit Einwilligung.
  interested_in        text[] not null default '{}'
                         check (interested_in <@ array['woman', 'man', 'nonbinary']),
  sensitive_consent_at timestamptz,
  -- Standort: Client rundet auf ca. 1 km, bevor er ihn sendet.
  location             extensions.geography(point, 4326),
  city                 text check (char_length(city) <= 80),
  search_radius_km     int not null default 25 check (search_radius_km between 1 and 200),
  age_min              int not null default 18 check (age_min >= 18),
  age_max              int not null default 99 check (age_max <= 120),
  is_visible           boolean not null default true,
  -- Nur serverseitig änderbar:
  xp                   int not null default 0 check (xp >= 0),
  is_premium           boolean not null default false,
  is_verified          boolean not null default false,
  last_active_at       timestamptz not null default now(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint age_range_valid check (age_min <= age_max),
  constraint orientation_needs_consent
    check (cardinality(interested_in) = 0 or sensitive_consent_at is not null)
);

create index profiles_location_idx on public.profiles using gist (location);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 18+ hart durchsetzen (CHECK mit current_date ist in Postgres nicht zulässig
-- bzw. nicht verlässlich, daher Trigger).
create function public.enforce_adult()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birthdate > (current_date - interval '18 years')::date then
    raise exception 'Lovel ist erst ab 18 Jahren.' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger profiles_enforce_adult
  before insert or update of birthdate on public.profiles
  for each row execute function public.enforce_adult();

-- -----------------------------------------------------------------------------
-- Fotos (Dateien liegen im privaten Storage-Bucket „profile-photos“)
-- -----------------------------------------------------------------------------
create table public.profile_photos (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  -- Pfad im Bucket: <user_id>/<datei>
  storage_path text not null unique,
  position     smallint not null check (position between 0 and 5),
  status       public.photo_status not null default 'pending',
  created_at   timestamptz not null default now(),
  unique (profile_id, position),
  constraint photo_in_own_folder
    check (split_part(storage_path, '/', 1) = profile_id::text)
);

-- -----------------------------------------------------------------------------
-- Likes, Passes, Matches
-- -----------------------------------------------------------------------------
create table public.likes (
  liker_id   uuid not null references public.profiles (id) on delete cascade,
  likee_id   uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (liker_id, likee_id),
  check (liker_id <> likee_id)
);
create index likes_likee_idx on public.likes (likee_id);

create table public.passes (
  passer_id  uuid not null references public.profiles (id) on delete cascade,
  passee_id  uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (passer_id, passee_id),
  check (passer_id <> passee_id)
);

create table public.matches (
  id            uuid primary key default gen_random_uuid(),
  user_a        uuid not null references public.profiles (id) on delete cascade,
  user_b        uuid not null references public.profiles (id) on delete cascade,
  created_at    timestamptz not null default now(),
  unmatched_at  timestamptz,
  unmatched_by  uuid references public.profiles (id) on delete set null,
  -- Paar immer sortiert speichern → genau eine Zeile pro Paar.
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index matches_user_b_idx on public.matches (user_b);

create function public.is_match_member(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.matches m
    where m.id = p_match_id
      and (select auth.uid()) in (m.user_a, m.user_b)
  );
$$;

create function public.is_match_active(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.matches m
    where m.id = p_match_id
      and m.unmatched_at is null
      and (select auth.uid()) in (m.user_a, m.user_b)
  );
$$;

-- -----------------------------------------------------------------------------
-- Chat
-- -----------------------------------------------------------------------------
create table public.messages (
  id         bigint generated always as identity primary key,
  match_id   uuid not null references public.matches (id) on delete cascade,
  sender_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index messages_match_created_idx on public.messages (match_id, created_at);

-- -----------------------------------------------------------------------------
-- Minispiele
-- -----------------------------------------------------------------------------
create table public.game_sessions (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references public.matches (id) on delete cascade,
  -- Schlüssel aus lib/features/games/game_catalog.dart
  game_key    text not null check (game_key ~ '^[a-z0-9_]{2,40}$'),
  status      public.game_status not null default 'waiting',
  created_by  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  result      jsonb,
  created_at  timestamptz not null default now(),
  finished_at timestamptz
);
create index game_sessions_match_idx on public.game_sessions (match_id);

create table public.game_moves (
  id         bigint generated always as identity primary key,
  session_id uuid not null references public.game_sessions (id) on delete cascade,
  player_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  round      smallint not null check (round >= 0),
  payload    jsonb not null check (pg_column_size(payload) <= 4096),
  created_at timestamptz not null default now(),
  unique (session_id, player_id, round)
);

create function public.is_game_member(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.game_sessions g
    join public.matches m on m.id = g.match_id
    where g.id = p_session_id
      and (select auth.uid()) in (m.user_a, m.user_b)
  );
$$;

-- -----------------------------------------------------------------------------
-- Sicherheit: Blockieren & Melden (Digital Services Act)
-- -----------------------------------------------------------------------------
create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

create function public.is_blocked_between(a uuid, b uuid)
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
  );
$$;

-- Blockieren beendet ein bestehendes Match automatisch.
create function public.unmatch_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.matches
     set unmatched_at = now(), unmatched_by = new.blocker_id
   where user_a = least(new.blocker_id, new.blocked_id)
     and user_b = greatest(new.blocker_id, new.blocked_id)
     and unmatched_at is null;
  return new;
end;
$$;

create trigger blocks_unmatch
  after insert on public.blocks
  for each row execute function public.unmatch_on_block();

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid default auth.uid() references public.profiles (id) on delete set null,
  reported_id uuid not null references public.profiles (id) on delete cascade,
  reason      public.report_reason not null,
  details     text not null default '' check (char_length(details) <= 2000),
  message_id  bigint references public.messages (id) on delete set null,
  status      public.report_status not null default 'open',
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  check (reporter_id is null or reporter_id <> reported_id)
);
create index reports_open_idx on public.reports (created_at) where status = 'open';

-- -----------------------------------------------------------------------------
-- Like-Kontingent & Rewarded Ads
-- -----------------------------------------------------------------------------
create table public.daily_like_usage (
  user_id       uuid not null references public.profiles (id) on delete cascade,
  day           date not null,
  likes_used    int not null default 0 check (likes_used >= 0),
  rewarded_ads  int not null default 0 check (rewarded_ads >= 0),
  primary key (user_id, day)
);

-- Jede Werbe-Belohnung genau einmal (AdMob Server-Side Verification).
create table public.ad_rewards (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  transaction_id text not null unique,
  ad_unit        text,
  created_at     timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- XP
-- -----------------------------------------------------------------------------
-- MUSS zu XpReason in lib/features/progress/level.dart passen.
create table public.xp_rewards (
  reason    text primary key,
  amount    int not null,
  daily_cap int  -- max. Vergaben pro Tag, null = unbegrenzt
);

insert into public.xp_rewards (reason, amount, daily_cap) values
  ('profile_completed',  50, null),
  ('photo_verified',     50, null),
  ('replied_to_message',  5, 10),
  ('game_finished',      20, 5),
  ('daily_quest',        15, 3);

create table public.xp_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  reason     text not null references public.xp_rewards (reason),
  amount     int not null,
  -- Verhindert Doppelvergabe für dasselbe Ereignis (z. B. Match-ID).
  ref_id     text not null default '',
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref_id)
);
create index xp_events_user_day_idx on public.xp_events (user_id, reason, created_at);

-- -----------------------------------------------------------------------------
-- Öffentliche Profilansicht (ohne Geburtsdatum, Standort, Präferenzen)
-- -----------------------------------------------------------------------------
create view public.public_profiles
with (security_barrier = true)
as
select
  p.id,
  p.display_name,
  date_part('year', age(p.birthdate))::int as age,
  p.bio,
  p.gender,
  p.city,
  public.level_for_xp(p.xp) as level,
  p.is_verified
from public.profiles p
where p.is_visible
  and not public.is_blocked_between(p.id, (select auth.uid()));

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.profiles         enable row level security;
alter table public.profile_photos   enable row level security;
alter table public.likes            enable row level security;
alter table public.passes           enable row level security;
alter table public.matches          enable row level security;
alter table public.messages         enable row level security;
alter table public.game_sessions    enable row level security;
alter table public.game_moves       enable row level security;
alter table public.blocks           enable row level security;
alter table public.reports          enable row level security;
alter table public.daily_like_usage enable row level security;
alter table public.ad_rewards       enable row level security;
alter table public.xp_rewards       enable row level security;
alter table public.xp_events        enable row level security;

-- Supabase vergibt standardmäßig alle Rechte an anon/authenticated.
-- Wir starten bei null und erlauben gezielt.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- profiles: nur das eigene Profil, nur unkritische Spalten schreibbar.
grant select on public.profiles to authenticated;
grant insert (id, display_name, birthdate, bio, gender, interested_in,
              sensitive_consent_at, location, city, search_radius_km,
              age_min, age_max, is_visible)
  on public.profiles to authenticated;
grant update (display_name, birthdate, bio, gender, interested_in,
              sensitive_consent_at, location, city, search_radius_km,
              age_min, age_max, is_visible)
  on public.profiles to authenticated;
grant delete on public.profiles to authenticated;

create policy "Eigenes Profil lesen" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Eigenes Profil anlegen" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "Eigenes Profil ändern" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "Eigenes Profil löschen" on public.profiles
  for delete to authenticated using (id = (select auth.uid()));

grant select on public.public_profiles to authenticated;

-- profile_photos
grant select, delete on public.profile_photos to authenticated;
grant insert (profile_id, storage_path, position) on public.profile_photos to authenticated;
grant update (position) on public.profile_photos to authenticated;

create policy "Eigene Fotos verwalten" on public.profile_photos
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy "Freigegebene Fotos anderer sehen" on public.profile_photos
  for select to authenticated
  using (
    status = 'approved'
    and not public.is_blocked_between(profile_id, (select auth.uid()))
  );

-- likes: „Wer hat mich geliked?“ ist kostenlos sichtbar (kein Pay-to-win).
-- Schreiben nur über like_profile().
grant select on public.likes to authenticated;
create policy "Eigene und erhaltene Likes sehen" on public.likes
  for select to authenticated
  using (
    liker_id = (select auth.uid())
    or (likee_id = (select auth.uid())
        and not public.is_blocked_between(liker_id, likee_id))
  );

grant select on public.passes to authenticated;
create policy "Eigene Passes sehen" on public.passes
  for select to authenticated using (passer_id = (select auth.uid()));

-- matches: lesen als Mitglied; anlegen/beenden nur per RPC.
grant select on public.matches to authenticated;
create policy "Eigene Matches sehen" on public.matches
  for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

-- messages
grant select on public.messages to authenticated;
grant insert (match_id, body) on public.messages to authenticated;
grant update (read_at) on public.messages to authenticated;

create policy "Nachrichten im eigenen Match lesen" on public.messages
  for select to authenticated using (public.is_match_member(match_id));
create policy "Nachrichten in aktivem Match senden" on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.is_match_active(match_id)
  );
create policy "Empfangene Nachrichten als gelesen markieren" on public.messages
  for update to authenticated
  using (public.is_match_member(match_id) and sender_id <> (select auth.uid()))
  with check (public.is_match_member(match_id) and sender_id <> (select auth.uid()));

-- game_sessions / game_moves
grant select on public.game_sessions to authenticated;
grant insert (match_id, game_key) on public.game_sessions to authenticated;
create policy "Spiele im eigenen Match sehen" on public.game_sessions
  for select to authenticated using (public.is_match_member(match_id));
create policy "Spiel in aktivem Match starten" on public.game_sessions
  for insert to authenticated
  with check (created_by = (select auth.uid()) and public.is_match_active(match_id));

grant select on public.game_moves to authenticated;
grant insert (session_id, round, payload) on public.game_moves to authenticated;
create policy "Spielzüge im eigenen Spiel sehen" on public.game_moves
  for select to authenticated using (public.is_game_member(session_id));
create policy "Eigene Spielzüge machen" on public.game_moves
  for insert to authenticated
  with check (player_id = (select auth.uid()) and public.is_game_member(session_id));

-- blocks
grant select, delete on public.blocks to authenticated;
grant insert (blocked_id) on public.blocks to authenticated;
alter table public.blocks alter column blocker_id set default auth.uid();
create policy "Eigene Blockierungen verwalten" on public.blocks
  for all to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));

-- reports: melden ja, lesen nur eigene; Bearbeitung durch Moderation (service_role).
grant select on public.reports to authenticated;
grant insert (reported_id, reason, details, message_id) on public.reports to authenticated;
create policy "Melden" on public.reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "Eigene Meldungen sehen" on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()));

-- Kontingent, XP: nur lesen.
grant select on public.daily_like_usage to authenticated;
create policy "Eigenes Kontingent sehen" on public.daily_like_usage
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.xp_rewards to authenticated;
create policy "XP-Regeln sind öffentlich" on public.xp_rewards
  for select to authenticated using (true);

grant select on public.xp_events to authenticated;
create policy "Eigene XP sehen" on public.xp_events
  for select to authenticated using (user_id = (select auth.uid()));

-- ad_rewards: kein Client-Zugriff.

-- -----------------------------------------------------------------------------
-- XP vergeben (nur Server)
-- -----------------------------------------------------------------------------
create function public.award_xp(p_user_id uuid, p_reason text, p_ref_id text default '')
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reward public.xp_rewards;
  v_today  int;
  v_rows   int;
begin
  select * into v_reward from public.xp_rewards where reason = p_reason;
  if not found then
    raise exception 'Unbekannter XP-Grund: %', p_reason;
  end if;

  if v_reward.daily_cap is not null then
    select count(*) into v_today
      from public.xp_events
     where user_id = p_user_id
       and reason = p_reason
       and (created_at at time zone 'Europe/Berlin')::date = public.current_app_day();
    if v_today >= v_reward.daily_cap then
      return 0;
    end if;
  end if;

  insert into public.xp_events (user_id, reason, amount, ref_id)
  values (p_user_id, p_reason, v_reward.amount, coalesce(p_ref_id, ''))
  on conflict (user_id, reason, ref_id) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return 0;
  end if;

  update public.profiles set xp = xp + v_reward.amount where id = p_user_id;
  return v_reward.amount;
end;
$$;

-- Antwort auf eine Nachricht des Gegenübers → XP (fördert „nicht ghosten“).
create function public.xp_for_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last_sender uuid;
begin
  select sender_id into v_last_sender
    from public.messages
   where match_id = new.match_id and id < new.id
   order by id desc
   limit 1;

  if v_last_sender is not null and v_last_sender <> new.sender_id then
    perform public.award_xp(new.sender_id, 'replied_to_message', new.id::text);
  end if;
  return new;
end;
$$;

create trigger messages_xp_for_reply
  after insert on public.messages
  for each row execute function public.xp_for_reply();

-- Aktivität für die Discovery-Sortierung.
create function public.touch_last_active()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set last_active_at = now()
   where id = new.sender_id and last_active_at < now() - interval '5 minutes';
  return new;
end;
$$;

create trigger messages_touch_last_active
  after insert on public.messages
  for each row execute function public.touch_last_active();

-- -----------------------------------------------------------------------------
-- RPC: Like-Kontingent
-- -----------------------------------------------------------------------------
create function public.like_quota_status()
returns table (
  likes_used int,
  rewarded_ads int,
  daily_limit int,
  remaining int,
  can_watch_ad boolean,
  is_premium boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with r as (select * from public.like_quota_rules()),
  me as (
    select p.is_premium from public.profiles p where p.id = (select auth.uid())
  ),
  u as (
    select coalesce(d.likes_used, 0) as likes_used,
           coalesce(d.rewarded_ads, 0) as rewarded_ads
    from (select 1) one
    left join public.daily_like_usage d
      on d.user_id = (select auth.uid()) and d.day = public.current_app_day()
  ),
  calc as (
    select u.likes_used, u.rewarded_ads, me.is_premium,
           r.free_likes_per_day
             + (case when me.is_premium then r.max_rewarded_ads_per_day
                     else u.rewarded_ads end) * r.likes_per_rewarded_ad as daily_limit,
           r.max_rewarded_ads_per_day
    from u, r, me
  )
  select likes_used, rewarded_ads, daily_limit,
         greatest(daily_limit - likes_used, 0),
         (not is_premium and rewarded_ads < max_rewarded_ads_per_day),
         is_premium
  from calc;
$$;

-- Wird von der Edge Function nach erfolgreicher AdMob-SSV aufgerufen.
create function public.grant_rewarded_ad_bonus(
  p_user_id uuid,
  p_transaction_id text,
  p_ad_unit text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max int;
  v_ads int;
begin
  select max_rewarded_ads_per_day into v_max from public.like_quota_rules();

  insert into public.daily_like_usage (user_id, day)
  values (p_user_id, public.current_app_day())
  on conflict do nothing;

  select rewarded_ads into v_ads
    from public.daily_like_usage
   where user_id = p_user_id and day = public.current_app_day()
   for update;

  if v_ads >= v_max then
    return false;
  end if;

  insert into public.ad_rewards (user_id, transaction_id, ad_unit)
  values (p_user_id, p_transaction_id, p_ad_unit)
  on conflict (transaction_id) do nothing;
  if not found then
    return false;  -- Transaktion schon verbucht
  end if;

  update public.daily_like_usage
     set rewarded_ads = rewarded_ads + 1
   where user_id = p_user_id and day = public.current_app_day();
  return true;
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC: Liken, Passen, Entmatchen
-- -----------------------------------------------------------------------------
create function public.like_profile(p_target uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := (select auth.uid());
  v_quota    record;
  v_match_id uuid;
  v_rows     int;
begin
  if v_me is null then
    raise exception 'Nicht angemeldet.' using errcode = '42501';
  end if;
  if p_target = v_me then
    raise exception 'Du kannst dich nicht selbst liken.';
  end if;
  if not exists (select 1 from public.profiles where id = p_target and is_visible)
     or public.is_blocked_between(v_me, p_target) then
    raise exception 'Profil nicht verfügbar.';
  end if;

  -- Schon geliked? Dann nichts verbrauchen.
  if exists (select 1 from public.likes where liker_id = v_me and likee_id = p_target) then
    select id into v_match_id from public.matches
     where user_a = least(v_me, p_target) and user_b = greatest(v_me, p_target);
    return jsonb_build_object('matched', v_match_id is not null, 'match_id', v_match_id);
  end if;

  insert into public.daily_like_usage (user_id, day)
  values (v_me, public.current_app_day())
  on conflict do nothing;
  perform 1 from public.daily_like_usage
   where user_id = v_me and day = public.current_app_day()
   for update;  -- serialisiert parallele Likes desselben Nutzers

  select * into v_quota from public.like_quota_status();
  if v_quota.remaining is null then
    raise exception 'Bitte zuerst ein Profil anlegen.';
  end if;
  if v_quota.remaining <= 0 then
    raise exception 'Keine Likes mehr für heute.' using errcode = 'P0001', hint = 'quota_exhausted';
  end if;

  insert into public.likes (liker_id, likee_id) values (v_me, p_target)
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    update public.daily_like_usage
       set likes_used = likes_used + 1
     where user_id = v_me and day = public.current_app_day();
  end if;
  delete from public.passes where passer_id = v_me and passee_id = p_target;

  -- Gegenseitig? → Match.
  if exists (select 1 from public.likes where liker_id = p_target and likee_id = v_me) then
    insert into public.matches (user_a, user_b)
    values (least(v_me, p_target), greatest(v_me, p_target))
    on conflict (user_a, user_b) do nothing
    returning id into v_match_id;
    if v_match_id is null then
      select id into v_match_id from public.matches
       where user_a = least(v_me, p_target) and user_b = greatest(v_me, p_target);
    end if;
  end if;

  return jsonb_build_object(
    'matched', v_match_id is not null,
    'match_id', v_match_id,
    'remaining', v_quota.remaining - 1
  );
end;
$$;

create function public.pass_profile(p_target uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.passes (passer_id, passee_id)
  select (select auth.uid()), p_target
  where (select auth.uid()) is not null and p_target <> (select auth.uid())
  on conflict do nothing;
$$;

create function public.unmatch(p_match_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.matches
     set unmatched_at = now(), unmatched_by = (select auth.uid())
   where id = p_match_id
     and unmatched_at is null
     and (select auth.uid()) in (user_a, user_b);
$$;

-- -----------------------------------------------------------------------------
-- RPC: Discovery-Feed
-- -----------------------------------------------------------------------------
create function public.discover_profiles(p_limit int default 20)
returns table (
  id uuid,
  display_name text,
  age int,
  bio text,
  gender text,
  city text,
  distance_km int,
  level int,
  is_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select * from public.profiles where id = (select auth.uid())
  )
  select
    p.id,
    p.display_name,
    date_part('year', age(p.birthdate))::int,
    p.bio,
    p.gender,
    p.city,
    -- auf ganze km gerundet, mindestens 1 → keine Triangulation auf Meter
    greatest(1, round(extensions.st_distance(p.location, me.location) / 1000))::int,
    public.level_for_xp(p.xp),
    p.is_verified
  from public.profiles p, me
  where p.id <> me.id
    and p.is_visible
    and me.location is not null
    and p.location is not null
    -- beidseitige Präferenzen
    and p.gender = any (me.interested_in)
    and me.gender = any (p.interested_in)
    and date_part('year', age(p.birthdate)) between me.age_min and me.age_max
    and date_part('year', age(me.birthdate)) between p.age_min and p.age_max
    -- beidseitiger Suchradius
    and extensions.st_dwithin(
          p.location, me.location,
          least(me.search_radius_km, p.search_radius_km) * 1000.0)
    -- schon gesehen / blockiert / gematcht ausblenden
    and not exists (select 1 from public.likes l where l.liker_id = me.id and l.likee_id = p.id)
    and not exists (select 1 from public.passes s where s.passer_id = me.id and s.passee_id = p.id)
    and not exists (
      select 1 from public.matches m
      where m.user_a = least(me.id, p.id) and m.user_b = greatest(me.id, p.id))
    and not public.is_blocked_between(me.id, p.id)
  order by p.last_active_at desc, extensions.st_distance(p.location, me.location)
  limit least(greatest(p_limit, 1), 50);
$$;

-- -----------------------------------------------------------------------------
-- Funktionsrechte: nichts für anon, gezielt für authenticated
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function
  public.like_quota_rules(),
  public.current_app_day(),
  public.level_for_xp(int),
  public.is_match_member(uuid),
  public.is_match_active(uuid),
  public.is_game_member(uuid),
  public.is_blocked_between(uuid, uuid),
  public.like_quota_status(),
  public.like_profile(uuid),
  public.pass_profile(uuid),
  public.unmatch(uuid),
  public.discover_profiles(int)
to authenticated;

grant execute on function
  public.award_xp(uuid, text, text),
  public.grant_rewarded_ad_bonus(uuid, text, text)
to service_role;

-- -----------------------------------------------------------------------------
-- Storage: privater Bucket für Profilfotos
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Eigene Fotos hochladen" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Eigene Fotos löschen" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Eigene und freigegebene Fotos ansehen" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.profile_photos pp
        where pp.storage_path = name
          and pp.status = 'approved'
          and not public.is_blocked_between(pp.profile_id, (select auth.uid()))
      )
    )
  );

-- -----------------------------------------------------------------------------
-- Realtime für Chat, Spiele und neue Matches
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime
      add table public.messages, public.game_moves, public.game_sessions, public.matches;
  end if;
end;
$$;
