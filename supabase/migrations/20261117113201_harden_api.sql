-- =============================================================================
-- API absichern (Befunde des Supabase Security Advisors)
--
-- 1. Hilfsfunktionen für RLS (is_match_member, is_blocked_between, …) liegen
--    jetzt im nicht veröffentlichten Schema `private`. Vorher waren sie per
--    /rest/v1/rpc aufrufbar – damit hätte man z. B. abfragen können, ob zwei
--    beliebige Nutzer:innen sich blockiert haben.
-- 2. Die View `public_profiles` lief mit den Rechten ihres Erstellers
--    (Security Definer View). Ersetzt durch die RPC `get_public_profiles`,
--    die genau dieselben unkritischen Spalten liefert.
-- =============================================================================

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- Policies und Trigger verweisen per OID auf die Funktionen und bleiben gültig.
alter function public.is_match_member(uuid) set schema private;
alter function public.is_match_active(uuid) set schema private;
alter function public.is_game_member(uuid) set schema private;
alter function public.is_blocked_between(uuid, uuid) set schema private;

-- -----------------------------------------------------------------------------
-- Öffentliche Profile per RPC statt Security-Definer-View
-- -----------------------------------------------------------------------------
drop view public.public_profiles;

create function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  age int,
  bio text,
  gender text,
  city text,
  level int,
  is_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.display_name,
    date_part('year', age(p.birthdate))::int,
    p.bio,
    p.gender,
    p.city,
    public.level_for_xp(p.xp),
    p.is_verified
  from public.profiles p
  where p.id = any (p_ids[1:100])
    and (p.is_visible or p.id = (select auth.uid()))
    and not private.is_blocked_between(p.id, (select auth.uid()));
$$;

-- -----------------------------------------------------------------------------
-- Funktionen, die die Hilfsfunktionen im Rumpf per Namen aufrufen, neu anlegen
-- -----------------------------------------------------------------------------
create or replace function public.like_profile(p_target uuid)
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
     or private.is_blocked_between(v_me, p_target) then
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

create or replace function public.discover_profiles(p_limit int default 20)
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
    and not private.is_blocked_between(me.id, p.id)
  order by p.last_active_at desc, extensions.st_distance(p.location, me.location)
  limit least(greatest(p_limit, 1), 50);
$$;

-- -----------------------------------------------------------------------------
-- Rechte
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated, service_role;

revoke execute on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
