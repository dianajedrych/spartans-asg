-- =============================================================================
-- ETAP 12: opinie produktowe — domykamy dwie luki, które istniały w
-- oryginalnym schemacie (001/003/005), zanim front-end zaczął faktycznie
-- z tej tabeli korzystać:
--
-- 1) protect_review_moderation_fields() chronił tylko UPDATE. Przy INSERCIE
--    klient mógł wysłać status='published' i is_verified_purchase=true i to
--    by przeszło — RLS na insert sprawdza tylko user_id, nie te dwie
--    kolumny. Czyli klient mógłby sam sobie "opublikować" i "zweryfikować"
--    opinię. Ten sam błąd klasy, przed którym broni się create_order()
--    (nigdy nie ufaj klientowi w kwestii statusu/ceny).
-- 2) brak ograniczenia "jedna opinia na produkt na klienta" — bez tego
--    ten sam klient mógłby dodać tę samą opinię wielokrotnie.
-- =============================================================================

-- Jedna opinia na produkt na klienta.
alter table reviews add constraint reviews_user_product_unique unique (user_id, product_id);

-- Wyświetlana nazwa autora ("Jan K.") — zapisana na sztywno w wierszu opinii
-- w momencie dodania (ten sam wzorzec "snapshot", co buyer_snapshot przy
-- zamówieniach), bo RLS na "profiles" pozwala każdemu czytać TYLKO własny
-- profil — bez tej kolumny strona produktu (czytana też przez gości) nie
-- mogłaby w ogóle pokazać, kto napisał daną opinię.
alter table reviews add column author_name text;

create or replace function protect_review_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_verified boolean;
  v_first text;
  v_last text;
begin
  if tg_op = 'INSERT' then
    -- Nowa opinia zawsze trafia do moderacji jako "pending" — klient nie
    -- może samodzielnie opublikować własnej opinii, niezależnie od tego,
    -- co wyśle w zapytaniu.
    new.status := 'pending';

    -- "Zweryfikowany zakup" liczymy tutaj, po stronie serwera, na podstawie
    -- prawdziwej historii zamówień — nigdy nie ufamy wartości przysłanej
    -- przez klienta w insertcie.
    select exists (
      select 1
      from order_items oi
      join orders o on o.id = oi.order_id
      where o.user_id = new.user_id
        and oi.product_id = new.product_id
        and o.status not in ('cancelled', 'refunded')
    ) into v_verified;
    new.is_verified_purchase := coalesce(v_verified, false);

    -- Zapisujemy wyświetlaną nazwę autora ("Jan K.") raz, w momencie
    -- dodania — patrz komentarz przy `alter table reviews add column
    -- author_name` wyżej w tym pliku.
    select first_name, last_name into v_first, v_last from profiles where id = new.user_id;
    new.author_name := trim(
      coalesce(v_first, '') ||
      case when v_last is not null and length(v_last) > 0 then ' ' || left(v_last, 1) || '.' else '' end
    );
    if coalesce(new.author_name, '') = '' then
      new.author_name := 'Klient Spartans ASG';
    end if;

    return new;
  end if;

  -- UPDATE: te dwie kolumny zmienia wyłącznie obsługa (is_staff) — bez
  -- zmian względem oryginalnej wersji triggera.
  if not is_staff(auth.uid()) then
    new.status := old.status;
    new.is_verified_purchase := old.is_verified_purchase;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_review_moderation_fields on reviews;
create trigger trg_protect_review_moderation_fields
  before insert or update on reviews
  for each row execute function protect_review_moderation_fields();
