From: Lisa Park <lisa.park@acmecommerce.com.au>
To: Data Platform Team <data-platform@acmecommerce.com.au>
CC: James Park <james.park@acmecommerce.com.au>, Sarah Chen <sarah.chen@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 09:14:00 +1000
Subject: RE: Retention campaign — need CLV metric ASAP

Hi team,

Following up from Friday's exec meeting — the board has approved the Q2 retention campaign budget ($1.2M) but Marketing needs a customer lifetime value metric before they can build targeting segments.

Specifically, Rebecca (Head of Marketing) needs:
- Lifetime spend per customer
- Order frequency (total orders + average order value)
- Recency indicators — days since first and last order
- Customer email for campaign targeting (she knows this needs to be masked for non-privileged roles)

Timeline: She wants this in the dashboard by end of next week. I know that's tight, but the campaign launch date is locked to March 10.

One thing to flag — in the Q4 retention analysis, we discovered that 3 customers had duplicate payment records that inflated their CLV by ~15%. James mentioned this was fixed in the int_payment_totals model but I want to make sure we're using the corrected aggregation, not raw payment sums.

Also, Maria from Governance pinged me — she wants to make sure any new model with customer email goes through the PII review process. She referenced the incident in November where a contractor accessed unmasked emails via a mart view. Let's not repeat that.

Can someone pick up the GitHub issue (#1) I created? Happy to jump on a call if needed.

Cheers,
Lisa Park
Product Manager — Growth & Retention


---

From: Maria Santos <maria.santos@acmecommerce.com.au>
To: Lisa Park <lisa.park@acmecommerce.com.au>
CC: Data Platform Team <data-platform@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 10:42:00 +1000
Subject: RE: RE: Retention campaign — need CLV metric ASAP

Lisa,

Thanks for flagging the PII aspect early. A few non-negotiables from my side:

1. The email column in any mart model MUST use our mask_pii() macro. We updated this last month to use is_role_in_session('PII_ALLOWED') instead of current_role() — this supports role hierarchy properly.

2. I'll need to see the governance audit trail showing the hook caught any PII violations during development. This is a board-level compliance requirement since the November incident.

3. For the Australian Privacy Act (APP 11), we need to ensure data minimisation — only include the columns Marketing actually needs. Don't expose raw names if they're not required for the campaign.

4. Rebecca's team will need the PII_ALLOWED role granted before they can see actual emails. I'll handle that separately once the model is deployed.

Happy to review the PR when it's ready.

Maria Santos
Data Governance Lead


---

From: James Park <james.park@acmecommerce.com.au>
To: Data Platform Team <data-platform@acmecommerce.com.au>
Date: Mon, 17 Feb 2026 11:03:00 +1000
Subject: RE: RE: RE: Retention campaign — need CLV metric ASAP

Quick note on the duplicate payments issue Lisa mentioned —

The fix is already in int_payment_totals. It aggregates payments per order (SUM of amount, grouped by order_id), so even if there were duplicate raw payment records, the intermediate model gives you one row per order with the correct total.

If the new CLV model joins through int_payment_totals → stg_orders → customer_id, it'll get the corrected numbers. Just make sure you DON'T sum payments directly from stg_payments — always go through int_payment_totals.

Also, for the order frequency metric: use COUNT(DISTINCT order_id) not COUNT(*) — there are edge cases where a single order has multiple payment methods.

James
