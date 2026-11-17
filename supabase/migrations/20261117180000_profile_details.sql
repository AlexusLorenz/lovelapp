-- =============================================================================
-- Profil-Details: Steckbrief (Kinder, Rauchen, Alkohol, …) und drei Fragen
--
-- Werte MÜSSEN zu lib/features/profile/profile_basics.dart und
-- lib/features/profile/profile_prompts.dart passen.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Steckbrief: alles freiwillig
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column relationship_goal text
    check (relationship_goal in ('long_term', 'open', 'casual', 'friends', 'unsure')),
  add column children text
    check (children in ('want_someday', 'dont_want', 'have_want_more', 'have_no_more', 'not_sure')),
  add column smoking text check (smoking in ('never', 'sometimes', 'regularly')),
  add column drinking text check (drinking in ('never', 'socially', 'regularly')),
  add column exercise text check (exercise in ('often', 'sometimes', 'rarely')),
  add column height_cm smallint check (height_cm between 120 and 230);

grant insert (relationship_goal, children, smoking, drinking, exercise, height_cm),
      update (relationship_goal, children, smoking, drinking, exercise, height_cm)
  on public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Drei Fragen pro Profil
-- -----------------------------------------------------------------------------
create table public.profile_prompts (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  position   smallint not null check (position between 0 and 2),
  prompt_key text not null check (prompt_key ~ '^[a-z0-9_]{2,40}$'),
  answer     text not null check (char_length(btrim(answer)) between 1 and 150),
  updated_at timestamptz not null default now(),
  primary key (profile_id, position),
  unique (profile_id, prompt_key)
);

create trigger profile_prompts_updated_at
  before update on public.profile_prompts
  for each row execute function public.set_updated_at();

-- Sichtbar für andere, wenn das Profil sichtbar ist und niemand blockiert hat.
create function private.can_see_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = p_profile_id
      and (p.is_visible or p.id = (select auth.uid()))
      and not private.is_blocked_between(p.id, (select auth.uid()))
  );
$$;
revoke execute on function private.can_see_profile(uuid) from public, anon;
grant execute on function private.can_see_profile(uuid) to authenticated, service_role;

alter table public.profile_prompts enable row level security;
revoke all on public.profile_prompts from anon, authenticated;

grant select, delete on public.profile_prompts to authenticated;
grant insert (profile_id, position, prompt_key, answer) on public.profile_prompts to authenticated;
grant update (prompt_key, answer) on public.profile_prompts to authenticated;

create policy "Fragen sichtbarer Profile lesen" on public.profile_prompts
  for select to authenticated
  using (private.can_see_profile(profile_id));
create policy "Eigene Fragen anlegen" on public.profile_prompts
  for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy "Eigene Fragen ändern" on public.profile_prompts
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy "Eigene Fragen löschen" on public.profile_prompts
  for delete to authenticated
  using (profile_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- RPCs um die Steckbrief-Felder erweitern (Rückgabetyp ändert sich → neu anlegen)
-- -----------------------------------------------------------------------------
drop function public.get_public_profiles(uuid[]);
drop function public.discover_profiles(int);

create function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  age int,
  bio text,
  gender text,
  city text,
  level int,
  is_verified boolean,
  relationship_goal text,
  children text,
  smoking text,
  drinking text,
  exercise text,
  height_cm smallint
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
    p.is_verified,
    p.relationship_goal,
    p.children,
    p.smoking,
    p.drinking,
    p.exercise,
    p.height_cm
  from public.profiles p
  where p.id = any (p_ids[1:100])
    and (p.is_visible or p.id = (select auth.uid()))
    and not private.is_blocked_between(p.id, (select auth.uid()));
$$;

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
  is_verified boolean,
  relationship_goal text,
  children text,
  smoking text,
  drinking text,
  exercise text,
  height_cm smallint
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
    p.is_verified,
    p.relationship_goal,
    p.children,
    p.smoking,
    p.drinking,
    p.exercise,
    p.height_cm
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

revoke execute on function public.get_public_profiles(uuid[]) from public, anon;
revoke execute on function public.discover_profiles(int) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
grant execute on function public.discover_profiles(int) to authenticated;
