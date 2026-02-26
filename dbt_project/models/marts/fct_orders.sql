with orders as (
    select * from {{ ref('stg_orders') }}
),

payment_totals as (
    select * from {{ ref('int_payment_totals') }}
),

final as (
    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status,
        coalesce(payment_totals.total_amount, 0) as amount,
        payment_totals.number_of_payments,
        payment_totals.primary_payment_method
    from orders
    left join payment_totals on orders.order_id = payment_totals.order_id
)

select * from final
