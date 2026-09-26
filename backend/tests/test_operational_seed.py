import unittest
from werkzeug.security import check_password_hash

from app import create_app
from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.seed_operational import DEMO_DEVICE_TOKENS, seed_operational_demo


class OperationalSeedTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite://", "CACHE_ENABLED": False})
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        for model in (Asistencia, Novedad, Turno, Dispositivo, Puesto, Empleado):
            db.session.query(model).delete()
        db.session.commit()

    def test_official_operational_seed_is_idempotent_and_preserves_assignments(self):
        first = seed_operational_demo()
        second = seed_operational_demo()
        self.assertEqual(first["puestos"], 4)
        self.assertEqual(first["dispositivos"], 4)
        self.assertEqual(first["turnos"], 28)
        self.assertEqual(second["turnos"], 0)
        self.assertEqual(second["empleados"], 0)
        self.assertEqual(db.session.query(Puesto).count(), 4)
        self.assertEqual(db.session.query(Dispositivo).count(), 4)
        self.assertEqual(db.session.query(Asistencia).count(), 0)
        self.assertEqual(db.session.query(Novedad).count(), 0)
        self.assertTrue(all(
            turno.hora_inicio is None and turno.hora_fin is None
            for turno in db.session.query(Turno).all()
        ))
        self.assertEqual(
            db.session.query(Turno).filter_by(tipo_asignacion="SACA_FRANCO").count(),
            14,
        )
        vertice = db.session.execute(
            db.select(Puesto).where(Puesto.nombre_puesto == "ED. VERTICE")
        ).scalar_one()
        fixed_vertice = db.session.execute(
            db.select(Turno).where(
                Turno.id_puesto == vertice.id_puesto,
                Turno.tipo_asignacion == "FIJO",
            )
        ).scalars().all()
        self.assertEqual(len(fixed_vertice), 2)
        self.assertEqual(fixed_vertice[0].empleado.apellidos, "DELGADO TITUAÑA")
        self.assertEqual(
            {turno.tipo_turno for turno in fixed_vertice},
            {"12 HORAS", "24 HORAS"},
        )
        expected = {
            "BAVIERA-01": {"FIJO": 2, "SACA_FRANCO": 2},
            "CENTURY-01": {"FIJO": 2, "SACA_FRANCO": 2},
            "GRAND-VICTORIA-01": {"FIJO": 2, "SACA_FRANCO": 1},
            "VERTICE-01": {"FIJO": 1, "SACA_FRANCO": 2},
        }
        client = self.app.test_client()
        for code, assignments in expected.items():
            device = db.session.scalar(
                db.select(Dispositivo).where(Dispositivo.codigo_dispositivo == code)
            )
            self.assertTrue(
                check_password_hash(device.token_operativo_hash, DEMO_DEVICE_TOKENS[code])
            )
            response = client.get(
                f"/operacion/dispositivos/{device.id_dispositivo}/guardias",
                headers={"X-Device-Token": DEMO_DEVICE_TOKENS[code]},
            )
            self.assertEqual(response.status_code, 200, response.get_json())
            guards = response.get_json()["data"]
            actual = {
                kind: sum(g["tipo_asignacion"] == kind for g in guards)
                for kind in assignments
            }
            self.assertEqual(actual, assignments)
            self.assertTrue(all(
                {item["tipo_turno"] for item in g["turnos_disponibles"]}
                == {"12 HORAS", "24 HORAS"}
                for g in guards
            ))


if __name__ == "__main__":
    unittest.main()
