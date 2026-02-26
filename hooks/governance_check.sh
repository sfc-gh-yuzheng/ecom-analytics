#!/bin/bash
# Governance Hook: Validates PII masking and naming conventions in dbt models
# Runs as PreToolUse on Edit|Write tool calls
# Exit code 2 = block the operation

set -e

# Read hook input from stdin
INPUT=$(cat)

# Extract tool name and file path
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print(d.get('file_path',''))" 2>/dev/null)
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print(d.get('content','') or d.get('new_string',''))" 2>/dev/null)

# Only check .sql files in the models directory
if [[ ! "$FILE_PATH" == *"/models/"*".sql" ]]; then
    exit 0
fi

# --- Check 1: Model naming conventions ---
FILENAME=$(basename "$FILE_PATH" .sql)
DIRNAME=$(dirname "$FILE_PATH")

if [[ "$DIRNAME" == *"/staging"* ]]; then
    if [[ ! "$FILENAME" == stg_* ]] && [[ ! "$FILENAME" == _* ]]; then
        echo "GOVERNANCE VIOLATION: Staging model '$FILENAME' must use 'stg_' prefix." >&2
        echo "Convention: staging models are named stg_<source_table>." >&2
        exit 2
    fi
elif [[ "$DIRNAME" == *"/intermediate"* ]]; then
    if [[ ! "$FILENAME" == int_* ]] && [[ ! "$FILENAME" == _* ]]; then
        echo "GOVERNANCE VIOLATION: Intermediate model '$FILENAME' must use 'int_' prefix." >&2
        echo "Convention: intermediate models are named int_<business_concept>." >&2
        exit 2
    fi
elif [[ "$DIRNAME" == *"/marts"* ]]; then
    if [[ ! "$FILENAME" == dim_* ]] && [[ ! "$FILENAME" == fct_* ]] && [[ ! "$FILENAME" == _* ]]; then
        echo "GOVERNANCE VIOLATION: Mart model '$FILENAME' must use 'dim_' or 'fct_' prefix." >&2
        echo "Convention: marts use dim_<entity> for dimensions, fct_<event> for facts." >&2
        exit 2
    fi
fi

# --- Check 2: PII columns in mart models must use mask_pii() ---
if [[ "$DIRNAME" == *"/marts"* ]]; then
    PII_COLUMNS=("email" "phone" "ssn" "date_of_birth" "address" "phone_number" "social_security")

    for col in "${PII_COLUMNS[@]}"; do
        # Check if PII column name appears in content (case-insensitive)
        if echo "$CONTENT" | grep -qi "\b${col}\b"; then
            # Check if it's wrapped in mask_pii()
            if ! echo "$CONTENT" | grep -qi "mask_pii.*${col}\|${col}.*mask_pii"; then
                echo "GOVERNANCE VIOLATION: PII column '${col}' detected in mart model without mask_pii() macro." >&2
                echo "All PII columns in mart models MUST be wrapped with {{ mask_pii('column_name') }}." >&2
                echo "See: macros/mask_pii.sql for the masking macro." >&2
                exit 2
            fi
        fi
    done
fi

# All checks passed
exit 0
