{% macro mask_pii(column_name) %}
    case
        when is_role_in_session('PII_ALLOWED')
        then {{ column_name }}
        when {{ column_name }} like '%@%'
        then regexp_replace({{ column_name }}, '.+@', '***@')
        else '***'
    end
{% endmacro %}
