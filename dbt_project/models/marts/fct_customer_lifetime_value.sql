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

customer_spend as (
    select
        orders.customer_id,
        sum(payment_totals.total_amount) as total_lifetime_spend
    from orders
    left join payment_totals on orders.order_id = payment_totals.order_id
    group by orders.customer_id
),

customer_preferred_payment as (
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

final as (
    select
        customer_orders.customer_id,
        {{ mask_pii('customer_orders.email') }} as email,
        {{ mask_pii("customer_orders.first_name || ' ' || customer_orders.last_name") }} as customer_name,
        customer_orders.number_of_orders as total_orders,
        coalesce(customer_spend.total_lifetime_spend, 0) as total_lifetime_spend,
        case
            when customer_orders.number_of_orders > 0
            then coalesce(customer_spend.total_lifetime_spend, 0) / customer_orders.number_of_orders
            else 0
        end as avg_order_value,
        datediff('day', customer_orders.first_order_date, current_date) as days_since_first_order,
        datediff('day', customer_orders.most_recent_order_date, current_date) as days_since_last_order,
        customer_preferred_payment.payment_method as preferred_payment_method,
        case
            when coalesce(customer_spend.total_lifetime_spend, 0) >= 500
                and datediff('day', customer_orders.most_recent_order_date, current_date) <= 90
            then 'VIP'
            when coalesce(customer_spend.total_lifetime_spend, 0) >= 200
                and datediff('day', customer_orders.most_recent_order_date, current_date) <= 90
            then 'Regular'
            when coalesce(customer_spend.total_lifetime_spend, 0) >= 200
                and datediff('day', customer_orders.most_recent_order_date, current_date) > 90
            then 'At-Risk'
            else 'New'
        end as customer_segment
    from customer_orders
    left join customer_spend
        on customer_orders.customer_id = customer_spend.customer_id
    left join customer_preferred_payment
        on customer_orders.customer_id = customer_preferred_payment.customer_id
        and customer_preferred_payment.rn = 1
)

select * from final
