with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payment_totals as (
    select * from {{ ref('int_payment_totals') }}
),

customer_spend as (
    select
        orders.customer_id,
        sum(payment_totals.total_amount) as lifetime_spend,
        count(distinct orders.order_id) as total_orders
    from orders
    left join payment_totals on orders.order_id = payment_totals.order_id
    group by orders.customer_id
),

customer_payment_methods as (
    select * from {{ ref('int_customer_payment_methods') }}
),

final as (
    select
        customer_orders.customer_id,
        {{ mask_pii("customer_orders.first_name || ' ' || customer_orders.last_name") }} as customer_name,
        {{ mask_pii('customer_orders.email') }} as email,
        coalesce(customer_spend.lifetime_spend, 0) as lifetime_spend,
        coalesce(customer_spend.total_orders, 0) as total_orders,
        case
            when coalesce(customer_spend.total_orders, 0) > 0
            then coalesce(customer_spend.lifetime_spend, 0) / customer_spend.total_orders
            else 0
        end as average_order_value,
        datediff('day', customer_orders.first_order_date, current_date()) as days_since_first_order,
        datediff('day', customer_orders.most_recent_order_date, current_date()) as days_since_last_order,
        customer_payment_methods.preferred_payment_method,
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
    left join customer_payment_methods on customer_orders.customer_id = customer_payment_methods.customer_id
)

select * from final
