-- =============================================================================
-- Test-Accounts (nur für die Entwicklungsphase)
--
-- profiles.is_test markiert vorgefertigte Test-Konten, in die man sich auf der
-- Anmeldeseite mit einem Tipp einloggen kann. Da deren Zugangsdaten in der App
-- stecken, sind sie streng von echten Konten getrennt: Test- und echte Konten
-- gelten untereinander als „blockiert“. Damit sehen sie sich nirgends – nicht
-- in Entdecken, Likes, Profilen, Chats oder bei der Gegnersuche in Spielen.
--
-- is_test kann nur der Server setzen (keine Spalten-Grants).
-- Vor dem Launch: Test-Konten löschen (siehe supabase/seed/test_accounts.sql).
-- =============================================================================

alter table public.profiles add column is_test boolean not null default false;

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
  or coalesce((select p.is_test from public.profiles p where p.id = a), false)
     <> coalesce((select p.is_test from public.profiles p where p.id = b), false);
$$;
