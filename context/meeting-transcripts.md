# Data Platform Standup — 18 Feb 2026
**Attendees**: Sarah Chen, Jordan Lee, James Park, Lisa Park (guest)
**Duration**: 22 minutes

## Agenda
- CLV metric for retention campaign (Issue #1)
- Q2 pipeline capacity planning

---

### CLV Metric Discussion

**Lisa**: Quick context — board approved the retention budget. Marketing needs CLV in the dashboard by end of next week. I've created issue #1 with the requirements. Key fields: lifetime spend, order count, avg order value, recency, and email for targeting.

**Sarah**: I'll pick this up. It should be a new fact table in marts — `fct_customer_lifetime_value`. It'll join `int_customer_orders` for the customer details and `int_payment_totals` for the spend aggregation. Standard pattern.

**James**: Make sure you go through `int_payment_totals` for spend, not raw payments. We had the duplicate issue in Q4 — the intermediate model handles the dedup.

**Sarah**: Got it. I'll use `int_payment_totals` joined to `stg_orders` for the payment-to-customer link, then join `int_customer_orders` for the customer details.

**Jordan**: What materialization are you thinking? If Marketing is querying this from a dashboard, a table makes sense — it's a cross-domain join that would be expensive to recompute on every query.

**Sarah**: Agreed — table materialization in marts, same as `dim_customers` and `fct_orders`.

**Lisa**: One question — does "average order value" mean average of order totals, or average of individual payment amounts? Some orders have split payments.

**James**: Good question. It should be average of the total payment per order — so `AVG(int_payment_totals.total_amount)`. That way a split payment order counts as one value, not two.

**Sarah**: Makes sense. I'll document that in the YAML schema description.

**Jordan**: On the recency metrics — `days_since_first_order` and `days_since_last_order` — use `datediff('day', date, current_date())`. These will change daily since it's a table materialization. That's fine for a retention campaign, but flag it in the docs so nobody expects static values.

**Sarah**: Will do.

**Lisa**: Maria also wants to make sure the PII hook catches any issues. Can we test that during development?

**Sarah**: Yes — the governance hook runs on every file write. If I try to add email without `mask_pii()`, it'll block the write and log it to the audit table. Maria can see the audit trail in the PR review.

**Action items**:
- Sarah: Build `fct_customer_lifetime_value` model (target: tomorrow)
- Sarah: Ensure governance hook fires on PII, document in PR
- James: Verify `int_payment_totals` dedup is working correctly
- Jordan: Review model performance once PR is up
- Lisa: Brief Rebecca on timeline and PII_ALLOWED role requirement

---

### Q2 Pipeline Capacity

**Jordan**: Quick flag — we're at 72% warehouse utilisation on the daily 6am build. Adding more mart tables is fine for now, but if we add 3+ more fact tables this quarter, we should consider bumping to a Medium warehouse or staggering the build.

**Sarah**: Noted. The CLV model is small — 100 customers, maybe 1000 at scale. Not a concern yet.

**Jordan**: Agreed. Just planting the seed for the capacity review in April.

---

*Notes taken by Sarah Chen*
