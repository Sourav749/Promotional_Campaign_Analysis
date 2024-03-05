-- List products base price greater than 500 featured in 'BOGOF' promos.

SELECT distinct(product_name), base_price
FROM fact_events f
JOIN dim_products d
	ON f.product_code = d.product_code
WHERE base_price > 500 AND promo_type = "BOGOF";


-- Generate a report that provides an overview of the number of stores in each city. 

SELECT 
	city,
	COUNT(store_id) AS cnt
FROM dim_stores
GROUP BY city
ORDER BY cnt DESC;


-- Generate a report showing each campaign's total revenue before and after.


WITH cte as(
SELECT 
    campaign_name,base_price,`quantity_sold(before_promo)`,`quantity_sold(after_promo)`,
	CASE
		WHEN promo_type = '50% off' THEN base_price - base_price * 50 / 100
		WHEN promo_type = '25% off' THEN base_price - base_price * 25 / 100
		WHEN promo_type = '33% off' THEN base_price - base_price * 33 / 100
        WHEN promo_type = '500 Cashback' THEN base_price - 500
        ELSE base_price
	END AS promo_price
FROM fact_events f
JOIN dim_campaigns d
    ON f.campaign_id = d.campaign_id
)
SELECT 
	campaign_name,
	ROUND(SUM(base_price * `quantity_sold(before_promo)`)/1000000,2) AS Revenue_before_promotion,
	ROUND(SUM(promo_price * `quantity_sold(after_promo)`)/1000000,2) AS Revenue_after_promotion
FROM cte
GROUP BY campaign_name;


-- Generate a report calculating ISU% for each category during Diwali campaign and include category rankings based on ISU%."

WITH quantity as(
SELECT 
	category,
    campaign_id,
    `quantity_sold(before_promo)` AS quantity_before_promo,
	CASE
        WHEN promo_type = 'BOGOF' THEN `quantity_sold(after_promo)` * 2
        ELSE `quantity_sold(after_promo)`
	END AS promo_qty
    FROM fact_events f
    JOIN dim_products d ON f.product_code = d.product_code),
cte AS (
    SELECT 
        category,
        campaign_id,
        ROUND((SUM(promo_qty) - SUM(quantity_before_promo)) *100 / SUM(quantity_before_promo),2) AS ISU_Pct
    FROM quantity
    GROUP BY category , campaign_id
)
SELECT 
    category,ISU_Pct,
    dense_rank() OVER (ORDER BY isu_pct DESC) AS Ctaegory_Rank
FROM cte
JOIN dim_campaigns d ON cte.campaign_id = d.campaign_id 
WHERE campaign_name = 'Diwali';

-- Create a report of the Top 5 products ranked by IR% across all campaigns, including product name and essential details.


WITH cte AS(
SELECT 
		f.product_code,
        f.base_price,
		p.product_name,
		p.category,
		`quantity_sold(before_promo)` AS quantity_before_promo,
		`quantity_sold(after_promo)` AS quantity_after_promo,
        CASE
            WHEN promo_type = '50% off' THEN base_price - base_price * 50 / 100
            WHEN promo_type = '25% off' THEN base_price - base_price * 25 / 100
            WHEN promo_type = '33% off' THEN base_price - base_price * 33 / 100
            WHEN promo_type = '500 Cashback' THEN base_price - 500
            ELSE base_price
        END AS promo_price
FROM fact_events f
JOIN dim_products p ON f.product_code = p.product_code
),
Revenue AS(
SELECT  
        product_code,
        product_name,
        category,
        SUM(base_price * quantity_before_promo) / 1000000 AS total_revenue_before_promotion,
        SUM(promo_price * quantity_after_promo) / 1000000 AS total_revenue_after_promotion
    FROM cte
    GROUP BY product_code, product_name, category
)
SELECT 
    product_name,
    category,
    ROUND(((total_revenue_after_promotion - total_revenue_before_promotion) / total_revenue_before_promotion) * 100, 0) AS IR_Pct
    /* RANK() OVER (ORDER BY ((total_revenue_after_promotion - total_revenue_before_promotion) / total_revenue_before_promotion) DESC) AS rank_order */
FROM Revenue
ORDER BY IR_Pct DESC
LIMIT 5;



