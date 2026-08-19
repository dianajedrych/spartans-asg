# Spartans ASG — sklep

Sklep internetowy Spartans ASG. Jeden statyczny plik (`Spartans ASG.dc.html`) +
Supabase jako backend (baza danych, logowanie, pliki). Bez własnego serwera
i bez kroku budowania — plik jest hostowany bezpośrednio na GitHub Pages.

Panel administracyjny (do zarządzania produktami, zamówieniami, wydarzeniami
i galerią) to **osobna aplikacja**, w osobnym repozytorium:
[spartans-asg-admin](https://github.com/dianajedrych/spartans-asg-admin).

Instrukcja obsługi panelu dla właściciela sklepu — bez kodu, bez SQL — jest
w [ADMIN_GUIDE.md](ADMIN_GUIDE.md). Opis podejścia do bezpieczeństwa jest w
[SECURITY.md](SECURITY.md). Pełny opis architektury i decyzji projektowych
(dla programisty kontynuującego pracę) jest w [ARCHITECTURE.md](ARCHITECTURE.md).

## Stos technologiczny

- **Frontend**: `Spartans ASG.dc.html` — komponent klasowy React (bez JSX-a
  budowanego narzędziami; transpilacja przez Babel Standalone w przeglądarce,
  patrz `support.js`). Routing przez `#/...` w URL (hash), obsługiwany ręcznie.
- **Backend**: [Supabase](https://supabase.com) — PostgreSQL, Auth, Storage,
  Row Level Security. Konfiguracja połączenia (URL + publiczny klucz) jest w
  `supabase-config.js` — te wartości są **publiczne i bezpieczne**, prawdziwa
  ochrona danych jest w regułach RLS w bazie, nie w ukrywaniu klucza.
- **Hosting**: GitHub Pages, branch `main`, bez kroku budowania.

## Uruchomienie lokalne

Plik jest statyczny — wystarczy dowolny serwer plików, np.:

```bash
python -m http.server 8533
```

i otworzyć `http://localhost:8533/Spartans%20ASG.dc.html`.

## Baza danych

Migracje SQL są w `supabase/migrations/`, w kolejności numerycznej. Każda ma
komentarz na górze tłumaczący, co robi i dlaczego. Uruchamia się je ręcznie
przez **Supabase Dashboard → SQL Editor** (wklej zawartość pliku, uruchom) —
w kolejności od najstarszej.

Skrót zawartości:

| Plik | Co robi |
|---|---|
| `001_initial_schema.sql` | 24 tabele — produkty, zamówienia, wydarzenia, opinie (nieużywane, patrz niżej), galeria, role użytkowników, dziennik zmian... |
| `002_indexes.sql` | Indeksy pod najczęstsze zapytania. |
| `003_rls.sql` | Row Level Security — reguły dostępu na każdej tabeli. Patrz `SECURITY.md`. |
| `004_functions.sql` | Funkcje `create_order()` (atomowe składanie zamówień), `admin_update_order_status()`, `admin_set_role()`. |
| `005_triggers.sql` | Automatyczne slugi, ochrona pól moderacji opinii, generowanie SKU. |
| `006_seed.sql` | Prawdziwe dane startowe (39 produktów, kategorie, marki, wydarzenia archiwalne). |
| `007_admin_product_functions.sql` | `admin_create_product()` — tworzenie produktu z wariantami w jednej transakcji. |
| `008_storage.sql` | Buckety na zdjęcia (produkty, galeria, marki, wydarzenia) + reguły dostępu. |
| `010_reviews_insert_guard.sql` | Zabezpieczenie tabeli `reviews` przed samodzielnym publikowaniem/weryfikowaniem opinii. Tabela istnieje w schemacie, ale **funkcja opinii nie jest już używana** w sklepie ani w panelu (usunięta na prośbę właściciela) — migracja została mimo to zastosowana, bo naprawia realną lukę bezpieczeństwa niezależnie od tego, czy UI z niej korzysta. |

Uwaga: numeracja przeskakuje z `008` na `010` — plik `009` (rejestracja na
wydarzenia przez wewnętrzny formularz) został napisany, ale wycofany przed
zastosowaniem, bo zapisy na wydarzenia idą wyłącznie przez zewnętrzny link
(Google Forms) ustawiany w panelu admina.

## Pierwszy administrator

Nowe konto zawsze dostaje rolę `customer`. Nadanie roli `admin` pierwszej
osobie **musi** się odbyć ręcznie w Supabase (nie da się tego zrobić z
poziomu aplikacji — to celowe zabezpieczenie, patrz `SECURITY.md`):

1. Zarejestruj się normalnie w sklepie.
2. W Supabase Dashboard → **Table Editor** → tabela `user_roles` → **Insert row**:
   `user_id` = Twoje ID (znajdziesz w **Authentication → Users**), `role` = `admin`.

Od tego momentu możesz logować się tym kontem w panelu administracyjnym i
nadawać role innym osobom już z poziomu panelu (docelowo — obecnie zarządzanie
rolami innych osób nie ma jeszcze własnego ekranu w panelu, funkcja
`admin_set_role()` w bazie już na to pozwala).

## Wdrożenie

Push na `main` — GitHub Pages serwuje plik automatycznie. Czasem build w
GitHub Pages się zawiesza ("building" na dłużej niż minutę) — wtedy pomaga
ręczne wywołanie: `gh api -X POST repos/dianajedrych/spartans-asg/pages/builds`.
