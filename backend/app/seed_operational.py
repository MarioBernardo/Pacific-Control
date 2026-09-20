from datetime import date, datetime, time

from werkzeug.security import generate_password_hash

from app.auth.auth_seed import seed_demo_users
from app.extensions import cache, db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno


DEMO_DEVICE_TOKENS = {
    "BAVIERA-01": "BavieraDemo2026!",
    "CENTURY-01": "CenturyDemo2026!",
    "GRAND-VICTORIA-01": "GrandVictoriaDemo2026!",
    "VERTICE-01": "VerticeDemo2026!",
}

DEMO_OPERATIONAL_ACCOUNTS = {
    "BAVIERA-01": ("baviera", "BavieraOperativa2026!"),
    "CENTURY-01": ("century", "CenturyOperativa2026!"),
    "GRAND-VICTORIA-01": ("grandvictoria", "GrandVictoriaOperativa2026!"),
    "VERTICE-01": ("vertice", "VerticeOperativa2026!"),
}


OFFICIAL_ASSIGNMENTS = {
    "ED. BAVIERA": {
        "address": "Edificio Baviera",
        "device": "BAVIERA-01",
        "shift": "24 HORAS",
        "fixed": [
            "TIPANTUÑA TACO DIEGO MARCELO",
            "CACHIHUANGO CEPEDA HUMBERTO",
        ],
        "relief": [
            "BERNARDO CAMPO MARIO DAVID",
            "BETANCOURTH TITUAÑA BYRON SEBASTIAN",
        ],
    },
    "ED. CENTURY PLAZA I": {
        "address": "Edificio Century Plaza I",
        "device": "CENTURY-01",
        "shift": "24 HORAS",
        "fixed": [
            "CAIZAPANTA ITURRALDE VINICIO XAVIER",
            "VELEZ QUIÑONEZ LUIS DAMIAN",
        ],
        "relief": [
            "BERNARDO CAMPO MARIO DAVID",
            "BETANCOURTH TITUAÑA BYRON SEBASTIAN",
        ],
    },
    "ED. GRAND VICTORIA": {
        "address": "Edificio Grand Victoria",
        "device": "GRAND-VICTORIA-01",
        "shift": "12 HORAS",
        "fixed": [
            "MENDEZ AGUAS FRANKLIN GIOVANNY",
            "CEVALLOS SANCHEZ LENIN EFRAIN",
        ],
        "relief": [
            "PANGAY QUEVEDO STALIN AMADO",
        ],
    },
    "ED. VERTICE": {
        "address": "Edificio Vertice",
        "device": "VERTICE-01",
        "shift": None,
        "fixed": [
            "DELGADO TITUAÑA ANDERSON DAVID",
        ],
        "relief": [
            "BERNARDO CAMPO MARIO DAVID",
            "BETANCOURTH TITUAÑA BYRON SEBASTIAN",
        ],
    },
}


def _employee(full_name: str, index: int) -> tuple[Empleado, bool]:
    parts = full_name.split()
    correo = f"demo.guardia{index}@pacific.test"

    employee = db.session.execute(
        db.select(Empleado).where(Empleado.correo == correo)
    ).scalar_one_or_none()

    created = employee is None
    if created:
        employee = Empleado(
            cedula=f"0910000{index:03d}",
            nombres=" ".join(parts[2:]),
            apellidos=" ".join(parts[:2]),
            correo=correo,
            password_hash=generate_password_hash("Guardia123!"),
            telefono=f"099000{index:04d}",
            cargo="GUARDIA",
            estado=True,
        )
        db.session.add(employee)
    else:
        employee.nombres = " ".join(parts[2:])
        employee.apellidos = " ".join(parts[:2])
        employee.cargo = "GUARDIA"
        employee.estado = True

    return employee, created


def seed_operational_demo() -> dict[str, int]:
    """Create the official operational demo graph idempotently."""
    seed_demo_users()

    employees_by_name = {}
    names = []

    for data in OFFICIAL_ASSIGNMENTS.values():
        names.extend(data["fixed"] + data["relief"])

    created_employees = 0
    for index, name in enumerate(dict.fromkeys(names), start=1):
        employee, was_created = _employee(name, index)
        employees_by_name[name] = employee
        created_employees += int(was_created)

    db.session.flush()

    created = {
        "empleados": created_employees,
        "puestos": 0,
        "dispositivos": 0,
        "turnos": 0,
        "asistencias": 0,
        "novedades": 0,
    }

    demo_date = date.today()
    first_turno = None

    for building, data in OFFICIAL_ASSIGNMENTS.items():
        puesto = db.session.execute(
            db.select(Puesto).where(Puesto.nombre_puesto == building)
        ).scalar_one_or_none()

        if puesto is None:
            puesto = Puesto(
                nombre_puesto=building,
                direccion=data["address"],
                estado="activo",
            )
            db.session.add(puesto)
            created["puestos"] += 1
        else:
            puesto.direccion = data["address"]
            puesto.estado = "activo"

        db.session.flush()

        device = db.session.execute(
            db.select(Dispositivo).where(
                Dispositivo.codigo_dispositivo == data["device"]
            )
        ).scalar_one_or_none()

        if device is None:
            device = Dispositivo(
                codigo_dispositivo=data["device"],
                modelo="Terminal operativo",
                estado="activo",
                id_puesto=puesto.id_puesto,
            )
            db.session.add(device)
            created["dispositivos"] += 1
        else:
            device.id_puesto = puesto.id_puesto
            device.estado = "activo"
        device.token_operativo_hash = generate_password_hash(
            DEMO_DEVICE_TOKENS[data["device"]]
        )
        username, password = DEMO_OPERATIONAL_ACCOUNTS[data["device"]]
        device.usuario_operativo = username
        device.password_operativo_hash = generate_password_hash(password)
        cache.delete(f"pacific-control:operacion:sesion:{device.id_dispositivo}")

        names_for_assignment = (
            [(name, "FIJO") for name in data["fixed"]]
            + [(name, "SACA_FRANCO") for name in data["relief"]]
        )

        for name, assignment in names_for_assignment:
            employee = employees_by_name[name]
            for shift in ("12 HORAS", "24 HORAS"):
                turno = db.session.execute(
                    db.select(Turno).where(
                        Turno.fecha == demo_date,
                        Turno.id_empleado == employee.id_empleado,
                        Turno.id_puesto == puesto.id_puesto,
                        Turno.tipo_turno == shift,
                    )
                ).scalar_one_or_none()

                if turno is None:
                    turno = Turno(
                        fecha=demo_date,
                        hora_inicio=time(0, 0),
                        hora_fin=time(0, 0),
                        estado="activo",
                        tipo_turno=shift,
                        tipo_asignacion=assignment,
                        id_empleado=employee.id_empleado,
                        id_puesto=puesto.id_puesto,
                    )
                    db.session.add(turno)
                    created["turnos"] += 1
                else:
                    turno.tipo_asignacion = assignment
                    turno.estado = "activo"

                db.session.flush()

                if first_turno is None:
                    first_turno = (turno, device, employee, puesto)

    if first_turno is not None:
        turno, device, employee, puesto = first_turno

        attendance = db.session.execute(
            db.select(Asistencia).where(
                Asistencia.id_turno == turno.id_turno,
                Asistencia.id_empleado == employee.id_empleado,
            )
        ).scalar_one_or_none()

        if attendance is None:
            db.session.add(
                Asistencia(
                    fecha_hora=datetime.combine(demo_date, time(8, 0)),
                    latitud=0,
                    longitud=0,
                    observacion=f"Demo {puesto.nombre_puesto}",
                    estado="registrada",
                    id_empleado=employee.id_empleado,
                    id_turno=turno.id_turno,
                    id_dispositivo=device.id_dispositivo,
                )
            )
            created["asistencias"] += 1

        novelty = db.session.execute(
            db.select(Novedad).where(
                Novedad.id_turno == turno.id_turno,
                Novedad.tipo == "CONTROL OPERATIVO",
            )
        ).scalar_one_or_none()

        if novelty is None:
            db.session.add(
                Novedad(
                    tipo="CONTROL OPERATIVO",
                    descripcion=f"Registro demo de {puesto.nombre_puesto}",
                    fecha_hora=datetime.combine(demo_date, time(8, 30)),
                    estado="abierta",
                    id_empleado=employee.id_empleado,
                    id_turno=turno.id_turno,
                )
            )
            created["novedades"] += 1

    db.session.commit()
    return created


if __name__ == "__main__":
    from app import create_app

    app = create_app()

    with app.app_context():
        print(seed_operational_demo())
