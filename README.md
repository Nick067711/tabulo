# TabMath

Tabliczka mnożenia i podstawowe działania dla dzieci (6–10 lat). Wersja testowa.

Każde wgranie zmian do gałęzi `main` automatycznie buduje plik `tabmath-test.apk`
(zakładka **Actions**) i publikuje go w zakładce **Releases**.

## Instalacja na telefonie

1. Na telefonie otwórz stronę repozytorium → **Releases** → najnowsza wersja.
2. Pobierz `tabmath-test.apk` i otwórz pobrany plik.
3. Android zapyta o zgodę na instalację z tego źródła – zezwól (tylko dla przeglądarki lub menedżera plików).

## Struktura

- `lib/state.dart` – dane aplikacji i zapis w telefonie
- `lib/logic.dart` – losowanie zadań, formatowanie
- `lib/i18n.dart` – teksty (PL i EN pełne, DE/ES/FR/UK częściowo)
- `lib/ui.dart` – kolory i wspólne elementy (przyciski, klawiatura)
- `lib/screens/` – ekrany

## Podpis wersji testowych

`branding/test-signing/debug.keystore` to klucz tylko do wersji testowych: dzięki niemu każda nowa
wersja instaluje się na poprzedniej. Wersja do Google Play będzie podpisana osobnym, prywatnym kluczem.
