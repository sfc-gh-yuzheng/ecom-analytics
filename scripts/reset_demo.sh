#!/usr/bin/env bash
# =============================================================
# Demo Reset Script — Data Saturday Brisbane
# Resets all state so the demo can be run again from scratch.
# Safe to run multiple times (idempotent).
#
# Usage: bash scripts/reset_demo.sh
# =============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="sfc-gh-yuzheng/ecom-analytics"
SNOWFLAKE_CONN="demo"
DATABASE="ECOM_ANALYTICS"
SCHEMA="DBT_DEV"

cd "$REPO_DIR"

echo "========================================"
echo "  Demo Reset — $(date)"
echo "========================================"

# ----- 1. Close open PRs -----
echo ""
echo "[1/7] Closing open pull requests..."
open_prs=$(gh pr list --repo "$REPO" --state open --json number --jq '.[].number' 2>/dev/null || true)
if [ -n "$open_prs" ]; then
  for pr in $open_prs; do
    echo "  Closing PR #$pr"
    gh pr close "$pr" --repo "$REPO" --delete-branch 2>/dev/null || true
  done
else
  echo "  No open PRs found."
fi

# ----- 2. Delete remote feature branches -----
echo ""
echo "[2/7] Cleaning up remote feature branches..."
remote_branches=$(git branch -r --list 'origin/*' | grep -v 'origin/main' | grep -v 'origin/HEAD' | sed 's|origin/||' || true)
if [ -n "$remote_branches" ]; then
  for branch in $remote_branches; do
    echo "  Deleting remote branch: $branch"
    git push origin --delete "$branch" 2>/dev/null || true
  done
else
  echo "  No feature branches found."
fi

# ----- 3. Reset local git state -----
echo ""
echo "[3/7] Resetting local git to main..."
git checkout main 2>/dev/null || true
# Delete local feature branches
local_branches=$(git branch --list | grep -v '^\* main$' | grep -v '^  main$' || true)
if [ -n "$local_branches" ]; then
  for branch in $local_branches; do
    branch=$(echo "$branch" | xargs)  # trim whitespace
    echo "  Deleting local branch: $branch"
    git branch -D "$branch" 2>/dev/null || true
  done
fi
git fetch origin
git reset --hard origin/main
git clean -fd

echo "  On commit: $(git log --oneline -1)"

# ----- 4. Reopen GitHub issue #1 -----
echo ""
echo "[4/7] Reopening GitHub issue #1..."
issue_state=$(gh issue view 1 --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
if [ "$issue_state" = "CLOSED" ]; then
  gh issue reopen 1 --repo "$REPO"
  echo "  Issue #1 reopened."
elif [ "$issue_state" = "OPEN" ]; then
  echo "  Issue #1 already open."
else
  echo "  Could not determine issue state: $issue_state"
fi

# ----- 5. Reset Snowflake DBT_DEV schema -----
echo ""
echo "[5/7] Resetting Snowflake schema ${DATABASE}.${SCHEMA}..."
snow sql -c "$SNOWFLAKE_CONN" -q "DROP SCHEMA IF EXISTS ${DATABASE}.${SCHEMA};" 2>&1 || {
  echo "  WARNING: Could not drop schema. You may need to run this manually:"
  echo "    DROP SCHEMA IF EXISTS ${DATABASE}.${SCHEMA};"
  echo "    CREATE SCHEMA ${DATABASE}.${SCHEMA};"
}
snow sql -c "$SNOWFLAKE_CONN" -q "CREATE SCHEMA IF NOT EXISTS ${DATABASE}.${SCHEMA};" 2>&1 || {
  echo "  WARNING: Could not create schema."
}

# ----- 6. Redeploy base dbt project -----
echo ""
echo "[6/7] Redeploying base dbt project to Snowflake..."
snow dbt deploy ECOM_ANALYTICS_PROJECT \
  --source dbt_project \
  --database "$DATABASE" \
  --schema "$SCHEMA" \
  -c "$SNOWFLAKE_CONN" 2>&1 || {
  echo "  WARNING: dbt deploy failed. You may need to deploy manually."
}

snow dbt execute -c "$SNOWFLAKE_CONN" \
  --database "$DATABASE" \
  --schema "$SCHEMA" \
  ECOM_ANALYTICS_PROJECT build 2>&1 || {
  echo "  WARNING: dbt build failed. You may need to build manually."
}

# ----- 7. Verify -----
echo ""
echo "[7/7] Verification..."
echo "  Git commit: $(git log --oneline -1)"
echo "  Git branch: $(git branch --show-current)"
echo "  Open PRs:   $(gh pr list --repo "$REPO" --state open --json number --jq 'length' 2>/dev/null || echo 'unknown')"
echo "  Issue #1:   $(gh issue view 1 --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo 'unknown')"
echo ""
echo "  Snowflake objects in ${DATABASE}.${SCHEMA}:"
snow sql -c "$SNOWFLAKE_CONN" -q "SHOW OBJECTS IN SCHEMA ${DATABASE}.${SCHEMA};" 2>&1 || echo "  Could not query Snowflake."

echo ""
echo "========================================"
echo "  Reset complete! Ready for demo."
echo "========================================"
