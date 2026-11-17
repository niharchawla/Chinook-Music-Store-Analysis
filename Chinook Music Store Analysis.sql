/* =====================================================================
   CHINOOK MUSIC STORE — STUDENT ANSWER TEMPLATE
   ===================================================================== */

USE chinook;


/* =====================================================================
   OBJECTIVE QUESTIONS
   ===================================================================== */

-- O1.
-- Does any table have missing values or duplicates? If yes how would you
-- handle it ?

-- Duplicate primary-key check on customer
SELECT
    customer_id,
    COUNT(*) AS cnt
FROM customer
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- NULL profile — customer table
SELECT
    SUM(company IS NULL) AS null_company,
    SUM(state IS NULL) AS null_state,
    SUM(postal_code IS NULL) AS null_postal_code,
    SUM(phone IS NULL) AS null_phone,
    SUM(fax IS NULL) AS null_fax
FROM customer;

-- NULL profile — track table
SELECT
    SUM(composer IS NULL) AS null_composer,
    SUM(album_id IS NULL) AS null_album_id,
    SUM(genre_id IS NULL) AS null_genre_id
FROM track;

-- O2.
-- Find the top-selling tracks and top artist in the USA and identify their
-- most famous genres.

-- Top selling Tracks
select
    t.name as track_name,
    ar.name as artist_name,
    g.name as genre_name,
    round(sum(il.unit_price * il.quantity), 2) as revenue,
    sum(il.quantity) as units_sold
from invoice i
join invoice_line il
    on i.invoice_id = il.invoice_id
join track t
    on il.track_id = t.track_id
join album al
    on t.album_id = al.album_id
join artist ar
    on al.artist_id = ar.artist_id
join genre g
    on t.genre_id = g.genre_id
where i.billing_country = 'USA'
group by
    t.track_id,
    t.name,
    ar.name,
    g.name
order by revenue desc, units_sold desc
limit 5;

-- Top Artist
select
    ar.name as artist_name,
    round(sum(il.unit_price * il.quantity), 2) as revenue,
    sum(il.quantity) as units_sold
from invoice i
join invoice_line il
    on i.invoice_id = il.invoice_id
join track t
    on il.track_id = t.track_id
join album al
    on t.album_id = al.album_id
join artist ar
    on al.artist_id = ar.artist_id
where i.billing_country = 'USA'
group by
    ar.artist_id,
    ar.name
order by revenue desc, units_sold desc
limit 5;

-- O3.
-- What is the customer demographic breakdown (age, gender, location) of
-- Chinook's customer base?

	-- Customers by Country / State / City
select
    country,
    state,
    city,
    count(*) as customer_count
from customer
group by
    country,
    state,
    city
order by customer_count desc;

	-- Customers per Country
select
    country,
    count(*) as customer_count
from customer
group by country
order by customer_count desc;


-- O4.
-- Calculate the total revenue and number of invoices for each country, state,
-- and city:

select
    billing_country as country,
    billing_state as state,
    billing_city as city,
    count(invoice_id) as num_invoices,
    round(sum(total),2) as total_revenue
from invoice
group by
    billing_country,
    billing_state,
    billing_city
order by total_revenue desc;

-- O5.
-- Find the top 5 customers by total revenue in each country

with customer_sales as(
    select
        c.country,
        concat(c.first_name,' ',c.last_name) as customer_name,
        sum(i.total) as total_revenue
    from customer c
    join invoice i
        on c.customer_id = i.customer_id
    group by
        c.country,
        c.customer_id,
        customer_name
),
ranked_customers as(
    select *,
           dense_rank() over(
               partition by country
               order by total_revenue desc
           ) as rnk
    from customer_sales
)
select
    country,
    customer_name,
    round(total_revenue,2) as total_revenue,
    rnk
from ranked_customers
where rnk <= 5;

-- O6.
-- Identify the top-selling track for each customer

with customer_track_sales as
(
    select
        c.customer_id,
        t.name as track_name,
        sum(il.quantity) as units,
        row_number() over
        (
            partition by c.customer_id
            order by sum(il.quantity) desc,
                     t.name
        ) as rn
    from customer c
    join invoice i
        on c.customer_id = i.customer_id
    join invoice_line il
        on i.invoice_id = il.invoice_id
    join track t
        on il.track_id = t.track_id
    group by
        c.customer_id,
        t.track_id,
        t.name
)
select
    customer_id,
    track_name,
    units
from customer_track_sales
where rn = 1;

-- O7.
-- Are there any patterns or trends in customer purchasing behavior (e.g.,
-- frequency of purchases, preferred payment methods, average order value)?

	-- Store-wide averages
    with customer_orders as
(
    select
        customer_id,
        count(*) as invoice_count
    from invoice
    group by customer_id
),
invoice_tracks as
(
    select
        invoice_id,
        sum(quantity) as tracks_per_invoice
    from invoice_line
    group by invoice_id
)
select
    round(avg(total),2) as avg_order_value,
    (
        select round(avg(invoice_count),2)
        from customer_orders
    ) as avg_invoices_per_customer,
    (
        select round(avg(tracks_per_invoice),2)
        from invoice_tracks
    ) as avg_tracks_per_invoice
from invoice;

-- Per-customer behavior profile
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    COUNT(i.invoice_id) AS num_orders,
    ROUND(AVG(i.total),2) AS avg_order_value,
    ROUND(SUM(i.total),2) AS total_spend,
    DATEDIFF(
        MAX(i.invoice_date),
        MIN(i.invoice_date)
    ) AS tenure_days
FROM customer c
JOIN invoice i
    ON c.customer_id = i.customer_id
GROUP BY
    c.customer_id,
    customer_name;


-- O8.
-- What is the customer churn rate?
with customer_activity as(
    select
        customer_id,
        max(invoice_date) as last_purchase_date
    from invoice
    group by customer_id
),
latest_invoice as(
    select max(invoice_date) as max_invoice_date
    from invoice
)
select
    count(*) as total_customers,
    sum(case
            when last_purchase_date <date_sub((select max_invoice_date
                     from latest_invoice),interval 3 month) then 1
            else 0
        end
    ) as churned_customers,
    round(100 *sum(case
						when last_purchase_date <date_sub((select max_invoice_date
                         from latest_invoice),interval 3 month) then 1
					else 0
            end
        ) / count(*), 2
    ) as churn_rate_pct
from customer_activity;


-- O9.
-- Calculate the percentage of total sales contributed by each genre in the
-- USA and identify the best-selling genres and artists.
with genre_sales as
(
    select
        g.name as genre,
        sum(il.unit_price * il.quantity) as genre_revenue
    from invoice i
    join invoice_line il
        on i.invoice_id = il.invoice_id
    join track t
        on il.track_id = t.track_id
    join genre g
        on t.genre_id = g.genre_id
    where i.billing_country = 'USA'
    group by g.name
)
select
    genre,
    round(genre_revenue,2) as genre_revenue,
    round(
        genre_revenue * 100 /
        sum(genre_revenue) over(),
        2
    ) as pct_of_usa_sales
from genre_sales
order by genre_revenue desc;


-- O10.
-- Find customers who have purchased tracks from at least 3 different genres
select
    c.customer_id,
    concat(c.first_name,' ',c.last_name) as customer_name,
    count(distinct t.genre_id) as distinct_genres
from customer c
join invoice i
    on c.customer_id = i.customer_id
join invoice_line il
    on i.invoice_id = il.invoice_id
join track t
    on il.track_id = t.track_id
group by
    c.customer_id,
    customer_name
order by c.customer_id;


-- O11.
-- Rank genres based on their sales performance in the USA

with genre_sales as(
    select
        g.name as genre,
        sum(il.unit_price * il.quantity) as revenue
    from invoice i
    join invoice_line il
        on i.invoice_id = il.invoice_id
    join track t
        on il.track_id = t.track_id
    join genre g
        on t.genre_id = g.genre_id
    where i.billing_country = 'USA'
    group by g.name
)
select
    genre,
    round(revenue,2) as revenue,
    dense_rank() over(
        order by revenue desc) as sales_rank
from genre_sales;


-- O12.
-- Identify customers who have not made a purchase in the last 3 months

with latest_date as(
    select max(invoice_date) as max_date
    from invoice
)
select
    c.customer_id,
    concat(c.first_name,' ',c.last_name) as customer_name,
    c.country,
    max(i.invoice_date) as last_purchase_date
from customer c
join invoice i
    on c.customer_id = i.customer_id
group by
    c.customer_id,
    customer_name,
    c.country
having max(i.invoice_date)<date_sub((select max_date
									from latest_date),interval 3 month)
order by last_purchase_date;

/* =====================================================================
   SUBJECTIVE QUESTIONS
   ===================================================================== */

-- S1.
-- Recommend the three albums from the new record label that should be
-- prioritised for advertising and promotion in the USA based on genre
-- sales analysis.

with usa_album_sales as(
    select
        al.title as album_title,
        ar.name as artist_name,
        g.name as genre_name,
        sum(il.unit_price * il.quantity) as revenue
    from invoice i
    join invoice_line il
        on i.invoice_id = il.invoice_id
    join track t
        on il.track_id = t.track_id
    join album al
        on t.album_id = al.album_id
    join artist ar
        on al.artist_id = ar.artist_id
    join genre g
        on t.genre_id = g.genre_id
    where i.billing_country = 'USA'
    group by
        al.album_id,
        al.title,
        ar.name,
        g.name
)
select
    album_title,
    artist_name,
    genre_name,
    round(revenue,2) as revenue
from usa_album_sales
order by revenue desc
limit 3;

-- S2.
-- Determine the top-selling genres in countries other than the USA and
-- identify any commonalities or differences.

with genre_sales as(
    select
        i.billing_country as country,
        g.name as genre,
        sum(il.unit_price * il.quantity) as revenue
    from invoice i
    join invoice_line il
        on i.invoice_id = il.invoice_id
    join track t
        on il.track_id = t.track_id
    join genre g
        on t.genre_id = g.genre_id
    where i.billing_country <> 'USA'
    group by
        country,
        genre
)
select
    country,
    genre,
    round(revenue,2) as revenue,
    dense_rank() over(partition by country
        order by revenue desc
    ) as sales_rank
from genre_sales;

-- S3.
-- Customer Purchasing Behavior Analysis: How do the purchasing habits
-- (frequency, basket size, spending amount) of long-term customers differ
-- from those of new customers? What insights can these patterns provide
-- about customer loyalty and retention strategies?

with customer_metrics as(
    select
        customer_id,
        min(invoice_date) as first_purchase,
        max(invoice_date) as last_purchase,
        count(invoice_id) as total_orders,
        sum(total) as total_spend,
        avg(total) as avg_order_value
    from invoice
    group by customer_id
)
select
    case
        when datediff(last_purchase, first_purchase) >= 365
        then 'long_term'
        else 'new'
    end as customer_type,
    count(*) as customers,
    round(avg(total_orders),2) as avg_orders,
    round(avg(total_spend),2) as avg_spend,
    round(avg(avg_order_value),2) as avg_order_value
from customer_metrics
group by customer_type;

-- S4.
-- Product Affinity Analysis: Which music genres, artists, or albums are
-- frequently purchased together by customers? How can this information
-- guide product recommendations and cross-selling initiatives?

select
    g1.name as genre_1,
    g2.name as genre_2,
    count(*) as frequency
from invoice_line il1
join invoice_line il2
    on il1.invoice_id = il2.invoice_id
   and il1.track_id < il2.track_id
join track t1
    on il1.track_id = t1.track_id
join track t2
    on il2.track_id = t2.track_id
join genre g1
    on t1.genre_id = g1.genre_id
join genre g2
    on t2.genre_id = g2.genre_id
group by
    g1.name,
    g2.name
order by frequency desc;

-- S5.
-- Regional Market Analysis: Do customer purchasing behaviors and churn rates
-- vary across different geographic regions or store locations? How might
-- these correlate with local demographic or economic factors?

select
    c.country,
    count(distinct c.customer_id) as customers,
    count(i.invoice_id) as orders_count,
    round(sum(i.total),2) as revenue,
    round(avg(i.total),2) as avg_order_value
from customer c
left join invoice i
    on c.customer_id = i.customer_id
group by c.country
order by revenue desc;

-- S6.
-- Customer Risk Profiling: Based on customer profiles (age, gender, location,
-- purchase history), which customer segments are more likely to churn or
-- pose a higher risk of reduced spending? What factors contribute to this
-- risk?

with customer_metrics as(
    select
        c.customer_id,
        concat(c.first_name, ' ', c.last_name) as customer_name,
        c.country,
        max(i.invoice_date) as last_purchase_date,
        count(i.invoice_id) as total_orders,
        sum(i.total) as total_spent,
        datediff(current_date(), max(i.invoice_date)) as days_since_last_purchase
    from customer c
    join invoice i
        on c.customer_id = i.customer_id
    group by
        c.customer_id,
        concat(c.first_name, ' ', c.last_name),
        c.country
)
select
    customer_name,
    country,
    total_orders,
    total_spent,
    days_since_last_purchase,
    case
        when days_since_last_purchase > 180	then 'High Risk (Churned)'
        when days_since_last_purchase > 90 then 'Medium Risk (Lapsing)'
        when total_spent < 10 and total_orders = 1 then 'Low Value / One-time Buyer'
        else 'Active / Loyal'
    end as risk_profile
from customer_metrics
order by days_since_last_purchase desc;

-- S7.
-- Customer Lifetime Value Modeling: How can you leverage customer data
-- (tenure, purchase history, engagement) to predict the lifetime value of
-- different customer segments? This could inform targeted marketing and
-- loyalty program strategies. Can you observe any common characteristics
-- or purchase patterns among customers who have stopped purchasing?

with customer_metrics as (
    select c.customer_id,
        concat(c.first_name, ' ', c.last_name) as name, (timestampdiff( month,
                min(i.invoice_date),
                max(i.invoice_date)
            ) + 1
        ) as tenure_months,
        count(i.invoice_id) as total_orders,
        sum(i.total) as total_spent
    from customer c
    join invoice i
        on c.customer_id = i.customer_id
    group by c.customer_id,
			concat(c.first_name, ' ', c.last_name)
),
ltv_projection as (
    select *,
        (total_spent / tenure_months) as monthly_avg_spend,
        ((total_spent / tenure_months) * 24) as projected_24mo_ltv
    from customer_metrics
)
select
    name,
    total_spent as historical_ltv,
    round(monthly_avg_spend, 2) as monthly_velocity,
    round(projected_24mo_ltv, 2) as future_potential,
    case
        when monthly_avg_spend > 5 then 'Platinum (High Velocity)'
        when total_spent > 45 then 'Gold (High History)'
        else 'Silver (Low Engagement)'
    end as segment
from ltv_projection
order by projected_24mo_ltv desc;

-- S8.
-- If data on promotional campaigns (discounts, events, email marketing) is
-- available, how could you measure their impact on customer acquisition,
-- retention, and overall sales?


-- S9.
-- How would you approach this problem, if the objective and subjective
-- questions weren't given?

-- revenue analysis
select
    round(sum(total),2) as total_revenue
from invoice;

-- customers
select
    count(*) as total_customers
from customer;

-- product sales
select
    track_id,
    count(*) as total_sales
from invoice_line
group by track_id
order by total_sales desc;

-- geography
select
    billing_country as country,
    round(sum(total),2) as revenue
from invoice
group by billing_country
order by revenue desc;


-- S10.
-- How can you alter the "Albums" table to add a new column named
-- "ReleaseYear" of type INTEGER to store the release year of each album?

alter table album
add column releaseyear int;

-- S11.
-- Chinook is interested in understanding the purchasing behavior of customers
-- based on their geographical location. They want to know the average
-- total amount spent by customers from each country, along with the number
-- of customers and the average number of tracks purchased per customer.
-- Write an SQL query to provide this information.

with customer_stats as (
    select
        c.country,
        c.customer_id,
        sum(i.total) as total_spent,
        sum(il.quantity) as tracks_purchased
    from customer c
    left join invoice i
        on c.customer_id = i.customer_id
    left join invoice_line il
        on i.invoice_id = il.invoice_id
    group by
        c.country,
        c.customer_id
)
select
    country,
    count(customer_id) as total_customers,
    round(avg(total_spent),2) as avg_customer_spend,
    round(avg(tracks_purchased),2) as avg_tracks_per_customer
from customer_stats
group by country
order by avg_customer_spend desc;

/* ===================================== END OF FILE ===================================== */
