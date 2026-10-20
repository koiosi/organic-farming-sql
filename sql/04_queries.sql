-- Q1: Is the 30 % target by 2030 realistic? Required vs. historical pace (pp/year)
with hist as (
    select (max(organic_share) filter (where year = 2024)
          - max(organic_share) filter (where year = 2014)) / 10 as hist_pp_per_year
    from mart.de_overview
),
need as (
    select max(required) filter (where year = 2025)
         - max(required) filter (where year = 2024) as required_pp_per_year
    from mart.trajectory
),
proj as (
    select projected from mart.trajectory where year = 2030
)
select round(h.hist_pp_per_year, 2)                          as hist_pp_per_year,
       round(n.required_pp_per_year, 2)                      as required_pp_per_year,
       round(n.required_pp_per_year / h.hist_pp_per_year, 1) as required_vs_hist,
       round(p.projected::numeric, 1)                        as projected_2030
from hist h cross join need n cross join proj p;

-- Q2: Consolidation years: farms shrink faster than area
select year,
       round(farms_yoy_pct, 1) as farms_yoy_pct,
       round(area_yoy_pct, 1)  as area_yoy_pct,
       round(avg_farm_size, 1) as avg_farm_size_ha
from mart.de_overview
where farms_yoy_pct < area_yoy_pct and area_yoy_pct <= 0
order by year;

-- Q3: Europe: top 5 and Germany (note: latest available year per country)
select *
from (
    select rank_share, geo, coalesce(country, geo) as country, year, organic_share,
           round(organic_share - first_value(organic_share) over (order by rank_share), 1) as diff_to_leader
    from mart.eu_comparison
) x
where rank_share <= 5 or geo = 'DE'
order by rank_share;

-- Q4: Steepest decline in number of producers 2023 -> 2024
select geo, coalesce(country, geo) as country, y2023, y2024, change_abs,
       round(change_pct, 1) as change_pct
from mart.producer_change
where y2023 is not null and y2024 is not null
order by change_pct asc
limit 5;
