---
name: business-requirements
description: "Acme Commerce business logic, metric definitions, segmentation rules, and requirements interpretation. Use when: reading a GitHub issue, translating requirements into implementation, defining CLV metrics, applying segmentation thresholds, or verifying business logic alignment. Triggers: github issue, issue, requirements, business logic, implement issue, CLV, segmentation, metric definition, acceptance criteria, lifetime value, customer segment."
---

# Business Requirements — Acme Commerce

You translate GitHub issues and stakeholder requirements into correct implementations. Every new model must align with the canonical metric definitions, segmentation rules, and data lineage constraints documented here.

## When to Use

- Reading a GitHub issue to plan implementation
- Translating acceptance criteria into model logic
- Choosing the correct aggregation method for a business metric
- Applying customer segmentation thresholds
- Deciding which intermediate models to join through
- Reviewing whether an implementation matches what was requested

## Metric Definitions

These are the canonical definitions for Acme Commerce business metrics. Do not deviate without stakeholder approval.

| Metric | Definition | Correct Source | Aggregation |
|--------|-----------|----------------|-------------|
| **Lifetime spend** | Total payment amount across all of a customer's orders | `int_payment_totals.total_amount` joined via `stg_orders.order_id` | `SUM(total_amount)` grouped by `customer_id` |
| **Total orders** | Count of distinct orders placed by a customer | `stg_orders` | `COUNT(DISTINCT order_id)` — NOT `COUNT(*)` (split payments create multiple payment rows per order) |
| **Average order value** | Lifetime spend divided by total orders | Derived from the two metrics above | `lifetime_spend / total_orders` with `CASE` guard for zero-order customers |
| **Days since first order** | Calendar days between first order date and today | `int_customer_orders.first_order_date` | `DATEDIFF('day', first_order_date, CURRENT_DATE())` |
| **Days since last order** | Calendar days between most recent order and today | `int_customer_orders.most_recent_order_date` | `DATEDIFF('day', most_recent_order_date, CURRENT_DATE())` |
| **Preferred payment method** | The payment method a customer has used most frequently across all orders | `stg_payments` joined to `stg_orders` | Count by `(customer_id, payment_method)`, rank with `ROW_NUMBER()` using `payment_count DESC, payment_method ASC` as tiebreaker. Pick `rn = 1`. |

### Why These Sources Matter

- **Spend MUST flow through `int_payment_totals`**: This model aggregates payments per order and handles the Q4 payment dedup issue where 3 customers had duplicate payment records inflating CLV by ~15%. Never sum directly from `stg_payments`.
- **Order count uses DISTINCT**: A single order can have multiple payments (split payments). `COUNT(*)` on a payments table overcounts.
- **AOV is spend/orders, not AVG(amount)**: Using `AVG(total_amount)` from `int_payment_totals` treats each order equally, but the business definition is the ratio of total spend to total orders at the customer level.

## Segmentation Rules

Marketing's 4-tier customer segmentation for retention campaigns. Thresholds confirmed by Rebecca (Head of Marketing) for Q2 2026 — will not change this quarter.

### Evaluation Order

Segments MUST be evaluated in this order (first match wins):

| Priority | Segment | Spend Threshold | Recency Threshold | Description |
|----------|---------|----------------|-------------------|-------------|
| 1 | **VIP** | ≥ $500 | Ordered within last 90 days | High-value, active customers |
| 2 | **Regular** | ≥ $200 | Ordered within last 90 days | Moderate-value, active customers |
| 3 | **At-Risk** | ≥ $200 | No orders in last 90 days | High-value customers gone quiet — **primary campaign target** |
| 4 | **New** | < $200 | Any | Low spend (regardless of recency) |

### Implementation Pattern

```sql
CASE
    WHEN lifetime_spend >= 500
        AND days_since_last_order <= 90
    THEN 'VIP'
    WHEN lifetime_spend >= 200
        AND days_since_last_order <= 90
    THEN 'Regular'
    WHEN lifetime_spend >= 200
        AND days_since_last_order > 90
    THEN 'At-Risk'
    ELSE 'New'
END AS customer_segment
```

Hardcoded thresholds are acceptable for v1 (confirmed by Lisa Park, PM). Configurable thresholds flagged as future improvement by Maria Santos (Governance).

## Requirements Interpretation Rules

When reading a GitHub issue, follow these rules to translate requirements into implementation:

### Rule 1 — Issue acceptance criteria are must-haves
Every checked/unchecked box in the acceptance criteria section is a hard requirement. The implementation is not complete until all are addressed.

### Rule 2 — Email-only requests are stretch goals
Requirements mentioned only in stakeholder emails (not in the issue) are nice-to-haves. Examples from this project:
- `first_order_channel` (Lisa's email — stretch goal, skip for v1)
- `is_active` boolean flag (Lisa's follow-up email — nice-to-have)

Do NOT implement stretch goals unless explicitly asked. Flag them in the PR description.

### Rule 3 — Check for implicit PII requirements
The issue may not list all PII columns. Cross-reference with the `pii-governance` skill:
- Concatenated names (`first_name || ' ' || last_name`) are PII even if the issue only mentions email
- Any column derivable to a person's identity requires `mask_pii()` in marts

### Rule 4 — Map technical notes to implementation constraints
The "Technical Notes" section of an issue contains non-negotiable implementation constraints:
- Required join paths (e.g., "use `int_payment_totals` for spend")
- Known data issues to avoid (e.g., payment dedup)
- Staleness caveats to document

### Rule 5 — Verify against stakeholder emails
Before finalizing implementation, check `context/emails.md` for:
- Corrections to the issue (e.g., Maria flagging that customer name is PII)
- Technical guidance (e.g., James specifying `COUNT(DISTINCT order_id)`)
- Explicit rejections of approaches (e.g., "do NOT sum from `stg_payments` directly")

## Data Lineage Constraints

Required join paths for Acme Commerce metrics. These are not suggestions — they exist to avoid known data quality issues.

```
Customer identity + order history:
  stg_customers ──→ int_customer_orders
    (customer_id, first_name, last_name, email, first_order_date, most_recent_order_date, number_of_orders)

Spend per customer:
  stg_orders ──→ int_payment_totals (join on order_id)
    Then GROUP BY customer_id from stg_orders
    (lifetime_spend, total_orders)

Preferred payment method:
  stg_payments ──→ stg_orders (join on order_id to get customer_id)
    Then COUNT by (customer_id, payment_method), rank, pick top 1
    Requires new intermediate model: int_customer_payment_methods
```

### Prohibited Paths

| Do NOT | Why | Correct Path |
|--------|-----|-------------|
| Sum amounts from `stg_payments` directly | Duplicate payment records (Q4 incident) | Join through `int_payment_totals` |
| Use `COUNT(*)` for order count on payment-joined data | Split payments inflate count | `COUNT(DISTINCT order_id)` |
| Use `MAX(payment_method)` for preferred method | Lexicographic — not frequency-based | `ROW_NUMBER()` over count with alphabetical tiebreaker |
| Join marts directly to staging | Violates layering convention | Route through intermediate models |

## Known Pitfalls

| Pitfall | Impact | Mitigation |
|---------|--------|------------|
| **Payment dedup** | 3 customers had duplicate payments in Q4, inflating CLV by ~15% | Always use `int_payment_totals` which aggregates per order |
| **Split payments** | One order can have multiple payment rows | Use `COUNT(DISTINCT order_id)` for order counts |
| **`MODE()` tie ambiguity** | `MODE()` returns arbitrary value on ties (e.g., 2 credit_card + 2 bank_transfer) | Use `ROW_NUMBER()` with deterministic tiebreaker (`payment_method ASC`) |
| **Point-in-time staleness** | `days_since_*` and `customer_segment` are snapshot values — stale between table builds | Document in YAML schema description. Not a bug — expected for table materialization |
| **Concatenated name = PII** | `first_name \|\| ' ' \|\| last_name` is PII under Australian Privacy Act even if issue only flags email | Apply `mask_pii()` or `is_role_in_session('PII_ALLOWED')` check |
| **Zero-order customers** | Division by zero in AOV calculation if customer has no orders | Guard with `CASE WHEN total_orders > 0 THEN ... ELSE 0 END` |
| **Null amounts from LEFT JOIN** | Customers with no payments get NULL spend | Wrap in `COALESCE(..., 0)` |

## Workflow

### Step 1: Read the GitHub Issue
Parse the issue into: background, metric requirements, segmentation rules, targeting fields, acceptance criteria, and technical notes.

### Step 2: Map Requirements to Metric Definitions
For each metric in the issue, look it up in the Metric Definitions table above. Use the canonical source and aggregation — do not invent alternatives.

### Step 3: Check Data Lineage Constraints
Verify the planned join path against the required paths above. Flag any prohibited paths.

### Step 4: Cross-Reference Emails
Read `context/emails.md` for corrections, implicit requirements, and technical guidance not captured in the issue.

### Step 5: Identify Intermediate Models Needed
If the required join path needs a model that doesn't exist yet, plan to create it (e.g., `int_customer_payment_methods` for preferred payment method).

**⚠️ STOP**: If the issue requirements conflict with the canonical metric definitions or data lineage constraints above, flag the conflict before proceeding.

## Stopping Points

- ✋ If a metric definition in the issue differs from the canonical table — confirm with user
- ✋ If a required join path doesn't exist yet — confirm the intermediate model design
- ✋ If stretch goals from emails are ambiguous — confirm scope with user

## Output

- Requirements mapped to canonical metric definitions
- Join path plan with intermediate models identified
- Pitfalls flagged with mitigations
- Stretch goals listed separately from must-haves
