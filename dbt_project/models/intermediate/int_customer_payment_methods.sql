with payments as (
    select * from {{ ref('stg_payments') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_payment_methods as (
    select
        orders.customer_id,
        payments.payment_method,
        count(*) as payment_count
    from payments
    inner join orders on payments.order_id = orders.order_id
    group by orders.customer_id, payments.payment_method
),

ranked as (
    select
        customer_id,
        payment_method,
        payment_count,
        row_number() over (
            partition by customer_id
            order by payment_count desc, payment_method
        ) as rn
    from customer_payment_methods
)

select
    customer_id,
    payment_method as preferred_payment_method
from ranked
where rn = 1
