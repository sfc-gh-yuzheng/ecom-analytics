with payments as (
    select * from {{ ref('stg_payments') }}
),

payment_totals as (
    select
        order_id,
        sum(amount) as total_amount,
        count(payment_id) as number_of_payments,
        max(payment_method) as primary_payment_method
    from payments
    group by order_id
)

select * from payment_totals
