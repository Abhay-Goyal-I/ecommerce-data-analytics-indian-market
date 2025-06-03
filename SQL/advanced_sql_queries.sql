
-- ADVANCED SQL QUERIES FOR E-COMMERCE ANALYTICS

-- 1. Monthly Revenue Growth Analysis
SELECT 
    strftime('%Y-%m', transaction_date) as month,
    SUM(total_amount) as monthly_revenue,
    COUNT(*) as total_orders,
    ROUND(SUM(total_amount) / COUNT(*), 2) as avg_order_value,
    LAG(SUM(total_amount)) OVER (ORDER BY strftime('%Y-%m', transaction_date)) as prev_month_revenue,
    ROUND(
        (SUM(total_amount) - LAG(SUM(total_amount)) OVER (ORDER BY strftime('%Y-%m', transaction_date))) 
        / LAG(SUM(total_amount)) OVER (ORDER BY strftime('%Y-%m', transaction_date)) * 100, 2
    ) as growth_rate
FROM transactions 
GROUP BY strftime('%Y-%m', transaction_date)
ORDER BY month;

-- 2. Customer Lifetime Value Analysis
WITH customer_metrics AS (
    SELECT 
        customer_id,
        COUNT(*) as total_orders,
        SUM(total_amount) as total_spent,
        ROUND(SUM(total_amount) / COUNT(*), 2) as avg_order_value,
        MIN(transaction_date) as first_purchase,
        MAX(transaction_date) as last_purchase,
        julianday(MAX(transaction_date)) - julianday(MIN(transaction_date)) as customer_lifespan
    FROM transactions
    GROUP BY customer_id
)
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(total_spent), 2) as avg_lifetime_value,
    ROUND(AVG(total_orders), 2) as avg_orders_per_customer,
    ROUND(AVG(avg_order_value), 2) as avg_order_value,
    ROUND(AVG(customer_lifespan), 0) as avg_lifespan_days
FROM customer_metrics cm
JOIN transactions t ON cm.customer_id = t.customer_id
GROUP BY customer_segment
ORDER BY avg_lifetime_value DESC;

-- 3. Product Category Performance with Seasonality
SELECT 
    category,
    CASE 
        WHEN strftime('%m', transaction_date) IN ('03', '04', '10', '11', '12') THEN 'Festival Season'
        ELSE 'Regular Season'
    END as season,
    SUM(total_amount) as revenue,
    COUNT(*) as orders,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    ROUND(AVG(customer_rating), 2) as avg_rating
FROM transactions
GROUP BY category, season
ORDER BY category, season;

-- 4. Geographic Market Penetration Analysis
SELECT 
    city_tier,
    city,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_amount) as total_revenue,
    COUNT(*) as total_orders,
    ROUND(SUM(total_amount) / COUNT(*), 2) as avg_order_value,
    ROUND(SUM(total_amount) / COUNT(DISTINCT customer_id), 2) as revenue_per_customer
FROM transactions
GROUP BY city_tier, city
ORDER BY total_revenue DESC;

-- 5. Payment Method Efficiency Analysis
SELECT 
    payment_method,
    COUNT(*) as transaction_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions), 2) as usage_percentage,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,
    SUM(CASE WHEN delivery_status = 'Delivered' THEN 1 ELSE 0 END) as successful_deliveries,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) as success_rate
FROM transactions
GROUP BY payment_method
ORDER BY transaction_count DESC;

-- 6. Customer Retention Cohort Analysis
WITH first_purchase AS (
    SELECT 
        customer_id,
        MIN(DATE(transaction_date)) as cohort_month
    FROM transactions
    GROUP BY customer_id
),
customer_activity AS (
    SELECT 
        t.customer_id,
        fp.cohort_month,
        DATE(t.transaction_date) as transaction_month,
        (strftime('%Y', t.transaction_date) - strftime('%Y', fp.cohort_month)) * 12 + 
        (strftime('%m', t.transaction_date) - strftime('%m', fp.cohort_month)) as period_number
    FROM transactions t
    JOIN first_purchase fp ON t.customer_id = fp.customer_id
)
SELECT 
    cohort_month,
    period_number,
    COUNT(DISTINCT customer_id) as customers,
    ROUND(COUNT(DISTINCT customer_id) * 100.0 / 
          FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER (
              PARTITION BY cohort_month ORDER BY period_number
          ), 2) as retention_rate
FROM customer_activity
WHERE period_number <= 12
GROUP BY cohort_month, period_number
ORDER BY cohort_month, period_number;

-- 7. Advanced Customer Segmentation (RFM Analysis)
WITH rfm_calculations AS (
    SELECT 
        customer_id,
        julianday('2024-12-31') - julianday(MAX(transaction_date)) as recency,
        COUNT(*) as frequency,
        SUM(total_amount) as monetary
    FROM transactions
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency DESC) as R,
        NTILE(5) OVER (ORDER BY frequency) as F,
        NTILE(5) OVER (ORDER BY monetary) as M
    FROM rfm_calculations
)
SELECT 
    CASE 
        WHEN F >= 4 AND M >= 4 THEN 'Champions'
        WHEN R >= 3 AND F >= 3 AND M >= 3 THEN 'Loyal Customers'
        WHEN R >= 4 THEN 'Potential Loyalists'
        WHEN R >= 3 AND F <= 2 THEN 'New Customers'
        WHEN R <= 2 AND F >= 3 THEN 'At Risk'
        WHEN R <= 2 AND F <= 2 THEN 'Lost Customers'
        ELSE 'Others'
    END as rfm_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(recency), 0) as avg_recency,
    ROUND(AVG(frequency), 2) as avg_frequency,
    ROUND(AVG(monetary), 2) as avg_monetary
FROM rfm_scores
GROUP BY rfm_segment
ORDER BY avg_monetary DESC;

-- 8. Delivery Performance by Region and Category
SELECT 
    city_tier,
    category,
    COUNT(*) as total_orders,
    SUM(CASE WHEN delivery_status = 'Delivered' THEN 1 ELSE 0 END) as delivered_orders,
    SUM(CASE WHEN delivery_status = 'Cancelled' THEN 1 ELSE 0 END) as cancelled_orders,
    SUM(CASE WHEN delivery_status = 'Returned' THEN 1 ELSE 0 END) as returned_orders,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) as delivery_success_rate,
    ROUND(AVG(customer_rating), 2) as avg_customer_rating
FROM transactions
GROUP BY city_tier, category
HAVING COUNT(*) >= 100  -- Only categories with significant volume
ORDER BY delivery_success_rate DESC;

-- 9. Weekend vs Weekday Performance Analysis
SELECT 
    CASE 
        WHEN strftime('%w', transaction_date) IN ('0', '6') THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    category,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    ROUND(AVG(customer_rating), 2) as avg_rating
FROM transactions
GROUP BY day_type, category
ORDER BY day_type, revenue DESC;

-- 10. Festival Season Impact Analysis
SELECT 
    category,
    CASE WHEN is_festival_season = 1 THEN 'Festival Season' ELSE 'Regular Season' END as season_type,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    ROUND(AVG(quantity), 2) as avg_quantity,
    COUNT(DISTINCT customer_id) as unique_customers
FROM transactions
GROUP BY category, is_festival_season
ORDER BY category, season_type;
