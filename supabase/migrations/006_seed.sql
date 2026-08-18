-- =============================================================================
-- SPARTANS ASG — 006_seed.sql
-- Dane startowe zmigrowane z dzisiejszego hardcoded stanu strony
-- (Spartans ASG.dc.html). Patrz ARCHITECTURE.md sekcja 10 — co jest tu
-- prawdziwą migracją, a co zostaje jawnie oznaczone jako TODO.
--
-- Bezpieczne do uruchomienia RAZ na świeżej bazie. Nie uruchamiaj drugi raz
-- bez wyczyszczenia tabel — nie ma tu ON CONFLICT DO NOTHING wszędzie.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Kategorie — 10 głównych + podkategorie (2 poziomy, jak w subcategoriesMap).
-- Slug generowany automatycznie triggerem (005).
-- -----------------------------------------------------------------------------
insert into categories (name, sort_order) values
  ('Repliki ASG', 1),
  ('Magazynki', 2),
  ('Części wewnętrzne', 3),
  ('Taktyka', 4),
  ('Optyka', 5),
  ('Baterie i zasilanie', 6),
  ('Kulki ASG', 7),
  ('Odzież i ochrona', 8),
  ('Chemia i konserwacja', 9),
  ('Promocje', 10);

insert into categories (parent_id, name, sort_order)
select c.id, x.name, x.ord
from categories c
join (values
  ('Repliki ASG', 'AEG', 1), ('Repliki ASG', 'GBB', 2), ('Repliki ASG', 'CO2', 3), ('Repliki ASG', 'Sprężynowa', 4),
  ('Magazynki', 'Magazynki M4', 1), ('Magazynki', 'Magazynki pistoletowe', 2), ('Magazynki', 'Magazynki snajperskie', 3),
  ('Części wewnętrzne', 'Hop-Up', 1), ('Części wewnętrzne', 'Cylindry i głowice cylindra', 2),
  ('Części wewnętrzne', 'Koła zębate i łożyska', 3), ('Części wewnętrzne', 'Tłoki i głowice tłoków', 4),
  ('Części wewnętrzne', 'Dysze', 5),
  ('Taktyka', 'Kamizelki taktyczne', 1), ('Taktyka', 'Hełmy', 2), ('Taktyka', 'Ładownice', 3), ('Taktyka', 'Torby i pokrowce', 4),
  ('Optyka', 'Montaże', 1),
  ('Baterie i zasilanie', 'Akumulatory', 1),
  ('Kulki ASG', 'Bio', 1), ('Kulki ASG', 'Tracer', 2),
  ('Odzież i ochrona', 'Hełmy', 1),
  ('Chemia i konserwacja', 'Smarowanie', 1), ('Chemia i konserwacja', 'Czyszczenie', 2)
) as x (parent_name, name, ord) on c.name = x.parent_name and c.parent_id is null;

-- -----------------------------------------------------------------------------
-- Marki — 23, tak jak this.shopBrands. Logo: TODO, właściciel dodaje w
-- /admin/brands.
-- -----------------------------------------------------------------------------
insert into brands (name) values
  ('8Fields'), ('ASG'), ('Abbey'), ('AirsoftPro'), ('BLS'), ('Battleaxe'), ('CYMA'),
  ('Double Bell'), ('Element'), ('Emerson Gear'), ('FMA'), ('G&G'), ('GFC Tactical'),
  ('Geoffs'), ('JAG Arms'), ('KWC'), ('Maple Leaf'), ('NOVUS'), ('SHS'), ('Specna Arms'),
  ('Theta Optics'), ('Tokyo Marui'), ('WELL');

-- -----------------------------------------------------------------------------
-- Pomocnicza funkcja tylko na potrzeby tego seeda: znajduje kategorię-liść po
-- (kategoria główna, podkategoria) albo samą kategorię główną, gdy podkategorii
-- nie ma.
-- -----------------------------------------------------------------------------
create or replace function seed_resolve_category_id(p_top text, p_sub text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  if p_sub is not null then
    select c.id into v_id
      from categories c
      join categories parent on parent.id = c.parent_id
      where c.name = p_sub and parent.name = p_top;
  else
    select id into v_id from categories where name = p_top and parent_id is null;
  end if;
  return v_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Produkty — 30 pozycji, 1:1 z this.products w Spartans ASG.dc.html.
--
-- Mapowanie cen: stary model miał "price" (cena bieżąca) + "oldPrice" (cena
-- przed obniżką, tylko gdy promo=true). Nowy model ma base_price + sale_price
-- (sale_price musi być <= base_price). Gdzie oldPrice istniał: base_price =
-- oldPrice, sale_price = price. Gdzie nie: base_price = price, sale_price = null.
--
-- "Kompatybilność" z opisu produktu -> product_specifications (prawdziwa dana,
-- nie wymyślona). Waga kulek (Kulki ASG) -> też specyfikacja, nie osobna kolumna
-- (to dokładnie przypadek użycia z pkt 8: dowolny parametr bez zmiany schematu).
--
-- Pełny marketingowy opis (description) NIE jest migrowany 1:1 — w oryginale
-- to był identyczny, powtarzalny szablon jawnie oznaczony jako "Wersja
-- demonstracyjna do testowego sklepu internetowego" na każdym produkcie, więc
-- nie ma sensu przepisywać go jako prawdziwej treści. short_description
-- zostaje wypełniony, pełny opis to TODO do napisania przez właściciela w
-- kreatorze produktu (KROK 5).
-- -----------------------------------------------------------------------------
do $$
declare
  v_row record;
  v_product_id uuid;
  v_variant_id uuid;
  v_variant_label text;
  v_first_variant boolean;
  v_base numeric;
  v_sale numeric;
begin
  for v_row in
    select * from (values
      -- old_slug, name, brand, top_cat, sub_cat, weight_g, price, old_price, compat, variants, bestseller, is_new, stock
      ('replika-m4-cqb-0001', 'Replika M4 CQB', 'CYMA', 'Repliki ASG', 'AEG', null, 499.99, 549.99, 'M4 / STANAG', 'Czarny', false, true, 3),
      ('replika-aks47-0005', 'Replika AKS47', 'G&G', 'Repliki ASG', 'AEG', null, 399.99, 439.99, 'AK / AKS', 'Czarny,oliwkowy', true, false, 15),
      ('replika-hi-capa-combat-0006', 'Replika Hi-Capa Combat', 'WELL', 'Repliki ASG', 'GBB', null, 399.99, 439.99, 'Hi-Capa', 'Czarny', false, false, 24),
      ('replika-pistoletu-co2-0007', 'Replika pistoletu CO2', 'Tokyo Marui', 'Repliki ASG', 'CO2', null, 299.99, 329.99, 'Dedykowany magazynek CO2', 'Czarny', false, false, 7),
      ('magazynek-mid-cap-do-m4-0011', 'Magazynek Mid-Cap do M4', 'Battleaxe', 'Magazynki', 'Magazynki M4', null, 44.99, null, '120', 'Czarny', true, true, 19),
      ('gumka-hop-up-80-0020', 'Gumka Hop-Up 80°', 'Maple Leaf', 'Części wewnętrzne', 'Hop-Up', null, 30.99, null, 'VSR / GBB', 'Czarny', false, true, 35),
      ('cylinder-typu-1-0021', 'Cylinder typu 1', 'Element', 'Części wewnętrzne', 'Cylindry i głowice cylindra', null, 69.99, null, 'AEG', 'Srebrny', false, false, 21),
      ('kamizelka-plate-carrier-0026', 'Kamizelka Plate Carrier', 'Specna Arms', 'Taktyka', 'Kamizelki taktyczne', null, 199.99, null, 'MOLLE', 'Ranger Green', true, true, 16),
      ('helm-taktyczny-fast-0032', 'Hełm taktyczny FAST', 'Emerson Gear', 'Taktyka', 'Hełmy', null, 169.99, null, 'Uniwersalny', 'Multicam', true, true, 17),
      ('offsetowy-montaz-latarki-0037', 'Offsetowy montaż latarki', 'NOVUS', 'Optyka', 'Montaże', null, 74, null, 'RIS 22 mm', 'Czarny', true, true, 35),
      ('akumulator-lipo-11-1v-1300-mah-0041', 'Akumulator LiPo 11.1V 1300 mAh', 'Specna Arms', 'Baterie i zasilanie', 'Akumulatory', null, 99.99, null, 'AEG', 'Czarny', false, false, 22),
      ('kulki-bio-0-25-g-1-kg-0043', 'Kulki BIO 0.25 g 1 kg', 'BLS', 'Kulki ASG', 'Bio', '0.25', 59.99, null, '6 mm', 'Białe', false, false, 20),
      ('kulki-tracer-0-25-g-0046', 'Kulki tracer 0.25 g', 'Geoffs', 'Kulki ASG', 'Tracer', '0.25', 69.99, null, '6 mm / tracer', 'Zielone', false, false, 18),
      ('helm-fast-0048', 'Hełm FAST', 'Emerson Gear', 'Odzież i ochrona', 'Hełmy', null, 169.99, null, 'Uniwersalny', 'Czarny', false, false, 2),
      ('smar-silikonowy-0051', 'Smar silikonowy', 'Abbey', 'Chemia i konserwacja', 'Smarowanie', null, 24.99, null, 'Konserwacja', 'Bezbarwny', false, false, 11),
      ('preparat-do-czyszczenia-repliki-0052', 'Preparat do czyszczenia repliki', 'GFC Tactical', 'Chemia i konserwacja', 'Czyszczenie', null, 29.99, 34.49, 'Konserwacja', 'Bezbarwny', false, true, 23),
      ('replika-ak-tactical-standard-0056', 'Replika AK Tactical Standard', 'Specna Arms', 'Repliki ASG', 'AEG', null, 449.99, 494.99, 'AK', 'Czarny', false, true, 9),
      ('replika-aks47-gen-2-0057', 'Replika AKS47 Gen.2', 'JAG Arms', 'Repliki ASG', 'AEG', null, 399.99, 439.99, 'AK / AKS', 'Czarny,oliwkowy', false, false, 29),
      ('replika-pistoletu-co2-black-0059', 'Replika pistoletu CO2 Black', 'WELL', 'Repliki ASG', 'CO2', null, 299.99, null, 'Dedykowany magazynek CO2', 'Czarny', false, false, 29),
      ('magazynek-do-hi-capa-v2-0065', 'Magazynek do Hi-Capa V2', 'CYMA', 'Magazynki', 'Magazynki pistoletowe', null, 79.99, 87.99, '31', 'Czarny', false, true, 17),
      ('zestaw-kol-zebatych-tactical-0067', 'Zestaw kół zębatych Tactical', 'AirsoftPro', 'Części wewnętrzne', 'Koła zębate i łożyska', null, 89.99, 103.49, 'V2 / V3', 'Stal', false, true, 26),
      ('gumka-hop-up-70-gen-2-0071', 'Gumka Hop-Up 70° Gen.2', 'AirsoftPro', 'Części wewnętrzne', 'Hop-Up', null, 30.99, 35.64, 'VSR / GBB', 'Czarny', false, false, 19),
      ('gumka-hop-up-80-v2-0072', 'Gumka Hop-Up 80° V2', 'AirsoftPro', 'Części wewnętrzne', 'Hop-Up', null, 30.99, null, 'VSR / GBB', 'Czarny', false, false, 20),
      ('tlok-14-zebow-tactical-0074', 'Tłok 14 zębów Tactical', 'SHS', 'Części wewnętrzne', 'Tłoki i głowice tłoków', null, 59.99, 68.99, 'Gearbox V2', 'Czarny', false, false, 28),
      ('dysza-uszczelniona-pro-0075', 'Dysza uszczelniona Pro', 'Maple Leaf', 'Części wewnętrzne', 'Dysze', null, 29.99, 34.49, 'M4 AEG', 'Czarny', false, false, 28),
      ('kamizelka-plate-carrier-gen-2-0078', 'Kamizelka Plate Carrier Gen.2', 'FMA', 'Taktyka', 'Kamizelki taktyczne', null, 199.99, null, 'MOLLE', 'Ranger Green', false, false, 31),
      ('ladownica-uniwersalna-tactical-0081', 'Ładownica uniwersalna Tactical', 'GFC Tactical', 'Taktyka', 'Ładownice', null, 49.99, 54.99, 'MOLLE', 'Coyote', false, true, 28),
      ('pokrowiec-na-replike-compact-0083', 'Pokrowiec na replikę Compact', '8Fields', 'Taktyka', 'Torby i pokrowce', null, 149.99, null, 'Repliki długie', 'Czarny', false, false, 11),
      ('helm-taktyczny-fast-standard-0084', 'Hełm taktyczny FAST Standard', 'Specna Arms', 'Taktyka', 'Hełmy', null, 169.99, 195.49, 'Uniwersalny', 'Multicam', false, true, 15),
      ('wysoki-montaz-optyki-tactical-0088', 'Wysoki montaż optyki Tactical', 'Theta Optics', 'Optyka', 'Montaże', null, 31.99, 35.19, 'RIS 22 mm', 'Czarny', false, false, 34),
      ('akumulator-lipo-11-1v-1300-mah-v2-0093', 'Akumulator LiPo 11.1V 1300 mAh V2', 'Specna Arms', 'Baterie i zasilanie', 'Akumulatory', null, 99.99, 109.99, 'AEG', 'Czarny', false, false, 18),
      ('replika-ar15-rifle-gen-2-0106', 'Replika AR15 Rifle Gen.2', 'ASG', 'Repliki ASG', 'AEG', null, 649.99, 714.99, 'M4 / STANAG', 'Czarny', false, false, 30),
      ('replika-ar15-carbine-v2-0107', 'Replika AR15 Carbine V2', 'JAG Arms', 'Repliki ASG', 'AEG', null, 729.99, null, 'M4 / STANAG', 'FDE', false, false, 8),
      ('replika-hi-capa-combat-pro-0110', 'Replika Hi-Capa Combat Pro', 'ASG', 'Repliki ASG', 'GBB', null, 399.99, null, 'Hi-Capa', 'Czarny', false, false, 6),
      ('replika-pistoletu-co2-compact-0111', 'Replika pistoletu CO2 Compact', 'Double Bell', 'Repliki ASG', 'CO2', null, 299.99, null, 'Dedykowany magazynek CO2', 'Czarny', false, true, 16),
      ('replika-sniper-rifle-gen-2-0113', 'Replika Sniper Rifle Gen.2', 'Tokyo Marui', 'Repliki ASG', 'Sprężynowa', null, 449.99, 517.49, 'VSR / dedykowane', 'Czarny', true, false, 19),
      ('magazynek-hi-cap-do-m4-v2-0114', 'Magazynek Hi-Cap do M4 V2', 'Battleaxe', 'Magazynki', 'Magazynki M4', null, 49.99, 54.99, '300', 'Czarny', true, true, 22),
      ('metalowy-magazynek-low-cap-compact-0118', 'Metalowy magazynek low-cap Compact', 'KWC', 'Magazynki', 'Magazynki snajperskie', null, 47.99, 52.79, '25', 'Czarny', true, false, 33),
      ('zestaw-kol-zebatych-standard-0119', 'Zestaw kół zębatych Standard', 'Element', 'Części wewnętrzne', 'Koła zębate i łożyska', null, 89.99, 98.99, 'V2 / V3', 'Stal', false, false, 18)
    ) as t (old_slug, name, brand, top_cat, sub_cat, weight_g, price, old_price, compat, variants_csv, bestseller, is_new, stock)
  loop
    v_base := coalesce(v_row.old_price, v_row.price);
    v_sale := case when v_row.old_price is not null and v_row.old_price > v_row.price then v_row.price else null end;

    insert into products (
      slug, name, short_description, brand_id, category_id,
      base_price, sale_price, is_bestseller, is_new
    ) values (
      v_row.old_slug, v_row.name, v_row.name || ' marki ' || v_row.brand || '.',
      (select id from brands where name = v_row.brand),
      seed_resolve_category_id(v_row.top_cat, v_row.sub_cat),
      v_base, v_sale, v_row.bestseller, v_row.is_new
    )
    returning id into v_product_id;

    -- Kompatybilność jako prawdziwa specyfikacja (nie wymyślona — z opisu produktu).
    insert into product_specifications (product_id, spec_name, spec_value, sort_order)
      values (v_product_id, 'Kompatybilność', v_row.compat, 1);

    if v_row.weight_g is not null then
      insert into product_specifications (product_id, spec_name, spec_value, spec_unit, sort_order)
        values (v_product_id, 'Waga kulki', v_row.weight_g, 'g', 2);
    end if;

    -- Warianty: dokładnie te etykiety, które miał produkt w starych danych
    -- (np. "Czarny,oliwkowy" -> 2 warianty). Trigger ensure_default_variant
    -- widzi już >=1 wariant w tej samej transakcji, więc nie dokłada "Standard".
    v_first_variant := true;
    foreach v_variant_label in array string_to_array(v_row.variants_csv, ',')
    loop
      insert into product_variants (product_id, label)
        values (v_product_id, v_variant_label)
        returning id into v_variant_id;

      -- Cały stan z danych startowych trafia na PIERWSZY wariant (tak jak w
      -- starym modelu, gdzie stan był wspólny dla produktu, nie per wariant).
      -- Właściciel może później rozbić stan po wariantach w panelu.
      if v_first_variant then
        update inventory set quantity_on_hand = v_row.stock where variant_id = v_variant_id;
        v_first_variant := false;
      end if;
    end loop;
  end loop;
end $$;

drop function seed_resolve_category_id(text, text);

-- -----------------------------------------------------------------------------
-- Wydarzenia — "Niedzielne U3" (cykliczne) + 4 archiwalne. Treść narracyjna
-- "Korengal" i regulamin "U3" trafiają do events.content jako jsonb (patrz
-- ARCHITECTURE.md sekcja 4.3) — to jest ta sama treść, która dziś jest na
-- stronie, nie wymyślona.
-- -----------------------------------------------------------------------------
insert into events (name, short_description, event_date, location, status, content) values
  (
    'Niedzielne U3',
    'Cotygodniowa rozgrywka dla graczy każdego poziomu. Dobra okazja, żeby wpaść na swoją pierwszą grę.',
    null, -- data cykliczna, TODO: właściciel ustawia najbliższy termin w panelu
    'Wszystkie poziomy',
    'published',
    jsonb_build_object(
      'intro', 'Zapraszamy na cotygodniowe U3.',
      'cennik', jsonb_build_array('z własnym sprzętem 40 zł', 'z wypożyczonym 100 zł', 'wypożyczenie stalkera / okularów +10 zł'),
      'wejsciowka', 'W cenie wejściówki: kiełba z grilla + woda.',
      'platnosc', 'Płatność: gotówka i BLIK.'
    )
  );

insert into events (name, event_date, status, content) values
  ('Niedzielne U3 — 09.08.2026', '2026-08-09', 'closed',
    jsonb_build_object('desc', 'Cotygodniowa rozgrywka terenowa U3 z udziałem graczy różnych poziomów. Dobra frekwencja, kilka nowych twarzy i tradycyjna Giełda ASG po grze.')),
  ('Korengal – edycja III', '2026-06-01', 'closed',
    jsonb_build_object('desc', 'Trzydniowy milsim Korengal w swojej trzeciej edycji — rozbudowane frakcje, nocne akcje i pełna obsługa organizacyjna na terenie wydarzenia.',
                         'miejsce', 'Kamieniołom Józefów + las.')),
  ('Pokaz ASG – Dni Lublina', '2026-05-01', 'closed',
    jsonb_build_object('desc', 'Pokaz sprzętu i rozgrywki ASG zorganizowany podczas miejskiej imprezy Dni Lublina — prezentacja replik, strefa bezpiecznego strzelania i rozmowy z mieszkańcami zainteresowanymi hobby.')),
  ('Niedzielne U3 — 02.08.2026', '2026-08-02', 'closed',
    jsonb_build_object('desc', 'Kolejna edycja Niedzielnego U3 — pogoda dopisała, teren w dobrym stanie po pracach porządkowych z poprzedniego tygodnia.'));

-- Zdjęcia wydarzeń: TODO — dzisiejsze zdjęcia archiwalne są syntetyczne
-- (placeholdery), właściciel wgrywa prawdziwe przez panel /admin/events.

-- -----------------------------------------------------------------------------
-- Galeria — 4 albumy z dzisiejszych danych. Zdjęcia w środku: TODO (dziś
-- generowane syntetycznie, nie ma prawdziwych plików per zdjęcie w albumie —
-- tylko okładki, patrz sekcja "Zdjęcia" w odpowiedzi na pytania w czacie).
-- -----------------------------------------------------------------------------
insert into gallery_albums (name, sort_order) values
  ('Niedzielne U3 – 09.08.2026', 1),
  ('Korengal – edycja III', 2),
  ('Event / pokaz – Dni Lublina', 3),
  ('Inne wydarzenia', 4);

-- -----------------------------------------------------------------------------
-- Pierwszy administrator — NIE da się zrobić w SQL, bo trzeba najpierw
-- prawdziwego konta Supabase Auth. Instrukcja krok po kroku jest w README.md
-- ("Tworzenie pierwszego administratora"), skrót:
--   1. Zarejestruj się normalnie w sklepie (dostaniesz rolę "customer").
--   2. W Supabase Dashboard -> Table Editor -> user_roles -> wstaw ręcznie
--      wiersz: user_id = Twoje id z auth.users, role = 'admin'.
--   3. Od tego momentu logujesz się do panelu /admin tym samym kontem.
-- -----------------------------------------------------------------------------
