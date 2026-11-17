-- Neue Likes live an die App melden (für den Likes-Tab und sein Badge).
-- RLS gilt auch für Realtime: Man bekommt nur Likes, die man sehen darf.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'likes'
     ) then
    alter publication supabase_realtime add table public.likes;
  end if;
end;
$$;

-- Ungelesene Nachrichten schnell zählen.
create index if not exists messages_unread_idx
  on public.messages (match_id)
  where read_at is null;
