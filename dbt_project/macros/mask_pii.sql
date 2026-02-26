{% macro mask_pii(column_name) %}
    case
        when current_role() in ('ANALYST', 'REPORTER')
        then regexp_replace({{ column_name }}, '.+@', '***@')
        else {{ column_name }}
    end
{% endmacro %}
