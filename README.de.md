# Ökolandbau in Deutschland – SQL-Analyse (PostgreSQL)

[English version](README.md)

**Frage:** Deutschland will bis 2030 einen Anteil von 30 % Ökolandbaufläche erreichen. Bei 11,1 % im Jahr 2024: Ist das Ziel realistisch?

Dieses Projekt bildet die Analyse meines Begleitprojekts [organic-farming-dashboard](https://github.com/koiosi/organic-farming-dashboard) (R + Power BI) **in SQL** nach und prüft, ob SQL die R-Ergebnisse reproduziert.

## Vorgehen
1. **Staging (`stg`)** – Die sechs CSV-Exporte der R-Pipeline werden 1:1 als Text geladen (`load_data.py`, pandas + SQLAlchemy; `NA` → `NULL`).
2. **Analyseschicht (`mart`)** – Views, die Datentypen umwandeln und alle abgeleiteten Kennzahlen aus den Rohspalten neu berechnen:
   - `mart.de_overview`: durchschnittliche Betriebsgröße, Veränderung zum Vorjahr (`LAG`), Abstand zum Ziel
   - `mart.trajectory`: OLS-Trend 2014–2024 (`regr_slope`/`regr_intercept`) im Vergleich zum linearen Pfad, der für 30 % im Jahr 2030 nötig wäre
   - `mart.producer_change`, `mart.eu_latest`, `mart.eu_comparison` (Ranking mit `RANK`, `DISTINCT ON`)
3. **Abgleich** – Jede neu berechnete Kennzahl wird mit dem von R exportierten Wert verglichen. Maximale absolute Abweichung bei allen Prüfungen < 1e-12 (alle 37 Länder zugeordnet).

## Zentrale Ergebnisse (aus `sql/04_queries.sql`)
- Abstand zum Ziel 2024: 18,9 Prozentpunkte. Trendfortschreibung für 2030: **14,5 %**.
- Bisheriges Tempo 2014–2024: 0,49 Prozentpunkte pro Jahr; erforderlich: 3,15 Prozentpunkte pro Jahr (**6,4-fach**).
- 2024: −10,0 % Betriebe (−3.641) bei nur −0,5 % Fläche; durchschnittliche Betriebsgröße 56,0 ha → Konsolidierung statt Rückgang.
- Deutschland liegt auf Rang 14 von 37 Ländern (jeweils letzter verfügbarer Wert; Österreich 2020, die meisten anderen 2024).
- Stärkster Rückgang der Erzeuger 2023→2024: Schweden −18,1 %, Türkei −13,7 %, Deutschland −10,0 %.

## Hinweise zur Datenqualität
- 2023 zeigt −0,6 % Betriebe, aber +13,4 % Fläche: vermuteter Zeitreihenbruch (siehe Begleitprojekt); deshalb in der Konsolidierungs-Abfrage ausgeschlossen.
- Fünf Länder (AL, ME, MK, RS, UK) fehlen in `organic_share_all_years.csv`; sie werden aus dem R-Vergleichsexport ergänzt (Spalte `source` in `mart.eu_comparison`). Ihre Ländernamen sind im R-Export leer.
- Das Staging speichert alle Spalten bewusst als Text; Typumwandlungen erfolgen ausdrücklich in den Views.

## Reproduzieren
```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env      # DATABASE_URL und DATA_DIR setzen
python load_data.py         # löscht und baut stg (und mart) neu auf
psql -d portfolio -f sql\01_views_de.sql
psql -d portfolio -f sql\02_views_eu.sql
psql -d portfolio -f sql\03_views_eu_full.sql
psql -d portfolio -f sql\04_queries.sql
```
Voraussetzung: PostgreSQL 15+ (entwickelt mit 18) und Python 3.12.

**Technik:** PostgreSQL, SQL (CTEs, Fensterfunktionen, `FILTER`, `DISTINCT ON`, Regressionsaggregate), Python (pandas, SQLAlchemy, psycopg).