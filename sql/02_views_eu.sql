-- Latest available value per country, ranked
create or replace view mart.eu_latest as
select geo, country, year, organic_share,
       rank() over (order by organic_share desc) as rank_share
from (
    select distinct on (geo)
           geo, country, year::int as year, organic_share::numeric as organic_share
    from stg.organic_share_all_years
    where organic_share is not null
    order by geo, year::int desc
) l;

-- Change in number of producers 2023 -> 2024
create or replace view mart.producer_change as
select geo, country,
       y2023::int                                 as y2023,
       y2024::int                                 as y2024,
       y2024::int - y2023::int                    as change_abs,
       100 * (y2024::numeric / y2023::numeric - 1) as change_pct
from stg.producer_change;

-- Reconciliation vs. R export
select 'producer_change_abs' as check_name,
       max(abs(m.change_abs - s.change_abs::numeric)) as max_abs_diff,
       count(*) as n
from mart.producer_change m join stg.producer_change s using (geo)
union all
select 'producer_change_pct',
       max(abs(m.change_pct - s.change_pct::numeric)),
       count(*)
from mart.producer_change m join stg.producer_change s using (geo);
