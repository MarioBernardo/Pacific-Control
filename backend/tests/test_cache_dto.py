import unittest
from datetime import date, time
from unittest.mock import patch

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import cache, db
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.services.cache_service import cache_service


JWT_SECRET = "TEST_ONLY_CACHE_DTO_SECRET_0123456789_abcdefghijklmnopqrstuvwxyz"


class CacheDtoTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "CACHE_ENABLED": True,
            "JWT_SECRET_KEY": JWT_SECRET,
        })
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        db.session.remove()
        db.drop_all()
        db.create_all()
        self.cached = {}
        self.cache_gets = []
        self.cache_sets = []
        self.cache_patterns = []
        self.patches = (
            patch.object(cache, "get_json", side_effect=self._cache_get),
            patch.object(cache, "set_json", side_effect=self._cache_set),
            patch.object(cache, "delete", return_value=True),
            patch.object(
                cache,
                "delete_pattern",
                side_effect=lambda pattern: not self.cache_patterns.append(pattern),
            ),
        )
        for item in self.patches:
            item.start()

        puesto = Puesto(
            nombre_puesto="ED. CACHE",
            direccion="Dirección cache",
            estado="activo",
        )
        admin = Empleado(
            cedula="0999999901",
            nombres="Ana",
            apellidos="Admin",
            correo="admin.cache@test.local",
            password_hash=generate_password_hash("test-only"),
            telefono="0999999901",
            cargo="ADMINISTRADOR",
            estado=True,
        )
        guardia = Empleado(
            cedula="0999999902",
            nombres="Galo",
            apellidos="Guardia",
            correo="guardia.cache@test.local",
            password_hash=generate_password_hash("test-only"),
            telefono="0999999902",
            cargo="GUARDIA",
            estado=True,
        )
        db.session.add_all((puesto, admin, guardia))
        db.session.flush()
        self.device = Dispositivo(
            codigo_dispositivo="CACHE-01",
            modelo="Terminal",
            estado="activo",
            id_puesto=puesto.id_puesto,
        )
        self.shift = Turno(
            fecha=date.today(),
            hora_inicio=time(7),
            hora_fin=time(19),
            estado="activo",
            tipo_turno="12 HORAS",
            tipo_asignacion="FIJO",
            id_empleado=guardia.id_empleado,
            id_puesto=puesto.id_puesto,
        )
        db.session.add_all((self.device, self.shift))
        db.session.commit()
        self.headers = {
            "Authorization": f"Bearer {create_access_token(identity=str(admin.id_empleado))}"
        }
        self.client = self.app.test_client()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()

    def _cache_get(self, key):
        self.cache_gets.append(key)
        return self.cached.get(key)

    def _cache_set(self, key, value, ttl=None):
        self.cache_sets.append(key)
        self.cached[key] = value
        return True

    def _assert_miss_then_hit(self, path, expected_relation):
        first = self.client.get(path, headers=self.headers)
        second = self.client.get(path, headers=self.headers)
        self.assertEqual(first.status_code, 200, first.get_json())
        self.assertEqual(second.status_code, 200, second.get_json())
        self.assertEqual(first.get_json(), second.get_json())
        self.assertEqual(len(self.cache_sets), 1)
        self.assertEqual(len(self.cache_gets), 2)
        self.assertIsNotNone(first.get_json()["data"][expected_relation])

    def test_turno_cache_miss_and_hit_return_identical_json_with_relations(self):
        self._assert_miss_then_hit(
            f"/turnos/{self.shift.id_turno}",
            "empleado",
        )
        self.assertIn("puesto", self.cached[next(iter(self.cached))])

    def test_dispositivo_cache_miss_and_hit_return_identical_json_with_puesto(self):
        self._assert_miss_then_hit(
            f"/dispositivos/{self.device.id_dispositivo}",
            "puesto",
        )

    def test_related_dto_caches_are_invalidated(self):
        cache_service.invalidate("puesto", 1)
        self.assertEqual(
            set(self.cache_patterns),
            {
                "pacific-control:dispositivo:*",
                "pacific-control:turno:*",
                "pacific-control:asistencia:*",
                "pacific-control:novedad:*",
            },
        )


if __name__ == "__main__":
    unittest.main()
