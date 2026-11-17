-- =============================================================================
-- Interessen, Lieblingsspiele und Lieblingskünstler:innen
--
-- Kategorien der Interessen MÜSSEN zu lib/features/interests/interest_catalog.dart
-- passen (Liste in private.interest_categories unten).
-- Grenzen MÜSSEN zum Client passen:
--   * max. 3 Interessen pro Kategorie  (maxPerCategory)
--   * max. 6 Spiele                    (maxFavoriteGames)
--   * max. 6 Künstler:innen            (maxFavoriteArtists)
--
-- Geschrieben wird nur über RPCs, die die ganze Liste atomar ersetzen und alle
-- Grenzen prüfen. Lesen dürfen alle, die das Profil sehen dürfen.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Interessen
-- -----------------------------------------------------------------------------
create function private.interest_categories()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'music', 'books', 'sports', 'creative', 'hobbies', 'food', 'film',
    'travel', 'gaming', 'nature', 'knowledge', 'going_out', 'animals',
    'wellbeing', 'tech'
  ];
$$;

create table public.profile_interests (
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  interest_key text not null check (interest_key ~ '^[a-z_]{2,20}\.[a-z0-9_]{2,40}$'),
  category     text generated always as (split_part(interest_key, '.', 1)) stored,
  created_at   timestamptz not null default now(),
  primary key (profile_id, interest_key)
);

create index profile_interests_profile_idx on public.profile_interests (profile_id);

alter table public.profile_interests enable row level security;
revoke all on public.profile_interests from anon, authenticated;
grant select (profile_id, interest_key, category) on public.profile_interests to authenticated;

create policy "Interessen sichtbarer Profile lesen" on public.profile_interests
  for select to authenticated
  using (private.can_see_profile(profile_id));

create function public.set_profile_interests(p_keys text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_keys text[] := coalesce(
    (select array_agg(distinct k) from unnest(p_keys) as k where k is not null),
    '{}'
  );
begin
  if v_me is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;

  if exists (
    select 1 from unnest(v_keys) as k
    where k !~ '^[a-z_]{2,20}\.[a-z0-9_]{2,40}$'
       or split_part(k, '.', 1) <> all (private.interest_categories())
  ) then
    raise exception 'Unbekanntes Interesse' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(v_keys) as k
    group by split_part(k, '.', 1)
    having count(*) > 3
  ) then
    raise exception 'Höchstens 3 Interessen pro Kategorie' using errcode = '22023';
  end if;

  delete from public.profile_interests where profile_id = v_me;
  insert into public.profile_interests (profile_id, interest_key)
  select v_me, k from unnest(v_keys) as k;
end;
$$;
revoke execute on function public.set_profile_interests(text[]) from public, anon;
grant execute on function public.set_profile_interests(text[]) to authenticated;

-- -----------------------------------------------------------------------------
-- Lieblingsspiele (Daten von RAWG; nur deren Bild-CDN erlaubt)
-- -----------------------------------------------------------------------------
create table public.profile_games (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  position   smallint not null check (position between 0 and 5),
  rawg_id    integer not null check (rawg_id > 0),
  name       text not null check (char_length(btrim(name)) between 1 and 120),
  cover_url  text check (cover_url ~ '^https://media\.rawg\.io/media/[A-Za-z0-9_./-]+$'),
  primary key (profile_id, position),
  unique (profile_id, rawg_id)
);

alter table public.profile_games enable row level security;
revoke all on public.profile_games from anon, authenticated;
grant select (profile_id, position, rawg_id, name, cover_url) on public.profile_games to authenticated;

create policy "Spiele sichtbarer Profile lesen" on public.profile_games
  for select to authenticated
  using (private.can_see_profile(profile_id));

-- p_games: [{"id": 3328, "name": "The Witcher 3", "cover": "https://media.rawg.io/…"}, …]
create function public.set_profile_games(p_games jsonb)
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
  if jsonb_typeof(p_games) is distinct from 'array' then
    raise exception 'Liste erwartet' using errcode = '22023';
  end if;
  if jsonb_array_length(p_games) > 6 then
    raise exception 'Höchstens 6 Spiele' using errcode = '22023';
  end if;

  delete from public.profile_games where profile_id = v_me;
  insert into public.profile_games (profile_id, position, rawg_id, name, cover_url)
  select v_me,
         (g.ord - 1)::smallint,
         (g.value ->> 'id')::integer,
         btrim(g.value ->> 'name'),
         nullif(g.value ->> 'cover', '')
  from jsonb_array_elements(p_games) with ordinality as g (value, ord);
end;
$$;
revoke execute on function public.set_profile_games(jsonb) from public, anon;
grant execute on function public.set_profile_games(jsonb) to authenticated;

-- -----------------------------------------------------------------------------
-- Lieblingskünstler:innen (Daten von Spotify; nur deren Bild-CDN erlaubt)
-- -----------------------------------------------------------------------------
create table public.profile_artists (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  position   smallint not null check (position between 0 and 5),
  spotify_id text not null check (spotify_id ~ '^[A-Za-z0-9]{10,40}$'),
  name       text not null check (char_length(btrim(name)) between 1 and 120),
  image_url  text check (image_url ~ '^https://i\.scdn\.co/image/[A-Za-z0-9]+$'),
  primary key (profile_id, position),
  unique (profile_id, spotify_id)
);

alter table public.profile_artists enable row level security;
revoke all on public.profile_artists from anon, authenticated;
grant select (profile_id, position, spotify_id, name, image_url) on public.profile_artists to authenticated;

create policy "Künstler sichtbarer Profile lesen" on public.profile_artists
  for select to authenticated
  using (private.can_see_profile(profile_id));

-- p_artists: [{"id": "4Z8W4fKeB5YxbusRsdQVPb", "name": "Radiohead", "image": "https://i.scdn.co/image/…"}, …]
create function public.set_profile_artists(p_artists jsonb)
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
  if jsonb_typeof(p_artists) is distinct from 'array' then
    raise exception 'Liste erwartet' using errcode = '22023';
  end if;
  if jsonb_array_length(p_artists) > 6 then
    raise exception 'Höchstens 6 Künstler:innen' using errcode = '22023';
  end if;

  delete from public.profile_artists where profile_id = v_me;
  insert into public.profile_artists (profile_id, position, spotify_id, name, image_url)
  select v_me,
         (a.ord - 1)::smallint,
         a.value ->> 'id',
         btrim(a.value ->> 'name'),
         nullif(a.value ->> 'image', '')
  from jsonb_array_elements(p_artists) with ordinality as a (value, ord);
end;
$$;
revoke execute on function public.set_profile_artists(jsonb) from public, anon;
grant execute on function public.set_profile_artists(jsonb) to authenticated;
