with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payment_totals as (
    select * from {{ ref('int_payment_totals') }}
),

customer_payments as (
    select
        orders.customer_id,
        sum(payment_totals.total_amount) as lifetime_spend
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
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        customer_orders.number_of_orders,
        coalesce(customer_payments.lifetime_spend, 0) as lifetime_spend
    from customer_orders
    left join customer_payments on customer_orders.customer_id = customer_payments.customer_id
)

select * from final
