create schema if not exists mart;

-- Germany overview: derived metrics recomputed from raw columns
create or replace view mart.de_overview as
with base as (
    select year::int               as year,
           hectares::numeric       as hectares,
           n_farms::numeric        as n_farms,
           organic_share::numeric  as organic_share
    from stg.de_overview
),
tgt as (
    select value::numeric as target
    from stg.kpis
    where metric = 'target_2030'
)
select b.year,
       b.hectares,
       b.n_farms,
       b.organic_share,
       b.hectares / b.n_farms                           as avg_farm_size,
       100 * (b.hectares / lag(b.hectares) over w - 1)  as area_yoy_pct,
       100 * (b.n_farms  / lag(b.n_farms)  over w - 1)  as farms_yoy_pct,
       t.target - b.organic_share                       as gap_to_target
from base b
cross join tgt t
window w as (order by b.year);

-- Trend (OLS 2014-2024) vs. linear path required to reach the target in 2030
create or replace view mart.trajectory as
with fit as (
    select regr_slope(organic_share, year)     as slope,
           regr_intercept(organic_share, year) as intercept
    from mart.de_overview
    where year between 2014 and 2024
),
cur as (
    select year as y0, organic_share as s0
    from mart.de_overview
    order by year desc
    limit 1
),
tgt as (
    select value::numeric as target
    from stg.kpis
    where metric = 'target_2030'
)
select g.year,
       f.intercept + f.slope * g.year                              as projected,
       c.s0 + (t.target - c.s0) * (g.year - c.y0) / (2030 - c.y0)  as required
from fit f
cross join cur c
cross join tgt t
cross join lateral generate_series(c.y0, 2030) as g(year);

-- Reconciliation: SQL result vs. values exported by the R pipeline
select check_name, max_abs_diff, max_abs_diff < 1e-6 as ok
from (
    select 'avg_farm_size' as check_name,
           max(abs(m.avg_farm_size - s.avg_farm_size::numeric)) as max_abs_diff
    from mart.de_overview m join stg.de_overview s on s.year::int = m.year
    union all
    select 'area_yoy_pct',
           max(abs(m.area_yoy_pct - s.area_yoy_pct::numeric))
    from mart.de_overview m join stg.de_overview s on s.year::int = m.year
    union all
    select 'farms_yoy_pct',
           max(abs(m.farms_yoy_pct - s.farms_yoy_pct::numeric))
    from mart.de_overview m join stg.de_overview s on s.year::int = m.year
    union all
    select 'gap_to_target',
           max(abs(m.gap_to_target - s.gap_to_target::numeric))
    from mart.de_overview m join stg.de_overview s on s.year::int = m.year
    union all
    select 'trajectory_projected',
           max(abs(m.projected::numeric - s.projected::numeric))
    from mart.trajectory m join stg.trajectory s on s.year::int = m.year
    union all
    select 'trajectory_required',
           max(abs(m.required::numeric - s.required::numeric))
    from mart.trajectory m join stg.trajectory s on s.year::int = m.year
) c
order by check_name;
