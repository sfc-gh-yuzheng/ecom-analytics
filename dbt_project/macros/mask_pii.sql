{% macro mask_pii(column_name) %}
    case
        when is_role_in_session('PII_ALLOWED')
        then {{ column_name }}
        else regexp_replace({{ column_name }}, '.+@', '***@')
    end
{% endmacro %}
