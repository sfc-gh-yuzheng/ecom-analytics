# Acme Commerce — dbt Analytics with Cortex Code

A demo project showing how AI coding agents can build, govern, and review dbt models on Snowflake using [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code).

---

## What This Demo Shows

An AI agent reads a GitHub issue, interprets it through business architecture docs, generates dbt models, self-corrects when governance hooks block PII violations, commits and creates a PR, then **three review agents** each pull context from different organisational data sources (architecture docs, stakeholder emails, Slack messages, meeting transcripts) and synthesise it into actionable PR reviews. A human merges. CI/CD deploys to Snowflake.

The throughline: **agents pull context from scattered organisational knowledge and synthesise it into actionable work — but governance guardrails and human-in-the-loop merge ensure control is never lost.**

---

## Project Structure

```
ecom-analytics/
├── .cortex/                        # Cortex Code configuration
│   ├── agents/                     # Custom PR review agents
│   │   ├── pr-reviewer.md          # Orchestrator — spawns 3 reviewers
│   │   ├── pr-reviewer-architecture.md
│   │   ├── pr-reviewer-stakeholder.md
│   │   └── pr-reviewer-team-knowledge.md
│   └── skills/
│       └── business-architecture/
│           └── SKILL.md            # Business architecture skill
├── context/                        # Organisational context for agents
│   ├── emails.md                   # Stakeholder email threads
│   ├── slack-messages.md           # #data-platform Slack export
│   └── meeting-transcripts.md      # Standup meeting notes
├── dbt_project/                    # dbt project (deployed to Snowflake)
│   ├── models/
│   │   ├── staging/                # stg_ views — 1:1 source mirrors
│   │   ├── intermediate/           # int_ views — business logic joins
│   │   └── marts/                  # dim_/fct_ tables — consumption layer
│   ├── macros/
│   │   ├── mask_pii.sql            # Role-based PII masking macro
│   │   └── generate_schema_name.sql
│   └── dbt_project.yml
├── hooks/                          # Cortex Code governance hooks
│   ├── governance_check.sh         # PII masking + naming conventions
│   ├── no_merge_check.sh           # Prevents agents from merging PRs
│   └── sql_security_check.sh       # Blocks DROP, TRUNCATE, unsafe DELETE
├── scripts/
│   └── reset_demo.sh               # Reset everything to clean state
├── .github/workflows/
│   └── deploy-dbt-to-snowflake.yml # CI/CD pipeline
└── setup/
    └── seed_data.sql               # Raw data seeds
```

---

## Architecture

### dbt Layers

```
RAW (seeds)          STAGING (views)       INTERMEDIATE (views)       MARTS (tables)
─────────────        ───────────────       ────────────────────       ──────────────
raw.customers   →    stg_customers    →    int_customer_orders   →   dim_customers
raw.orders      →    stg_orders       →                          →   fct_orders
raw.payments    →    stg_payments     →    int_payment_totals    ┘
```

| Layer | Schema | Materialization | Naming | Purpose |
|-------|--------|----------------|--------|---------|
| Staging | `STAGING` | view | `stg_` | 1:1 rename and cast from raw |
| Intermediate | `INTERMEDIATE` | view | `int_` | Business logic joins, not exposed to consumers |
| Marts | `MARTS` | table | `dim_` / `fct_` | Final consumption layer for dashboards |

### Snowflake

- **Database**: `ECOM_ANALYTICS`
- **Execution**: Snowflake-native dbt via `snow dbt deploy` + `snow dbt execute`
- **Artifact schema**: `DBT_PROJECT` (stores deployed dbt project + governance audit table)
- **Auth**: Key-pair (RSA / SNOWFLAKE_JWT) for both local and CI/CD

### PII Masking

The `mask_pii()` macro uses Snowflake's `is_role_in_session()`:

```sql
CASE
    WHEN is_role_in_session('PII_ALLOWED') THEN column_value
    ELSE regexp_replace(column_value, '.+@', '***@')
END
```

Users with the `PII_ALLOWED` role see real values. Everyone else sees masked data. This is enforced at query time — no separate views needed.

---

## Cortex Code Features Used

### Custom Skill — Business Architecture

**File**: `.cortex/skills/business-architecture/SKILL.md`

A skill gives Cortex Code domain knowledge it wouldn't otherwise have. This skill teaches the agent about Acme Commerce's:

- **Data domains** — Customer (HIGH PII), Order (LOW PII), Finance (MEDIUM PII)
- **Model naming conventions** — `stg_`, `int_`, `dim_`, `fct_` per layer
- **Compliance requirements** — GDPR, Australian Privacy Act, SOX
- **Domain owners** — who owns what and who to notify
- **7-step analysis workflow** — identify domains → assess PII → map to models → evaluate SLAs → check compliance → identify stakeholders → generate requirements

When the agent reads a GitHub issue, this skill fires automatically and the agent interprets the request through the business architecture — placing models in the right layer, flagging PII, applying naming conventions.

### Custom Agents — Data-Source-Based PR Reviewers

**Files**: `.cortex/agents/pr-reviewer*.md`

Four agent definitions that work together:

| Agent | Data Sources It Reads | What It Reviews |
|-------|----------------------|-----------------|
| **Orchestrator** (`pr-reviewer.md`) | PR diff, changed files | Spawns the three reviewers in parallel, summarises findings |
| **Architecture & Standards** (`pr-reviewer-architecture.md`) | Architecture skill, `mask_pii.sql`, governance audit trail (Snowflake query), existing YAML schemas | Architecture alignment, naming conventions, compliance (GDPR/Privacy Act), audit trail verification |
| **Stakeholder Communications** (`pr-reviewer-stakeholder.md`) | `context/emails.md`, linked GitHub issue | Requirements traceability, stakeholder concerns, gaps between emails and issue spec |
| **Team Knowledge** (`pr-reviewer-team-knowledge.md`) | `context/slack-messages.md`, `context/meeting-transcripts.md` | Tribal knowledge, past incidents, design decisions from meetings, unresolved tensions |

Each agent posts its review as a separate GitHub PR comment. The idea: **different data sources surface different insights**, just like different team members would bring different context to a review.

### Hooks — Governance Guardrails

**Files**: `hooks/*.sh` (registered in `~/.snowflake/cortex/hooks.json`)

Hooks are shell scripts that run automatically before Cortex Code executes a tool call. They can **block** the action (exit code 2) or **allow** it (exit code 0).

| Hook | Trigger | What It Checks |
|------|---------|---------------|
| `governance_check.sh` | `Edit` or `Write` on model files | PII columns in marts must use `mask_pii()`. Model names must follow `stg_`/`int_`/`dim_`/`fct_` convention. Logs every PASS/BLOCK to `GOVERNANCE_AUDIT` table in Snowflake. |
| `no_merge_check.sh` | `Bash` commands | Blocks `gh pr merge`, `gh api .../merge`, and `git push ... main`. Agents can create PRs but cannot merge — only humans can. |
| `sql_security_check.sh` | `snowflake_sql_execute` | Blocks `DROP`, `TRUNCATE`, and `DELETE` without `WHERE`. |

The governance hook also writes an **audit trail** to `ECOM_ANALYTICS.DBT_PROJECT.GOVERNANCE_AUDIT` — every governance decision (PASS or BLOCK) is logged with timestamp, file path, and policy code. The Architecture review agent queries this table during PR review.

### Organisational Context Data

**Files**: `context/*.md`

Mock data representing organisational knowledge that agents read during PR reviews:

| File | Contents | Key Details |
|------|----------|-------------|
| `emails.md` | Stakeholder email thread (PM, Governance Lead, Analytics Engineer) | Requirements from Marketing, PII concerns, `data_classification` meta tag request, stretch goals not in the issue |
| `slack-messages.md` | #data-platform channel export (17-19 Feb) | Technical decisions (MODE() for payment method, hardcoded thresholds debate), staleness warnings, dim_customers overlap discussion |
| `meeting-transcripts.md` | Standup transcript (18 Feb) | 3-vs-4 segment debate, threshold configurability tension, PII masking discussion, action items |

These files contain **deliberate tensions and gaps** across sources — requirements in emails not captured in the issue, design disagreements in meetings, warnings in Slack that apply to the implementation. The review agents surface these.

---

## CI/CD Pipeline

**File**: `.github/workflows/deploy-dbt-to-snowflake.yml`

Triggers on push to `main` when `dbt_project/**` files change. Steps:

1. Checkout code
2. Install Snowflake CLI (`snowflakedb/snowflake-cli-action@v2.0`)
3. Create schemas if not exists
4. `snow dbt deploy` — push dbt project to Snowflake
5. `snow dbt execute ... build` — run all models and tests
6. Verify deployment

Uses a `CI_DEPLOYER` service user with RSA key-pair auth. Runs in ~1.5 minutes.

---

## Demo Flow

### Pre-Demo
```bash
bash scripts/reset_demo.sh
```
Resets git, GitHub (PRs, issues, branches), and Snowflake to clean state. ~2 minutes.

### Phase 1 — Read Issue & Interpret with Business Architecture (~1 min)
> "Read GitHub issue #1 and tell me what we need to build"

The agent reads the issue (CLV model with segmentation) and the business-architecture skill fires. It analyses affected domains, PII impact, model placement, compliance requirements.

### Phase 2 — Generate dbt Models (~1-2 min)
> "Build it"

The agent generates `fct_customer_lifetime_value.sql` and its YAML schema. The governance hook runs on every file write — if the agent writes PII without `mask_pii()`, the hook blocks and the agent self-corrects. Every check is logged to the audit trail.

**Talk track while agent works**: Explain the hook system, show the governance_check.sh code, point out the audit trail concept.

### Phase 3 — Commit & Create PR (~30s)
> "Commit and create a PR"

Agent creates a feature branch, commits, pushes, creates a PR referencing "Closes #1". The no-merge guardrail prevents any merge attempt.

### Phase 4 — Three Agents Review the PR (~1-2 min)
> "Review the PR" (or invoke @pr-reviewer)

The orchestrator spawns three reviewers in parallel. Each reads different context:
- **Architecture agent** → queries the governance audit trail, checks compliance
- **Stakeholder agent** → reads emails, maps requirements to implementation
- **Team Knowledge agent** → reads Slack and meeting notes, surfaces tribal knowledge

**Talk track while agents work**: Split screen — show the context files while explaining what each agent is reading. "Agent 1 is querying the governance audit trail right now. Agent 2 is reading stakeholder emails to check if every requirement was implemented. Agent 3 is reading Slack messages to surface warnings from the team."

### Phase 5 — Human Merges (~30s)
Switch to GitHub, review the three comments, merge the PR. The no-merge guardrail means only you can do this.

### Phase 6 — CI/CD Deploys & Query Results (~2 min)
CI/CD triggers automatically. While it runs, explain the pipeline. Once complete:
> "Query the CLV data and show me the governance audit trail"

Show masked emails, customer segments, and the full audit trail proving governance was enforced throughout.

---

## Reset

```bash
bash scripts/reset_demo.sh
```

This script:
1. Closes open PRs
2. Cleans up feature branches
3. Resets git to `demo-baseline` tag
4. Reopens issue #1, cleans comments
5. Cleans PR review comments
6. Drops and recreates Snowflake schemas, redeploys dbt project
7. Verifies everything

Safe to run multiple times. Takes ~2 minutes.
