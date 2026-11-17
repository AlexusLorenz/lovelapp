-- pgTAP: Profilfotos
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'foto@test.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'andere@test.local');
insert into public.profiles (id, display_name, birthdate, gender) values
  ('00000000-0000-0000-0000-0000000000f1', 'Foto', current_date - interval '25 years', 'woman'),
  ('00000000-0000-0000-0000-0000000000f2', 'Andere', current_date - interval '25 years', 'man');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';

select lives_ok($$
  insert into public.profile_photos (profile_id, storage_path, position) values
    (auth.uid(), auth.uid() || '/a.jpg', 0),
    (auth.uid(), auth.uid() || '/b.jpg', 1),
    (auth.uid(), auth.uid() || '/c.jpg', 2) $$, 'Eigene Fotos anlegen');
select is((select count(*)::int from public.profile_photos where status = 'approved'), 3,
  'Vorläufig sofort freigegeben');
select throws_ok($$
  insert into public.profile_photos (profile_id, storage_path, position)
  values (auth.uid(), 'fremd/x.jpg', 3) $$, '23514', null, 'Nur im eigenen Ordner');
select throws_ok($$
  insert into public.profile_photos (profile_id, storage_path, position)
  values (auth.uid(), auth.uid() || '/d.jpg', 6) $$, '23514', null, 'Höchstens sechs Fotos');
select throws_ok($$
  insert into public.profile_photos (profile_id, storage_path, position, status)
  values (auth.uid(), auth.uid() || '/e.jpg', 3, 'approved') $$, '42501', null,
  'Freigabe-Status nicht selbst setzbar');

-- Reihenfolge tauschen
select lives_ok($$
  select public.reorder_profile_photos(array(
    select id from public.profile_photos order by position desc)) $$,
  'Reihenfolge umkehren');
select is((select storage_path from public.profile_photos where position = 0),
  '00000000-0000-0000-0000-0000000000f1/c.jpg', 'c steht jetzt vorne');
select throws_ok($$
  select public.reorder_profile_photos(array(
    select id from public.profile_photos where position < 2)) $$,
  '22023', null, 'Alle eigenen Fotos müssen dabei sein');

-- Andere sehen freigegebene Fotos, können sie aber nicht umsortieren
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f2';
select is((select count(*)::int from public.profile_photos), 3, 'Freigegebene Fotos sichtbar');
select throws_ok($$
  select public.reorder_profile_photos(array(select id from public.profile_photos)) $$,
  '22023', null, 'Fremde Fotos nicht umsortierbar');
delete from public.profile_photos;
select is((select count(*)::int from public.profile_photos), 3, 'Fremde Fotos nicht löschbar');

reset role;
select * from finish();
rollback;
