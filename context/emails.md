From: Lisa Park <lisa.park@acmecommerce.com.au>
To: Data Platform Team <data-platform@acmecommerce.com.au>
CC: James Park <james.park@acmecommerce.com.au>, Sarah Chen <sarah.chen@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 09:14:00 +1000
Subject: RE: Retention campaign — need CLV model with segments ASAP

Hi team,

Following up from Friday's exec meeting — the board approved the Q2 retention campaign budget ($1.2M) and Marketing needs a customer lifetime value model with segmentation before they can build targeting workflows.

I've created GitHub issue #1 with the full spec, but here's what Rebecca (Head of Marketing) specifically asked for in our 1:1 on Friday:

**Core metrics:**
- Lifetime spend per customer
- Order frequency (total orders + average order value)
- Recency indicators — days since first and last order

**Segmentation:**
- VIP, Regular, At-Risk, and New segments based on spend + recency
- At-Risk is the primary campaign target (high-value customers who've gone quiet)
- She mentioned $200 and $500 as the spend thresholds, 90 days for recency

**Targeting fields:**
- Customer email for campaign sends (masked for non-privileged roles, she knows the drill)
- Customer full name (first + last concatenated) — the email templates use "Hi {name}" personalisation
- Preferred payment method — they're running payment-method-specific offers (e.g., 10% off for credit card users)

**Timeline**: Dashboard by end of next week. Campaign launch locked to March 10.

One thing to flag — in the Q4 retention analysis, we found 3 customers with duplicate payment records that inflated CLV by ~15%. James confirmed this was fixed in `int_payment_totals` but I want to make sure we're using the corrected path.

Also — Rebecca asked whether we could add a `first_order_channel` column showing what payment method was used on their very first order. She thinks there's a correlation between acquisition channel and retention. I told her we'd see if the data supports it, but I didn't add it to the issue since it's a stretch goal. Flagging it here in case someone has time.

Cheers,
Lisa Park
Product Manager — Growth & Retention


---

From: Maria Santos <maria.santos@acmecommerce.com.au>
To: Lisa Park <lisa.park@acmecommerce.com.au>
CC: Data Platform Team <data-platform@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 10:42:00 +1000
Subject: RE: RE: Retention campaign — need CLV model with segments ASAP

Lisa,

Thanks for flagging early. A few non-negotiables from Governance:

1. **Both email AND customer name must use `mask_pii()`**. I noticed the issue only mentions email as PII — but concatenated first+last name is absolutely PII under the Australian Privacy Act. Make sure whoever picks this up knows that `customer_name` needs masking too.

2. The `mask_pii()` macro was updated last month to use `is_role_in_session('PII_ALLOWED')` instead of `current_role()`. This supports role hierarchy properly. Please verify the implementation uses the current version.

3. I need to see the **governance audit trail** showing the automated hook caught any PII violations during development. This has been a board-level requirement since the November incident where a contractor accessed unmasked emails through a mart view.

4. For Australian Privacy Act compliance (APP 11 — data minimisation): only include columns Marketing actually needs. Don't expose raw fields that aren't required for the campaign.

5. **New requirement** — I'd like the YAML schema to include `meta` tags with `data_classification` for any PII column. Something like:
   ```yaml
   meta:
     data_classification: "PII - Personal Identifier"
   ```
   This helps our automated scanning tools flag sensitive columns. I know we haven't done this on existing models, but I want to start with this one.

6. On the segmentation thresholds — are these hardcoded in the SQL? If Marketing changes the thresholds next quarter, do we need a code change and full deploy? Worth thinking about whether these should be configurable. Not blocking, but flagging for design discussion.

Happy to review the PR when it's ready.

Maria Santos
Data Governance Lead


---

From: James Park <james.park@acmecommerce.com.au>
To: Data Platform Team <data-platform@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 11:03:00 +1000
Subject: RE: RE: RE: Retention campaign — need CLV model with segments ASAP

Quick notes on the technical side:

**Payment dedup**: The fix is in `int_payment_totals`. It aggregates payments per order (`SUM(amount)` grouped by `order_id`), so duplicates are handled. The CLV model MUST join through `int_payment_totals` → `stg_orders` for the customer link. Do NOT sum from `stg_payments` directly.

**Order count**: Use `COUNT(DISTINCT order_id)` not `COUNT(*)` — there are edge cases with multiple payment methods per order.

**Average order value**: This should be `AVG(total_amount)` from `int_payment_totals`, not `SUM/COUNT`. Using AVG means split-payment orders are treated as one value, which is what Marketing wants.

**Preferred payment method**: This one's trickier than it sounds. `int_payment_totals` has `primary_payment_method` per order (uses `MAX()` which is just lexicographic — not great). For a true "preferred" method, you'd want a `MODE()` across all orders. Snowflake supports `MODE()` as an aggregate function, but watch out — if a customer has used credit_card twice and bank_transfer twice, `MODE()` returns an arbitrary one. Might be worth adding a tiebreaker (most recent). Or just go with the simpler approach and use the most frequent, accepting the tie ambiguity.

**First order attribution**: If Lisa's `first_order_channel` stretch goal makes it in, you'd need a window function — `FIRST_VALUE(payment_method) OVER (PARTITION BY customer_id ORDER BY order_date)` on the joined payments data. It's doable but adds complexity. I'd skip it for v1.

James


---

From: Lisa Park <lisa.park@acmecommerce.com.au>
To: Maria Santos <maria.santos@acmecommerce.com.au>
CC: Data Platform Team <data-platform@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 14:22:00 +1000
Subject: RE: RE: RE: RE: Retention campaign — need CLV model with segments ASAP

Maria — good catch on the customer name PII. I'll update the issue to call that out explicitly.

On your point about configurable thresholds — I hear you, but for the March 10 launch we need to keep it simple. Hardcoded thresholds are fine for v1. Rebecca confirmed the $200/$500/90-day numbers won't change this quarter. If they do change for Q3, we'll handle it then.

One more thing — Rebecca just pinged me. She wants to know if we can add a `is_active` boolean flag. Her definition: a customer is "active" if they've ordered within the last 180 days. She says the dashboard team prefers boolean flags over having to interpret days_since columns. I'm not adding this to the issue since it's nice-to-have, but wanted to float it.

Lisa
