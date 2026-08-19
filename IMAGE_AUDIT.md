# SPARTANS ASG — Audyt systemu zdjęć

**Data:** 2026-08-19
**Zakres:** pełny przepływ zdjęć ADMIN → UPLOAD → STORAGE → DATABASE → FRONTEND → LISTA → SZCZEGÓŁY → KLIENT, dla produktów, wydarzeń i galerii.

Ten dokument opisuje, co faktycznie sprawdzono (nie co "powinno działać"), jakie błędy znaleziono, jaka była ich przyczyna źródłowa i jaka naprawa została zastosowana — oraz co zweryfikowano po naprawie, żywym testem, a nie odczytem kodu.

---

## Ustalenie kluczowe (przyczyna źródłowa wszystkich błędów z sekcji "PRODUKTY" i "WYDARZENIA")

`<image-slot>` to mechanizm **wyłącznie edytora Claude Design**. Jego zapis (plik `.image-slots.state.json`) idzie przez `window.omelette.writeFile` — most, który istnieje tylko w środowisku edytora, nigdy na realnie wdrożonej stronie statycznej (GitHub Pages). Skutek: **każdy `<image-slot>` na żywej stronie zawsze pokazywał tylko placeholder, niezależnie od tego, co administrator wgrał** — potok admin → upload → Storage → baza działał poprawnie, ale front sklepu w ogóle nie czytał `product_images` ani `cover_image_storage_path`. To tłumaczy też powtarzające się przez cały projekt błędy 404 dla `.image-slots.state.json` w konsoli.

Naprawa (zastosowana dla każdego miejsca z realnym, dynamicznym zdjęciem): policzyć `hasImage`/`imageUrl` raz, centralnie w JS, i w szablonie owinąć `<image-slot>` parą `sc-if` — `hasImage` renderuje prawdziwy `<img src="...">`, `!hasImage` renderuje oryginalny `<image-slot>` jako fallback, gdy zdjęcia jeszcze nie ma.

---

## Tabela wyników

| Test | Wynik | Problem | Lokalizacja | Naprawione |
|---|---|---|---|---|
| Zdjęcie produktu — lista sklepu, polecane, karta | PASS | `<image-slot>` nigdy nie renderuje realnej treści na wdrożonej stronie | `Spartans ASG.dc.html` — `loadCatalog()` + siatka produktów, home, ulubione, porównanie, koszyk, powiązane, upsell | TAK |
| Zdjęcie produktu — szczegóły (hero + 2 miniatury) | PASS | j.w. | product detail template | TAK |
| Zdjęcie okładkowe wydarzenia (ogólny szablon `eventDetail`) | PASS | j.w. | event detail template | TAK |
| Zdjęcie "Niedzielne U3" — karta na liście wydarzeń i strona dedykowana | PASS | Strona U3 jest w pełni hardkodowana (`isU3`) i nigdy nie czytała `events.cover_image_storage_path` — mimo że realne zdjęcie zostało już wgrane przez administratora w panelu | `nearestEvent`/`u3` w renderVals, `event-u3-img`, `u3-hero` | TAK |
| Wyścig `initSupabase()` nadpisujący klienta w trakcie zapytania | PASS | `initSupabase()` bezwarunkowo tworzył nowego klienta Supabase, nawet gdy `loadCatalog`/`loadEvents`/`loadGallery` już z niego korzystały — mogło to dawać zapytania bez sesji dla zalogowanego pracownika | `initSupabase()` | TAK |
| Statyczne, niesterowane z panelu zdjęcia (Korengal hero/miniatura, mapa dojazdu, O nas) | PASS | Te same puste `<image-slot>` — nigdy nie mogły pokazać realnej treści | 4 miejsca w `Spartans ASG.dc.html` | TAK |
| Izolacja albumów galerii (Korengal / Dni Lublina / Inne wydarzenia / Niedzielne U3) | PASS | — | `gallery_images` + Storage `albums/{id}/...` | NIE DOTYCZY |
| Placeholder przy braku zdjęcia (produkt bez zdjęcia, album bez zdjęć) | PASS | — | siatka produktów (41 z 43 produktów wciąż bez realnego zdjęcia), album "Niedzielne U3" (0 zdjęć) | NIE DOTYCZY |
| RLS Storage — anonimowy zapis do `product-images`/`gallery-images`/`event-images` | PASS | — | `008_storage.sql` polityki | NIE DOTYCZY |
| RLS Storage — anonimowe usunięcie/nadpisanie istniejącego pliku | PASS | — | j.w. | NIE DOTYCZY |
| RLS Storage — publiczny odczyt pozostaje możliwy | PASS | — | j.w. | NIE DOTYCZY |
| Limit rozmiaru / typu pliku na poziomie Storage | WARNING | Buckety nie miały `file_size_limit`/`allowed_mime_types` — jedyną "walidacją" był `accept="image/*"` w panelu (tylko podpowiedź przeglądarki, nie zabezpieczenie) | `008_storage.sql`, `ProductWizard.tsx` | CZĘŚCIOWO (migracja `011_storage_limits.sql` gotowa, czeka na uruchomienie przez właściciela w SQL Editor — nie mam uprawnień service_role, by uruchomić ją sam) |
| Rozmiar wgrywanych zdjęć (wydajność) | PASS | Oryginalne pliki z aparatu do 27 MB | pipeline resize (Pillow, max 1600px, JPEG q82) | TAK — dla wszystkich 21 zdjęć wgranych w tym audycie |
| Bezpośrednia dostępność URL Storage | PASS | — | `product-images`, `gallery-images`, `event-images` | NIE DOTYCZY |
| Alt-text z realnej nazwy, nie z nazwy pliku | PASS | — | wszystkie `<img alt="...">` | NIE DOTYCZY |
| Lazy loading | WARNING → PASS | Żaden z 17 dynamicznych `<img>` nie miał `loading="lazy"` | wszystkie miejsca poza hero produktu (LCP) i lightboxem | TAK |
| Spójność bazy — osierocone rekordy / osierocone pliki | PASS | — | patrz raport niżej | NIE DOTYCZY |
| Duplikaty, przerwane wgrania, edycja współbieżna | NOT APPLICABLE | Nie odtworzono w tej sesji warunków wyścigu/przerwania sieci na żywo — brak narzędzia do symulacji przerwanego uploadu w tym środowisku | — | NIE DOTYCZY |
| Stare/istniejące produkty (sprzed audytu) — edytowalność | NOT APPLICABLE | Nie retestowano w tej sesji edycji istniejącego produktu przez kreator — funkcja była już zweryfikowana we wcześniejszym etapie projektu (ETAP 15), nie powtórzono tu żywego testu | `ProductWizard.tsx` | NIE DOTYCZY |
| Cache/CDN po podmianie zdjęcia | NOT APPLICABLE | Nie sprawdzono nagłówków `Cache-Control` w tej sesji; podmiana zdjęcia i tak generuje nową, unikalną nazwę pliku (znacznik czasu), więc naturalnie omija problem starego cache pod tym samym URL — ale to nie zostało potwierdzone bezpośrednim pomiarem nagłówków w tej sesji | Storage | NIE DOTYCZY |
| Logo w wysokiej rozdzielczości (`logo.jpg`) | WARNING | Plik JPG bez przezroczystości — użycie zamiast obecnego przezroczystego PNG w nagłówku złamałoby wygląd na ciemnym tle | — | ŚWIADOMIE POMINIĘTE (decyzja, nie błąd) |

---

## Szczegóły najważniejszych testów

### 1. Zdjęcia produktów — pełny przepływ

**CO SPRAWDZONO:** czy zdjęcie wgrane przez administratora (Storage + `product_images`) faktycznie pojawia się na każdej stronie sklepu, gdzie produkt jest pokazywany.

**JAK SPRAWDZONO:** dwa realne, wcześniej istniejące rekordy `product_images` (wgrane organicznie przez administratora, nie przeze mnie) — `curl -sI` na ich publiczne URL-e Storage zwróciło `200 OK`. Przed naprawą front nigdy nie czytał tej tabeli. Po naprawie: `javascript_tool` → `document.querySelectorAll('img')` na stronie głównej, `/shop`, stronie produktu — realne URL-e Supabase (`.../product-images/products/.../....png`) obecne w DOM z poprawnym `alt` (nazwa produktu).

**WYNIK:** przed naprawą — 0 zdjęć produktowych widocznych gdziekolwiek na stronie. Po naprawie — oba realne zdjęcia widoczne w siatce sklepu i na stronie szczegółów.

**EWENTUALNY BŁĄD:** `loadCatalog()` nie pobierał `product_images` w zapytaniu Supabase; szablon renderował wyłącznie `<image-slot>`.

**NAPRAWA:** rozszerzono `select` o `product_images (storage_path, is_primary, sort_order)`, policzono `hasImage`/`imageUrl`/`galleryUrls` raz w reshape'ie, przekazano dalej przez `cartItems`, `favoriteProducts`, `compareProducts` (jawne literały obiektowe — trzeba było dopisać pola ręcznie), `selectedProduct` (spread). 12 miejsc w szablonie zamienione na wzorzec `sc-if hasImage/img` + `sc-if !hasImage/image-slot`.

### 2. Zdjęcia wydarzeń — ogólny szablon i "Niedzielne U3"

**CO SPRAWDZONO:** zdjęcie okładkowe wydarzenia (`events.cover_image_storage_path`) na liście wydarzeń i stronie szczegółów — zarówno dla wydarzeń korzystających z generycznego szablonu, jak i dla "Niedzielne U3", które ma własną, dedykowaną, hardkodowaną stronę.

**JAK SPRAWDZONO:** znaleziono realny rekord w bazie — wydarzenie "Niedzielne U3 - 23.08.2026" miało już ustawiony `cover_image_storage_path` (`events/041361ad.../cover-1787069951366.jpg`, `curl -sI` → `200 OK`), wgrany wcześniej przez administratora przez panel. Sprawdzono `javascript_tool` na `#/events` i `#/u3` po nawigacji przez realne kliknięcie w nawigację (nie hash-only routing).

**WYNIK:** przed naprawą — zdjęcie nigdzie się nie pojawiało, mimo że istniało w bazie i w Storage. Po naprawie — widoczne zarówno na karcie "Niedzielne U3" na liście wydarzeń (`event-u3-img`), jak i na hero dedykowanej strony (`u3-hero`).

**EWENTUALNY BŁĄD:** strona "Niedzielne U3" (`isU3`) jest w pełni hardkodowana od ETAP 11 (własna, bogata strona zamiast generycznego szablonu) i nigdy nie czytała `cover_image_storage_path` swojego rekordu w `events`. To osobny błąd od ogólnego problemu `<image-slot>` — dotyczy konkretnie tej jednej, specjalnej strony.

**NAPRAWA:** `nearestEvent` i `u3` w renderVals doczytują teraz `dbEvents.find(slug === 'niedzielne-u3')` i liczą `hasImage`/`imageUrl` z jego `cover_image_storage_path`, dokładnie jak `eventDetail`. `event-u3-img` i `u3-hero` owinięte wzorcem `sc-if hasImage/img`.

**UWAGA POZA ZAKRESEM TEGO AUDYTU:** ta sama strona `isU3` ma też **całkowicie hardkodowaną treść zakładek** (opis, sprzęt, mapa, limity, bezpieczeństwo) — nie czyta `events.content.tabs`, mimo że funkcja edycji zakładek w panelu (dodana w tej samej turze zmian co ten audyt) zapisuje właśnie tam. To znaczy, że **jeśli administrator edytuje zakładki "Niedzielne U3" w panelu, zmiany nigdy się nie pojawią na stronie** — ale to błąd treści/architektury strony, nie systemu zdjęć, więc zgodnie z zasadą "nie naprawiaj w ciemno / nie rozszerzaj zakresu" nie został tu naprawiony. Wymaga osobnej decyzji właściciela (czy warto przepisać stronę U3 na generyczny szablon, czy ręcznie zsynchronizować treść).

### 3. Statyczne zdjęcia bez powiązania z panelem (Korengal hero, mapa dojazdu, O nas)

**CO SPRAWDZONO:** cztery miejsca w kodzie, które nigdy nie były podpięte pod żaden rekord bazy — to stałe, jednorazowe zdjęcia strony (nie są edytowalne z panelu administratora).

**JAK SPRAWDZONO:** wgrano realne zdjęcia (tytułowa plansza "KORENGAL", zdjęcie lotnicze terenu jako mapa dojazdu, zdjęcie wnętrza sklepu) do bucketu `gallery-images` pod prefiksem `site/` (RLS na tym buckecie nie ogranicza ścieżki, tylko `is_staff`). `curl -sI` → `200 OK` dla wszystkich trzech plików. Podmieniono `<image-slot>` na `<img>` z twardo wpisanym publicznym URL-em Storage. Zweryfikowano `javascript_tool` po realnej nawigacji do `#/events` → klik "KORENGAL" → klik zakładki "MAPA", oraz `#/about`.

**WYNIK:** wszystkie 4 miejsca renderują realne zdjęcia, zweryfikowane bezpośrednim odczytem `<img src>` w DOM.

**NAPRAWA:** ponieważ to zdjęcia stałe, niesterowane z panelu (w odróżnieniu od produktów/wydarzeń), zastosowano najprostszą bezpieczną naprawę — bezpośredni `<img src="https://.../storage/v1/object/public/...">`, bez wzorca `hasImage` (nie ma tu dynamicznego stanu do sprawdzenia).

### 4. Bezpieczeństwo — RLS i polityki Storage dla zdjęć

**CO SPRAWDZONO:** czy niezalogowany/niebędący pracownikiem użytkownik może wgrać, nadpisać lub usunąć zdjęcie w którymkolwiek z 4 bucketów (`product-images`, `gallery-images`, `event-images`, `brand-logos`), oraz czy odczyt publiczny nadal działa.

**JAK SPRAWDZONO:** żywe zapytania `curl` z kluczem publicznym (`sb_publishable_...`) bez sesji administratora — POST (upload), DELETE, PUT (nadpisanie) na istniejący, realny plik.

**WYNIK:**
```
POST product-images (anon)  → 403 "new row violates row-level security policy"
POST gallery-images (anon)  → 403 (jw.)
POST event-images (anon)    → 403 (jw.)
DELETE istniejącego pliku   → 403 (jw.)
PUT (nadpisanie) pliku      → 403 (jw.)
GET tego samego pliku       → 200 OK (odczyt publiczny działa)
```
Wgrania przez konto ze sesją `is_staff` (rzeczywiste 21 zdjęć wgranych w tym audycie) — wszystkie `200`/`201`.

**EWENTUALNY BŁĄD:** brak.

**NAPRAWA:** nie dotyczy — polityki z `008_storage.sql` działają zgodnie z projektem.

### 5. Limit rozmiaru i typu pliku (WARNING, częściowo naprawione)

**CO SPRAWDZONO:** czy Storage sam odrzuca zbyt duże lub nie-obrazkowe pliki.

**JAK SPRAWDZONO:** przegląd `008_storage.sql` — buckety tworzone bez `file_size_limit`/`allowed_mime_types`. Przegląd `ProductWizard.tsx` — jedyna walidacja to atrybut `accept="image/*"` na `<input type="file">`, który jest tylko podpowiedzią przeglądarki (użytkownik może wybrać "Wszystkie pliki" i wgrać cokolwiek).

**WYNIK:** administrator (nie klient sklepu — to nie jest luka bezpieczeństwa w sensie ataku z zewnątrz, bo tylko `is_staff` może w ogóle wgrywać) mógłby przez pomyłkę wgrać plik 200 MB albo plik niebędący zdjęciem, i Storage by to przyjął bez ostrzeżenia.

**NAPRAWA:** napisano `supabase/migrations/011_storage_limits.sql` — ustawia `file_size_limit = 10 MB` i `allowed_mime_types` (jpeg/png/webp/gif) na wszystkich 4 buckietach. **Migracja nie została jeszcze uruchomiona na żywej bazie** — zmiana konfiguracji bucketu wymaga uprawnień `service_role`, których celowo nie ma w żadnym repozytorium ani w tej sesji (patrz `SECURITY.md`). Właściciel musi ją uruchomić ręcznie przez Supabase Dashboard → SQL Editor, tak jak wszystkie pozostałe migracje.

### 6. Spójność bazy — osierocone rekordy i pliki

**CO SPRAWDZONO:** czy każdy rekord `product_images`/`gallery_images` wskazuje na realnie istniejący plik w Storage, i odwrotnie.

**JAK SPRAWDZONO:** pobrano pełną listę `storage_path` z `product_images` (2 rekordy) i `gallery_images` (18 rekordów, po tym audycie) przez REST API, oraz `cover_image_storage_path` z `events` i `gallery_albums`. Każdy z wgranych w tym audycie plików potwierdzony `200 OK` przez bezpośredni `curl` na publiczny URL.

**WYNIK:** brak osieroconych rekordów bazy (każdy `storage_path` wskazuje na realnie wgrany plik) i brak osieroconych plików w Storage (każdy plik wgrany w tym audycie ma odpowiadający rekord w `product_images`/`gallery_images` albo jest świadomym plikiem statycznym pod `site/`, nieprzypisanym do żadnej tabeli, bo z założenia nie jest edytowalny z panelu).

**NAPRAWA:** nie dotyczy.

### 7. Lazy loading

**CO SPRAWDZONO:** czy zdjęcia poza pierwszym ekranem mają `loading="lazy"`.

**JAK SPRAWDZONO:** przegląd wszystkich 17 dynamicznych `<img>` w pliku — żaden nie miał atrybutu `loading`.

**WYNIK PRZED NAPRAWĄ:** 0 z 17 dynamicznych `<img>` miało lazy loading.

**NAPRAWA:** dodano `loading="lazy"` do 20 znaczników `<img>` (17 dynamicznych + 3 z 4 statycznych, które nie miały go jeszcze z poprzedniej naprawy), świadomie pomijając: główne zdjęcie hero na stronie szczegółów produktu (pierwszy ekran, LCP) oraz zdjęcie w lightboxie (zawsze otwierane na żądanie, ma być widoczne natychmiast). Zweryfikowano `javascript_tool` → `img.loading === "lazy"` na żywej stronie po zmianie.

---

## Podsumowanie danych wgranych w tym audycie

21 realnych zdjęć (z folderu `C:\Users\Diana\Desktop\asg\`), zmniejszonych do max. 1600px (dłuższy bok), JPEG q82 (Pillow) przed wgraniem:

- **13 zdjęć** → album galerii "Korengal – edycja III" (12 zdjęć z gry + 1 plansza tytułowa jako okładka).
- **3 zdjęcia** → album "Event / pokaz – Dni Lublina" (zdjęcia z widocznym logo Spartans ASG na targach).
- **2 zdjęcia** → album "Inne wydarzenia" (zimowe zdjęcie grupowe Niedzielne U3 — świadomie NIE wrzucone do albumu "Niedzielne U3 – 09.08.2026", bo pokazuje śnieg, niespójne z sierpniową datą tego albumu; zdjęcie sprzętu do wypożyczenia).
- **1 zdjęcie** (plansza "KORENGAL") → dodatkowo wykorzystane jako statyczne hero/miniatura na stronach wydarzenia Korengal.
- **1 zdjęcie** (mapa lotnicza) → statyczna mapa dojazdu na stronie Korengal.
- **1 zdjęcie** (wnętrze sklepu) → statyczne zdjęcie na stronie "O nas".
- **1 zdjęcie** (`logo.jpg`) → **świadomie pominięte** — JPG bez przezroczystości, złamałby wygląd nagłówka na ciemnym tle w miejscu obecnego przezroczystego PNG.

Wszystkie okładki albumów (`Korengal`, `Dni Lublina`, `Inne wydarzenia`) ustawione. Album "Niedzielne U3 – 09.08.2026" pozostał z 0 zdjęć (celowo — brak zdjęcia pasującego do tej konkretnej daty) i poprawnie pokazuje placeholder zamiast błędu.

---

## Checklist końcowy

### PRODUKTY
- [x] Upload działa (Storage + `product_images`)
- [x] Zdjęcie faktycznie trafia do Storage
- [x] Rekord faktycznie trafia do bazy
- [x] Podgląd w panelu admina pokazuje realne zdjęcie
- [x] Lista produktów w sklepie pokazuje realne zdjęcie
- [x] Karta produktu (siatka) pokazuje realne zdjęcie
- [x] Strona szczegółów produktu pokazuje realne zdjęcie (hero + miniatury)
- [x] Zdjęcie główne (primary) wybierane poprawnie
- [x] Podmiana zdjęcia działa (nowa nazwa pliku przy każdym wgraniu)
- [x] Usunięcie zdjęcia działa (`removeExistingImage` w panelu)
- [x] Kolejność zdjęć (`sort_order`) respektowana przy renderze
- [ ] Cache po podmianie zdjęcia — NIE ZWERYFIKOWANO bezpośrednim pomiarem nagłówków w tej sesji
- [x] Responsywność mobilna (zweryfikowano na viewport 375×812, brak przepełnienia poziomego, `object-fit:cover` bez deformacji)
- [x] Placeholder przy braku zdjęcia (41 z 43 starych produktów wciąż poprawnie pokazuje `<image-slot>`)

### WYDARZENIA
- [x] Upload działa (Storage + `events.cover_image_storage_path`)
- [x] Zdjęcie trafia do Storage (bucket `event-images`)
- [x] Rekord trafia do bazy
- [x] Podgląd w panelu admina
- [x] Lista wydarzeń pokazuje realne zdjęcie (generyczne wydarzenia + "Niedzielne U3")
- [x] Strona szczegółów wydarzenia pokazuje realne zdjęcie (generyczny szablon + dedykowana strona "Niedzielne U3" + dedykowana strona "Korengal")
- [x] Podmiana zdjęcia (nowa nazwa pliku ze znacznikiem czasu)
- [x] Usunięcie zdjęcia
- [x] Zakładki (Cennik, Mapa, Co w cenie, Wymogi bezpieczeństwa) renderują się z `events.content.tabs` dla generycznych wydarzeń — **poza stronami specjalnymi (Korengal, Niedzielne U3), które mają własną, hardkodowaną treść zakładek (poza zakresem tego audytu, patrz sekcja 2)**

### BEZPIECZEŃSTWO
- [x] RLS/polityki Storage sprawdzone żywym atakiem, nie tylko odczytem kodu
- [x] Klient (anon) nie może wgrać zdjęcia do żadnego z 4 bucketów — potwierdzone 403
- [x] Klient (anon) nie może usunąć ani nadpisać istniejącego zdjęcia — potwierdzone 403
- [x] Dostęp administratora do wgrywania faktycznie działa — potwierdzone 21 udanymi wgraniami w tej sesji
- [ ] Limit rozmiaru/typu pliku na poziomie Storage — WARNING, migracja gotowa (`011_storage_limits.sql`), nieuruchomiona (wymaga `service_role`, którego ta sesja celowo nie ma)

### JAKOŚĆ
- [x] Brak złamanych zdjęć (broken images) na żadnej sprawdzonej stronie po naprawie
- [x] Brak osieroconych rekordów w bazie
- [x] Brak osieroconych plików w Storage (spośród wgranych w tym audycie)
- [x] Poprawne URL-e (publiczne, `getPublicUrl`, zgodne z modelem bezpieczeństwa opisanym w `SECURITY.md`)
- [ ] Cache — nie zmierzono bezpośrednio nagłówków w tej sesji (patrz wyżej)
- [x] Brak przesunięcia layoutu (kontenery mają stały `height`/`width` niezależnie od tego, czy renderuje się `<img>` czy `<image-slot>`)
- [x] Brak deformacji zdjęć (`object-fit: cover` wszędzie, zweryfikowane na desktop i mobile)
