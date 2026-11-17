-- =============================================================================
-- Erhaltene Likes: Wer hat mich geliked und wartet noch auf meine Antwort?
--
-- Kostenlos für alle (kein Pay-to-win). Ausgeblendet werden Personen, mit
-- denen schon ein Match besteht, die ich selbst schon geliked oder
-- weggewischt habe, unsichtbare Profile und Blockierungen in beide Richtungen.
-- =============================================================================

create function public.get_received_likes(p_limit int default 50)
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
  height_cm smallint,
  liked_at timestamptz
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
    case
      when p.location is null or me.location is null then null
      else greatest(1, round(extensions.st_distance(p.location, me.location) / 1000))::int
    end,
    public.level_for_xp(p.xp),
    p.is_verified,
    p.relationship_goal,
    p.children,
    p.smoking,
    p.drinking,
    p.exercise,
    p.height_cm,
    l.created_at
  from public.likes l
  join me on l.likee_id = me.id
  join public.profiles p on p.id = l.liker_id
  where p.is_visible
    and not private.is_blocked_between(me.id, p.id)
    and not exists (
      select 1 from public.likes mine where mine.liker_id = me.id and mine.likee_id = p.id)
    and not exists (
      select 1 from public.passes s where s.passer_id = me.id and s.passee_id = p.id)
    and not exists (
      select 1 from public.matches m
      where m.user_a = least(me.id, p.id) and m.user_b = greatest(me.id, p.id))
  order by l.created_at desc
  limit least(greatest(p_limit, 1), 100);
$$;

revoke execute on function public.get_received_likes(int) from public, anon;
grant execute on function public.get_received_likes(int) to authenticated;
