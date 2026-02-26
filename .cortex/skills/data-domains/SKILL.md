---
name: data-domains
description: "Acme Commerce data domain ownership, table lineage, SLAs, and downstream consumers. Use when: analyzing which domains a change affects, identifying table dependencies, checking SLAs, or determining who owns a data asset. Triggers: what domain, who owns, what tables, data lineage, SLA, downstream, upstream, domain owner, table dependencies."
---

# Data Domains — Acme Commerce

You have authoritative knowledge of Acme Commerce's three data domains. When any change, issue, or question touches data assets, use this skill to identify affected domains, ownership, and dependencies.

## When to Use

- Assessing which domains a new feature or model change touches
- Identifying upstream/downstream table dependencies
- Determining SLA impact of a change
- Flagging when cross-team coordination is needed

## Domains

### Customer Domain
- **Owner**: Data Platform Team (lead: **Sarah Chen**)
- **SLA**: Refreshed within 4 hours of source update
- **PII Classification**: HIGH — email, name, phone, address
- **Consumers**: Marketing dashboards, CRM sync, customer support tools
- **Key Tables**: `stg_customers` → `int_customer_orders` → `dim_customers`

### Order Domain
- **Owner**: Analytics Engineering Team (lead: **James Park**)
- **SLA**: Refreshed within 1 hour — revenue-critical
- **PII Classification**: LOW — no direct PII, links to Customer via `customer_id`
- **Consumers**: Executive revenue dashboards, finance reconciliation, demand forecasting
- **Key Tables**: `stg_orders` → `fct_orders`

### Finance Domain
- **Owner**: Finance Analytics Team (lead: **Maria Santos**)
- **SLA**: Daily reconciliation by 06:00 AEST
- **PII Classification**: MEDIUM — payment methods are sensitive but not PII
- **Consumers**: Monthly close process, audit reports, tax calculations
- **Key Tables**: `stg_payments` → `int_payment_totals`

## Table Lineage

```
RAW.CUSTOMERS ──→ stg_customers ──→ int_customer_orders ──→ dim_customers
                                                          ↘ fct_customer_lifetime_value
RAW.ORDERS ─────→ stg_orders ────→ int_customer_orders
                                 ├→ int_payment_totals ──→ fct_orders
RAW.PAYMENTS ───→ stg_payments ──→ int_payment_totals
```

## Workflow

### Step 1: Identify Affected Domains

For any change, list which domains are touched and why.

### Step 2: Check Cross-Domain Impact

If a change crosses multiple domains, **flag for cross-team coordination** between domain owners. Example: a model joining Customer and Finance data requires sign-off from both Sarah Chen and Maria Santos.

### Step 3: Assess SLA Impact

Will this change affect refresh times? Order domain has the tightest SLA (1 hour). Adding expensive joins or new materializations to the order path requires performance review with James Park.

**⚠️ STOP**: If a change crosses 2+ domains, confirm the coordination plan with the user before proceeding.

## Stopping Points

- ✋ After domain analysis — confirm affected domains with user
- ✋ If cross-domain — confirm coordination plan before proceeding

## Output

- List of affected domains with ownership
- Upstream/downstream dependency map for the change
- SLA risk assessment (if applicable)
- Required stakeholder notifications
