import unittest

from flask_jwt_extended import create_access_token
from werkzeug.security import check_password_hash, generate_password_hash

from app import create_app
from app.auth.auth_seed import DEMO_USERS, seed_demo_users
from app.extensions import db
from app.models.empleado import Empleado


TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class RoleSecurityTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app(
            {
                "TESTING": True,
                "SQLALCHEMY_DATABASE_URI": "sqlite://",
                "CACHE_ENABLED": False,
                "JWT_SECRET_KEY": TEST_JWT_SECRET_KEY,
            }
        )
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

    def _employee(self, cargo: str, correo: str, estado: bool = True) -> Empleado:
        empleado = Empleado(
            cedula=str(1000000000 + len(correo)),
            nombres="Usuario",
            apellidos="Prueba",
            correo=correo,
            password_hash=generate_password_hash("clave-segura"),
            telefono="0999999999",
            cargo=cargo,
            estado=estado,
        )
        db.session.add(empleado)
        db.session.commit()
        return empleado

    def _token(self, empleado: Empleado) -> str:
        return create_access_token(identity=str(empleado.id_empleado))

    def test_each_defined_role_can_login(self):
        for cargo in ("ADMINISTRADOR", "SUPERVISOR", "GUARDIA"):
            with self.subTest(cargo=cargo):
                empleado = self._employee(cargo, f"{cargo.lower()}@pacific.test")
                response = self.client.post(
                    "/auth/login",
                    json={"correo": empleado.correo, "password": "clave-segura"},
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.get_json()["data"]["empleado"]["cargo"], cargo)

    def test_inactive_employee_cannot_login(self):
        empleado = self._employee("SUPERVISOR", "inactivo@pacific.test", estado=False)
        response = self.client.post(
            "/auth/login",
            json={"correo": empleado.correo, "password": "clave-segura"},
        )
        self.assertEqual(response.status_code, 401)

    def test_administrator_can_access_employee_collection(self):
        empleado = self._employee("ADMINISTRADOR", "admin@pacific.test")
        response = self.client.get(
            "/empleados",
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 200)

    def test_supervisor_can_access_employee_collection(self):
        empleado = self._employee("SUPERVISOR", "supervisor@pacific.test")
        response = self.client.get(
            "/empleados",
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 200)

    def test_guardia_can_access_operational_collection(self):
        empleado = self._employee("GUARDIA", "guardia@pacific.test")
        response = self.client.get(
            "/puestos",
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 200)

    def test_guardia_is_rejected_for_administrative_routes(self):
        empleado = self._employee("GUARDIA", "guardia@pacific.test")
        response = self.client.get(
            "/empleados",
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 403)

    def test_supervisor_is_rejected_for_administrator_only_mutation(self):
        empleado = self._employee("SUPERVISOR", "supervisor@pacific.test")
        response = self.client.post(
            "/empleados",
            json={},
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 403)

    def test_unknown_role_is_rejected_with_the_forbidden_contract(self):
        empleado = self._employee("Sin matriz definida", "legacy@pacific.test")
        response = self.client.get(
            "/empleados",
            headers={"Authorization": f"Bearer {self._token(empleado)}"},
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(
            response.get_json(),
            {"error": "No tiene permiso para acceder a este recurso."},
        )

    def test_demo_seed_is_idempotent_and_hashes_passwords(self):
        first_run = seed_demo_users()
        second_run = seed_demo_users()
        self.assertEqual(len(first_run), len(DEMO_USERS))
        self.assertEqual(len(second_run), len(DEMO_USERS))
        self.assertEqual(db.session.query(Empleado).count(), len(DEMO_USERS))
        for data in DEMO_USERS:
            empleado = db.session.execute(
                db.select(Empleado).where(Empleado.correo == data["correo"])
            ).scalar_one()
            self.assertNotEqual(empleado.password_hash, data["password"])
            self.assertTrue(check_password_hash(empleado.password_hash, data["password"]))


if __name__ == "__main__":
    unittest.main()