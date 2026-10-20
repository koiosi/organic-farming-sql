# Organic Farming in Germany – SQL Analysis (PostgreSQL)


Deutsche Version: [README.de.md](README.de.md)

**Question:** Germany targets 30 % organic farmland by 2030. At 11.1 % in 2024, is it on track?
**Frage (DE):** Deutschland will bis 2030 30 % Ökolandbaufläche erreichen. Bei 11,1 % (2024): Ist das Ziel realistisch?

This project rebuilds the analysis of my companion project [organic-farming-dashboard](https://github.com/koiosi/organic-farming-dashboard) (R + Power BI) **in SQL** and verifies that SQL reproduces the R results.

## Approach
1. **Staging (`stg`)** – the six CSV exports of the R pipeline are loaded 1:1 as text (`load_data.py`, pandas + SQLAlchemy; `NA` → `NULL`).
2. **Analytics layer (`mart`)** – views that cast types and recompute all derived metrics from the raw columns:
   - `mart.de_overview`: average farm size, year-over-year change (`LAG`), gap to target
   - `mart.trajectory`: OLS trend 2014–2024 (`regr_slope`/`regr_intercept`) vs. the linear path needed to reach 30 % in 2030
   - `mart.producer_change`, `mart.eu_latest`, `mart.eu_comparison` (ranking with `RANK`, `DISTINCT ON`)
3. **Reconciliation** – every recomputed metric is compared to the value exported by R. Maximum absolute difference < 1e-12 for all checks (37 of 37 countries matched).

## Key findings (from `sql/04_queries.sql`)
- Gap to target 2024: 18.9 pp. Trend extrapolation for 2030: **14.5 %**.
- Historical pace 2014–2024: 0.49 pp/year; required: 3.15 pp/year (**6.4×** faster).
- 2024: −10.0 % holdings (−3,641) but only −0.5 % area; average farm size 56.0 ha → consolidation.
- Germany ranks 14th of 37 countries (latest available year per country; Austria 2020, most others 2024).
- Steepest decline in producers 2023→2024: Sweden −18.1 %, Turkey −13.7 %, Germany −10.0 %.

## Data notes
- 2023 shows holdings −0.6 % but area +13.4 %: suspected series break (see companion project), therefore excluded from the "consolidation" query.
- Five countries (AL, ME, MK, RS, UK) are not in `organic_share_all_years.csv`; they are added from the R comparison export (`source` column in `mart.eu_comparison`). Their country names are empty in the R export.
- Staging keeps all columns as text on purpose; type casts happen explicitly in the views.

## Reproduce
```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env      # set DATABASE_URL and DATA_DIR
python load_data.py         # drops and rebuilds stg (and mart)
psql -d portfolio -f sql\01_views_de.sql
psql -d portfolio -f sql\02_views_eu.sql
psql -d portfolio -f sql\03_views_eu_full.sql
psql -d portfolio -f sql\04_queries.sql
```
Requires PostgreSQL 15+ (developed on 18) and Python 3.12.

**Stack:** PostgreSQL, SQL (CTEs, window functions, `FILTER`, `DISTINCT ON`, regression aggregates), Python (pandas, SQLAlchemy, psycopg).
