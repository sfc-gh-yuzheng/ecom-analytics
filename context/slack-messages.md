# #data-platform — Slack Channel Export
## 17-19 Feb 2026

---

**@sarah.chen** — 17 Feb, 2:15 PM
Picking up issue #1 (CLV metric). Going to create `fct_customer_lifetime_value` in marts. Will join `int_customer_orders` + `int_payment_totals` through `stg_orders`. Should be straightforward.

**@james.park** — 17 Feb, 2:18 PM
👍 Reminder: go through `int_payment_totals` for spend, not `stg_payments` directly. The intermediate model handles the payment dedup we fixed in Q4.

**@sarah.chen** — 17 Feb, 2:20 PM
Yep, got it. Will also make sure to use `COUNT(DISTINCT order_id)` for the order count, not `COUNT(*)`.

---

**@jordan.lee** — 17 Feb, 3:45 PM
FYI — just checked the warehouse monitor. Our `COMPUTE_WH` (X-Small) is running the full dbt build in ~8 seconds. Adding one more table materialisation won't move the needle. We're fine.

**@sarah.chen** — 17 Feb, 3:47 PM
Good to know. The CLV model will be a table (same as other marts). It's a small dataset for now.

---

**@maria.santos** — 18 Feb, 9:02 AM
Team — reminder that ANY mart model with customer PII must use `mask_pii()`. After the November incident where a contractor accessed unmasked emails, this is now a board-level requirement. The governance hook should catch it automatically, but I'll verify in the PR review.

Also: I want to see entries in the `GOVERNANCE_AUDIT` table showing the hook fired during development. This proves our automated compliance pipeline is working.

**@sarah.chen** — 18 Feb, 9:05 AM
Understood. I'll intentionally test the hook by writing the email column without masking first, then fix it. That way the audit trail shows the BLOCK → correction flow.

**@maria.santos** — 18 Feb, 9:06 AM
Perfect. That's exactly what I want to demonstrate to the board. 👏

---

**@lisa.park** — 18 Feb, 11:30 AM
Update from Rebecca (Marketing): She confirmed the campaign targeting will use email, lifetime spend, and days since last order as the primary segmentation fields. Customers with >$200 lifetime spend and >90 days since last order are the "win-back" segment.

**@sarah.chen** — 18 Feb, 11:32 AM
Noted. I'll make sure those columns have clear descriptions in the YAML schema so the dashboard team knows what they're looking at.

---

**@jordan.lee** — 18 Feb, 4:10 PM
@sarah.chen quick thought — for the `days_since_last_order` column, since the model is materialised as a table, the value will be stale until the next dbt build. It'll drift by 1 day between builds. Not a problem for a weekly campaign, but worth documenting.

**@sarah.chen** — 18 Feb, 4:12 PM
Good call. I'll add a note in the column description: "Calculated at build time — value reflects days as of last dbt build, not real-time."

**@jordan.lee** — 18 Feb, 4:13 PM
If it ever becomes a problem, we can switch to a view or add a Snowflake dynamic table. But for now, table is the right call.

---

**@james.park** — 19 Feb, 8:45 AM
Just double-checked: `int_payment_totals` is confirmed working correctly. Ran a quick validation — all 99 orders have exactly one row each, totals match the raw payments. The Q4 dedup fix is solid.

**@sarah.chen** — 19 Feb, 9:00 AM
Great. PR should be up today. Will tag everyone for review.

---

**@maria.santos** — 19 Feb, 2:30 PM
One more thing — when the CLV model goes live, I'll need to grant `PII_ALLOWED` to Rebecca's role (`MARKETING_ANALYST`) so she can see actual emails. Until then, she'll see masked values (`***@domain.com`). I'll do this after the PR is merged and deployed.

**@lisa.park** — 19 Feb, 2:32 PM
Thanks Maria. I'll let Rebecca know she'll see masked data initially.
