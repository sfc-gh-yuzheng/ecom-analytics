#!/bin/bash
# ================================================================
# Governance Hook — dbt Model Policy Enforcement
# ================================================================
# Runs as PreToolUse on Edit|Write tool calls.
# Validates PII masking and naming conventions in dbt models.
#
# Exit codes:
#   0 = pass (allow the tool call)
#   2 = block (reject the tool call, agent must self-correct)
#
# Audit: Every governance decision (PASS or BLOCK) is logged
# to ECOM_ANALYTICS.DBT_PROJECT.GOVERNANCE_AUDIT in Snowflake.
# ================================================================

# --- Parse hook input (JSON on stdin) ---
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except: print('')
" 2>/dev/null)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {})
    print(d.get('file_path', ''))
except: print('')
" 2>/dev/null)

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {})
    print(d.get('content', '') or d.get('new_string', ''))
except: print('')
" 2>/dev/null)

# --- Helper: log to Snowflake (async, never blocks) ---
audit_log() {
    local governance="$1"
    local policy="$2"
    local detail="$3"
    local safe_file=$(echo "$FILE_PATH" | sed "s/'/''/g")
    local safe_detail=$(echo "$detail" | sed "s/'/''/g")

    nohup snow sql -c demo -q "
    INSERT INTO ECOM_ANALYTICS.DBT_PROJECT.GOVERNANCE_AUDIT
        (tool_name, file_path, governance, detail)
    VALUES
        ('${TOOL_NAME}', '${safe_file}', '${governance}', '${policy}: ${safe_detail}');
    " > /dev/null 2>&1 &
}

# --- Only check .sql files in the models directory ---
if [[ ! "$FILE_PATH" == *"/models/"*".sql" ]]; then
    exit 0
fi

FILENAME=$(basename "$FILE_PATH" .sql)
DIRNAME=$(dirname "$FILE_PATH")

# ================================================================
# CHECK 1: Model naming conventions
# ================================================================
# Policy: staging=stg_, intermediate=int_, marts=dim_|fct_
# YAML files (prefix _) are always allowed.

VIOLATION=""

if [[ "$DIRNAME" == *"/staging"* ]]; then
    if [[ ! "$FILENAME" == stg_* ]] && [[ ! "$FILENAME" == _* ]]; then
        VIOLATION="Staging model '${FILENAME}' must use 'stg_' prefix. Convention: stg_<source_table>."
    fi
elif [[ "$DIRNAME" == *"/intermediate"* ]]; then
    if [[ ! "$FILENAME" == int_* ]] && [[ ! "$FILENAME" == _* ]]; then
        VIOLATION="Intermediate model '${FILENAME}' must use 'int_' prefix. Convention: int_<business_concept>."
    fi
elif [[ "$DIRNAME" == *"/marts"* ]]; then
    if [[ ! "$FILENAME" == dim_* ]] && [[ ! "$FILENAME" == fct_* ]] && [[ ! "$FILENAME" == _* ]]; then
        VIOLATION="Mart model '${FILENAME}' must use 'dim_' or 'fct_' prefix. Convention: dim_<entity> or fct_<event>."
    fi
fi

if [[ -n "$VIOLATION" ]]; then
    echo "" >&2
    echo "GOVERNANCE BLOCK — Naming Convention Violation" >&2
    echo "───────────────────────────────────────────────" >&2
    echo "  Policy:  ACME-NMG-001 (Model Naming Standards)" >&2
    echo "  File:    ${FILENAME}.sql" >&2
    echo "  Issue:   ${VIOLATION}" >&2
    echo "" >&2
    audit_log "BLOCK" "ACME-NMG-001" "$VIOLATION"
    exit 2
fi

# ================================================================
# CHECK 2: PII columns in mart models must use mask_pii()
# ================================================================
# Policy: Any PII column in a marts-layer model must be wrapped
# in the mask_pii() Jinja macro. Raw PII is only permitted in
# staging and intermediate layers.

if [[ "$DIRNAME" == *"/marts"* ]]; then
    PII_COLUMNS=("email" "phone" "ssn" "date_of_birth" "address" "phone_number" "social_security")

    for col in "${PII_COLUMNS[@]}"; do
        if echo "$CONTENT" | grep -qi "\b${col}\b"; then
            if ! echo "$CONTENT" | grep -qi "mask_pii.*${col}\|${col}.*mask_pii"; then
                echo "" >&2
                echo "GOVERNANCE BLOCK — PII Violation" >&2
                echo "────────────────────────────────" >&2
                echo "  Policy:  ACME-PII-003 (PII Masking in Mart Models)" >&2
                echo "  File:    ${FILENAME}.sql" >&2
                echo "  Column:  ${col}" >&2
                echo "  Issue:   Raw PII column '${col}' in mart layer without masking." >&2
                echo "  Fix:     Wrap with {{ mask_pii('alias.${col}') }}" >&2
                echo "  Ref:     macros/mask_pii.sql" >&2
                echo "" >&2
                audit_log "BLOCK" "ACME-PII-003" "Raw PII column '${col}' without mask_pii() in ${FILENAME}.sql"
                exit 2
            fi
        fi
    done
fi

# ================================================================
# All checks passed
# ================================================================
audit_log "PASS" "ALL" "All governance checks passed for ${FILENAME}.sql"
exit 0
