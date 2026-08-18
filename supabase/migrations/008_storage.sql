-- =============================================================================
-- SPARTANS ASG — 008_storage.sql
-- Buckety Supabase Storage na zdjęcia (produkty, galeria, marki, wydarzenia)
-- + reguły dostępu: każdy czyta (zdjęcia są publiczne w sklepie), tylko
-- obsługa (is_staff) może wgrywać/usuwać.
-- =============================================================================

insert into storage.buckets (id, name, public)
values
  ('product-images', 'product-images', true),
  ('gallery-images', 'gallery-images', true),
  ('brand-logos', 'brand-logos', true),
  ('event-images', 'event-images', true)
on conflict (id) do nothing;

create policy "Publiczny odczyt zdjęć produktów"
  on storage.objects for select
  using (bucket_id = 'product-images');

create policy "Obsługa zarządza zdjęciami produktów w Storage"
  on storage.objects for all
  using (bucket_id = 'product-images' and is_staff(auth.uid()))
  with check (bucket_id = 'product-images' and is_staff(auth.uid()));

create policy "Publiczny odczyt zdjęć galerii"
  on storage.objects for select
  using (bucket_id = 'gallery-images');

create policy "Obsługa zarządza zdjęciami galerii w Storage"
  on storage.objects for all
  using (bucket_id = 'gallery-images' and is_staff(auth.uid()))
  with check (bucket_id = 'gallery-images' and is_staff(auth.uid()));

create policy "Publiczny odczyt logotypów marek"
  on storage.objects for select
  using (bucket_id = 'brand-logos');

create policy "Obsługa zarządza logotypami marek w Storage"
  on storage.objects for all
  using (bucket_id = 'brand-logos' and is_staff(auth.uid()))
  with check (bucket_id = 'brand-logos' and is_staff(auth.uid()));

create policy "Publiczny odczyt zdjęć wydarzeń"
  on storage.objects for select
  using (bucket_id = 'event-images');

create policy "Obsługa zarządza zdjęciami wydarzeń w Storage"
  on storage.objects for all
  using (bucket_id = 'event-images' and is_staff(auth.uid()))
  with check (bucket_id = 'event-images' and is_staff(auth.uid()));
