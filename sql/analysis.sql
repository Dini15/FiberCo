---Section 1 - Infrastructure & Utilization

SELECT * FROM subscription_snapshot;

---1. Montly Penetration Rate
WITH total_homepass AS(SELECT
i.region,
i.technology,
i.exclusive_flag, COUNT(DISTINCT i.homeid) AS total_hp
FROM homepass i
LEFT JOIN region_master g on i.fibernode=g.fibernode GROUP BY 1,2,3),
active_customers AS (SELECT
i.region,
i.technology,
i.exclusive_flag,
s.snapshot_date,
COUNT(DISTINCT s.contract_account) AS active_ca
FROM subscription_snapshot s
JOIN homepass i ON s.homeid=i.homeid
WHERE s.active_flag=1
GROUP BY 1,2,3, 4)
SELECT a.snapshot_date,
a.region,
a.technology,
CASE WHEN a.exclusive_flag = 'Y' THEN 'Exclusive' ELSE 'Non-Exclusive' END AS area_type,
a.active_ca,
t.total_hp,
ROUND(CAST(a.active_ca AS NUMERIC) / NULLIF(t.total_hp, 0) * 100, 2) AS penetration_rate_pct
FROM active_customers a
JOIN total_homepass t 
ON a.region = t.region 
AND a.technology = t.technology 
AND a.exclusive_flag = t.exclusive_flag
ORDER BY a.snapshot_date DESC, penetration_rate_pct DESC
LIMIT 10;

--- 2. Identify High Capex & Low Utilization areas AND Underperforming Fibernodes
WITH node_performance AS (
SELECT 
i.fibernode,
i.region,
SUM(i.capex_cost) as total_node_capex,
COUNT(DISTINCT i.homeid) as total_hp,
COUNT(DISTINCT CASE WHEN s.active_flag = 1 THEN s.contract_account END) as active_ca
FROM homepass i
LEFT JOIN subscription_snapshot s ON i.homeid = s.homeid 
AND s.snapshot_date = (SELECT MAX(snapshot_date) FROM subscription_snapshot)
GROUP BY 1, 2),
benchmarks AS (
SELECT *,
CAST(active_ca AS NUMERIC) / NULLIF(total_hp, 0) * 100 as utilization_rate,
AVG(total_node_capex) OVER() as avg_capex,
AVG(CAST(active_ca AS NUMERIC) / NULLIF(total_hp, 0) * 100) OVER() as avg_utilization
FROM node_performance)

SELECT fibernode, region,
ROUND(CAST(total_node_capex AS NUMERIC), 0) as capex_cost,
ROUND(CAST(utilization_rate AS NUMERIC), 2) as util_pct,
ROUND(CAST(avg_utilization AS NUMERIC), 2) as network_avg_util_pct,
'Underperforming' as status
FROM benchmarks
WHERE total_node_capex > avg_capex
AND utilization_rate < avg_utilization
ORDER BY total_node_capex DESC;

--- 3. Compare Monetization Trend Between Exclusive vs Open Access Areas and FTTH vs HFC
WITH revenue_detail AS (SELECT s.snapshot_date,
i.technology,
i.exclusive_flag,
SUM(p.package_price + COALESCE(p.ao_rrp_price, 0)) as gross_revenue,
SUM(COALESCE(p.ao_wholesale_price, 0) + sc.lease_fee_per_active) as total_cost
FROM subscription_snapshot s
JOIN homepass i ON s.homeid = i.homeid
JOIN media_package p ON s.contract_account = p.contract_account
JOIN servco_fin sc ON s.servco_id = sc.servco_id
WHERE s.active_flag = 1 
GROUP BY 1, 2, 3)
SELECT snapshot_date,
technology,
CASE WHEN exclusive_flag = 'Y' THEN 'Exclusive' ELSE 'Open Access' END as area_type,
gross_revenue, (gross_revenue - total_cost) as contribution_margin,
ROUND(CAST((gross_revenue - total_cost) AS NUMERIC) / NULLIF(gross_revenue, 0) * 100, 2) as margin_pct
FROM revenue_detail
ORDER BY snapshot_date DESC, area_type ASC
LIMIT 20; 

-- Section 2 – Servco Performance & Competition
SELECT 
    f.servco_name,
    -- 1. Evaluasi vs Minimum Guarantee
    COUNT(DISTINCT s.homeid) AS active_subs,
    f.minimum_guarantee::numeric AS target,
    ROUND(COUNT(DISTINCT s.homeid) * 100.0 / f.minimum_guarantee::numeric, 2) AS pct_achievement,
    
    -- 2. Analisis Exclusive Window vs Post-Exclusive
    CASE 
        WHEN h.exclusive_flag = 'Y' AND s.snapshot_date <= h.exclusive_end_date THEN 'Exclusive'
        ELSE 'Post-Exclusive'
    END AS window_status,

    -- 3. Analisis ISP Count (Single vs Multi)
    -- Kita asumsikan jika ada 'exclusive_flag' Y maka itu Single-ISP pada masanya
    CASE 
        WHEN h.exclusive_flag = 'Y' THEN 'Single-ISP Area'
        ELSE 'Multi-ISP Area'
    END AS area_type

FROM subscription_snapshot s
JOIN servco_fin f ON s.servco_id = f.servco_id
JOIN homepass h ON s.homeid = h.homeid
WHERE s.servco_id = '101' 
  AND s.active_flag = 1
GROUP BY 1, 3, 5, 6;
-- 3. Performance Comparision In Exclusive Window vs Post Exclusive and In single-ISP vs multi-ISP areas
SELECT * FROM subscription_snapshot;
-- Section 3 – Media Monetization & Profitability
-- 1. Media attach rate per servco and per region
-- 2. Contribution analysis by Lease Revenue vs Media Revenue and Media Margin by Product
-- 3. Identification on Most Profitable Media Product, Servco with Strongest Upsell Capability, and Regions with Highest Monetization Potential
-- 4. Is media bundling meaningfully improving ARPU?

-- Section 4 – Strategic Recommendations
-- 1. 3 Strategies priorities for the next 6 months
-- 2. Strategic Action

