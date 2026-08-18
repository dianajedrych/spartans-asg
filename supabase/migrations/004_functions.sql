-- =============================================================================
-- SPARTANS ASG — 004_functions.sql
-- Logika serwerowa: generowanie SKU/slug/numeru zamówienia, atomowe
-- tworzenie zamówienia, zmiana statusu przez obsługę.
-- has_role() / is_staff() są już w 003_rls.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Numeracja zamówień: SP-2026-00142
-- -----------------------------------------------------------------------------
create sequence if not exists order_number_seq start 1;

create or replace function generate_order_number()
returns text
language plpgsql
as $$
begin
  return 'SP-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('order_number_seq')::text, 5, '0');
end;
$$;

-- -----------------------------------------------------------------------------
-- Automatyczny SKU produktu, gdy admin go nie poda: SP-000001, SP-000002...
-- -----------------------------------------------------------------------------
create sequence if not exists product_sku_seq start 1;

create or replace function generate_product_sku()
returns text
language plpgsql
as $$
begin
  return 'SP-' || lpad(nextval('product_sku_seq')::text, 6, '0');
end;
$$;

-- -----------------------------------------------------------------------------
-- Slug z nazwy: "Specna Arms EDGE 2.0" -> "specna-arms-edge-2-0",
-- a przy konflikcie "-2", "-3"...
-- -----------------------------------------------------------------------------
create or replace function slugify(p_text text)
returns text
language sql
immutable
as $$
  select trim(both '-' from
    regexp_replace(
      lower(
        translate(p_text,
          'ąćęłńóśźżĄĆĘŁŃÓŚŹŻ',
          'acelnoszzACELNOSZZ'
        )
      ),
      '[^a-z0-9]+', '-', 'g'
    )
  )
$$;

create or replace function unique_slug(p_table text, p_base text)
returns text
language plpgsql
as $$
declare
  v_slug text := slugify(p_base);
  v_candidate text := v_slug;
  v_suffix int := 1;
  v_exists boolean;
begin
  loop
    execute format('select exists(select 1 from %I where slug = $1)', p_table)
      into v_exists using v_candidate;
    exit when not v_exists;
    v_suffix := v_suffix + 1;
    v_candidate := v_slug || '-' || v_suffix;
  end loop;
  return v_candidate;
end;
$$;

-- -----------------------------------------------------------------------------
-- create_order — jedyna droga zapisu zamówienia. Patrz ARCHITECTURE.md sekcja 8.
--
-- p_items: [{"variant_id": "uuid", "quantity": 2}, ...] — WYŁĄCZNIE variant_id
-- i ilość. Cena jest zawsze doliczana tu, nigdy przyjmowana od klienta.
-- Dostępna dla gościa (auth.uid() is null) i zalogowanego klienta.
-- -----------------------------------------------------------------------------
create or replace function create_order(
  p_items jsonb,
  p_delivery_option text,
  p_payment_method text,
  p_buyer jsonb,
  p_shipping_address jsonb default null,
  p_invoice_details jsonb default null,
  p_shipping_cost numeric default 0
)
returns table (out_order_id uuid, out_order_number text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item record;
  v_inv record;
  v_product record;
  v_price numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_order_id uuid := gen_random_uuid();
  v_order_number text := generate_order_number();
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Koszyk jest pusty.';
  end if;

  -- Obrona w głąb: frontend też waliduje te pola, ale backend nie może na
  -- tym polegać (DevTools może pominąć walidację frontendową).
  if coalesce(p_buyer ->> 'imie', '') = '' or coalesce(p_buyer ->> 'nazwisko', '') = ''
     or coalesce(p_buyer ->> 'telefon', '') = '' or coalesce(p_buyer ->> 'email', '') = '' then
    raise exception 'Podaj imię, nazwisko, numer telefonu i e-mail, aby złożyć zamówienie.';
  end if;

  -- "drop if exists" jako zabezpieczenie na wypadek, gdyby funkcja została
  -- wywołana dwa razy w tej samej transakcji (tabela tymczasowa żyje do
  -- commit, nie do końca pojedynczego wywołania funkcji).
  drop table if exists tmp_order_items;
  create temporary table tmp_order_items (
    variant_id uuid, product_id uuid, name text, sku text,
    unit_price numeric, quantity integer, line_total numeric, snapshot jsonb
  ) on commit drop;

  for v_item in
    select * from jsonb_to_recordset(p_items) as x (variant_id uuid, quantity integer)
  loop
    if v_item.variant_id is null or v_item.quantity is null or v_item.quantity <= 0 then
      raise exception 'Nieprawidłowa pozycja w koszyku.';
    end if;

    -- Blokada wiersza magazynowego — to jest mechanizm przeciw race condition:
    -- jeśli dwóch klientów kupuje ostatnią sztukę jednocześnie, drugie
    -- zapytanie czeka tutaj, a po zwolnieniu blokady widzi już zaktualizowany
    -- (zmniejszony) stan i dostaje błąd zamiast podwójnej sprzedaży.
    select iv.quantity_on_hand into v_inv
      from inventory iv
      where iv.variant_id = v_item.variant_id
      for update;

    if not found then
      raise exception 'Jeden z produktów nie jest już dostępny.';
    end if;

    if v_inv.quantity_on_hand < v_item.quantity then
      raise exception 'Niektóre produkty przestały być dostępne w wybranej ilości.';
    end if;

    select p.id as product_id, p.name, p.sku, p.base_price, p.sale_price, p.is_active,
           pv.sku as variant_sku, pv.label as variant_label, pv.price_override
      into v_product
      from product_variants pv
      join products p on p.id = pv.product_id
      where pv.id = v_item.variant_id;

    if not found or not v_product.is_active then
      raise exception 'Jeden z produktów nie jest już dostępny.';
    end if;

    -- Cena ZAWSZE liczona tutaj z aktualnych danych produktu — nigdy z inputu.
    v_price := coalesce(
      v_product.price_override,
      case when v_product.sale_price is not null and v_product.sale_price < v_product.base_price
           then v_product.sale_price else v_product.base_price end
    );
    v_line_total := v_price * v_item.quantity;
    v_subtotal := v_subtotal + v_line_total;

    insert into tmp_order_items values (
      v_item.variant_id, v_product.product_id, v_product.name,
      coalesce(v_product.variant_sku, v_product.sku),
      v_price, v_item.quantity, v_line_total,
      jsonb_build_object(
        'product_id', v_product.product_id, 'name', v_product.name, 'sku', v_product.sku,
        'variant_label', v_product.variant_label, 'variant_sku', v_product.variant_sku,
        'unit_price', v_price, 'quantity', v_item.quantity
      )
    );

    update inventory
      set quantity_on_hand = quantity_on_hand - v_item.quantity, updated_at = now()
      where variant_id = v_item.variant_id;
  end loop;

  insert into orders (
    id, order_number, user_id, status, currency, subtotal, shipping_cost, total,
    payment_method, delivery_method, buyer_snapshot, shipping_address_snapshot,
    invoice_details_snapshot
  ) values (
    v_order_id, v_order_number, v_user_id, 'new', 'PLN', v_subtotal, coalesce(p_shipping_cost, 0),
    v_subtotal + coalesce(p_shipping_cost, 0), p_payment_method, p_delivery_option, p_buyer,
    p_shipping_address, p_invoice_details
  );

  insert into order_items (
    order_id, product_id, variant_id, product_name_snapshot, sku_snapshot,
    unit_price_snapshot, quantity, line_total, product_snapshot
  )
  select v_order_id, product_id, variant_id, name, sku, unit_price, quantity, line_total, snapshot
  from tmp_order_items;

  insert into order_status_history (order_id, from_status, to_status, changed_by, note)
    values (v_order_id, null, 'new', v_user_id, 'Zamówienie złożone przez klienta.');

  if v_user_id is not null then
    delete from cart_items where cart_id in (select id from carts where user_id = v_user_id);
  end if;

  return query select v_order_id, v_order_number;
end;
$$;

-- Wywoływane z frontendu (przez RPC) zarówno przez gościa, jak i zalogowanego.
grant execute on function create_order(jsonb, text, text, jsonb, jsonb, jsonb, numeric) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- admin_update_order_status — jedyna droga zmiany statusu zamówienia.
-- Uprawnienia sprawdzane TU, wewnątrz funkcji (obrona w głąb) — nie tylko
-- przez RLS na tabeli orders (pkt 52 wymagań: "RLS/backend musi również
-- blokować dostęp", nie tylko UI).
-- -----------------------------------------------------------------------------
create or replace function admin_update_order_status(
  p_order_id uuid,
  p_new_status order_status,
  p_note text default null,
  p_tracking_number text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_status order_status;
begin
  if not is_staff(auth.uid()) then
    raise exception 'Brak uprawnień do zmiany statusu zamówienia.';
  end if;

  select status into v_old_status from orders where id = p_order_id for update;
  if not found then
    raise exception 'Zamówienie nie istnieje.';
  end if;

  update orders set status = p_new_status, updated_at = now() where id = p_order_id;

  insert into order_status_history (order_id, from_status, to_status, changed_by, note)
    values (p_order_id, v_old_status, p_new_status, auth.uid(), p_note);

  if p_tracking_number is not null then
    insert into shipments (order_id, tracking_number, status)
      values (p_order_id, p_tracking_number, 'wyslano')
      on conflict (order_id) do update
        set tracking_number = excluded.tracking_number, status = excluded.status, updated_at = now();
  end if;

  insert into admin_logs (actor_id, action, entity_type, entity_id, before, after)
    values (
      auth.uid(), 'order_status_changed', 'order', p_order_id,
      jsonb_build_object('status', v_old_status),
      jsonb_build_object('status', p_new_status, 'note', p_note)
    );
end;
$$;

grant execute on function admin_update_order_status(uuid, order_status, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- admin_set_role — jedyna droga nadania/odebrania roli. Tylko admin.
-- Osobna funkcja zamiast bezpośredniego insert/delete z frontendu na
-- user_roles trzyma cały audyt nadawania uprawnień w jednym miejscu.
-- -----------------------------------------------------------------------------
create or replace function admin_set_role(p_target_user_id uuid, p_role app_role, p_grant boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_role(auth.uid(), 'admin') then
    raise exception 'Tylko administrator może zarządzać rolami.';
  end if;

  if p_grant then
    insert into user_roles (user_id, role) values (p_target_user_id, p_role)
      on conflict (user_id, role) do nothing;
  else
    delete from user_roles where user_id = p_target_user_id and role = p_role;
  end if;

  insert into admin_logs (actor_id, action, entity_type, entity_id, after)
    values (
      auth.uid(),
      case when p_grant then 'role_granted' else 'role_revoked' end,
      'user', p_target_user_id, jsonb_build_object('role', p_role)
    );
end;
$$;

grant execute on function admin_set_role(uuid, app_role, boolean) to authenticated;
