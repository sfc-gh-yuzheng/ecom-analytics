---
name: pii-governance
description: "PII classification, masking rules, compliance frameworks, and data governance policies for Acme Commerce. Use when: assessing PII impact, applying mask_pii(), checking GDPR/Privacy Act compliance, adding data_classification meta tags, or reviewing governance audit trail. Triggers: PII, masking, mask_pii, compliance, GDPR, privacy, governance, data classification, sensitive data, personal information, audit trail."
---

# PII Governance — Acme Commerce

You enforce Acme Commerce's PII classification and masking rules. Every model change that introduces, exposes, or transforms personal information must comply with these rules.

## When to Use

- A new or modified model includes PII columns (email, name, phone, address)
- Checking whether `mask_pii()` is correctly applied
- Verifying `data_classification` meta tags in YAML schemas
- Assessing regulatory compliance (GDPR, Australian Privacy Act)
- Reviewing the governance audit trail

## PII Classification Table

| Column | Classification | Masking in Marts | Meta Tag Required |
|--------|---------------|-----------------|-------------------|
| `email` | PII - Personal Identifier | `{{ mask_pii('email') }}` | Yes |
| `first_name`, `last_name` | PII - Personal Identifier | `{{ mask_pii('name_col') }}` | Yes |
| `phone`, `address` | PII - Personal Identifier | `{{ mask_pii('col') }}` | Yes |
| `payment_method` | Sensitive (not PII) | No masking needed | No |
| `customer_id` | Pseudonymous identifier | No masking needed | No |

## Masking Rules

**Rule 1 — Mart models only**: PII columns in `models/marts/` must be wrapped in `{{ mask_pii('column_alias') }}`. Raw PII is permitted in staging and intermediate layers.

**Rule 2 — YAML meta tags**: PII columns must include in their schema YAML:
```yaml
meta:
  data_classification: "PII - Personal Identifier"
```

**Rule 3 — Implementation**: The `mask_pii()` macro uses `is_role_in_session('PII_ALLOWED')`:
- With `PII_ALLOWED` role → raw value visible
- Without → `regexp_replace(column, '.+@', '***@')`

**Rule 4 — Automated enforcement**: The `governance_check.sh` hook runs on every Write/Edit to model files. It blocks (exit code 2) if a PII column appears in a mart model without `mask_pii()`. Every check is logged to `ECOM_ANALYTICS.DBT_PROJECT.GOVERNANCE_AUDIT`.

## Compliance Frameworks

### GDPR (Article 25) — EU Customers
Data protection by design. PII must not be accessible without role-based access controls.
**Pass criteria**: `mask_pii()` applied + `PII_ALLOWED` role check + `data_classification` meta tags.

### Australian Privacy Act (APP 11)
Reasonable steps to protect personal information from misuse, loss, unauthorised access.
**Pass criteria**: Same as GDPR + schema tests on PII columns (not_null at minimum).

### SOX Controls — Finance Domain
Financial data must be auditable. Payment amounts must never be negative in marts.
**Pass criteria**: `not_null` tests on all amount fields.

### PCI-DSS — Payment Data
Payment card data must be protected. Current `payment_method` column contains category labels (credit_card, bank_transfer) — not card numbers. No masking required.

## Workflow

### Step 1: Identify PII Columns
Scan the model for any column matching the PII classification table above.

### Step 2: Verify Masking
For each PII column in a mart model, confirm `mask_pii()` is applied in the SQL and `data_classification` meta tag exists in the YAML.

### Step 3: Check Audit Trail
```bash
snow sql -c demo -q "SELECT * FROM ECOM_ANALYTICS.DBT_PROJECT.GOVERNANCE_AUDIT ORDER BY ts DESC LIMIT 10;"
```

**⚠️ STOP**: If any PII column is unmasked in a mart model, this is a compliance blocker. Flag immediately.

## Stopping Points

- ✋ If unmasked PII found in marts — flag as blocker before proceeding
- ✋ After compliance assessment — confirm findings with user

## Output

- PII column inventory with masking status (pass/fail per column)
- Compliance assessment against applicable frameworks
- Audit trail entries (if any)
- Required remediation steps
