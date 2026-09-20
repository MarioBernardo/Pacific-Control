from datetime import date, datetime
from math import ceil
from flask import request
from sqlalchemy import String, cast, or_
from app.extensions import db
from app.services.crud_utils import CrudValidationError

def paginated(model, *, filters=None, search_columns=(), sort_fields=None, options=()):
    args = request.args
    try:
        page = int(args.get("page", 1))
        per_page = int(args.get("per_page", 20))
    except ValueError as error:
        raise CrudValidationError({"pagination": "page y per_page deben ser enteros."}) from error
    if page < 1 or per_page < 1 or per_page > 100:
        raise CrudValidationError({"pagination": "page debe ser >= 1 y per_page debe estar entre 1 y 100."})
    statement = db.select(model).options(*options)
    for parameter, column in (filters or {}).items():
        value = args.get(parameter)
        if value is not None:
            try:
                python_type = getattr(column.type, "python_type", str)
                if python_type is int:
                    value = int(value)
                elif python_type is bool:
                    normalized = value.lower()
                    if normalized not in {"true", "false", "1", "0"}:
                        raise ValueError
                    value = normalized in {"true", "1"}
                elif python_type in {date, datetime}:
                    value = python_type.fromisoformat(value)
            except (ValueError, NotImplementedError):
                raise CrudValidationError({parameter: "Valor de filtro inválido."})
            statement = statement.where(column == value)
    search = args.get("search", "").strip()
    if search and search_columns:
        statement = statement.where(or_(*(cast(column, String).ilike(f"%{search}%") for column in search_columns)))
    allowed = sort_fields or {column.name: column for column in model.__table__.primary_key.columns}
    sort_name = args.get("sort", next(iter(allowed)))
    if sort_name not in allowed:
        raise CrudValidationError({"sort": "Campo de ordenamiento no permitido."})
    order = args.get("order", "asc").lower()
    if order not in {"asc", "desc"}:
        raise CrudValidationError({"order": "Use asc o desc."})
    column = allowed[sort_name]
    statement = statement.order_by(column.desc() if order == "desc" else column.asc())
    total = db.session.scalar(db.select(db.func.count()).select_from(statement.order_by(None).subquery()))
    items = db.session.execute(statement.offset((page - 1) * per_page).limit(per_page)).scalars().all()
    return items, {"page": page, "per_page": per_page, "total": total, "pages": ceil(total / per_page) if total else 0}
