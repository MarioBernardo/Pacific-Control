import unittest

from app import create_app
from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.seed_operational import seed_operational_demo


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
        self.assertEqual(first["turnos"], 14)
        self.assertEqual(second["turnos"], 0)
        self.assertEqual(db.session.query(Puesto).count(), 4)
        self.assertEqual(db.session.query(Dispositivo).count(), 4)
        self.assertEqual(db.session.query(Asistencia).count(), 1)
        self.assertEqual(db.session.query(Novedad).count(), 1)
        self.assertEqual(
            db.session.query(Turno).filter_by(tipo_asignacion="SACA_FRANCO").count(),
            7,
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
        self.assertEqual(len(fixed_vertice), 1)
        self.assertEqual(fixed_vertice[0].empleado.apellidos, "DELGADO TITUAÑA")


if __name__ == "__main__":
    unittest.main()
