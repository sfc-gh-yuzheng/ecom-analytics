# #data-platform — Slack Channel Export
## 17-19 Feb 2026

---

**@sarah.chen** — 17 Feb, 2:15 PM
Picking up issue #1 (CLV model with segmentation). Going to create `fct_customer_lifetime_value` in marts. Will join `int_customer_orders` + `int_payment_totals` through `stg_orders`. The segmentation logic adds some complexity but should be manageable.

**@james.park** — 17 Feb, 2:18 PM
👍 Reminder: go through `int_payment_totals` for spend, not `stg_payments` directly. The intermediate model handles the payment dedup we fixed in Q4. Also use `COUNT(DISTINCT order_id)` for order count — some orders have multiple payment rows.

**@sarah.chen** — 17 Feb, 2:20 PM
Got it. For the preferred payment method — James, you mentioned MODE() in the email thread. I'm leaning towards just using MODE() and accepting the tie ambiguity. We only have 4 payment methods so ties should be rare. Thoughts?

**@james.park** — 17 Feb, 2:24 PM
MODE() is fine for v1. If you want to be precise, you could do a subquery with `COUNT(*) ... ORDER BY count DESC, most_recent_order_date DESC LIMIT 1` but that's overkill for 100 customers. MODE() it is.

**@jordan.lee** — 17 Feb, 2:31 PM
Quick thought on the segmentation — the segment column is derived from `days_since_last_order` which is calculated at build time. A customer with `days_since_last_order = 89` will be "Regular" today but flip to "At-Risk" tomorrow after the build. That's fine for weekly campaigns, but document it clearly. Segment boundaries are fuzzy between builds.

**@sarah.chen** — 17 Feb, 2:33 PM
Good point. I'll add a column description noting it's calculated at build time. Same applies to `days_since_first_order` and `days_since_last_order` — those drift by 1 day between builds.

---

**@jordan.lee** — 17 Feb, 3:45 PM
FYI — just checked the warehouse monitor. `COMPUTE_WH` (X-Small) is running the full dbt build in ~8 seconds. Adding one more table materialisation won't move the needle. We're fine for now.

**@sarah.chen** — 17 Feb, 3:47 PM
Good to know. The CLV model is small — 100 customers. Not a concern yet.

---

**@maria.santos** — 18 Feb, 9:02 AM
Team — reminder that ANY mart model with customer PII must use `mask_pii()`. This applies to **both email AND customer name** — concatenated first+last is PII under the Australian Privacy Act. I flagged this in my email but want to make sure it's visible here too.

After the November incident where a contractor accessed unmasked emails, this is now a board-level requirement. The governance hook should catch email automatically, but I'm not sure it checks for name columns. Verify this manually.

**@sarah.chen** — 18 Feb, 9:05 AM
Understood. I'll make sure both `customer_email` and `customer_name` go through `mask_pii()`.

**@maria.santos** — 18 Feb, 9:08 AM
Also — I asked in the email thread for `data_classification` meta tags in the YAML schema for PII columns. I know this is new and we haven't done it on existing models, but I want to start the practice. Something like:
```
meta:
  data_classification: "PII - Contact Information"
```
Not blocking the PR on it, but strongly preferred.

---

**@lisa.park** — 18 Feb, 11:30 AM
Update from Rebecca (Marketing): She confirmed the segmentation thresholds:
- **VIP**: ≥$500 spend AND ordered in last 90 days
- **Regular**: ≥$200 spend AND ordered in last 90 days  
- **At-Risk**: ≥$200 spend BUT >90 days since last order
- **New**: <$200 spend

Primary campaign targets are At-Risk. She also wants the segment column to be testable — `accepted_values` test with those four values.

**@jordan.lee** — 18 Feb, 11:35 AM
Are we hardcoding those thresholds ($200, $500, 90 days) directly in the SQL? If Marketing changes them next quarter, that's a code change + full deploy cycle. We could pull them from a Snowflake parameter table or use dbt vars. Just flagging — not blocking.

**@sarah.chen** — 18 Feb, 11:38 AM
For v1, I'm going to hardcode them. Lisa confirmed in email the thresholds won't change this quarter. We can refactor to vars or a config table later if needed. Adding a comment in the SQL noting the source of the thresholds.

**@jordan.lee** — 18 Feb, 11:40 AM
Fair enough. Just make sure the comment references where the thresholds came from (Rebecca via Lisa, 18 Feb). Future us will thank you.

---

**@james.park** — 19 Feb, 8:45 AM
Just double-checked: `int_payment_totals` is confirmed working correctly. All 99 orders have exactly one row each, totals match the raw payments. The Q4 dedup fix is solid.

**@sarah.chen** — 19 Feb, 9:00 AM
Great. One question for the group — should `preferred_payment_method` be masked? It's not PII by itself, but combined with customer_id and spend patterns, you could argue it's quasi-identifying. Maria?

**@maria.santos** — 19 Feb, 9:15 AM
Payment method alone isn't PII. It's fine unmasked. The risk is in the combination with name+email, which are already masked. As long as those are masked, payment method is just a categorical attribute.

**@sarah.chen** — 19 Feb, 9:20 AM
Got it. PR should be up today. Will tag everyone for review.

---

**@maria.santos** — 19 Feb, 2:30 PM
When the CLV model goes live, I'll need to grant `PII_ALLOWED` to Rebecca's role (`MARKETING_ANALYST`) so she can see actual emails and names. Until then, she'll see masked values. I'll handle this after the PR is merged and deployed.

**@lisa.park** — 19 Feb, 2:32 PM
Thanks Maria. I'll let Rebecca know she'll see masked data initially.

**@jordan.lee** — 19 Feb, 3:00 PM
@sarah.chen one more thing — since `dim_customers` already has `lifetime_spend` and `number_of_orders`, make sure the CLV model doesn't just duplicate that. The value-add should be the segmentation, the payment method analysis, and the recency metrics. If someone asks "why not just add columns to dim_customers?" — the answer is that CLV is a different grain of analysis (campaign-oriented vs customer-master).

**@sarah.chen** — 19 Feb, 3:05 PM
Exactly. `dim_customers` is the customer master — stable attributes. `fct_customer_lifetime_value` is a campaign-oriented analytical model. Different consumers, different refresh expectations. I'll note this in the PR description.
