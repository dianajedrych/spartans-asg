-- =============================================================================
-- SPARTANS ASG — 007_admin_product_functions.sql
-- Panel administratora, ETAP 6: tworzenie produktu.
--
-- Dlaczego osobna funkcja RPC zamiast zwykłych insertów z panelu:
-- product_variants ma trigger "ensure_default_variant" (005_triggers.sql),
-- odroczony do końca TRANSAKCJI — jeśli admin doda produkt i jego warianty
-- osobnymi zapytaniami REST (każde to inna transakcja), trigger zdąży
-- dopisać niechciany wariant "Standard" zanim właściwe warianty w ogóle
-- trafią do bazy. Ta funkcja wstawia produkt + warianty + specyfikacje w
-- jednej transakcji, więc trigger poprawnie widzi już realne warianty.
--
-- Edycja istniejącego produktu (zmiana ceny, ukrycie, dodanie zdjęcia,
-- doprecyzowanie stanu) NIE ma tego problemu i może iść zwykłymi
-- zapytaniami REST z panelu — RLS z 003_rls.sql już to pozwala tylko
-- obsłudze (is_staff).
-- =============================================================================

create or replace function admin_create_product(
  p_name text,
  p_slug text default null,
  p_sku text default null,
  p_short_description text default null,
  p_description text default null,
  p_brand_id uuid default null,
  p_category_id uuid default null,
  p_base_price numeric default null,
  p_sale_price numeric default null,
  p_is_active boolean default true,
  p_is_featured boolean default false,
  p_is_18_plus boolean default false,
  p_is_bestseller boolean default false,
  p_is_new boolean default false,
  p_variants jsonb default null, -- [{"label":"Czarny","sku":null,"price_override":null,"quantity":10}, ...]
  p_specifications jsonb default null -- [{"spec_name":"FPS","spec_value":"350","spec_unit":"FPS"}, ...]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id uuid;
  v_variant jsonb;
  v_variant_id uuid;
  v_spec jsonb;
begin
  if not is_staff(auth.uid()) then
    raise exception 'Brak uprawnień do dodawania produktów.';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Nazwa produktu jest wymagana.';
  end if;
  if p_base_price is null or p_base_price < 0 then
    raise exception 'Podaj poprawną cenę.';
  end if;
  if p_sale_price is not null and p_sale_price > p_base_price then
    raise exception 'Cena promocyjna nie może być wyższa niż cena podstawowa.';
  end if;

  insert into products (
    name, slug, sku, short_description, description, brand_id, category_id,
    base_price, sale_price, is_active, is_featured, is_18_plus, is_bestseller, is_new, created_by
  ) values (
    trim(p_name), nullif(trim(coalesce(p_slug, '')), ''), nullif(trim(coalesce(p_sku, '')), ''),
    p_short_description, p_description, p_brand_id, p_category_id,
    p_base_price, p_sale_price, p_is_active, p_is_featured, p_is_18_plus, p_is_bestseller, p_is_new, auth.uid()
  ) returning id into v_product_id;

  if p_variants is not null and jsonb_array_length(p_variants) > 0 then
    for v_variant in select * from jsonb_array_elements(p_variants)
    loop
      insert into product_variants (product_id, label, sku, price_override)
        values (
          v_product_id,
          coalesce(nullif(v_variant ->> 'label', ''), 'Standard'),
          nullif(v_variant ->> 'sku', ''),
          nullif(v_variant ->> 'price_override', '')::numeric
        )
        returning id into v_variant_id;
      update inventory set quantity_on_hand = coalesce((v_variant ->> 'quantity')::int, 0)
        where variant_id = v_variant_id;
    end loop;
  end if;

  if p_specifications is not null and jsonb_array_length(p_specifications) > 0 then
    for v_spec in select * from jsonb_array_elements(p_specifications)
    loop
      if coalesce(v_spec ->> 'spec_name', '') <> '' and coalesce(v_spec ->> 'spec_value', '') <> '' then
        insert into product_specifications (product_id, spec_name, spec_value, spec_unit)
          values (v_product_id, v_spec ->> 'spec_name', v_spec ->> 'spec_value', nullif(v_spec ->> 'spec_unit', ''));
      end if;
    end loop;
  end if;

  insert into admin_logs (actor_id, action, entity_type, entity_id, after)
    values (auth.uid(), 'product_created', 'product', v_product_id, jsonb_build_object('name', p_name));

  return v_product_id;
end;
$$;

grant execute on function admin_create_product(
  text, text, text, text, text, uuid, uuid, numeric, numeric,
  boolean, boolean, boolean, boolean, boolean, jsonb, jsonb
) to authenticated;
