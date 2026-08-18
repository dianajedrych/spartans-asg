-- =============================================================================
-- SPARTANS ASG — 005_triggers.sql
-- Automatyzacje: nowy użytkownik -> profil + rola, produkt -> SKU/slug/wariant,
-- wariant -> wiersz magazynowy, znaczniki updated_at.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Nowy użytkownik Supabase Auth -> automatyczny profil + domyślna rola.
-- -----------------------------------------------------------------------------
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, first_name, last_name)
    values (
      new.id,
      new.raw_user_meta_data ->> 'first_name',
      new.raw_user_meta_data ->> 'last_name'
    );
  insert into user_roles (user_id, role) values (new.id, 'customer');
  return new;
end;
$$;

create trigger trg_handle_new_user
  after insert on auth.users
  for each row execute function handle_new_user();

-- -----------------------------------------------------------------------------
-- updated_at — automatycznie odświeżane przy każdej zmianie wiersza.
-- -----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on profiles for each row execute function set_updated_at();
create trigger trg_addresses_updated_at before update on addresses for each row execute function set_updated_at();
create trigger trg_products_updated_at before update on products for each row execute function set_updated_at();
create trigger trg_carts_updated_at before update on carts for each row execute function set_updated_at();
create trigger trg_orders_updated_at before update on orders for each row execute function set_updated_at();
create trigger trg_payments_updated_at before update on payments for each row execute function set_updated_at();
create trigger trg_shipments_updated_at before update on shipments for each row execute function set_updated_at();
create trigger trg_reviews_updated_at before update on reviews for each row execute function set_updated_at();
create trigger trg_events_updated_at before update on events for each row execute function set_updated_at();

-- -----------------------------------------------------------------------------
-- Produkt: automatyczny SKU (jeśli admin go nie poda) i slug z nazwy.
-- -----------------------------------------------------------------------------
create or replace function set_product_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.sku is null then
    new.sku := generate_product_sku();
  end if;
  if new.slug is null or new.slug = '' then
    new.slug := unique_slug('products', new.name);
  end if;
  return new;
end;
$$;

create trigger trg_set_product_defaults
  before insert on products
  for each row execute function set_product_defaults();

-- -----------------------------------------------------------------------------
-- Slug z nazwy dla brands / categories / events / gallery_albums.
-- -----------------------------------------------------------------------------
create or replace function set_slug_from_name()
returns trigger
language plpgsql
as $$
begin
  if new.slug is null or new.slug = '' then
    new.slug := unique_slug(TG_TABLE_NAME, new.name);
  end if;
  return new;
end;
$$;

create trigger trg_brands_slug before insert on brands for each row execute function set_slug_from_name();
create trigger trg_categories_slug before insert on categories for each row execute function set_slug_from_name();
create trigger trg_events_slug before insert on events for each row execute function set_slug_from_name();
create trigger trg_gallery_albums_slug before insert on gallery_albums for each row execute function set_slug_from_name();

-- -----------------------------------------------------------------------------
-- Każdy produkt ma ZAWSZE >=1 wariant. Trigger odroczony do końca transakcji:
-- jeśli w tej samej transakcji admin od razu doda własne warianty, "Standard"
-- się nie utworzy; jeśli nie doda żadnego, przy commicie dostaje "Standard".
--
-- WAŻNE dla ETAP 6 (panel admina): to działa poprawnie TYLKO gdy produkt i
-- jego warianty są wstawiane w JEDNEJ transakcji — czyli przez jedną funkcję
-- RPC (np. admin_create_product(...), analogicznie do create_order), a nie
-- przez dwa osobne wywołania supabase-js .insert() (każde to osobna,
-- automatycznie zatwierdzana transakcja — drugi insert nie zdąży przed
-- odroczonym sprawdzeniem pierwszego).
-- -----------------------------------------------------------------------------
create or replace function ensure_default_variant()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from product_variants where product_id = new.id) then
    insert into product_variants (product_id, label) values (new.id, 'Standard');
  end if;
  return null;
end;
$$;

create constraint trigger trg_ensure_default_variant
  after insert on products
  deferrable initially deferred
  for each row
  execute function ensure_default_variant();

-- -----------------------------------------------------------------------------
-- Każdy nowy wariant dostaje od razu wiersz magazynowy (stan = 0, admin
-- ustawia realną ilość przez panel).
-- -----------------------------------------------------------------------------
create or replace function ensure_inventory_row()
returns trigger
language plpgsql
as $$
begin
  insert into inventory (variant_id, quantity_on_hand)
    values (new.id, 0)
    on conflict (variant_id) do nothing;
  return new;
end;
$$;

create trigger trg_ensure_inventory_row
  after insert on product_variants
  for each row execute function ensure_inventory_row();

-- -----------------------------------------------------------------------------
-- Ochrona pól moderacyjnych na reviews: RLS (003) pozwala autorowi
-- edytować WŁASNĄ opinię, dopóki ma status 'pending' — ale RLS kontroluje
-- tylko to, do których WIERSZY jest dostęp, nie to, które KOLUMNY wolno
-- zmienić w ramach tego samego UPDATE. Bez tego triggera autor mógłby w tym
-- samym zapytaniu, które edytuje treść, dopisać status='published' albo
-- is_verified_purchase=true samemu sobie. Trigger wymusza, że te dwa pola
-- zmienia wyłącznie obsługa (is_staff), niezależnie od tego, co przyszło w
-- zapytaniu UPDATE.
-- -----------------------------------------------------------------------------
create or replace function protect_review_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_staff(auth.uid()) then
    new.status := old.status;
    new.is_verified_purchase := old.is_verified_purchase;
  end if;
  return new;
end;
$$;

create trigger trg_protect_review_moderation_fields
  before update on reviews
  for each row execute function protect_review_moderation_fields();
