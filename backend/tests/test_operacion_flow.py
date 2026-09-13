"""Integration tests for the operative guard identification flow.

Covers:
- GET /operacion/dispositivos/<id>
- GET /operacion/dispositivos/codigo/<codigo>
- GET /operacion/dispositivos/<id>/guardias
- GET /operacion/dispositivos/<id>/sesion
- POST /operacion/dispositivos/<id>/sesion/identificar
- DELETE /operacion/dispositivos/<id>/sesion
- Seed idempotency for guardia.demo user
- Turnos: tipo_turno and tipo_asignacion validation
"""

import unittest
from datetime import date, time

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno

TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"

_TEST_CONFIG = {
    "TESTING": True,
    "SQLALCHEMY_DATABASE_URI": "sqlite://",
    "CACHE_ENABLED": False,
    "JWT_SECRET_KEY": TEST_JWT_SECRET_KEY,
}


class OperacionFlowTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        db.session.query(Turno).delete()
        db.session.query(Dispositivo).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

        # Create base data
        self.puesto = Puesto(
            nombre_puesto="ED. BAVIERA",
            direccion="Edificio Baviera",
            estado="activo",
        )
        db.session.add(self.puesto)
        db.session.flush()

        self.device = Dispositivo(
            codigo_dispositivo="BAVIERA-01",
            modelo="Terminal operativo",
            estado="activo",
            id_puesto=self.puesto.id_puesto,
        )
        db.session.add(self.device)
        db.session.flush()

        self.admin = Empleado(
            cedula="9000000001",
            nombres="Admin",
            apellidos="Test",
            correo="admin.op@test.com",
            password_hash=generate_password_hash("Test123!"),
            telefono="0999999001",
            cargo="ADMINISTRADOR",
            estado=True,
        )
        self.guard = Empleado(
            cedula="9000000002",
            nombres="Diego",
            apellidos="Tipantuña",
            correo="guard.op@test.com",
            password_hash=generate_password_hash("Guardia123!"),
            telefono="0999999002",
            cargo="GUARDIA",
            estado=True,
        )
        db.session.add_all([self.admin, self.guard])
        db.session.flush()

        self.turno = Turno(
            fecha=date(2026, 9, 13),
            hora_inicio=time(0, 0),
            hora_fin=time(0, 0),
            estado="activo",
            tipo_turno="24 HORAS",
            tipo_asignacion="FIJO",
            id_empleado=self.guard.id_empleado,
            id_puesto=self.puesto.id_puesto,
        )
        db.session.add(self.turno)
        db.session.commit()

    def _token(self, empleado):
        return create_access_token(identity=str(empleado.id_empleado))

    def _auth(self, empleado=None):
        e = empleado or self.admin
        return {"Authorization": f"Bearer {self._token(e)}"}

    # ── Authentication required ─────────────────────────────────────────

    def test_operative_endpoints_require_token(self):
        device_id = self.device.id_dispositivo
        for path in (
            f"/operacion/dispositivos/{device_id}",
            f"/operacion/dispositivos/{device_id}/guardias",
            f"/operacion/dispositivos/{device_id}/sesion",
        ):
            with self.subTest(path=path):
                resp = self.client.get(path)
                self.assertEqual(resp.status_code, 401)

    # ── Device info ─────────────────────────────────────────────────────

    def test_get_device_by_id_returns_puesto_info(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["codigo_dispositivo"], "BAVIERA-01")
        self.assertIsNotNone(data["puesto"])
        self.assertEqual(data["puesto"]["nombre_puesto"], "ED. BAVIERA")

    def test_get_device_by_codigo(self):
        resp = self.client.get(
            "/operacion/dispositivos/codigo/BAVIERA-01",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["id_dispositivo"], self.device.id_dispositivo)

    def test_nonexistent_device_returns_404(self):
        resp = self.client.get(
            "/operacion/dispositivos/99999",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)

    def test_nonexistent_device_by_codigo_returns_404(self):
        resp = self.client.get(
            "/operacion/dispositivos/codigo/NOPE-99",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)

    # ── Available guards ────────────────────────────────────────────────

    def test_list_guards_returns_active_guards_with_assignment(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        guards = resp.get_json()["data"]
        self.assertEqual(len(guards), 1)
        g = guards[0]
        self.assertEqual(g["id_empleado"], self.guard.id_empleado)
        self.assertEqual(g["tipo_asignacion"], "FIJO")
        self.assertIn("nombre_completo", g)

    def test_list_guards_for_nonexistent_device_returns_404(self):
        resp = self.client.get(
            "/operacion/dispositivos/99999/guardias",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)

    def test_list_guards_excludes_inactive_employees(self):
        # Deactivate guard
        self.guard.estado = False
        db.session.commit()
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.get_json()["data"]), 0)
        # Restore
        self.guard.estado = True
        db.session.commit()

    # ── Session ──────────────────────────────────────────────────────────

    def test_get_session_returns_sin_identificar_when_empty(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertIn(data["estado"], ("sin_identificar",))

    def test_identify_guard_sets_session(self):
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["estado"], "identificado")
        guardia = data["guardia_identificado"]
        self.assertEqual(guardia["id_empleado"], self.guard.id_empleado)
        self.assertEqual(guardia["tipo_asignacion"], "FIJO")

    def test_identify_guard_invalid_payload_returns_400(self):
        for body in ({}, {"id_empleado": "not-an-int"}, {"id_empleado": -1}):
            with self.subTest(body=body):
                resp = self.client.post(
                    f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
                    json=body,
                    headers=self._auth(),
                )
                self.assertEqual(resp.status_code, 400)

    def test_identify_nonexistent_employee_returns_404(self):
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": 99999},
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)

    def test_identify_inactive_employee_returns_404(self):
        self.guard.estado = False
        db.session.commit()
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)
        self.guard.estado = True
        db.session.commit()

    def test_clear_session_returns_200(self):
        # Identify first
        self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
            headers=self._auth(),
        )
        # Now clear
        resp = self.client.delete(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)

    def test_clear_nonexistent_device_returns_404(self):
        resp = self.client.delete(
            "/operacion/dispositivos/99999/sesion",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 404)

    # ── Guardia role can operate device ─────────────────────────────────

    def test_guardia_can_access_operative_endpoints(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}",
            headers=self._auth(self.guard),
        )
        self.assertEqual(resp.status_code, 200)

    def test_operative_session_does_not_grant_admin_access(self):
        # Identify guard in session
        self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
            headers=self._auth(self.guard),
        )
        # Guard still cannot create puestos
        resp = self.client.post(
            "/puestos",
            json={"nombre_puesto": "x", "direccion": "y", "estado": "activo"},
            headers=self._auth(self.guard),
        )
        self.assertEqual(resp.status_code, 403)


class TurnoValidationTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        db.session.query(Turno).delete()
        db.session.query(Dispositivo).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

        self.puesto = Puesto(
            nombre_puesto="Puesto Validacion",
            direccion="Dir",
            estado="activo",
        )
        db.session.add(self.puesto)
        self.admin = Empleado(
            cedula="8000000001",
            nombres="Adm",
            apellidos="Val",
            correo="adm.val@test.com",
            password_hash=generate_password_hash("Test123!"),
            telefono="0988888001",
            cargo="ADMINISTRADOR",
            estado=True,
        )
        self.guard_emp = Empleado(
            cedula="8000000002",
            nombres="Grd",
            apellidos="Val",
            correo="grd.val@test.com",
            password_hash=generate_password_hash("Test123!"),
            telefono="0988888002",
            cargo="GUARDIA",
            estado=True,
        )
        db.session.add_all([self.admin, self.guard_emp])
        db.session.commit()

    def _token(self, emp):
        return create_access_token(identity=str(emp.id_empleado))

    def _auth(self):
        return {"Authorization": f"Bearer {self._token(self.admin)}"}

    def _valid_payload(self, **overrides):
        payload = {
            "fecha": "2026-09-13",
            "hora_inicio": "08:00:00",
            "hora_fin": "20:00:00",
            "estado": "activo",
            "tipo_turno": "24 HORAS",
            "tipo_asignacion": "FIJO",
            "id_empleado": self.guard_emp.id_empleado,
            "id_puesto": self.puesto.id_puesto,
        }
        payload.update(overrides)
        return payload

    def test_valid_tipo_turno_values_are_accepted(self):
        for tipo in ("24 HORAS", "12 HORAS", "MIXTO"):
            with self.subTest(tipo=tipo):
                resp = self.client.post(
                    "/turnos",
                    json=self._valid_payload(tipo_turno=tipo),
                    headers=self._auth(),
                )
                self.assertEqual(resp.status_code, 201, resp.get_json())

    def test_invalid_tipo_turno_returns_400(self):
        resp = self.client.post(
            "/turnos",
            json=self._valid_payload(tipo_turno="8 HORAS"),
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("tipo_turno", resp.get_json().get("detalles", {}))

    def test_valid_tipo_asignacion_values_are_accepted(self):
        for tipo in ("FIJO", "SACA_FRANCO"):
            with self.subTest(tipo=tipo):
                resp = self.client.post(
                    "/turnos",
                    json=self._valid_payload(tipo_asignacion=tipo),
                    headers=self._auth(),
                )
                self.assertEqual(resp.status_code, 201, resp.get_json())

    def test_invalid_tipo_asignacion_returns_400(self):
        resp = self.client.post(
            "/turnos",
            json=self._valid_payload(tipo_asignacion="EVENTUAL"),
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("tipo_asignacion", resp.get_json().get("detalles", {}))

    def test_turno_meta_options_endpoint(self):
        resp = self.client.get(
            "/turnos/meta/opciones",
            headers=self._auth(),
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertIn("tipo_turno", data)
        self.assertIn("tipo_asignacion", data)
        self.assertIn("24 HORAS", data["tipo_turno"])
        self.assertIn("MIXTO", data["tipo_turno"])
        self.assertIn("FIJO", data["tipo_asignacion"])
        self.assertIn("SACA_FRANCO", data["tipo_asignacion"])


class GuardiaDemoUserTestCase(unittest.TestCase):
    """Verify the guardia.demo@pacific.test user is created by seed."""

    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
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

    def test_guardia_demo_user_created_by_seed_and_can_login(self):
        from app.auth.auth_seed import seed_demo_users
        seed_demo_users()

        resp = self.client.post(
            "/auth/login",
            json={"correo": "guardia.demo@pacific.test", "password": "Guardia123!"},
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertIn("access_token", data)
        self.assertEqual(data["empleado"]["cargo"], "GUARDIA")

    def test_guardia_demo_seed_is_idempotent(self):
        from app.auth.auth_seed import seed_demo_users
        seed_demo_users()
        seed_demo_users()

        from app.models.empleado import Empleado as E
        count = db.session.query(E).filter_by(correo="guardia.demo@pacific.test").count()
        self.assertEqual(count, 1)

    def test_guardia_demo_cannot_access_admin_endpoints(self):
        from app.auth.auth_seed import seed_demo_users
        from flask_jwt_extended import create_access_token

        seed_demo_users()
        emp = db.session.execute(
            db.select(Empleado).where(Empleado.correo == "guardia.demo@pacific.test")
        ).scalar_one()
        token = create_access_token(identity=str(emp.id_empleado))
        headers = {"Authorization": f"Bearer {token}"}

        # Should be forbidden on admin routes
        resp = self.client.post(
            "/empleados",
            json={},
            headers=headers,
        )
        self.assertEqual(resp.status_code, 403)
