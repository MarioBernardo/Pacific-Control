"""Integration tests for AUTH-01 and SEC-01."""

from datetime import timedelta
import unittest

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.empleado import Empleado


TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class AuthSecurityTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "CACHE_ENABLED": False,
            "JWT_SECRET_KEY": TEST_JWT_SECRET_KEY,
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
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

    def _employee(self, *, correo="activo@pacific.test", estado=True):
        empleado = Empleado(
            cedula="1234567890" if estado else "0987654321",
            nombres="Usuario",
            apellidos="Prueba",
            correo=correo,
            password_hash=generate_password_hash("clave-segura"),
            telefono="0999999999",
            cargo="Sin matriz definida",
            estado=estado,
        )
        db.session.add(empleado)
        db.session.commit()
        return empleado

    def _token_for(self, empleado):
        return create_access_token(identity=str(empleado.id_empleado))

    def test_login_valid_returns_access_token(self):
        self._employee()
        response = self.client.post(
            "/auth/login",
            json={"correo": "activo@pacific.test", "password": "clave-segura"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("access_token", response.get_json()["data"])

    def test_login_invalid_returns_generic_401(self):
        self._employee()
        response = self.client.post(
            "/auth/login",
            json={"correo": "activo@pacific.test", "password": "incorrecta"},
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json(), {"error": "Credenciales inválidas."})

    def test_all_crud_posts_require_a_token(self):
        for endpoint in (
            "/empleados", "/puestos", "/dispositivos", "/turnos",
            "/asistencias", "/novedades",
        ):
            with self.subTest(endpoint=endpoint):
                response = self.client.post(endpoint, json={})
                self.assertEqual(response.status_code, 401)
                self.assertIn("error", response.get_json())

    def test_protected_post_accepts_an_active_employee_token(self):
        empleado = self._employee()
        response = self.client.post(
            "/puestos",
            json={
                "nombre_puesto": "Puesto de prueba",
                "direccion": "Dirección de prueba",
                "estado": "activo",
            },
            headers={"Authorization": f"Bearer {self._token_for(empleado)}"},
        )
        self.assertEqual(response.status_code, 201)
        self.assertIn("data", response.get_json())

    def test_invalid_token_returns_json_401(self):
        response = self.client.post(
            "/puestos", json={}, headers={"Authorization": "Bearer no-es-un-token"}
        )
        self.assertEqual(response.status_code, 401)
        self.assertIn("error", response.get_json())

    def test_expired_token_returns_json_401(self):
        empleado = self._employee()
        token = create_access_token(
            identity=str(empleado.id_empleado), expires_delta=timedelta(seconds=-1)
        )
        response = self.client.post(
            "/puestos", json={}, headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(response.status_code, 401)
        self.assertIn("error", response.get_json())

    def test_inactive_employee_cannot_login_or_access_protected_resources(self):
        empleado = self._employee(correo="inactivo@pacific.test", estado=False)
        login_response = self.client.post(
            "/auth/login",
            json={"correo": empleado.correo, "password": "clave-segura"},
        )
        access_response = self.client.post(
            "/puestos",
            json={},
            headers={"Authorization": f"Bearer {self._token_for(empleado)}"},
        )
        self.assertEqual(login_response.status_code, 401)
        self.assertEqual(access_response.status_code, 403)
        self.assertIn("error", access_response.get_json())
