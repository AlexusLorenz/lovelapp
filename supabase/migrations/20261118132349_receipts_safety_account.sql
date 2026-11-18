-- =============================================================================
-- Zustellbestätigung im Chat, Konto löschen
--
-- 1. messages.delivered_at: „angekommen“ (zwei graue Häkchen). Gesetzt, sobald
--    die App der Empfänger:in die Nachricht empfangen hat (mark_messages_delivered).
--    read_at bleibt „gelesen“ (zwei rote Häkchen).
--    Zeitstempel setzt immer der Server; sie lassen sich weder zurücksetzen
--    noch vordatieren. Gelesen schließt angekommen ein.
-- 2. delete_own_account(): löscht das eigene Konto samt allen Daten (DSGVO).
--    Die Fotodateien im Storage löscht die App vorher selbst (Storage-API).
-- =============================================================================

alter table public.messages add column delivered_at timestamptz;

-- Bestehende gelesene Nachrichten gelten auch als angekommen.
update public.messages set delivered_at = read_at where read_at is not null;

grant update (delivered_at) on public.messages to authenticated;

create function private.guard_message_receipts()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Inhalt, Absender, Match und Zeit sind unveränderlich.
  new.body := old.body;
  new.sender_id := old.sender_id;
  new.match_id := old.match_id;
  new.created_at := old.created_at;

  new.read_at := coalesce(
    old.read_at,
    case when new.read_at is not null then now() end
  );
  new.delivered_at := coalesce(
    old.delivered_at,
    case when new.delivered_at is not null or new.read_at is not null then now() end
  );
  return new;
end;
$$;

create trigger messages_guard_receipts
  before update on public.messages
  for each row execute function private.guard_message_receipts();

-- Alle an mich gerichteten, noch nicht zugestellten Nachrichten als angekommen
-- markieren. Wird beim Start und bei jeder neuen Nachricht aufgerufen.
create function public.mark_messages_delivered()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_count integer;
begin
  if v_me is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;
  update public.messages msg
     set delivered_at = now()
    from public.matches m
   where m.id = msg.match_id
     and v_me in (m.user_a, m.user_b)
     and msg.sender_id <> v_me
     and msg.delivered_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke execute on function public.mark_messages_delivered() from public, anon;
grant execute on function public.mark_messages_delivered() to authenticated;

-- -----------------------------------------------------------------------------
-- Konto löschen
-- -----------------------------------------------------------------------------
create function public.delete_own_account()
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
  -- Profil zuerst: kaskadiert auf Fotos, Likes, Matches, Nachrichten, Spiele …
  delete from public.profiles where id = v_me;
  delete from auth.users where id = v_me;
end;
$$;
revoke execute on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
