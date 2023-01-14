-- Query for Pharmaceutical Sales Analysis

--1. Total order, revenue and profit grouped by month (Month-year).
-- Total order grouped by month (Month-year).
SELECT
	years,
	months,
	CAST(SUM(order_val) AS NUMERIC (36,2)) AS current_month_orders,
	lag(CAST(SUM(order_val) AS NUMERIC (36,2)), 1) over (order by months) as previous_month_orders,
	CAST((100 * (SUM(order_val) - lag(SUM(order_val), 1) over (order by months)) / lag(SUM(order_val),1) over 
	 (order by months)) AS NUMERIC (36,2)) || '%' as growth
FROM (
	SELECT 
		tr.no_resep,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		COUNT(DISTINCT tr.no_resep) AS order_val
	FROM transaction as tr
	GROUP BY tr.no_resep, years, months
) tmpA
GROUP BY years, months
ORDER BY months ASC
;

-- Total revenue grouped by month (Month-year).
SELECT
	years,
	months,
	CAST(SUM(revenue) AS NUMERIC (36,2)) AS current_month_revenue,
	lag(CAST(SUM(revenue) AS NUMERIC (36,2)), 1) over (order by months) as previous_month_revenue,
	CAST((100 * (SUM(revenue) - lag(SUM(revenue), 1) over (order by months)) / lag(SUM(revenue), 1) over 
	 (order by months)) AS NUMERIC (36,2)) || '%' as growth
FROM (
	SELECT 
		tr.no_resep,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(hj) AS revenue
	FROM transaction as tr
	GROUP BY tr.no_resep, years, months
) tmpB
GROUP BY years, months
ORDER BY months ASC
;

-- Total profit grouped by month (Month-year).
SELECT
	years,
	months,
	CAST(SUM(profit) AS NUMERIC (36,2)) AS current_month_profit,
	lag(CAST(SUM(profit) AS NUMERIC (36,2)), 1) over (order by months) as previous_month_profit,
	CAST((100 * (SUM(profit) - lag(SUM(profit), 1) over (order by months)) / lag(SUM(profit), 1) over 
	 (order by months)) AS NUMERIC (36,2))|| '%' as growth
FROM (
	SELECT 
		tr.no_resep,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(hj-hna) AS profit
	FROM transaction as tr
	GROUP BY tr.no_resep, years, months
) tmpC
GROUP BY years, months
ORDER BY months ASC
;


-- 2. Average treatment charge per REG_AS; 
-- Total order, Total revenue and Total profit grouped by REG_AS

-- Average treatment charge per REG_AS
CREATE TABLE average_treatment_table AS
WITH avg_treat AS (
	SELECT 
		sal.no_resep,
		sal.reg_as,
		SUM(hj) as charge
	FROM ms_sales as sal
	JOIN transaction as tra
	ON sal.no_resep = tra.no_resep
	GROUP BY 1,2
)
SELECT 
	reg_as, 
	CAST(AVG(charge) AS NUMERIC (36,2)) AS average_treatment_charge 
FROM avg_treat
GROUP BY 1;

-- Total order, Total revenue and Total profit grouped by REG_AS
SELECT 
	sal.reg_as,
	CAST(SUM(tr.hj) AS NUMERIC (36,2)) as Total_revenue,
	CAST(SUM(tr.hj-tr.hna) AS NUMERIC (36,2)) as total_profit,
	COUNT(tr.no_resep) as total_order
FROM transaction as tr
JOIN ms_sales as sal
ON sal.no_resep = tr.no_resep
GROUP BY 1;


-- 3. Total orders and sales based on hour.
SELECT
	hours,
	CAST(SUM(order_val) AS NUMERIC (36,2)) AS average_orders,
	CAST(SUM(revenue) AS NUMERIC (36,2))AS average_revenue
FROM (
	SELECT 
		tr.no_resep,
		date_part('hour', sal.jam_jual) AS hours,
		SUM(tr.qty) AS order_val,
		SUM(tr.hna) AS revenue,
		SUM(hj-hna) AS profit
	FROM transaction as tr
	INNER JOIN ms_sales as sal
	ON tr.no_resep = sal.no_resep
	GROUP BY tr.no_resep, hours
) tmpD
GROUP BY hours
ORDER BY hours ASC
;


-- 4. The most profitable drugs and its profit 
-- detail breakdown by month (Month-year)
WITH profit_months AS(
	SELECT 
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(hj-hna) AS profit
	FROM transaction as tr
	GROUP BY years, months
),
rank_profit_drugs AS (
	SELECT 
		tr.kd_obat,
		prod.nama,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(hj-hna) AS profit,
		rank() OVER (PARTITION BY date_part('month', tr.tgl) 
					 ORDER BY SUM(hj-hna) DESC) AS rank_prod
	FROM transaction as tr
	INNER JOIN ms_product as prod
	ON tr.kd_obat = prod.kd_obat
	GROUP BY tr.kd_obat, prod.nama, years, months
),
most_profit_drugs_month AS (
SELECT
	years,
	months,
	nama as medicine,
	profit
FROM rank_profit_drugs as rpd
WHERE rank_prod = 1
ORDER BY months ASC
)
SELECT 
	mpdm.years,
	mpdm.months,
	mpdm.medicine,
	mpdm.profit,
	CAST((mpdm.profit / pm.profit)*100 AS NUMERIC (36,2)) as pct_total_month
FROM most_profit_drugs_month as mpdm
JOIN profit_months as pm
ON mpdm.months = pm.months
;


-- 5. The most sold drugs 
-- detail breakdown by month (Month-year)
WITH qty_months AS(
	SELECT 
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.qty) AS total_quantity
	FROM transaction as tr
	GROUP BY years, months
),
rank_sold_drugs AS (
	SELECT 
		prod.kd_obat,
		prod.nama,
		prod.kd_pabrik as id_pabrik,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.qty) AS total_quantity,
		rank() OVER (PARTITION BY date_part('month', tr.tgl) 
					 ORDER BY SUM(tr.qty) DESC) AS rank_prod
	FROM transaction as tr
	INNER JOIN ms_product as prod
	ON tr.kd_obat = prod.kd_obat
	GROUP BY prod.kd_obat, prod.nama, prod.kd_pabrik, years, months
),
most_sold_drugs_month AS (
	SELECT
		years,
		months,
		nama as medicine,
		total_quantity
	FROM rank_sold_drugs
	WHERE rank_prod = 1
	ORDER BY months ASC
)
SELECT 
	msdm.years,
	msdm.months,
	msdm.medicine,
	msdm.total_quantity,
	CAST((msdm.total_quantity / qm.total_quantity)*100 AS NUMERIC (36,2)) as pct_total_month
FROM most_sold_drugs_month as msdm
JOIN qty_months as qm
ON msdm.months = qm.months
;

-- 5. Biggest Revenue Drugs each month
-- detail breakdown by month (Month-year)
WITH revenue_months AS(
	SELECT 
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.hj) AS total_revenue
	FROM transaction as tr
	GROUP BY years, months
), 
rank_rev_drugs_high AS (
	SELECT 
		tr.kd_obat,
		prod.nama,
		prod.kd_pabrik as id_pabrik,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.hj) AS total_revenue,
		rank() OVER (PARTITION BY date_part('month', tr.tgl) 
					 ORDER BY SUM(tr.hj) DESC) AS rank_prod
	FROM transaction as tr
	INNER JOIN ms_product as prod
	ON tr.kd_obat = prod.kd_obat
	GROUP BY tr.kd_obat, prod.nama, prod.kd_pabrik, years, months
),
most_revenue_drugs_month AS (
	SELECT
		years,
		months,
		nama as medicine,
		total_revenue
	FROM rank_rev_drugs_high
	WHERE rank_prod = 1
	ORDER BY months ASC
)
SELECT 
	mrdm.years,
	mrdm.months,
	mrdm.medicine,
	mrdm.total_revenue,
	CAST((mrdm.total_revenue / rm.total_revenue)*100 AS NUMERIC (36,2)) as pct_total_month
FROM most_revenue_drugs_month as mrdm
JOIN revenue_months as rm
ON mrdm.months = rm.months
;


-- 6. Lowest Revenue Drugs each month
-- detail breakdown by month (Month-year)
WITH revenue_months AS(
	SELECT 
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.hj) AS total_revenue
	FROM transaction as tr
	GROUP BY years, months
), 
rank_rev_drugs_low AS (
	SELECT 
		tr.kd_obat,
		prod.nama,
		prod.kd_pabrik as id_pabrik,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(tr.hj) AS total_revenue,
		rank() OVER (PARTITION BY date_part('month', tr.tgl) 
					 ORDER BY SUM(tr.hj) ASC) AS rank_prod
	FROM transaction as tr
	INNER JOIN ms_product as prod
	ON tr.kd_obat = prod.kd_obat
	GROUP BY tr.kd_obat, prod.nama, prod.kd_pabrik, years, months
),
least_revenue_drugs_month AS (
SELECT
	years,
	months,
	nama as medicine,
	total_revenue
FROM rank_rev_drugs_low
WHERE rank_prod = 1
ORDER BY months ASC
)
SELECT 
	lrdm.years,
	lrdm.months,
	lrdm.medicine,
	lrdm.total_revenue,
	CAST((lrdm.total_revenue / rm.total_revenue)*100 AS NUMERIC (36,2)) as pct_total_month
FROM least_revenue_drugs_month as lrdm
JOIN revenue_months as rm
ON lrdm.months = rm.months
;


-- 7. Revenue each suppliers
SELECT
	 kd_pabrik,
	 CAST(SUM(hj_rp) AS NUMERIC (36,2)) as Revenue
FROM ms_product
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
;

-- Combine Dataset
-- Inner Join
CREATE TABLE pharmaceutical_sales AS
SELECT
	tr.no_resep as no_resep,
	tr.tgl as date,
	tr.kd_cust as kd_cust,
	tr.kd_obat as kd_obat,
	sal.kd_dokter,
	prod.nama as product_name,
	prod.sat_jual as sat_jual,
	prod.kd_pabrik as kd_pabrik,
	prod.hj_rp as hj_rp,
	tr.qty,
	tr.hj,
	tr.hna,
	sal.jam_jual,
	sal.racik,
	sal.reg_as
FROM transaction as tr
INNER JOIN ms_product as prod
ON tr.kd_obat = prod.kd_obat
INNER JOIN ms_sales as sal
ON tr.no_resep = sal.no_resep
;

-- Outer Join
CREATE TABLE pharmaceutical_sales_outer AS
SELECT
	tr.no_resep as no_resep,
	tr.tgl as date,
	tr.kd_cust as kd_cust,
	tr.kd_obat as kd_obat,
	sal.kd_dokter,
	prod.nama as product_name,
	prod.sat_jual as sat_jual,
	prod.kd_pabrik as kd_pabrik,
	prod.hj_rp as hj_rp,
	tr.qty,
	tr.hj,
	tr.hna,
	sal.jam_jual,
	sal.racik,
	sal.reg_as
FROM transaction as tr
FULL OUTER JOIN ms_product as prod
ON tr.kd_obat = prod.kd_obat
FULL OUTER JOIN ms_sales as sal
ON tr.no_resep = sal.no_resep
;

---------------------------
---------------------------
---------------------------
SELECT
	years,
	months,
	
	CAST(AVG(profit) AS NUMERIC (36,2)) AS average_profit
FROM (
	SELECT 
		tr.no_resep,
		tr.kd_obat,
		date_part('year', tr.tgl) AS years,
		date_part('month', tr.tgl) AS months,
		SUM(hj-hna) AS profit
	FROM transaction as tr
	GROUP BY tr.no_resep, tr.kd_obat, years, months
) tmpA
GROUP BY years, months
ORDER BY months ASC
;

SELECT 
	months, cnt
FROM(
	SELECT 
		date_part('month', tr.tgl) AS months,
		COUNT(tr.kd_obat) as cnt
	FROM transaction as tr
	INNER JOIN ms_sales as sal
	ON tr.no_resep = sal.no_resep
) tmpB
GROUP BY months;



SELECT 
	date_part('hour', sal.jam_jual) AS hours,
	COUNT(tr.kd_obat) as cnt
FROM transaction as tr
INNER JOIN ms_sales as sal
ON tr.no_resep = sal.no_resep
GROUP BY hours
ORDER BY hours ASC;

SELECT 
	distinct date_part('hour', sal.jam_jual) AS hours
FROM ms_sales as sal
ORDER BY hours ASC;

select distinct date_part('month', tgl) AS months
from ms_sales;
select distinct date_part('month', tgl) AS months
from transaction;

select distinct kd_dokter from ms_sales;

select * from det_sales limit 5;
select * from ms_product limit 5;
select * from ms_sales limit 5;
select * from transaction limit 5;
	 
-- List the most favorable doctors ID every month
-- Favorable doctors every months
WITH orders_doctors AS (
	SELECT 
		sal.kd_dokter,
		date_part('year', sal.tgl) AS years,
		date_part('month', sal.tgl) AS months,
		COUNT(DISTINCT sal.no_resep) AS total_orders,
		rank() OVER (PARTITION BY date_part('month', sal.tgl) 
					 ORDER BY COUNT(DISTINCT sal.no_resep) DESC) AS rank_doc
	FROM ms_sales as sal
	GROUP BY sal.kd_dokter, years, months
)
SELECT
	years,
	months,
	kd_dokter,
	total_orders
FROM orders_doctors
WHERE rank_doc = 1
ORDER BY months ASC
;

-- Top 10 Doctors Orders
WITH top10_orders_doctors AS (
	SELECT 
		sal.kd_dokter,
		COUNT(DISTINCT sal.no_resep) AS total_orders
	FROM ms_sales as sal
	GROUP BY sal.kd_dokter
	ORDER BY COUNT(DISTINCT sal.no_resep) DESC
)
SELECT
	kd_dokter,
	total_orders
FROM top10_orders_doctors
LIMIT 10
;
