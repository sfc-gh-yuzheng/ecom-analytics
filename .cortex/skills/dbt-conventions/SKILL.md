---
name: dbt-conventions
description: "dbt model naming conventions, layer placement, schema test patterns, materialization rules, and YAML documentation standards for Acme Commerce. Use when: creating new models, choosing the correct layer, adding schema tests, deciding materialization, or reviewing model structure. Triggers: naming convention, which layer, what tests, model pattern, dbt standard, schema test, materialization, stg_, int_, dim_, fct_, YAML schema."
---

# dbt Conventions — Acme Commerce

You enforce Acme Commerce's dbt project standards. Every model must follow these naming, layering, testing, and documentation conventions.

## When to Use

- Creating a new dbt model — which layer, what prefix, how to materialize
- Adding or reviewing schema tests
- Writing YAML documentation for columns
- Checking if a model follows project conventions

## Naming Conventions

| Layer | Prefix | Materialization | Purpose | Example |
|-------|--------|-----------------|---------|---------|
| Staging | `stg_` | view | 1:1 source mirror — rename, cast, no joins | `stg_customers` |
| Intermediate | `int_` | view | Business logic, joins — not exposed to consumers | `int_customer_orders` |
| Marts | `dim_` / `fct_` | table | Final consumption layer for dashboards | `dim_customers`, `fct_orders` |

**`dim_`** = entity/dimension (slowly changing attributes). **`fct_`** = event/fact (transactional, measurable).

**Enforcement**: The `governance_check.sh` hook blocks models with incorrect prefixes (exit code 2).

## Schema Test Requirements

### Every model must have:
- **Primary key**: `unique` + `not_null` tests

### Mart models (`dim_`, `fct_`) additionally require:
- `not_null` on all financial/metric columns (amounts, counts)
- `accepted_values` on categorical columns (status, segment, type)
- `relationships` test on foreign keys referencing other mart models

### Existing patterns to match:

**`fct_orders`** (reference standard):
```yaml
- unique + not_null on order_id (PK)
- not_null on customer_id, amount
- accepted_values on status: [placed, shipped, completed, returned]
- relationships: customer_id → dim_customers.customer_id
```

**`dim_customers`** (reference standard):
```yaml
- unique + not_null on customer_id (PK)
- not_null on lifetime_spend
```

## YAML Documentation Standards

Every model in `_mart_models.yml` / `_stg_models.yml` / `_int_models.yml` must include:

1. **Model-level `description`** — what the model represents, key caveats (e.g., point-in-time staleness)
2. **Column-level `description`** — especially for calculated fields, explain the business logic
3. **`meta` tags** on PII columns — see `pii-governance` skill for classification rules

### Example (gold standard):
```yaml
- name: fct_customer_lifetime_value
  description: >
    Customer lifetime value with 4-tier segmentation. PII masked via mask_pii().
    days_since_* columns are point-in-time — stale between builds.
  columns:
    - name: customer_id
      description: "Primary key"
      tests: [unique, not_null]
    - name: email
      description: "Masked for non-PII_ALLOWED roles."
      meta:
        data_classification: "PII - Personal Identifier"
      tests: [not_null]
```

## Model Design Rules

1. **Always use `ref()`** — no hardcoded table references
2. **Marts join through intermediate models** — never aggregate directly from staging/raw
3. **One grain per model** — document the grain in the model description
4. **`coalesce()` defensively** — handle nulls from left joins on metric columns

## Workflow

### Step 1: Determine Layer and Prefix
Based on the model's purpose, select the correct layer from the naming conventions table.

### Step 2: Apply Test Pattern
Match the schema test requirements for that layer. Copy patterns from existing models.

### Step 3: Write YAML Documentation
Add model and column descriptions. Flag PII columns for `meta` tags.

**⚠️ STOP**: If a new model doesn't fit cleanly into an existing layer, discuss with the user before proceeding.

## Stopping Points

- ✋ If layer placement is ambiguous — confirm with user
- ✋ After writing schema tests — verify against existing model patterns

## Output

- Model placed in correct layer with correct prefix
- Schema tests matching project conventions
- YAML documentation with descriptions and meta tags
