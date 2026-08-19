# Instrukcja obsługi panelu — Spartans ASG

Ta instrukcja jest dla Ciebie, właścicielko/właścicielu sklepu. Nie znajdziesz
tu żadnego kodu ani skomplikowanych słów — tylko to, co klikasz i gdzie.

Panel jest pod adresem: **https://dianajedrych.github.io/spartans-asg-admin/**

Warto dodać tę stronę do zakładek w przeglądarce.

---

## 1. Logowanie

1. Wejdź na adres panelu.
2. Wpisz e-mail i hasło konta, na które nadano Ci dostęp administratora.
3. Kliknij **ZALOGUJ SIĘ**.

Jeśli zobaczysz komunikat **„Brak dostępu”** — logujesz się poprawnym kontem,
ale to konto nie ma jeszcze uprawnień administratora. Skontaktuj się z osobą,
która prowadzi techniczną stronę sklepu.

Po lewej stronie panelu masz zawsze widoczne menu: **Pulpit, Produkty,
Zamówienia, Wydarzenia, Galeria, Ustawienia**, a na samym dole przycisk
**Wyloguj się**.

---

## 2. Pulpit — pierwsza strona po zalogowaniu

Od razu widzisz cztery liczby:

- **Nowe zamówienia** — ile zamówień czeka na Twoją reakcję.
- **Wszystkie zamówienia** — ile zamówień w sumie kiedykolwiek wpłynęło.
- **Aktywne produkty** — ile produktów jest widocznych w sklepie.
- **Wszystkie produkty** — łącznie z ukrytymi.

Jeśli jakiś produkt kończy się na stanie, zobaczysz żółte pole **„⚠️ Wymaga
uwagi”** z przyciskiem **ZOBACZ**, który od razu pokaże listę tych produktów.

Niżej masz szybki skrót: **+ DODAJ PRODUKT** i **Zobacz produkty**.

---

## 3. Produkty

### Jak dodać nowy produkt

1. Kliknij **Produkty** w menu, potem **+ DODAJ PRODUKT** (albo od razu z Pulpitu).
2. Panel przeprowadzi Cię przez 8 kroków. Na górze zawsze widzisz, na którym
   kroku jesteś i co jeszcze zostało.

**Krok 1 — Zdjęcie i nazwa.** Wpisz nazwę produktu i dodaj zdjęcia (przycisk
**+ DODAJ**). Możesz dodać kilka zdjęć — pierwsze będzie zdjęciem głównym.

**Krok 2 — Kategoria.** Wybierz kategorię i (jeśli się pojawi) rodzaj. Potem
wybierz markę:
- jeśli marka jest już na liście — po prostu ją wybierz;
- jeśli **nie ma jej na liście** — wybierz **„+ Dodaj nową markę…”** na
  samym dole listy i wpisz nazwę. Panel sam ją utworzy przy zapisie, nie
  musisz nic więcej robić.

Pole **SKU** (kod produktu) możesz zostawić puste — system wygeneruje go sam.

**Krok 3 — Cena.** Wpisz cenę. Jeśli produkt ma być w promocji, zaznacz
„Produkt w promocji” i wpisz niższą cenę promocyjną.

**Krok 4 — Magazyn.** Wpisz, ile sztuk masz na stanie, oraz próg, przy którym
chcesz dostać ostrzeżenie o niskim stanie (domyślnie 3).

**Krok 5 — Opis.** Krótki opis (jedno zdanie, widoczne na liście produktów)
i pełny opis (widoczny na stronie produktu).

**Krok 6 — Parametry.** Opcjonalne — np. FPS, Hop-Up, waga. Kliknij
**+ DODAJ PARAMETR** dla każdego kolejnego.

**Krok 7 — Ustawienia.** Trzy przełączniki: „Produkt polecany” (wyróżniony w
sklepie), „Produkt 18+” (pokazuje ostrzeżenie wiekowe), „Produkt widoczny w
sklepie” (odznacz, żeby zapisać produkt, ale go jeszcze nie publikować).

**Krok 8 — Podgląd.** Zobaczysz, jak produkt będzie wyglądał. Na dole masz
dwa przyciski:
- **ZAPISZ WERSJĘ ROBOCZĄ** — zapisuje produkt, ale nie pokazuje go klientom;
- **🚀 OPUBLIKUJ** — zapisuje i publikuje od razu.

### Jak edytować istniejący produkt

Na liście produktów kliknij **EDYTUJ** przy produkcie — otworzy się ten sam
8-krokowy kreator, wypełniony obecnymi danymi.

### Jak ukryć produkt (bez usuwania)

Na liście produktów kliknij **Ukryj** przy produkcie i potwierdź. Produkt
zniknie ze sklepu, ale zostanie w systemie — możesz go w każdej chwili znów
pokazać przyciskiem **Pokaż**.

### Jak znaleźć produkt

Na górze listy masz:
- pole **🔍 Szukaj produktu** — szuka po nazwie, kodzie i marce;
- rozwijaną listę **kategorii** i **marek** — zawężają listę do wybranej;
- przyciski **Wszystkie / Aktywne / Ukryte / Niski stan / Brak magazynu** —
  filtrują po stanie produktu.

Filtry można łączyć — np. wybrać kategorię „Repliki ASG” i jednocześnie
filtr „Niski stan”, żeby zobaczyć tylko repliki, które trzeba domówić.

---

## 4. Zamówienia

### Jak wygląda lista

Na górze masz zakładki: **Wszystkie, 🟢 Nowe, 🟡 W realizacji, 📦 Spakowane,
🚚 Wysłane, ✅ Dostarczone, ❌ Anulowane** — przy każdej widzisz liczbę
zamówień w tym stanie. Jest też wyszukiwarka po numerze zamówienia, imieniu,
nazwisku lub e-mailu.

### Jak obsłużyć zamówienie krok po kroku

Kliknij na zamówienie z listy. Zobaczysz dane klienta, zamówione produkty,
sposób dostawy i płatności oraz historię statusów.

Na dole jest sekcja **ZMIEŃ STATUS** z **jednym przyciskiem** — panel sam
wie, jaki jest następny krok:

1. **🟢 Nowe** → przycisk **PRZEKAŻ DO REALIZACJI**
2. **🟡 W realizacji** → przycisk **OZNACZ JAKO SPAKOWANE**
3. **📦 Spakowane** → pole na **numer przesyłki** (opcjonalne) + przycisk
   **OZNACZ JAKO WYSŁANE**
4. **🚚 Wysłane** → przycisk **OZNACZ JAKO DOSTARCZONE**

Po dotarciu do „Dostarczone” zamówienie jest zamknięte — klient widzi całą
tę oś czasu na swoim koncie w sklepie.

W statusach **Nowe** i **W realizacji** masz też przycisk **ANULUJ
ZAMÓWIENIE** (z potwierdzeniem — nie da się kliknąć przez pomyłkę).

---

## 5. Wydarzenia

### Jak dodać nowe wydarzenie

1. **Wydarzenia** → **+ DODAJ WYDARZENIE**.
2. Wypełnij prosty formularz (jedna strona, bez kroków):

- **Nazwa wydarzenia** (wymagane) — np. „Niedzielne U3 — 23.08.2026”.
- **Zdjęcie** — okładka wydarzenia.
- **Krótki opis** — kilka zdań widocznych na liście i stronie wydarzenia.
- **Data i godzina** — zostaw puste, jeśli wydarzenie jest cykliczne bez
  ustalonego terminu.
- **Miejsce**.
- **Limit miejsc** — zostaw puste, jeśli nie ma limitu.
- **Link do zapisów** — wklej tu link do formularza Google, przez który
  ludzie się zapisują. **To jedyny sposób zapisu** — przycisk „Zapisz się”
  na stronie zawsze otwiera ten link. Jeśli zostawisz puste, klienci zobaczą
  informację, że link pojawi się wkrótce — możesz go dodać później.
- **Zakładki** — tu dodajesz dowolną liczbę dodatkowych sekcji, które pojawią
  się na stronie wydarzenia jako osobne przyciski, np. „Cennik”, „Co w
  cenie”, „Mapa”, „Wymogi bezpieczeństwa”. Kliknij **+ DODAJ ZAKŁADKĘ**,
  wpisz nazwę zakładki i jej treść. Możesz dodać ich tyle, ile potrzebujesz,
  i usunąć (🗑️) te, które nie są już potrzebne.
- **Status** — tylko **🟢 Opublikowane** jest widoczne dla klientów na liście
  najbliższych wydarzeń:
  - **📝 Szkic** — niewidoczne, wciąż pracujesz nad treścią;
  - **🟢 Opublikowane** — widoczne i aktywne;
  - **⚪ Zakończone** — trafia do archiwum wydarzeń;
  - **❌ Odwołane**.

3. Kliknij **DODAJ WYDARZENIE**.

### Jak edytować wydarzenie

Na liście wydarzeń kliknij **EDYTUJ** — ten sam formularz, wypełniony
obecnymi danymi. Np. kiedy zbliża się kolejna niedziela, wejdź w istniejące
wydarzenie cykliczne i po prostu zaktualizuj datę.

### Jak usunąć wydarzenie

Na liście kliknij **Usuń** przy wydarzeniu.

---

## 6. Galeria

Galeria to albumy ze zdjęciami — każdy album to jedno wydarzenie lub temat.

### Dodanie nowego albumu

1. **Galeria** → wpisz nazwę w polu **„Nowy album”** → **+ DODAJ ALBUM**.

### Wgrywanie zdjęć

1. Kliknij **ZARZĄDZAJ ZDJĘCIAMI** przy albumie.
2. W sekcji **„Dodaj zdjęcia”** wybierz plik (możesz zaznaczyć kilka naraz).
3. Poczekaj, aż napis „Wgrywanie...” zniknie — zdjęcia pojawią się na liście.

### Podpis, okładka, usuwanie zdjęć

- Pod każdym zdjęciem możesz wpisać **podpis** — zapisuje się automatycznie,
  kiedy klikniesz gdzie indziej.
- **„Ustaw jako okładkę”** — to zdjęcie będzie widoczne na liście albumów w
  sklepie.
- **„Usuń”** — usuwa zdjęcie (z potwierdzeniem).

### Zmiana nazwy i usuwanie albumu

Na liście albumów: **„Zmień nazwę”** albo **„Usuń album”** (usuwa cały album
razem ze wszystkimi zdjęciami — z potwierdzeniem).

---

## 7. Wylogowanie

Przycisk **Wyloguj się** jest zawsze widoczny na dole lewego menu.

---

## 8. Jeśli coś nie działa

- **Strona pokazuje pustą listę tam, gdzie coś powinno być** — odśwież
  stronę (klawisz F5 albo strzałka odświeżania w przeglądarce). Czasem
  wystarczy chwilę odczekać.
- **Widzisz komunikat o błędzie zapisu** — sprawdź, czy wszystkie wymagane
  pola są uzupełnione, i spróbuj ponownie. Panel nigdy nie pokazuje
  technicznych błędów — jeśli coś wygląda dziwnie/niepolsko, daj znać osobie,
  która prowadzi techniczną stronę sklepu.
- **Zapomniałaś/eś hasła** — na stronie logowania nie ma jeszcze przycisku
  resetu hasła w panelu; napisz do osoby prowadzącej techniczną stronę
  sklepu, żeby pomogła zresetować hasło przez Supabase.
