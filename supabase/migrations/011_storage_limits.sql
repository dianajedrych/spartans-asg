-- =============================================================================
-- SPARTANS ASG — 011_storage_limits.sql
-- Znaleziono podczas AUDYTU SYSTEMU ZDJĘĆ (2026-08-19): 4 buckety na zdjęcia
-- (product-images, gallery-images, brand-logos, event-images) nie miały
-- ustawionego limitu rozmiaru pliku ani dozwolonych typów MIME na poziomie
-- Storage — jedyną "walidacją" był atrybut accept="image/*" w polu <input>
-- w panelu admina, który jest tylko podpowiedzią przeglądarki, a nie
-- zabezpieczeniem (łatwo obejść wybierając "Wszystkie pliki").
--
-- To NIE jest luka bezpieczeństwa w sensie ataku z zewnątrz — do wgrywania
-- i tak dopuszczeni są tylko is_staff (patrz 008_storage.sql), więc żaden
-- klient sklepu nie mógł tego wykorzystać. Ale to realna luka jakościowa:
-- pracownik mógłby przez pomyłkę wgrać plik 200 MB albo plik niebędący
-- zdjęciem, i Storage by to przyjął bez żadnego ostrzeżenia. Naprawa jest
-- czysto addytywna — nie rusza istniejących danych, tylko dodaje limit na
-- nowe wgrania.
-- =============================================================================

update storage.buckets
set file_size_limit = 10485760, -- 10 MB — z zapasem ponad to, co realnie
                                 -- daje kompresja JPEG/WebP nawet ze zdjęć
                                 -- prosto z aparatu; frontend i tak przycina
                                 -- większość zdjęć przed wysyłką
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
where id in ('product-images', 'gallery-images', 'brand-logos', 'event-images');
