with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payment_totals as (
    select * from {{ ref('int_payment_totals') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

-- Aggregate lifetime spend per customer using int_payment_totals
customer_spend as (
    select
        orders.customer_id,
        sum(payment_totals.total_amount) as lifetime_spend,
        avg(payment_totals.total_amount) as avg_order_value
    from orders
    left join payment_totals on orders.order_id = payment_totals.order_id
    group by orders.customer_id
),

-- Derive preferred payment method by frequency per customer
payment_frequency as (
    select
        orders.customer_id,
        payments.payment_method,
        count(*) as method_count,
        row_number() over (
            partition by orders.customer_id
            order by count(*) desc, payments.payment_method
        ) as rn
    from orders
    inner join payments on orders.order_id = payments.order_id
    group by orders.customer_id, payments.payment_method
),

preferred_payment as (
    select
        customer_id,
        payment_method as preferred_payment_method
    from payment_frequency
    where rn = 1
),

final as (
    select
        customer_orders.customer_id,
        customer_orders.first_name || ' ' || customer_orders.last_name as customer_name_raw,
        customer_orders.email as email_raw,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        customer_orders.number_of_orders,
        coalesce(customer_spend.lifetime_spend, 0) as lifetime_spend,
        coalesce(customer_spend.avg_order_value, 0) as avg_order_value,
        datediff('day', customer_orders.first_order_date, current_date()) as days_since_first_order,
        datediff('day', customer_orders.most_recent_order_date, current_date()) as days_since_last_order,
        preferred_payment.preferred_payment_method,

        -- 4-tier customer segmentation
        -- Thresholds from Rebecca (Head of Marketing) via Lisa, confirmed 18 Feb 2026
        case
            when coalesce(customer_spend.lifetime_spend, 0) >= 500
                and datediff('day', customer_orders.most_recent_order_date, current_date()) <= 90
                then 'VIP'
            when coalesce(customer_spend.lifetime_spend, 0) >= 200
                and datediff('day', customer_orders.most_recent_order_date, current_date()) <= 90
                then 'Regular'
            when coalesce(customer_spend.lifetime_spend, 0) >= 200
                and datediff('day', customer_orders.most_recent_order_date, current_date()) > 90
                then 'At-Risk'
            else 'New'
        end as customer_segment

    from customer_orders
    left join customer_spend on customer_orders.customer_id = customer_spend.customer_id
    left join preferred_payment on customer_orders.customer_id = preferred_payment.customer_id
)

select
    customer_id,
    {{ mask_pii('customer_name_raw') }} as customer_name,
    {{ mask_pii('email_raw') }} as email,
    first_order_date,
    most_recent_order_date,
    number_of_orders,
    lifetime_spend,
    avg_order_value,
    days_since_first_order,
    days_since_last_order,
    preferred_payment_method,
    customer_segment
from final
