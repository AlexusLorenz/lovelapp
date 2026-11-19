-- pgTAP: Test-Konten sind von echten Konten getrennt
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'echt-w@test.local'),
  ('00000000-0000-0000-0000-0000000000e2', 'echt-m@test.local'),
  ('00000000-0000-0000-0000-0000000000f1', 'test-w@test.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'test-m@test.local');
insert into public.profiles (id, display_name, birthdate, gender, interested_in, sensitive_consent_at, location, is_test) values
  ('00000000-0000-0000-0000-0000000000e1', 'Echt W', current_date - interval '30 years', 'woman', '{man}', now(), 'SRID=4326;POINT(13.40 52.52)', false),
  ('00000000-0000-0000-0000-0000000000e2', 'Echt M', current_date - interval '30 years', 'man', '{woman}', now(), 'SRID=4326;POINT(13.41 52.52)', false),
  ('00000000-0000-0000-0000-0000000000f1', 'Test W', current_date - interval '30 years', 'woman', '{man}', now(), 'SRID=4326;POINT(13.40 52.53)', true),
  ('00000000-0000-0000-0000-0000000000f2', 'Test M', current_date - interval '30 years', 'man', '{woman}', now(), 'SRID=4326;POINT(13.41 52.53)', true);

set local role authenticated;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e1';
select is((select array_agg(display_name order by display_name) from public.discover_profiles()),
  array['Echt M'], 'Echte Nutzerin sieht nur echte Profile');
select throws_ok($$ select public.like_profile('00000000-0000-0000-0000-0000000000f2') $$,
  'P0001', null, 'Test-Konto nicht likebar');
select is((select count(*)::int from public.get_public_profiles(array['00000000-0000-0000-0000-0000000000f1'::uuid])),
  0, 'Test-Profil nicht abrufbar');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
select is((select array_agg(display_name order by display_name) from public.discover_profiles()),
  array['Test M'], 'Test-Konto sieht nur Test-Konten');
select lives_ok($$ select public.like_profile('00000000-0000-0000-0000-0000000000f2') $$,
  'Test-Konten können sich liken');
select throws_ok($$ update public.profiles set is_test = false where id = auth.uid() $$,
  '42501', null, 'is_test nicht selbst änderbar');

reset role;
select * from finish();
rollback;
