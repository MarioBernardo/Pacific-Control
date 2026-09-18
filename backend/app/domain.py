ACTIVE_STATES = frozenset({"activo", "inactivo"})
ATTENDANCE_STATES = frozenset({"registrada", "anulada"})
INCIDENT_STATES = frozenset({"abierta", "cerrada"})
EMPLOYEE_ROLES = frozenset({"ADMINISTRADOR", "SUPERVISOR", "GUARDIA"})


def validate_catalog(value, allowed, field, errors):
    if value is not None and value not in allowed:
        errors[field] = f"Valor no permitido. Use: {', '.join(sorted(allowed))}."
