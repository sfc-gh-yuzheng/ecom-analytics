# Data Platform Standup — 18 Feb 2026
**Attendees**: Sarah Chen, Jordan Lee, James Park, Lisa Park (guest), Maria Santos (guest)
**Duration**: 28 minutes

## Agenda
- CLV model with segmentation for retention campaign (Issue #1)
- Q2 pipeline capacity planning

---

### CLV Model Discussion

**Lisa**: Quick context — board approved the retention budget. Marketing needs the CLV model with customer segments in the dashboard by end of next week. I've updated issue #1 with the full spec. Key additions from Rebecca: customer segmentation (VIP/Regular/At-Risk/New), preferred payment method for targeted offers, and customer name for email personalisation.

**Sarah**: I'll pick this up. It'll be `fct_customer_lifetime_value` in marts — table materialisation. Joins `int_customer_orders` for customer details and `int_payment_totals` for spend aggregation. The segmentation adds a CASE WHEN block but it's straightforward.

**James**: Make sure you go through `int_payment_totals` for spend, not raw payments. The dedup from Q4 is in there. Also — for average order value, use `AVG(total_amount)` from `int_payment_totals`, not `SUM/COUNT`. That way split-payment orders count as one value.

**Sarah**: Got it. One thing I want to discuss — the four-segment model. Lisa, Rebecca wants VIP, Regular, At-Risk, and New. But looking at our data, the "New" segment is basically "everyone who hasn't spent much yet." That's a mix of genuinely new customers AND low-value ones who've been around a while. Should we split that?

**James**: I'd push back on adding a fifth segment. Four is already a lot for a v1. "New" is a fine catch-all. If Marketing needs finer granularity later, we can add a `customer_tenure_days` column and let them filter.

**Lisa**: Rebecca specifically asked for four. Let's keep it at four for now. If the campaign results show we need to split "New," we'll revisit in Q3.

**Sarah**: Fine with me. Four segments it is.

**Jordan**: On the segmentation thresholds — $200, $500, and 90 days. Are we hardcoding these or making them configurable?

**Sarah**: Hardcoding for v1. Lisa confirmed the thresholds are locked for this quarter.

**Jordan**: I'm not thrilled about that. If Rebecca changes her mind two weeks after launch, that's a code change, PR, review, merge, CI/CD deploy cycle. We could use dbt `var()` and set them in `dbt_project.yml` — same deploy cycle but at least the values are in config, not buried in SQL.

**James**: Jordan makes a fair point, but for a 100-customer dataset launching in 3 weeks, I'd rather ship simple and refactor later. Hardcode with a clear comment citing the source.

**Sarah**: I'll hardcode with a comment: "Thresholds from Rebecca (Head of Marketing) via Lisa, confirmed 18 Feb 2026." If they change, we know where to look.

**Jordan**: Fine. Just make sure the comment is there.

---

### PII Discussion

**Maria**: Two PII columns in this model — email and customer name. I want to be explicit: `customer_name` (first + last concatenated) is PII under the Australian Privacy Act, same as email. Both need `mask_pii()`.

**Sarah**: Agreed. I'll wrap both in `mask_pii()`.

**Maria**: Also — I've been pushing for `data_classification` meta tags in the YAML schema. I know we don't have this on `dim_customers` or `fct_orders` yet, but I want to start the practice with this model. It helps our automated compliance scanning.

**James**: Is that a blocker for the PR?

**Maria**: Not a blocker. Strongly preferred. If it slips, I'll add it as a follow-up task. But I'd rather get it right the first time.

**Sarah**: I'll try to include it. What format do you want?

**Maria**: Under the column definition in the YAML:
```
meta:
  data_classification: "PII - Contact Information"
```
For both email and customer_name.

---

### Preferred Payment Method

**Sarah**: For `preferred_payment_method` — James suggested `MODE()` in Slack. I'm going with that. If there's a tie, Snowflake picks arbitrarily, which is fine for our use case.

**James**: One nuance — MODE() across what? If you're computing it per customer, you need a subquery that has one row per order with the payment method, then MODE() over that. Don't MODE() over `stg_payments` directly because multi-payment orders would over-weight.

**Sarah**: Right — I'll MODE() over the `primary_payment_method` from `int_payment_totals` joined to `stg_orders`, grouped by customer. That gives one payment method per order, then MODE picks the most common.

**James**: That works.

---

### Model Overlap with dim_customers

**Jordan**: One design question — `dim_customers` already has `lifetime_spend` and `number_of_orders`. Are we duplicating data?

**Sarah**: Different purpose. `dim_customers` is the customer master — stable attributes, used as a dimension in joins. `fct_customer_lifetime_value` is campaign-oriented analytics — segmentation, recency, payment preferences. Different consumers, different refresh expectations. If we added all these columns to `dim_customers`, it would bloat the dimension with analytical fields.

**Jordan**: Makes sense. Just wanted to hear the rationale so we can defend it in review.

---

### Action Items

- **Sarah**: Build `fct_customer_lifetime_value` — target: tomorrow
- **Sarah**: Ensure both email and customer_name use `mask_pii()`, add `data_classification` meta tags if time
- **Sarah**: Hardcode segmentation thresholds with source comment
- **James**: Verify `int_payment_totals` dedup + validate MODE() approach for payment method
- **Jordan**: Review model performance and materialisation strategy once PR is up
- **Maria**: Review PII masking implementation and audit trail in PR
- **Lisa**: Brief Rebecca on timeline, PII_ALLOWED role requirement, and masked data initially

---

### Q2 Pipeline Capacity

**Jordan**: Quick flag — warehouse utilisation is at 72% on the daily 6am build. Adding one more table materialisation won't move the needle for now. But if we add 3+ more fact tables this quarter, we should consider bumping to a Medium warehouse or staggering the build.

**Sarah**: CLV model is small — 100 customers. No performance concern.

**Jordan**: Agreed. Just planting the seed for the capacity review in April.

---

*Notes taken by Sarah Chen*
