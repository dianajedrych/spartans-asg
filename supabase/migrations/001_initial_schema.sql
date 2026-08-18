-- =============================================================================
-- SPARTANS ASG — 001_initial_schema.sql
-- Podstawowy schemat: typy, tabele, klucze obce.
-- Uruchom w Supabase Dashboard → SQL Editor, w kolejności numerycznej plików.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Rozszerzenia
-- -----------------------------------------------------------------------------
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- -----------------------------------------------------------------------------
-- Typy wyliczeniowe (enum)
-- -----------------------------------------------------------------------------
create type app_role as enum ('customer', 'manager', 'admin');

create type order_status as enum (
  'new', 'processing', 'packed', 'shipped', 'delivered',
  'cancelled', 'returned', 'refunded'
);

create type review_status as enum ('pending', 'published', 'hidden');

create type event_status as enum ('draft', 'published', 'closed', 'cancelled');

-- -----------------------------------------------------------------------------
-- profiles — dane osobowe. Hasło/e-mail/sesja żyją w auth.users (Supabase Auth).
-- -----------------------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  phone text,
  date_of_birth date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table profiles is 'Dane osobowe klienta. Rola NIE jest tu przechowywana — patrz user_roles.';

-- -----------------------------------------------------------------------------
-- user_roles — CELOWO osobno od profiles (patrz ARCHITECTURE.md sekcja 7.2).
-- Klient nigdy nie może sam sobie nadać roli przez zwykłe "zapisz profil".
-- -----------------------------------------------------------------------------
create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  role app_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

-- -----------------------------------------------------------------------------
-- addresses
-- -----------------------------------------------------------------------------
create table addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  label text,
  imie text not null,
  nazwisko text not null,
  telefon text,
  linia1 text not null,
  linia2 text,
  kod_pocztowy text not null,
  miasto text not null,
  kraj text not null default 'Polska',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- brands
-- -----------------------------------------------------------------------------
create table brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  logo_storage_path text,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- categories — hierarchiczne (samoreferencja).
-- -----------------------------------------------------------------------------
create table categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references categories (id) on delete set null,
  name text not null,
  slug text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- products
-- -----------------------------------------------------------------------------
create table products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  name text not null,
  slug text not null unique,
  description text,
  short_description text,
  brand_id uuid references brands (id) on delete set null,
  category_id uuid references categories (id) on delete set null,
  base_price numeric(10, 2) not null check (base_price >= 0),
  sale_price numeric(10, 2) check (sale_price >= 0),
  currency text not null default 'PLN',
  is_active boolean not null default true,
  is_featured boolean not null default false, -- "Produkt polecany" w kreatorze (KROK 7)
  is_18_plus boolean not null default false,
  -- Odznaki "BESTSELLER" / "NOWOŚĆ" na kartach produktu. Na start to zwykłe
  -- flagi ustawiane ręcznie (tak jak dziś w danych startowych) — w przyszłości
  -- "nowość" da się łatwo zastąpić samym created_at, a "bestseller" realną
  -- agregacją sprzedaży z order_items, bez zmiany schematu.
  is_bestseller boolean not null default false,
  is_new boolean not null default false,
  low_stock_threshold integer not null default 3,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles (id) on delete set null,
  constraint sale_price_below_base check (sale_price is null or sale_price <= base_price)
);

-- -----------------------------------------------------------------------------
-- product_variants — KAŻDY produkt ma zawsze >=1 wariant (patrz trigger w 005).
-- -----------------------------------------------------------------------------
create table product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  sku text unique,
  label text not null default 'Standard',
  price_override numeric(10, 2) check (price_override >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- product_images
-- -----------------------------------------------------------------------------
create table product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  variant_id uuid references product_variants (id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- product_specifications — dowolne parametry (FPS, Hop-Up, Gearbox...),
-- bez zmiany schematu bazy przy każdym nowym typie parametru.
-- -----------------------------------------------------------------------------
create table product_specifications (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  spec_name text not null,
  spec_value text not null,
  spec_unit text,
  sort_order integer not null default 0
);

-- -----------------------------------------------------------------------------
-- inventory — JEDYNE źródło prawdy o stanie magazynowym. Jeden wiersz na wariant.
-- -----------------------------------------------------------------------------
create table inventory (
  variant_id uuid primary key references product_variants (id) on delete cascade,
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  low_stock_threshold integer not null default 3,
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- carts / cart_items
-- -----------------------------------------------------------------------------
create table carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references carts (id) on delete cascade,
  variant_id uuid not null references product_variants (id) on delete cascade,
  quantity integer not null check (quantity > 0),
  added_at timestamptz not null default now(),
  unique (cart_id, variant_id)
);

-- -----------------------------------------------------------------------------
-- orders / order_items / order_status_history
-- -----------------------------------------------------------------------------
create table orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  user_id uuid references profiles (id) on delete set null, -- nullable: gość może kupować
  status order_status not null default 'new',
  currency text not null default 'PLN',
  subtotal numeric(10, 2) not null check (subtotal >= 0),
  shipping_cost numeric(10, 2) not null default 0 check (shipping_cost >= 0),
  total numeric(10, 2) not null check (total >= 0),
  payment_method text,
  delivery_method text,
  buyer_snapshot jsonb not null,
  shipping_address_snapshot jsonb,
  invoice_details_snapshot jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  product_id uuid references products (id) on delete set null,
  variant_id uuid references product_variants (id) on delete set null,
  product_name_snapshot text not null,
  sku_snapshot text,
  unit_price_snapshot numeric(10, 2) not null check (unit_price_snapshot >= 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(10, 2) not null check (line_total >= 0),
  product_snapshot jsonb not null
);

create table order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- payments / shipments — gotowe pod przyszłą integrację, nigdy dane karty.
-- -----------------------------------------------------------------------------
create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders (id) on delete cascade, -- jedna płatność na zamówienie (v1)
  provider text not null,
  provider_payment_id text,
  status text not null default 'pending',
  amount numeric(10, 2) not null check (amount >= 0),
  currency text not null default 'PLN',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders (id) on delete cascade, -- jedna przesyłka na zamówienie (v1)
  carrier text,
  method text,
  tracking_number text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- favorites
-- -----------------------------------------------------------------------------
create table favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  product_id uuid not null references products (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- -----------------------------------------------------------------------------
-- comparison_lists / comparison_items
-- -----------------------------------------------------------------------------
create table comparison_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table comparison_items (
  id uuid primary key default gen_random_uuid(),
  comparison_list_id uuid not null references comparison_lists (id) on delete cascade,
  product_id uuid not null references products (id) on delete cascade,
  added_at timestamptz not null default now(),
  unique (comparison_list_id, product_id)
);

-- -----------------------------------------------------------------------------
-- reviews — NOWY system recenzji produktowych (nie testimoniale ze strony głównej)
-- -----------------------------------------------------------------------------
create table reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  order_item_id uuid references order_items (id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  title text,
  body text,
  is_verified_purchase boolean not null default false,
  status review_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- events / event_registrations
-- -----------------------------------------------------------------------------
create table events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  short_description text,
  cover_image_storage_path text,
  event_date date,
  event_time time,
  location text,
  price numeric(10, 2) check (price >= 0),
  capacity integer check (capacity >= 0),
  status event_status not null default 'draft',
  content jsonb, -- treści narracyjne w stylu "Korengal" (bloki tekst/zdjęcie/harmonogram)
  external_form_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles (id) on delete set null
);

create table event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events (id) on delete cascade,
  user_id uuid references profiles (id) on delete set null,
  imie text not null,
  nazwisko text not null,
  email text not null,
  telefon text,
  status text not null default 'zgłoszony',
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- gallery_albums / gallery_images
-- -----------------------------------------------------------------------------
create table gallery_albums (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  cover_image_storage_path text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table gallery_images (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references gallery_albums (id) on delete cascade,
  storage_path text not null,
  caption text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- admin_logs — audyt działań administratora (nigdy widoczne dla klienta)
-- -----------------------------------------------------------------------------
create table admin_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);
