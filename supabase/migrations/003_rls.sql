-- =============================================================================
-- SPARTANS ASG — 003_rls.sql
-- Row Level Security. Każda tabela wystawiona do frontendu ma RLS włączone.
-- Zasady odpowiadają tabeli z ARCHITECTURE.md sekcja 7.1.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Funkcje pomocnicze — SECURITY DEFINER, żeby uniknąć rekurencji RLS
-- (polityka na user_roles, która sama odpytuje user_roles).
-- -----------------------------------------------------------------------------
create function has_role(_user_id uuid, _role app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from user_roles
    where user_id = _user_id and role = _role
  )
$$;

create function is_staff(_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select has_role(_user_id, 'admin') or has_role(_user_id, 'manager')
$$;

-- =============================================================================
-- profiles
-- =============================================================================
alter table profiles enable row level security;

create policy "Klient czyta własny profil"
  on profiles for select
  using (auth.uid() = id or is_staff(auth.uid()));

create policy "Klient edytuje własny profil"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Profil tworzony automatycznie triggerem"
  on profiles for insert
  with check (auth.uid() = id);

-- =============================================================================
-- user_roles — klient TYLKO czyta własne role, nigdy nie zapisuje.
-- =============================================================================
alter table user_roles enable row level security;

create policy "Klient czyta własne role"
  on user_roles for select
  using (auth.uid() = user_id or is_staff(auth.uid()));

create policy "Tylko admin zarządza rolami"
  on user_roles for insert
  with check (has_role(auth.uid(), 'admin'));

create policy "Tylko admin zmienia role"
  on user_roles for update
  using (has_role(auth.uid(), 'admin'));

create policy "Tylko admin usuwa role"
  on user_roles for delete
  using (has_role(auth.uid(), 'admin'));

-- =============================================================================
-- addresses
-- =============================================================================
alter table addresses enable row level security;

create policy "Klient zarządza własnymi adresami"
  on addresses for all
  using (auth.uid() = user_id or is_staff(auth.uid()))
  with check (auth.uid() = user_id);

-- =============================================================================
-- brands / categories — publiczny odczyt, zapis tylko dla obsługi sklepu
-- =============================================================================
alter table brands enable row level security;
alter table categories enable row level security;

create policy "Każdy czyta marki" on brands for select using (true);
create policy "Obsługa zarządza markami" on brands for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Każdy czyta kategorie" on categories for select using (true);
create policy "Obsługa zarządza kategoriami" on categories for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

-- =============================================================================
-- products / product_variants / product_images / product_specifications
-- Klient widzi tylko aktywne produkty. Obsługa widzi i edytuje wszystko.
-- =============================================================================
alter table products enable row level security;
alter table product_variants enable row level security;
alter table product_images enable row level security;
alter table product_specifications enable row level security;

create policy "Klient czyta aktywne produkty"
  on products for select
  using (is_active or is_staff(auth.uid()));

create policy "Obsługa zarządza produktami"
  on products for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Klient czyta warianty aktywnych produktów"
  on product_variants for select
  using (
    is_staff(auth.uid())
    or exists (select 1 from products p where p.id = product_id and p.is_active)
  );

create policy "Obsługa zarządza wariantami"
  on product_variants for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Każdy czyta zdjęcia produktów"
  on product_images for select using (true);

create policy "Obsługa zarządza zdjęciami produktów"
  on product_images for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Każdy czyta specyfikacje produktów"
  on product_specifications for select using (true);

create policy "Obsługa zarządza specyfikacjami"
  on product_specifications for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

-- =============================================================================
-- inventory — stan magazynowy widoczny (do obliczenia "dostępny"/"ostatnie N szt."),
-- ale tylko obsługa może go zmieniać ręcznie (normalnie zmienia go create_order()).
-- =============================================================================
alter table inventory enable row level security;

create policy "Każdy czyta stan magazynowy"
  on inventory for select using (true);

create policy "Obsługa zarządza stanem magazynowym"
  on inventory for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

-- =============================================================================
-- carts / cart_items — tylko własne
-- =============================================================================
alter table carts enable row level security;
alter table cart_items enable row level security;

create policy "Klient zarządza własnym koszykiem"
  on carts for all
  using (auth.uid() = user_id or is_staff(auth.uid()))
  with check (auth.uid() = user_id);

create policy "Klient zarządza pozycjami własnego koszyka"
  on cart_items for all
  using (
    is_staff(auth.uid())
    or exists (select 1 from carts c where c.id = cart_id and c.user_id = auth.uid())
  )
  with check (
    exists (select 1 from carts c where c.id = cart_id and c.user_id = auth.uid())
  );

-- =============================================================================
-- orders / order_items — klient czyta tylko własne, insert TYLKO przez
-- funkcję create_order() (SECURITY DEFINER omija RLS w kontrolowany sposób),
-- więc tu nie ma polityki "insert" dla zwykłego klienta.
-- =============================================================================
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_status_history enable row level security;

create policy "Klient czyta własne zamówienia"
  on orders for select
  using (auth.uid() = user_id or is_staff(auth.uid()));

create policy "Obsługa aktualizuje zamówienia"
  on orders for update
  using (is_staff(auth.uid()));

create policy "Klient czyta pozycje własnych zamówień"
  on order_items for select
  using (
    is_staff(auth.uid())
    or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid())
  );

create policy "Klient czyta historię statusów własnych zamówień"
  on order_status_history for select
  using (
    is_staff(auth.uid())
    or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid())
  );

-- Uwaga: brak polityk INSERT na orders/order_items/order_status_history dla
-- zwykłego klienta — jedyna droga zapisu to funkcje create_order() i
-- admin_update_order_status() (004_functions.sql), które i tak omijają RLS
-- (SECURITY DEFINER) i same w sobie weryfikują uprawnienia.

-- =============================================================================
-- payments / shipments — jak orders
-- =============================================================================
alter table payments enable row level security;
alter table shipments enable row level security;

create policy "Klient czyta płatności własnych zamówień"
  on payments for select
  using (
    is_staff(auth.uid())
    or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid())
  );

create policy "Obsługa zarządza płatnościami"
  on payments for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Klient czyta przesyłki własnych zamówień"
  on shipments for select
  using (
    is_staff(auth.uid())
    or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid())
  );

create policy "Obsługa zarządza przesyłkami"
  on shipments for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

-- =============================================================================
-- favorites / comparison_lists / comparison_items — tylko własne
-- =============================================================================
alter table favorites enable row level security;
alter table comparison_lists enable row level security;
alter table comparison_items enable row level security;

create policy "Klient zarządza własnymi ulubionymi"
  on favorites for all
  using (auth.uid() = user_id or is_staff(auth.uid()))
  with check (auth.uid() = user_id);

create policy "Klient zarządza własną listą porównania"
  on comparison_lists for all
  using (auth.uid() = user_id or is_staff(auth.uid()))
  with check (auth.uid() = user_id);

create policy "Klient zarządza pozycjami własnego porównania"
  on comparison_items for all
  using (
    is_staff(auth.uid())
    or exists (
      select 1 from comparison_lists cl
      where cl.id = comparison_list_id and cl.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from comparison_lists cl
      where cl.id = comparison_list_id and cl.user_id = auth.uid()
    )
  );

-- =============================================================================
-- reviews — każdy czyta opublikowane (+ autor widzi własne niezależnie od
-- statusu), klient dodaje własną recenzję, tylko obsługa moderuje (update status)
-- =============================================================================
alter table reviews enable row level security;

create policy "Każdy czyta opublikowane opinie, autor widzi swoje"
  on reviews for select
  using (status = 'published' or auth.uid() = user_id or is_staff(auth.uid()));

create policy "Zalogowany klient dodaje opinię"
  on reviews for insert
  with check (auth.uid() = user_id);

-- Uwaga: to pozwala autorowi na UPDATE własnego wiersza, ale nie chroni
-- kolumn "status"/"is_verified_purchase" przed samodzielną zmianą przez
-- autora w tym samym zapytaniu — to jest zablokowane osobno, triggerem
-- protect_review_moderation_fields() w 005_triggers.sql (RLS kontroluje
-- wiersze, nie kolumny).
create policy "Autor edytuje własną nieopublikowaną opinię"
  on reviews for update
  using (auth.uid() = user_id and status = 'pending');

create policy "Obsługa moderuje opinie"
  on reviews for update
  using (is_staff(auth.uid()));

create policy "Obsługa usuwa opinie"
  on reviews for delete
  using (is_staff(auth.uid()));

-- =============================================================================
-- events / event_registrations
-- =============================================================================
alter table events enable row level security;
alter table event_registrations enable row level security;

create policy "Każdy czyta opublikowane wydarzenia"
  on events for select
  using (status = 'published' or is_staff(auth.uid()));

create policy "Obsługa zarządza wydarzeniami"
  on events for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Każdy zapisuje się na wydarzenie"
  on event_registrations for insert
  with check (true);

create policy "Klient czyta własne zapisy, obsługa czyta wszystkie"
  on event_registrations for select
  using (auth.uid() = user_id or is_staff(auth.uid()));

create policy "Obsługa zarządza zapisami"
  on event_registrations for update
  using (is_staff(auth.uid()));

-- =============================================================================
-- gallery_albums / gallery_images — publiczne, zarządzane przez obsługę
-- =============================================================================
alter table gallery_albums enable row level security;
alter table gallery_images enable row level security;

create policy "Każdy czyta albumy" on gallery_albums for select using (true);
create policy "Obsługa zarządza albumami" on gallery_albums for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

create policy "Każdy czyta zdjęcia galerii" on gallery_images for select using (true);
create policy "Obsługa zarządza zdjęciami galerii" on gallery_images for all
  using (is_staff(auth.uid())) with check (is_staff(auth.uid()));

-- =============================================================================
-- admin_logs — WYŁĄCZNIE admin (nie manager — dziennik zmian to wrażliwe dane)
-- =============================================================================
alter table admin_logs enable row level security;

create policy "Tylko admin czyta dziennik zmian"
  on admin_logs for select
  using (has_role(auth.uid(), 'admin'));

-- Brak polityki INSERT dla klienta/frontendu — wpisy dodają wyłącznie
-- funkcje SECURITY DEFINER (create_order, admin_update_order_status, ...).
