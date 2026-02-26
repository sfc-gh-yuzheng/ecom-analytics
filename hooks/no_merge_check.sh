#!/bin/bash
# ================================================================
# No-Merge Guardrail — Prevents agents from merging pull requests
# ================================================================
# Runs as PreToolUse on Bash tool calls.
# Blocks any attempt to merge a PR via gh CLI or git push to main.
#
# Exit codes:
#   0 = pass (allow the tool call)
#   2 = block (reject — human must merge)
# ================================================================

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {})
    print(d.get('command', ''))
except: print('')
" 2>/dev/null)

# Block: gh pr merge
if echo "$COMMAND" | grep -qiE 'gh\s+pr\s+merge'; then
    echo "" >&2
    echo "GUARDRAIL BLOCK — PR Merge Not Permitted" >&2
    echo "──────────────────────────────────────────" >&2
    echo "  Policy:  ACME-GOV-010 (Human-in-the-Loop Merge)" >&2
    echo "  Issue:   Agents cannot merge pull requests." >&2
    echo "  Reason:  All merges require human approval." >&2
    echo "  Action:  Create the PR and leave a review comment." >&2
    echo "           A human reviewer will merge when ready." >&2
    echo "" >&2
    exit 2
fi

# Block: gh api merge endpoint
if echo "$COMMAND" | grep -qiE 'gh\s+api.*merge'; then
    echo "" >&2
    echo "GUARDRAIL BLOCK — PR Merge Not Permitted" >&2
    echo "──────────────────────────────────────────" >&2
    echo "  Policy:  ACME-GOV-010 (Human-in-the-Loop Merge)" >&2
    echo "  Issue:   Agents cannot merge pull requests via API." >&2
    echo "  Action:  Leave a review comment instead." >&2
    echo "" >&2
    exit 2
fi

# Block: git push to main (force or otherwise)
if echo "$COMMAND" | grep -qiE 'git\s+push.*\bmain\b'; then
    echo "" >&2
    echo "GUARDRAIL BLOCK — Direct Push to Main Not Permitted" >&2
    echo "────────────────────────────────────────────────────" >&2
    echo "  Policy:  ACME-GOV-010 (Human-in-the-Loop Merge)" >&2
    echo "  Issue:   Agents cannot push directly to main." >&2
    echo "  Action:  Push to a feature branch and create a PR." >&2
    echo "" >&2
    exit 2
fi

exit 0
