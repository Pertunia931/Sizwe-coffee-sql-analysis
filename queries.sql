-- Sizwe Coffee Sales Analysis
-- Analysis for Nomsa (finance) and Bongani (sales): channel performance, product profitability,
-- collections, key accounts, trade-promotion gaps, rep targets, seasonality and the FY2025 margin decline.
-- Fiscal years: FY2024 = orders on or before 30 June 2024; FY2025 = orders from 1 July 2024 onward.
-- Currency: South African Rand (R). Dialect: Databricks / Spark SQL.


-- Task 1: Channel performance
WITH channel_revenue AS (
    SELECT
        so.channel,
        SUM(CASE WHEN so.order_date < '2024-07-01'
            THEN sl.line_revenue ELSE 0 END) AS fy2024_revenue,
        SUM(CASE WHEN so.order_date >= '2024-07-01'
            THEN sl.line_revenue ELSE 0 END) AS fy2025_revenue
    FROM sizwe_sales_orders AS so
    JOIN sizwe_sales_lines AS sl
        ON sl.order_id = so.order_id
    GROUP BY so.channel
)
SELECT
    channel,
    fy2024_revenue,
    fy2025_revenue,
    ROUND(100.0 * (fy2025_revenue - fy2024_revenue) / NULLIF(fy2024_revenue, 0), 1) AS growth_pct
FROM channel_revenue
ORDER BY channel;


-- Task 2: Where the profit actually comes from
WITH line_totals AS (
    SELECT
        p.product_line,
        SUM(sl.line_revenue) AS revenue,
        SUM(sl.cogs) AS cost_of_goods
    FROM sizwe_sales_lines AS sl
    JOIN sizwe_products AS p
        ON p.sku = sl.sku
    GROUP BY p.product_line
)
SELECT
    product_line,
    revenue,
    cost_of_goods,
    revenue - cost_of_goods AS gross_profit,
    ROUND(100.0 * (revenue - cost_of_goods) / NULLIF(revenue, 0), 1) AS gross_profit_margin_pct
FROM line_totals
ORDER BY gross_profit DESC;

-- Answer: House Blend earns the most gross profit (about R107.1m), but it is not the highest-margin line.
-- Single Origin has the best margin at 44.3%, yet earns less profit because it sells on a smaller revenue base.


-- Task 3: The collections problem
SELECT
    c.channel,
    COUNT(*) AS total_invoices,
    COUNT(a.settlement_date) AS settled_invoices,
    COUNT(*) - COUNT(a.settlement_date) AS open_invoices,
    ROUND(AVG(DATEDIFF(a.settlement_date, a.due_date)), 1) AS avg_days_to_settle,
    ROUND(SUM(a.invoice_amount - a.amount_settled), 2) AS outstanding_value
FROM sizwe_ar_ledger AS a
JOIN sizwe_customers AS c
    ON a.customer_id = c.customer_id
GROUP BY c.channel
ORDER BY c.channel;

-- Answer: Subscription customers pay about 26 days before the due date and almost nothing is outstanding (44 open invoices).
-- Wholesale pays about 17 days late on average, has 3,454 open invoices and holds roughly R87.8m of everything owed,
-- so the problem sits in Wholesale and I would investigate it first.


-- Task 4: The ten accounts that matter most
SELECT
    c.trading_name,
    c.segment,
    c.province,
    CASE WHEN r.rep_name IS NULL
        THEN 'Unassigned'
        ELSE r.rep_name
    END AS account_owner,
    ROUND(SUM(sl.line_revenue), 2) AS fy2025_revenue
FROM sizwe_sales_orders AS so
JOIN sizwe_sales_lines AS sl
    ON sl.order_id = so.order_id
JOIN sizwe_customers AS c
    ON c.customer_id = so.customer_id
LEFT JOIN sizwe_reps AS r
    ON r.rep_id = c.rep_id
WHERE so.order_date >= '2024-07-01'
GROUP BY c.customer_id, c.trading_name, c.segment, c.province, r.rep_name
ORDER BY fy2025_revenue DESC
LIMIT 10;


-- Task 5: A commercial gap
SELECT
    c.trading_name,
    c.segment,
    c.province,
    ROUND(SUM(sl.line_revenue), 2) AS total_revenue
FROM sizwe_customers AS c
JOIN sizwe_sales_orders AS so
    ON so.customer_id = c.customer_id
JOIN sizwe_sales_lines AS sl
    ON sl.order_id = so.order_id
WHERE c.channel = 'Wholesale'
    AND NOT EXISTS (
        SELECT 1
        FROM sizwe_trade_promotions AS tp
        WHERE tp.customer_id = c.customer_id
    )
GROUP BY c.customer_id, c.trading_name, c.segment, c.province
ORDER BY total_revenue DESC
LIMIT 15;

-- Answer: I would have each account's sales rep visit the top three (Umhlanga Fresh 108, Ridgeway Foods 308
-- and Kalahari Kitchen 42) and offer a targeted trade promotion, starting with Umhlanga Fresh 108,
-- because they already buy heavily at full price.


-- Task 6: Are the sales representatives hitting target?
WITH rep_revenue AS (
    SELECT
        r.rep_name,
        r.territory,
        r.target_monthly,
        IFNULL(SUM(sl.line_revenue), 0) / 12 AS avg_monthly_revenue
    FROM sizwe_reps AS r
    LEFT JOIN sizwe_sales_orders AS so
        ON so.rep_id = r.rep_id
        AND so.order_date >= '2024-07-01'
    LEFT JOIN sizwe_sales_lines AS sl
        ON sl.order_id = so.order_id
    GROUP BY r.rep_id, r.rep_name, r.territory, r.target_monthly
)
SELECT
    rep_name,
    territory,
    target_monthly,
    ROUND(avg_monthly_revenue, 2) AS avg_monthly_revenue,
    ROUND(100.0 * avg_monthly_revenue / NULLIF(target_monthly, 0), 1) AS pct_of_target
FROM rep_revenue
ORDER BY pct_of_target DESC;


-- Task 7: The shape of the year
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', so.order_date) AS month_start,
        SUM(sl.line_revenue) AS revenue
    FROM sizwe_sales_orders AS so
    JOIN sizwe_sales_lines AS sl
        ON sl.order_id = so.order_id
    GROUP BY DATE_TRUNC('month', so.order_date)
)
SELECT
    month_start,
    revenue,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start)) / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0), 1) AS pct_change_vs_prev_month,
    ROUND(AVG(revenue) OVER (
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3m_avg
FROM monthly_revenue
ORDER BY month_start;

-- Answer: Yes, there is a clear seasonal pattern: revenue slumps in December (December 2023 was the worst month at R29.9m),
-- then climbs steadily from January to peak in the winter months of June and July, and the cycle repeats almost exactly the next year.
-- Sizwe's quietest month is therefore December.


-- Task 8: Why has the margin moved?
WITH yearly AS (
    SELECT
        p.product_line,
        CASE WHEN so.order_date < '2024-07-01'
            THEN 'FY2024' ELSE 'FY2025' END AS financial_year,
        SUM(sl.line_revenue) AS revenue,
        SUM(sl.cogs) AS cost
    FROM sizwe_sales_lines AS sl
    JOIN sizwe_sales_orders AS so
        ON sl.order_id = so.order_id
    JOIN sizwe_products AS p
        ON sl.sku = p.sku
    GROUP BY 1, 2
)
SELECT
    product_line,
    financial_year,
    ROUND(revenue, 2) AS revenue,
    ROUND(100.0 * (revenue - cost) / NULLIF(revenue, 0), 1) AS gross_margin_pct,
    ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY financial_year), 1) AS share_of_revenue_pct
FROM yearly
ORDER BY product_line, financial_year DESC;

-- Answer: The margin fell because of mix, not because Sizwe got worse at selling coffee.
-- Bulk Commercial, the lowest-margin line at 19.9%, grew from R110.3m to R161.5m and now makes up 33.6% of revenue instead of 25.0%,
-- while the two highest-margin lines, Single Origin and Capsules, slipped in share (19.5% to 17.6% and 12.9% to 10.8%).
-- Every line held its own margin almost exactly, so the blended margin dropped from 34.7% to 33.0% because the business tilted
-- toward its least profitable line: revenue grew about 9%, but it was low-quality growth.
