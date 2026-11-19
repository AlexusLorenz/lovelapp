-- Supabase verbietet über die API UPDATE ohne WHERE (pg-safeupdate).
-- push_init_keys braucht deshalb eine (immer wahre) Bedingung.
create or replace function public.push_init_keys(p_public text, p_private text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  update private.push_config
     set vapid_public = coalesce(vapid_public, p_public),
         vapid_private = coalesce(vapid_private, p_private)
   where id;
  select public.push_get_config();
$$;
