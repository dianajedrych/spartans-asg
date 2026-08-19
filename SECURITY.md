# Bezpieczeństwo

Ten dokument opisuje, jak sklep chroni dane, co zostało realnie przetestowane
i co trzeba zrobić przed prawdziwym uruchomieniem (nie testowym). Pisany dla
kogoś, kto przejmuje ten projekt później i chce wiedzieć, czemu ufać, a czego
jeszcze pilnować.

## Model bezpieczeństwa w jednym zdaniu

**Frontend (sklep i panel admina) nigdy nie jest granicą bezpieczeństwa —
granicą jest baza danych.** Oba frontendy używają publicznego klucza
Supabase (`sb_publishable_...`), który jest bezpieczny do trzymania w
kodzie — nie daje żadnych uprawnień sam z siebie. Każde zapytanie do bazy
przechodzi przez **Row Level Security (RLS)**, więc nawet gdyby ktoś ominął
całą aplikację i pisał zapytania ręcznie (co przetestowaliśmy — patrz niżej),
nie zrobi nic więcej niż to, na co pozwala RLS.

`service_role key` (klucz omijający RLS) **nigdy** nie trafia do żadnego
pliku wysyłanego do przeglądarki — nie ma go w żadnym z dwóch repozytoriów,
sprawdzone też w historii gita obu.

## Role i eskalacja uprawnień

Role (`customer` / `manager` / `admin`) siedzą w osobnej tabeli `user_roles`,
**celowo odklejonej** od `profiles`. Gdyby rola była kolumną w `profiles`
(tabeli, którą klient może edytować, żeby zmienić imię/telefon), klient
mógłby w tym samym zapytaniu dopisać `role: 'admin'` i sam sobie nadać
uprawnienia. `user_roles` ma RLS, które pozwala klientowi wyłącznie
**odczytać własną rolę** — żaden insert/update/delete z poziomu klienta nie
przechodzi, nawet bezpośrednim zapytaniem do bazy z pominięciem aplikacji.

Jedyna droga nadania/odebrania roli to funkcja `admin_set_role()`, która sama
sprawdza w środku, czy wywołujący ma rolę `admin` — nie polega wyłącznie na
tym, kto ją może w ogóle wywołać.

## Co jest realnie przetestowane (nie tylko przeczytane w kodzie)

W trakcie budowy założone zostało zwykłe konto klienckie (bez żadnych ról) i
wykonano żywe próby ataku bezpośrednio na API, z pominięciem obu aplikacji:

| Próba | Wynik |
|---|---|
| Nadanie sobie roli `admin` bezpośrednim zapisem do `user_roles` | ❌ zablokowane przez RLS |
| Nadanie sobie roli `admin` przez `admin_set_role()` | ❌ „Tylko administrator może zarządzać rolami” |
| Zmiana statusu cudzego zamówienia przez `admin_update_order_status()` | ❌ „Brak uprawnień do zmiany statusu zamówienia” |
| Odczyt cudzych zamówień | ❌ pusty wynik |
| Odczyt dziennika zmian administratora (`admin_logs`) | ❌ pusty wynik |
| Odczyt cudzego koszyka | ❌ pusty wynik |
| Wymuszenie `status='published'` / `is_verified_purchase=true` przy dodawaniu opinii | ❌ serwer i tak nadpisuje na `pending`/`false` |
| Zamówienie większej ilości produktu, niż jest na stanie | ❌ „Niektóre produkty przestały być dostępne w wybranej ilości” |
| Bezpośrednia zmiana ceny produktu | ❌ zablokowane przez RLS |
| Bezpośrednie podbicie stanu magazynowego | ❌ zablokowane przez RLS |
| Dodanie kategorii bezpośrednim zapytaniem | ❌ zablokowane przez RLS |
| Wywołanie `admin_create_product()` bez roli obsługi | ❌ „Brak uprawnień do dodawania produktów” |

## Ceny i stan magazynowy — zawsze liczone po stronie serwera

Koszyk w przeglądarce liczy sumy tylko do **wyświetlenia**. Prawdziwe
zamówienie powstaje przez funkcję `create_order()` (`SECURITY DEFINER`),
która:

- **nigdy nie przyjmuje ceny z frontendu** — sama ją odczytuje z aktualnych
  danych produktu w momencie składania zamówienia (klient wysyła tylko
  `variant_id` i `quantity`);
- blokuje wiersz magazynowy (`SELECT ... FOR UPDATE`) na czas sprawdzania i
  aktualizacji stanu, więc dwóch klientów kupujących jednocześnie ostatnią
  sztukę nie może obu „przejść” (klasyczny race condition, sprawdzone też
  ręcznie z równoległymi zamówieniami);
- zapisuje migawkę (`*_snapshot`) nazwy/ceny/SKU produktu w momencie
  zamówienia, więc historia zamówień pozostaje poprawna, nawet jeśli produkt
  później zmieni cenę albo zostanie usunięty.

## Opinie produktowe — luka znaleziona i naprawiona

Tabela `reviews` istnieje w schemacie, ale funkcja opinii **nie jest już
używana** w sklepie ani w panelu (usunięta na prośbę właściciela — patrz
`ARCHITECTURE.md`). Migracja `010_reviews_insert_guard.sql` naprawia mimo to
realną lukę, na wypadek gdyby tabela była kiedyś znów wykorzystana: bez niej
trigger chronił tylko `UPDATE`, nie `INSERT` — klient mógłby przy dodawaniu
opinii wysłać wprost `status: 'published'` i `is_verified_purchase: true`.
Po naprawie serwer zawsze wymusza `status = 'pending'` i sam liczy
„zweryfikowany zakup” z prawdziwej historii zamówień.

## Panel administracyjny

Ochrona jest dwuwarstwowa:

1. **UI**: `ProtectedRoute` w panelu sprawdza realną rolę z bazy (`user_roles`
   przez `is_staff`), nie stan czysto po stronie przeglądarki — konto bez
   roli widzi ekran „Brak dostępu”, nie sam panel.
2. **RLS**: nawet gdyby ktoś ominął panel i wysyłał zapytania bezpośrednio,
   każda tabela wymaga `is_staff(auth.uid())` do zapisu.

Panel nigdy nie pokazuje właścicielowi surowych błędów technicznych — każdy
błąd zapisu ma zrozumiały, polski komunikat, a surowy szczegół trafia
wyłącznie do konsoli deweloperskiej (znaleziony i naprawiony jeden wyjątek od
tej zasady w edytorze wydarzeń podczas audytu).

## Znane elementy do zrobienia przed prawdziwym uruchomieniem

Te dwie rzeczy są celowe i tymczasowe — służą wygodnemu testowaniu, nie są
przeoczeniem:

1. **Potwierdzenie e-maila jest wyłączone** w Supabase (Authentication →
   Providers → Email → „Confirm email”). Trzeba je włączyć z powrotem przed
   prawdziwym uruchomieniem sklepu — wymaga to też skonfigurowania
   prawdziwego SMTP (domyślny limit Supabase na wysyłkę e-maili jest bardzo
   niski i nie nadaje się do produkcji).
2. **Oba repozytoria (sklep i panel) są publiczne na GitHub.** To nie jest
   luka bezpieczeństwa — prawdziwą ochroną danych jest RLS, nie ukrywanie
   kodu źródłowego — ale jeśli właściciel wolałby, żeby kod nie był publicznie
   widoczny, można ustawić oba repozytoria jako prywatne w ustawieniach GitHub.
