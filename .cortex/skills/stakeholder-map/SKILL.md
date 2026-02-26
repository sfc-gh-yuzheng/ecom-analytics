---
name: stakeholder-map
description: "Stakeholder registry, approval chains, and communication preferences for Acme Commerce data projects. Use when: determining who to notify about a change, identifying required approvals, routing questions to the right person, or planning stakeholder communications. Triggers: who to notify, approval, stakeholder, who needs to know, sign off, notify, communication, domain owner, escalation."
---

# Stakeholder Map — Acme Commerce

You know Acme Commerce's stakeholder landscape for data projects. Use this to route notifications, identify required approvals, and ensure the right people are informed at the right time.

## When to Use

- A model change needs approval before merge
- Determining who to notify about a new feature or breaking change
- Routing a technical question to the right domain expert
- Planning communications for a data project rollout

## Stakeholder Registry

| Person | Role | Domain | Cares About |
|--------|------|--------|-------------|
| **Rebecca** | Head of Marketing | Consumer | Segments, campaign targeting, CLV metrics |
| **Maria Santos** | Governance Lead | Finance/Compliance | PII masking, data classification, audit trails, regulatory compliance |
| **James Park** | Analytics Engineering Lead | Order/Finance | Payment data integrity, dedup logic, model performance, `int_payment_totals` |
| **Sarah Chen** | Data Platform Lead | Customer | Customer data quality, SLA adherence, PII column changes |
| **Lisa Park** | Product Manager | Cross-cutting | Requirements traceability, delivery timelines, stakeholder coordination |
| **Jordan** | Data Engineer | Platform | Segment boundary drift, historical data edge cases, performance |

## Approval Requirements

| Change Type | Required Approval | Notify |
|-------------|-------------------|--------|
| New PII column in marts | Maria Santos | Sarah Chen |
| New customer-domain model | Sarah Chen | Lisa Park |
| Payment schema change | James Park | Maria Santos |
| New order status value | James Park | — |
| Revenue model change | James Park | Finance Analytics team |
| Segment threshold change | Rebecca (via Lisa) | Jordan (drift monitoring) |
| Any model going to production | — | Lisa Park (PM tracking) |

## Communication Channels

- **Formal requests / decisions**: Email (see `context/emails.md`)
- **Quick questions / FYI**: Slack #data-platform (see `context/slack-messages.md`)
- **Design decisions / trade-offs**: Standup meetings (see `context/meeting-transcripts.md`)
- **Code review**: GitHub PR comments

## Escalation Path

```
Individual contributor → Domain lead → Lisa Park (PM) → Engineering Director
```

If a change is blocked by conflicting stakeholder requirements, escalate to Lisa Park to mediate.

## Workflow

### Step 1: Identify Affected Stakeholders

For any change, cross-reference the approval requirements table to determine who needs to approve and who needs to be notified.

### Step 2: Check Context Sources

Read relevant context files to understand prior stakeholder communications:
- `context/emails.md` — formal requirements and decisions
- `context/slack-messages.md` — informal discussions and warnings
- `context/meeting-transcripts.md` — verbal agreements and action items

### Step 3: Draft Communications

When notifying stakeholders, include:
1. What changed and why
2. How it affects their domain
3. What action (if any) is needed from them

**⚠️ STOP**: Before sending notifications, confirm the stakeholder list and message with the user.

## Stopping Points

- ✋ After identifying stakeholders — confirm list with user
- ✋ Before sending any notifications — get user approval

## Output

- Stakeholder notification list with required actions
- Draft communications (if requested)
- Approval status tracker
