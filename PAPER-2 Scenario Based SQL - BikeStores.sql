

-- Task 1 — Build the Sales Detail Dataset (6 marks)
-- Management needs a detailed sales dataset for analysis.
-- Return one row per order item containing:
-- order_id and order_date
-- customer full name
-- store name
-- staff full name
-- product name
-- category name
-- brand name
-- quantity, list_price, discount
-- calculated net_line_revenue

SELECT
o.order_id,
 o.order_date,
CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
     s.store_name,
     CONCAT(st.first_name, ' ', st.last_name) AS staff_full_name,
  p.product_name,
     cat.category_name,
   b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.quantity * oi.list_price * (1 - oi.discount) AS net_line_revenue
 FROM sales.orders AS o
INNER JOIN sales.customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN sales.stores AS s
    ON o.store_id = s.store_id
INNER JOIN sales.staffs AS st
    ON o.staff_id = st.staff_id
INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN production.products AS p
    ON oi.product_id = p.product_id
INNER JOIN production.categories AS cat
    ON p.category_id = cat.category_id
INNER JOIN production.brands AS b
    ON p.brand_id = b.brand_id;


-- Task 2 — Store Performance Summary (5 marks)
-- Create a store-level performance report for completed orders
-- showing:
-- store name
-- number of distinct orders
-- total units sold
-- total net revenue
-- average order value

SELECT
s.store_name,
    COUNT(DISTINCT o.order_id) AS number_of_distinct_orders,
 SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount))
        / COUNT(DISTINCT o.order_id) AS average_order_value
FROM sales.orders AS o
INNER JOIN sales.stores AS s    ON o.store_id = s.store_id
INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY s.store_name;


-- Task 3 — High-Value Customers (5 marks)
-- Management wants to identify high-value customers.
-- Return customers whose total completed-order spending is
-- greater than the average total spending of customers
-- who have completed orders.
-- Show customer_id, customer name, completed order count,
-- and total spending.
-- Order the result by total spending descending.

WITH customer_spending AS
(
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_spending
    FROM sales.customers AS c
    INNER JOIN sales.orders AS o
        ON c.customer_id = o.customer_id
    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
customer_id,
 customer_name,
  completed_order_count,
  total_spending
FROM customer_spending
WHERE total_spending > (
    SELECT AVG(total_spending)
  FROM customer_spending
)
ORDER BY total_spending DESC;


-- Task 4 — Inventory Risk Report (5 marks)
-- Operations wants to identify inventory risk.
-- Return products where the stock quantity is below 5
-- in at least one store.
-- Show product name, store name, current quantity,
-- category name, and brand name.
-- Products with zero stock should appear first,
-- followed by the lowest remaining quantities.

SELECT
    p.product_name,
    s.store_name,
    st.quantity AS current_quantity,
    c.category_name,
    b.brand_name
FROM production.stocks AS st
INNER JOIN production.products AS p
    ON st.product_id = p.product_id
INNER JOIN sales.stores AS s
ON st.store_id = s.store_id
INNER JOIN production.categories AS c
    ON p.category_id = c.category_id
INNER JOIN production.brands AS b
    ON p.brand_id = b.brand_id
WHERE st.quantity < 5
ORDER BY st.quantity ASC;


-- Task 5 — Top Products Within Each Category (6 marks)
-- For each product category, identify the top 3 products
-- by total net revenue from completed orders.
-- Return category name, product name, total units sold,
-- total net revenue, and the product's position within
-- its category.
-- Tied products must receive the same position and the
-- next position should not contain gaps.

WITH product_sales AS
(
    SELECT
        c.category_name,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue
    FROM production.categories AS c
    INNER JOIN production.products AS p
        ON c.category_id = p.category_id
    INNER JOIN sales.order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN sales.orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY
        c.category_name,
        p.product_name
),
ranked_products AS
(
    SELECT
        category_name,
            product_name,
        total_units_sold,
        total_net_revenue,
        DENSE_RANK() OVER
        (
            PARTITION BY category_name
 ORDER BY total_net_revenue DESC
        ) AS product_position
    FROM product_sales
)
SELECT
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    product_position
FROM ranked_products
WHERE product_position <= 3
ORDER BY
    category_name,
  product_position;


-- ============================================================
-- Task 6 — Monthly Sales Trend (6 marks)
-- ============================================================
-- Create a monthly sales trend for completed orders.
--
-- For each calendar month return:
-- year
-- month
-- total net revenue
-- previous month's total net revenue
-- revenue change from the previous month
--
-- The first month may have NULL for the previous-month
-- comparison. Sort chronologically.

WITH monthly_sales AS
(
    SELECT
        YEAR(o.order_date) AS year,
        MONTH(o.order_date) AS month,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue
    FROM sales.orders AS o
    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
)
SELECT
    year,
    month,
    total_net_revenue,
    LAG(total_net_revenue) OVER
    (
        ORDER BY year, month
    ) AS previous_month_total_net_revenue,
    total_net_revenue
        - LAG(total_net_revenue) OVER
        (
            ORDER BY year, month
        ) AS revenue_change_from_previous_month
FROM monthly_sales
ORDER BY
    year,
    month;


-- ============================================================
-- Task 7 — Reusable Reporting View (4 marks)
-- ============================================================
-- Create a view named sales.vw_customer_sales_summary
-- that returns one row per customer and includes:
-- customer_id
-- customer full name
-- total number of completed orders
-- total units purchased
-- total net revenue
-- most recent completed order date

CREATE VIEW sales.vw_customer_sales_summary AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
    COUNT(DISTINCT o.order_id) AS total_number_of_completed_orders,
    SUM(oi.quantity) AS total_units_purchased,
    SUM(
        oi.quantity * oi.list_price * (1 - oi.discount)
    ) AS total_net_revenue,
    MAX(o.order_date) AS most_recent_completed_order_date
FROM sales.customers AS c
INNER JOIN sales.orders AS o
    ON c.customer_id = o.customer_id
INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;

SELECT *
FROM sales.vw_customer_sales_summary;


-- ============================================================
-- Task 8 — Safe Data Modification (4 marks)
-- ============================================================
-- A customer with customer_id = 1 has requested that their
-- phone number be changed to '(999) 555-0101'.
--
-- Write SQL that performs this update inside an explicit
-- transaction. Include a validation query after the UPDATE
-- and show how the change can be rolled back during testing
-- so the assessment database is not permanently changed.

BEGIN TRANSACTION;

UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

SELECT
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;

ROLLBACK TRANSACTION;


-- ============================================================
-- Task 9 — Store Sales Procedure (6 marks)
-- ============================================================
-- Create a stored procedure named
-- sales.usp_store_sales_report with these input parameters:
-- @store_id
-- @start_date
-- @end_date

CREATE PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    SELECT
        s.store_id,
        s.store_name,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity) AS total_units_sold,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue
    FROM sales.stores AS s
    INNER JOIN sales.orders AS o
        ON s.store_id = o.store_id
    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id
    WHERE s.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date BETWEEN @start_date AND @end_date
    GROUP BY
        s.store_id,
        s.store_name;
END;

-- ============================================================
-- Task 10 — Management Insight Query (3 marks)
-- ============================================================
-- Write one additional SQL query that you believe would
-- provide useful insight to BikeStores management using
-- at least three tables.
--
-- Below the query, add a SQL comment of no more than three
-- lines explaining:
-- 1. the business question,
-- 2. what the result measures,
-- 3. why management should care about it.

SELECT
    s.store_id,
    s.store_name,
    c.category_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(
        oi.quantity * oi.list_price * (1 - oi.discount)
    ) AS total_revenue
FROM sales.stores AS s
INNER JOIN sales.orders AS o
    ON s.store_id = o.store_id
INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN production.products AS p
    ON oi.product_id = p.product_id
INNER JOIN production.categories AS c
    ON p.category_id = c.category_id
WHERE o.order_status = 4
GROUP BY
    s.store_id,
    s.store_name,
    c.category_name
ORDER BY
    total_revenue DESC;


