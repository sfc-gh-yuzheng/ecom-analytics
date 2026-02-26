# Acme Commerce — dbt Analytics with Cortex Code

A dbt project on Snowflake with [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) extensibility — custom skills, agents, hooks, and CI/CD. The project includes a custom skill that teaches the agent about the business data architecture, governance hooks that enforce PII masking and naming conventions, and a multi-agent PR review system where each agent pulls context from different organisational data sources (architecture docs, stakeholder emails, Slack messages, meeting transcripts).

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
| `no_merge_check.sh` | `Bash` commands | Blocks `gh pr merge`, `gh api .../merge`, and `git push ... main`. Enforces human-in-the-loop merge. |
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

---

## Best Practices — Writing Skills, Agents, and Hooks

This section documents the design principles applied to the custom skills, agents, and hooks in this project, drawn from Anthropic's skill authoring guidelines, Claude 4.x prompting best practices, and Snowflake Cortex Code extensibility documentation.

### Skill Authoring

**Progressive disclosure** is the core design principle. Skills load in three levels:

| Level | What Loads | When |
|-------|-----------|------|
| 1. Metadata | `name` and `description` from YAML frontmatter | Always — injected into system prompt at startup |
| 2. Instructions | Full SKILL.md body | When the user's request matches the description |
| 3. Resources | Additional files in the skill directory (references, scripts) | Only when SKILL.md references them |

This means the `description` field is the primary trigger mechanism. Write it carefully:

```yaml
# Good — third person, states WHAT + WHEN, specific triggers
description: "Interprets issues against the business data architecture — domains,
  PII classifications, naming conventions. Use when analyzing requirements,
  assessing PII impact, or placing models in the correct dbt layer."

# Bad — vague, first person
description: "I can help with data architecture questions"
```

**Guidelines applied in this project:**

- **Write descriptions in third person.** The description is injected into the system prompt. First/second person creates point-of-view confusion. Say "Interprets issues..." not "I interpret issues..." or "Use this to interpret..."
- **Keep SKILL.md under ~500 lines.** If a skill grows beyond this, split reference content into separate files (e.g., `references/domains.md`) and link them from SKILL.md. Claude loads referenced files only when needed.
- **Be specific about triggers.** The description should list concrete scenarios: "Use when analyzing requirements, assessing PII impact, evaluating data model changes." Vague descriptions like "Helps with data stuff" won't trigger reliably.
- **Structure with clear headings.** Use `##` sections for distinct concerns. This helps Claude navigate the skill content once loaded.
- **Match specificity to fragility.** For critical operations (database migrations, PII handling), use low-freedom instructions with exact commands. For creative tasks (report writing), use high-freedom guidance with examples.

**Skill directory structure** (for larger skills):

```
my-skill/
├── SKILL.md              # Core instructions (< 500 lines)
├── references/           # Loaded on demand
│   ├── domain-model.md
│   └── compliance-rules.md
└── scripts/              # Executable utilities
    └── validate.py
```

### Agent Authoring

Agents are autonomous subprocesses with their own system prompts. The YAML frontmatter configures their capabilities.

**Key configuration options:**

```yaml
---
name: my-agent
description: "What this agent does and when to use it."
tools: ["Read", "Glob", "Grep", "Bash"]  # Restrict to needed tools
model: claude-sonnet-4-5                   # Optional model override
---
```

**Guidelines applied in this project:**

- **Restrict tool access.** Only grant tools the agent actually needs. Our review agents get `Read`, `Glob`, `Grep`, `Bash` — no `Write` or `Edit` because reviewers should not modify code. The orchestrator additionally gets `Task` to spawn sub-agents.
- **Enforce boundaries with hooks, not instructions.** Don't tell agents what they can't do — prevent it structurally. A `no_merge_check.sh` hook that blocks `gh pr merge` commands is more reliable than a prompt rule saying "do not merge." Hooks are deterministic; prompt instructions are probabilistic.
- **Use plain language.** Claude 4.x models are highly responsive to system prompts. Aggressive language like "CRITICAL: You MUST..." can cause overtriggering. Direct statements work equally well.
- **Define data sources explicitly.** Each agent's prompt lists exactly which files to read and what to look for in them. This is more reliable than hoping the agent will find relevant context on its own.
- **Provide structured output formats.** Include a template for the agent's output. This ensures consistency across runs and makes the output parseable.
- **Use the Task tool for orchestration.** The orchestrator agent spawns sub-agents via the Task tool with `subagent_type: "general-purpose"`. Launch all sub-agents in a single message (parallel tool calls) for speed.

**Swarm pattern** (used by the PR review orchestrator):

```
Orchestrator (pr-reviewer)
├── spawns → Architecture reviewer (reads arch docs, audit trail)
├── spawns → Stakeholder reviewer (reads emails, GitHub issue)
└── spawns → Team Knowledge reviewer (reads Slack, meetings)
```

Each sub-agent works independently and posts its own output. The orchestrator summarises findings after all complete. This pattern scales well — add or remove reviewers without changing the others.

**Worktree isolation** — when agents need to make file changes in parallel, use `worktree_isolation: true` to give each agent its own git worktree. Not needed for read-only agents like reviewers.

### Hook Authoring

Hooks are shell scripts that intercept tool calls at lifecycle points. They provide deterministic control — guaranteeing that checks always run, rather than relying on the model to remember.

**Exit codes:**

| Code | Meaning | Use Case |
|------|---------|----------|
| `0` | Allow | Validation passed, or hook doesn't apply |
| `2` | Block | Policy violation — the tool call is rejected |

**JSON output** (optional, on stdout) enables richer control:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": "Note: governance check passed for this file."
  }
}
```

**Guidelines applied in this project:**

- **Keep hooks fast.** Hooks run synchronously before every matching tool call. Default timeout is 60 seconds. Our hooks use simple `grep` pattern matching — millisecond execution.
- **Handle errors gracefully.** If your hook can't determine whether to allow or block, return `exit 0` (allow). A broken hook that blocks everything will halt the agent.
- **Use `jq` for JSON parsing.** Hook input arrives on stdin as JSON. Parse with `jq -r '.tool_input.command'` rather than fragile string manipulation.
- **Log decisions for auditability.** The governance hook writes every PASS/BLOCK decision to a Snowflake table (`GOVERNANCE_AUDIT`). This creates a tamper-resistant audit trail that the review agents can query.
- **Scope matchers precisely.** Use regex in the `matcher` field: `"Edit|Write"` for file operations, `"Bash"` for shell commands, `"snowflake_sql_execute"` for SQL. Overly broad matchers slow everything down.
- **Use fire-and-forget for logging.** Audit writes use `nohup snow sql ... &` so they don't block the agent while waiting for Snowflake round-trips.

**Hook configuration** (in `~/.snowflake/cortex/hooks.json` or `.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "bash hooks/governance_check.sh"
        }]
      }
    ]
  }
}
```

**Three hook types:**

| Type | Description | When to Use |
|------|-------------|-------------|
| `command` | Runs a shell script | Deterministic checks (pattern matching, linting, logging) |
| `prompt` | Sends a prompt to an LLM | Complex validation too nuanced for regex |
| `agent` | Spawns a multi-turn sub-agent | Deep verification requiring file reads and reasoning |

For most governance and security use cases, `command` hooks are sufficient and fastest.
