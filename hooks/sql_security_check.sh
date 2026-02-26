#!/bin/bash
# SQL Security Hook: Blocks destructive SQL operations
# Runs as PreToolUse on snowflake_sql_execute tool calls
# Exit code 2 = block the operation

set -e

# Read hook input from stdin
INPUT=$(cat)

# Extract the SQL statement
SQL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('sql',''))" 2>/dev/null)

# Normalize to uppercase for checking
SQL_UPPER=$(echo "$SQL" | tr '[:lower:]' '[:upper:]')

# --- Check 1: Block DROP TABLE/VIEW/DATABASE ---
if echo "$SQL_UPPER" | grep -qE '\bDROP\s+(TABLE|VIEW|DATABASE|SCHEMA)\b'; then
    echo "SECURITY VIOLATION: DROP statements are blocked by governance policy." >&2
    echo "If you need to drop an object, request approval from the Data Platform team." >&2
    exit 2
fi

# --- Check 2: Block TRUNCATE ---
if echo "$SQL_UPPER" | grep -qE '\bTRUNCATE\s+TABLE\b'; then
    echo "SECURITY VIOLATION: TRUNCATE statements are blocked by governance policy." >&2
    echo "Use appropriate dbt model rebuilds instead of direct TRUNCATE operations." >&2
    exit 2
fi

# --- Check 3: Block DELETE without WHERE clause ---
if echo "$SQL_UPPER" | grep -qE '\bDELETE\s+FROM\b'; then
    if ! echo "$SQL_UPPER" | grep -qE '\bDELETE\s+FROM\b.*\bWHERE\b'; then
        echo "SECURITY VIOLATION: DELETE without WHERE clause is blocked by governance policy." >&2
        echo "All DELETE statements must include a WHERE clause to prevent accidental data loss." >&2
        exit 2
    fi
fi

# All checks passed
exit 0
