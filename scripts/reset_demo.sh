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
BASELINE_TAG="demo-baseline"  # Git tag marking the clean starting point
BACKUP_BRANCH="backup/clv-model"  # Persistent backup PR — survives resets
BACKUP_PR=6                        # PR number for the backup branch

cd "$REPO_DIR"

echo "========================================"
echo "  Demo Reset — $(date)"
echo "========================================"

# ----- 1. Close open PRs and delete feature branches -----
echo ""
echo "[1/7] Closing open pull requests..."
open_prs=$(gh pr list --repo "$REPO" --state open --json number --jq '.[].number' 2>/dev/null || true)
if [ -n "$open_prs" ]; then
  for pr in $open_prs; do
    if [ "$pr" -eq "$BACKUP_PR" ]; then
      echo "  Skipping backup PR #$pr"
      continue
    fi
    echo "  Closing PR #$pr"
    gh pr close "$pr" --repo "$REPO" --delete-branch 2>/dev/null || true
  done
else
  echo "  No open PRs found."
fi

# ----- 2. Delete remote + local feature branches -----
echo ""
echo "[2/7] Cleaning up branches..."
git fetch origin --prune 2>/dev/null || true

remote_branches=$(git branch -r --list 'origin/*' | grep -v 'origin/main' | grep -v 'origin/HEAD' | grep -v "origin/${BACKUP_BRANCH}" | sed 's|origin/||' || true)
if [ -n "$remote_branches" ]; then
  for branch in $remote_branches; do
    echo "  Deleting remote branch: $branch"
    git push origin --delete "$branch" 2>/dev/null || true
  done
else
  echo "  No remote feature branches."
fi

git checkout main 2>/dev/null || true
local_branches=$(git branch --list | grep -v '^\* main$' | grep -v '^  main$' || true)
if [ -n "$local_branches" ]; then
  for branch in $local_branches; do
    branch=$(echo "$branch" | xargs)
    if [ "$branch" = "$BACKUP_BRANCH" ]; then
      echo "  Skipping backup branch: $branch"
      continue
    fi
    echo "  Deleting local branch: $branch"
    git branch -D "$branch" 2>/dev/null || true
  done
fi

# ----- 3. Reset git to baseline commit -----
echo ""
echo "[3/7] Resetting git to baseline (${BASELINE_TAG})..."
git reset --hard "$BASELINE_TAG"
git push origin main --force
git clean -fd
echo "  On commit: $(git log --oneline -1)"

# ----- 4. Reopen GitHub issue #1 and clean up comments -----
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

# Remove comments from previous demo runs on issue #1
echo "  Cleaning up issue #1 comments..."
issue_comments=$(gh api "repos/${REPO}/issues/1/comments" --jq '.[].id' 2>/dev/null || true)
if [ -n "$issue_comments" ]; then
  for cid in $issue_comments; do
    gh api -X DELETE "repos/${REPO}/issues/comments/${cid}" 2>/dev/null || true
  done
  echo "  Removed $(echo "$issue_comments" | wc -w | xargs) comment(s)."
else
  echo "  No comments to clean up."
fi

# ----- 5. Clean up PR review comments from previous runs -----
echo ""
echo "[5/7] Cleaning up stale PR review comments..."
closed_prs=$(gh pr list --repo "$REPO" --state closed --json number --jq '.[].number' 2>/dev/null || true)
if [ -n "$closed_prs" ]; then
  for pr in $closed_prs; do
    pr_comments=$(gh api "repos/${REPO}/issues/${pr}/comments" --jq '.[].id' 2>/dev/null || true)
    if [ -n "$pr_comments" ]; then
      for cid in $pr_comments; do
        gh api -X DELETE "repos/${REPO}/issues/comments/${cid}" 2>/dev/null || true
      done
      echo "  Cleaned comments from PR #$pr"
    fi
  done
else
  echo "  No closed PRs found."
fi

# ----- 6. Reset Snowflake schemas -----
echo ""
echo "[6/7] Resetting Snowflake schemas..."

# Drop and recreate model schemas (clean slate)
for SCHEMA in STAGING INTERMEDIATE MARTS; do
  echo "  Resetting ${DATABASE}.${SCHEMA}..."
  snow sql -c "$SNOWFLAKE_CONN" -q "DROP SCHEMA IF EXISTS ${DATABASE}.${SCHEMA} CASCADE;" 2>/dev/null || true
  snow sql -c "$SNOWFLAKE_CONN" -q "CREATE SCHEMA ${DATABASE}.${SCHEMA};" 2>/dev/null || true
done

# Reset DBT_PROJECT schema (keep schema, recreate audit table)
echo "  Resetting ${DATABASE}.DBT_PROJECT..."
snow sql -c "$SNOWFLAKE_CONN" -q "DROP SCHEMA IF EXISTS ${DATABASE}.DBT_PROJECT CASCADE;" 2>/dev/null || true
snow sql -c "$SNOWFLAKE_CONN" -q "CREATE SCHEMA ${DATABASE}.DBT_PROJECT;" 2>/dev/null || true
snow sql -c "$SNOWFLAKE_CONN" -q "
CREATE TABLE ${DATABASE}.DBT_PROJECT.GOVERNANCE_AUDIT (
    ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    tool_name VARCHAR,
    file_path VARCHAR,
    governance VARCHAR,
    detail VARCHAR
);" 2>/dev/null || true

# Redeploy and build dbt project
echo "  Deploying dbt project..."
snow dbt deploy ECOM_ANALYTICS_PROJECT \
  --source dbt_project \
  --database "$DATABASE" \
  --schema DBT_PROJECT \
  --force \
  -c "$SNOWFLAKE_CONN" 2>/dev/null || {
  echo "  WARNING: dbt deploy failed."
}

echo "  Running dbt build..."
snow dbt execute -c "$SNOWFLAKE_CONN" \
  --database "$DATABASE" \
  --schema DBT_PROJECT \
  ECOM_ANALYTICS_PROJECT build 2>&1 || {
  echo "  WARNING: dbt build had issues."
}

# ----- 7. Verify -----
echo ""
echo "[7/7] Verification..."
echo "  Git commit:  $(git log --oneline -1)"
echo "  Git branch:  $(git branch --show-current)"
echo "  Open PRs:    $(gh pr list --repo "$REPO" --state open --json number --jq 'length' 2>/dev/null || echo 'unknown') (backup PR #${BACKUP_PR} preserved)"
echo "  Issue #1:    $(gh issue view 1 --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo 'unknown')"
echo ""
echo "  Snowflake schemas:"
snow sql -c "$SNOWFLAKE_CONN" -q "
SELECT table_schema, table_name, table_type
FROM ${DATABASE}.INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('RAW','STAGING','INTERMEDIATE','MARTS','DBT_PROJECT')
ORDER BY 1, 2;" 2>/dev/null || echo "  Could not query Snowflake."

echo ""
echo "========================================"
echo "  Reset complete! Ready for demo."
echo "========================================"
