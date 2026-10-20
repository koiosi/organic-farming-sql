create or replace view mart.eu_comparison as
with merged as (
    select geo, country, year, organic_share, 'all_years' as source
    from mart.eu_latest
    union all
    select s.geo, s.country, s.year::int, s.organic_share::numeric, 'eu_comparison_export'
    from stg.eu_comparison s
    where s.geo not in (select geo from mart.eu_latest)
)
select geo, country, year, organic_share, source,
       rank() over (order by organic_share desc) as rank_share
from merged;

-- Reconciliation vs. R export
select count(*) as n,
       max(abs(m.organic_share - s.organic_share::numeric)) as max_abs_diff
from stg.eu_comparison s
join mart.eu_comparison m on m.geo = s.geo and m.year = s.year::int;
