with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

payment_totals as (
    select * from {{ ref('int_payment_totals') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_payments as (
    select
        orders.customer_id,
        sum(payment_totals.total_amount) as lifetime_spend,
        count(distinct orders.order_id) as total_orders,
        avg(payment_totals.total_amount) as avg_order_value
    from orders
    left join payment_totals on orders.order_id = payment_totals.order_id
    group by orders.customer_id
),

final as (
    select
        customer_orders.customer_id,
        customer_orders.first_name,
        customer_orders.last_name,
        {{ mask_pii('customer_orders.email') }} as email,
        coalesce(customer_payments.lifetime_spend, 0) as lifetime_spend,
        coalesce(customer_payments.total_orders, 0) as total_orders,
        coalesce(customer_payments.avg_order_value, 0) as avg_order_value,
        datediff('day', customer_orders.first_order_date, current_date()) as days_since_first_order,
        datediff('day', customer_orders.most_recent_order_date, current_date()) as days_since_last_order
    from customer_orders
    left join customer_payments on customer_orders.customer_id = customer_payments.customer_id
)

select * from final
