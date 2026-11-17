-- =============================================================================
-- Foto-Upload: Reihenfolge ändern, vorläufige Freigabe
-- =============================================================================

-- Bis es eine Moderation gibt, sind neue Fotos sofort für andere sichtbar.
-- TODO(moderation): Default zurück auf 'pending' und Freigabe-Workflow
-- (z. B. Edge Function mit Bilderkennung + manuelle Prüfung) bauen.
alter table public.profile_photos alter column status set default 'approved';

-- Positionen tauschen braucht eine Prüfung erst am Ende der Transaktion.
alter table public.profile_photos
  drop constraint profile_photos_profile_id_position_key;
alter table public.profile_photos
  add constraint profile_photos_profile_id_position_key
  unique (profile_id, position) deferrable initially immediate;

-- Neue Reihenfolge der eigenen Fotos: p_ids[1] wird Position 0 usw.
-- Es müssen genau alle eigenen Fotos übergeben werden.
create function public.reorder_profile_photos(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := (select auth.uid());
  v_count int;
begin
  if v_me is null then
    raise exception 'Nicht angemeldet.' using errcode = '42501';
  end if;

  select count(*) into v_count from public.profile_photos where profile_id = v_me;
  if v_count <> coalesce(array_length(p_ids, 1), 0)
     or v_count <> (select count(distinct x) from unnest(p_ids) as x)
     or exists (
       select 1 from unnest(p_ids) as x
       where not exists (
         select 1 from public.profile_photos
         where id = x and profile_id = v_me)) then
    raise exception 'Ungültige Reihenfolge.' using errcode = '22023';
  end if;

  set constraints public.profile_photos_profile_id_position_key deferred;
  update public.profile_photos pp
     set position = o.ord - 1
    from unnest(p_ids) with ordinality as o(id, ord)
   where pp.id = o.id and pp.profile_id = v_me;
end;
$$;

revoke execute on function public.reorder_profile_photos(uuid[]) from public, anon;
grant execute on function public.reorder_profile_photos(uuid[]) to authenticated;
