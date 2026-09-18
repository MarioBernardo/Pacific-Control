"""Integration tests for the operative guard identification flow.

Security model tested here:
- /operacion endpoints do NOT require JWT — they represent the physical
  device layer, authenticated implicitly by the device code / puesto.
- A guard identified in the operative session does NOT gain admin privileges.
- Administrative endpoints (/puestos, /empleados, etc.) remain protected
  by JWT + cargo_required regardless of any operative session.
- An inactive employee cannot identify themselves.
- An employee not assigned to the device's puesto cannot identify themselves.
- A nonexistent device always returns 404.

Also covers:
- Turno tipo_turno / tipo_asignacion validation (valid + invalid values).
- GET /turnos/meta/opciones returns correct enum sets.
- Seed demo user idempotency (guardia.demo@pacific.test).
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
    "ALLOW_LEGACY_OPERATIVE_DEVICES": True,
}


# ---------------------------------------------------------------------------
# Helpers shared across test cases
# ---------------------------------------------------------------------------

def _make_puesto(nombre="ED. BAVIERA", direccion="Edificio Baviera"):
    p = Puesto(nombre_puesto=nombre, direccion=direccion, estado="activo")
    db.session.add(p)
    db.session.flush()
    return p


def _make_device(codigo, puesto_id):
    d = Dispositivo(
        codigo_dispositivo=codigo,
        modelo="Terminal operativo",
        estado="activo",
        id_puesto=puesto_id,
    )
    db.session.add(d)
    db.session.flush()
    return d


def _make_empleado(cedula, nombres, apellidos, correo, cargo="GUARDIA", estado=True):
    e = Empleado(
        cedula=cedula,
        nombres=nombres,
        apellidos=apellidos,
        correo=correo,
        password_hash=generate_password_hash("Test123!"),
        telefono="0999999999",
        cargo=cargo,
        estado=estado,
    )
    db.session.add(e)
    db.session.flush()
    return e


def _make_turno(empleado_id, puesto_id, tipo_asignacion="FIJO", tipo_turno="24 HORAS"):
    t = Turno(
        fecha=date.today(),
        hora_inicio=time(0, 0),
        hora_fin=time(0, 0),
        estado="activo",
        tipo_turno=tipo_turno,
        tipo_asignacion=tipo_asignacion,
        id_empleado=empleado_id,
        id_puesto=puesto_id,
    )
    db.session.add(t)
    db.session.flush()
    return t


def _jwt(empleado_id):
    return {"Authorization": f"Bearer {create_access_token(identity=str(empleado_id))}"}


# ---------------------------------------------------------------------------
# Operative flow — no JWT required
# ---------------------------------------------------------------------------

class OperacionFlowTestCase(unittest.TestCase):
    """Tests that the operative flow works WITHOUT any JWT token."""

    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
        cls.ctx = cls.app.app_context()
        cls.ctx.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.ctx.pop()

    def setUp(self):
        db.session.query(Turno).delete()
        db.session.query(Dispositivo).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

        self.puesto = _make_puesto()
        self.device = _make_device("BAVIERA-01", self.puesto.id_puesto)
        self.guard = _make_empleado("9000000001", "Diego", "Tipantuña", "guard.op@test.com")
        self.turno = _make_turno(
            self.guard.id_empleado, self.puesto.id_puesto,
            tipo_asignacion="FIJO", tipo_turno="24 HORAS",
        )
        # A guard NOT assigned to this puesto
        self.other_guard = _make_empleado("9000000003", "Otro", "Guardia", "other.guard@test.com")
        db.session.commit()

    # ── Endpoints work WITHOUT JWT ──────────────────────────────────────

    def test_get_device_by_id_requires_no_jwt(self):
        resp = self.client.get(f"/operacion/dispositivos/{self.device.id_dispositivo}")
        self.assertEqual(resp.status_code, 200)

    def test_sensitive_operation_requires_valid_device_token(self):
        self.app.config["ALLOW_LEGACY_OPERATIVE_DEVICES"] = False
        self.device.token_operativo_hash = generate_password_hash("device-secret")
        db.session.commit()
        path = f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias"
        self.assertEqual(self.client.get(path).status_code, 401)
        self.assertEqual(
            self.client.get(path, headers={"X-Device-Token": "wrong"}).status_code,
            401,
        )
        self.assertEqual(
            self.client.get(path, headers={"X-Device-Token": "device-secret"}).status_code,
            200,
        )
        self.app.config["ALLOW_LEGACY_OPERATIVE_DEVICES"] = True

    def test_get_device_by_codigo_requires_no_jwt(self):
        resp = self.client.get("/operacion/dispositivos/codigo/BAVIERA-01")
        self.assertEqual(resp.status_code, 200)

    def test_list_guards_requires_no_jwt(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias"
        )
        self.assertEqual(resp.status_code, 200)

    def test_get_session_requires_no_jwt(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion"
        )
        self.assertEqual(resp.status_code, 200)

    def test_identify_guard_requires_no_jwt(self):
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        self.assertEqual(resp.status_code, 200)

    def test_clear_session_requires_no_jwt(self):
        resp = self.client.delete(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion"
        )
        self.assertEqual(resp.status_code, 200)

    # ── Device info ─────────────────────────────────────────────────────

    def test_get_device_by_id_returns_puesto_info(self):
        resp = self.client.get(f"/operacion/dispositivos/{self.device.id_dispositivo}")
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["codigo_dispositivo"], "BAVIERA-01")
        self.assertIsNotNone(data["puesto"])
        self.assertEqual(data["puesto"]["nombre_puesto"], "ED. BAVIERA")

    def test_get_device_by_codigo(self):
        resp = self.client.get("/operacion/dispositivos/codigo/BAVIERA-01")
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["id_dispositivo"], self.device.id_dispositivo)

    def test_nonexistent_device_returns_404(self):
        resp = self.client.get("/operacion/dispositivos/99999")
        self.assertEqual(resp.status_code, 404)

    def test_nonexistent_device_by_codigo_returns_404(self):
        resp = self.client.get("/operacion/dispositivos/codigo/NOPE-99")
        self.assertEqual(resp.status_code, 404)

    # ── Available guards ────────────────────────────────────────────────

    def test_list_guards_returns_active_guards_with_assignment(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias"
        )
        self.assertEqual(resp.status_code, 200)
        guards = resp.get_json()["data"]
        self.assertEqual(len(guards), 1)
        g = guards[0]
        self.assertEqual(g["id_empleado"], self.guard.id_empleado)
        self.assertEqual(g["tipo_asignacion"], "FIJO")
        self.assertIn("nombre_completo", g)

    def test_list_guards_for_nonexistent_device_returns_404(self):
        resp = self.client.get("/operacion/dispositivos/99999/guardias")
        self.assertEqual(resp.status_code, 404)

    def test_list_guards_excludes_inactive_employees(self):
        self.guard.estado = False
        db.session.commit()
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias"
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.get_json()["data"]), 0)
        self.guard.estado = True
        db.session.commit()

    def test_list_guards_includes_saca_franco(self):
        sf = _make_empleado("9000000004", "Mario", "Bernardo", "sf.op@test.com")
        _make_turno(
            sf.id_empleado, self.puesto.id_puesto,
            tipo_asignacion="SACA_FRANCO",
        )
        db.session.commit()
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias"
        )
        codes = {g["tipo_asignacion"] for g in resp.get_json()["data"]}
        self.assertIn("FIJO", codes)
        self.assertIn("SACA_FRANCO", codes)

    # ── Session ──────────────────────────────────────────────────────────

    def test_get_session_returns_sin_identificar_when_empty(self):
        resp = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion"
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["estado"], "sin_identificar")
        self.assertIsNone(data["guardia_identificado"])

    def test_identify_guard_sets_session(self):
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()["data"]
        self.assertEqual(data["estado"], "identificado")
        guardia = data["guardia_identificado"]
        self.assertEqual(guardia["id_empleado"], self.guard.id_empleado)
        self.assertEqual(guardia["tipo_asignacion"], "FIJO")
        self.assertIn("id_turno", guardia)

    def test_identify_guard_invalid_payload_returns_400(self):
        for body in ({}, {"id_empleado": "not-an-int"}, {"id_empleado": -1}):
            with self.subTest(body=body):
                resp = self.client.post(
                    f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
                    json=body,
                )
                self.assertEqual(resp.status_code, 400)

    def test_identify_nonexistent_employee_returns_404(self):
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": 99999},
        )
        self.assertEqual(resp.status_code, 404)

    def test_identify_inactive_employee_returns_404(self):
        """An inactive employee cannot identify themselves."""
        self.guard.estado = False
        db.session.commit()
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        self.assertEqual(resp.status_code, 404)
        self.guard.estado = True
        db.session.commit()

    def test_identify_employee_not_assigned_to_puesto_returns_404(self):
        """An employee with no turno at this puesto cannot identify themselves."""
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.other_guard.id_empleado},
        )
        self.assertEqual(resp.status_code, 404)

    def test_identify_saca_franco_succeeds(self):
        """A SACA_FRANCO employee with a turno at the puesto can identify."""
        sf = _make_empleado("9000000005", "Byron", "Betancourth", "sf2.op@test.com")
        _make_turno(
            sf.id_empleado, self.puesto.id_puesto,
            tipo_asignacion="SACA_FRANCO",
        )
        db.session.commit()
        resp = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": sf.id_empleado},
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(
            resp.get_json()["data"]["guardia_identificado"]["tipo_asignacion"],
            "SACA_FRANCO",
        )

    def test_clear_session_returns_200(self):
        self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        resp = self.client.delete(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion"
        )
        self.assertEqual(resp.status_code, 200)

    def test_clear_nonexistent_device_returns_404(self):
        resp = self.client.delete("/operacion/dispositivos/99999/sesion")
        self.assertEqual(resp.status_code, 404)

    # ── Session does NOT grant admin access ─────────────────────────────

    def test_operative_session_does_not_grant_admin_access(self):
        """Identifying a guard in the operative session grants NO admin privileges.

        A guard-role employee with an active session must still be rejected
        when attempting to access admin-only endpoints.
        """
        # Identify the guard in the operative session (no JWT used)
        self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        # The guard's JWT (if they had one) must still be blocked from admin endpoints
        resp = self.client.post(
            "/puestos",
            json={"nombre_puesto": "x", "direccion": "y", "estado": "activo"},
            headers=_jwt(self.guard.id_empleado),
        )
        self.assertEqual(resp.status_code, 403)

    def test_admin_endpoints_still_require_jwt_after_operative_session(self):
        """Operative sessions provide no credential — admin routes require JWT."""
        # No JWT — must be 401 even if operative session exists
        self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            json={"id_empleado": self.guard.id_empleado},
        )
        resp = self.client.get("/turnos")
        self.assertEqual(resp.status_code, 401)


# ---------------------------------------------------------------------------
# Turno enum validation
# ---------------------------------------------------------------------------

class TurnoValidationTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
        cls.ctx = cls.app.app_context()
        cls.ctx.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.ctx.pop()

    def setUp(self):
        db.session.query(Turno).delete()
        db.session.query(Dispositivo).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

        self.puesto = _make_puesto("Puesto Val", "Dir Val")
        self.admin = _make_empleado(
            "8000000001", "Adm", "Val", "adm.val@test.com", cargo="ADMINISTRADOR"
        )
        self.guard_emp = _make_empleado(
            "8000000002", "Grd", "Val", "grd.val@test.com", cargo="GUARDIA"
        )
        db.session.commit()

    def _auth(self):
        return _jwt(self.admin.id_empleado)

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
        self.assertIn("12 HORAS", data["tipo_turno"])
        self.assertIn("MIXTO", data["tipo_turno"])
        self.assertIn("FIJO", data["tipo_asignacion"])
        self.assertIn("SACA_FRANCO", data["tipo_asignacion"])


# ---------------------------------------------------------------------------
# Seed demo users
# ---------------------------------------------------------------------------

class GuardiaDemoUserTestCase(unittest.TestCase):
    """Verify guardia.demo@pacific.test is created by seed and stays non-admin."""

    @classmethod
    def setUpClass(cls):
        cls.app = create_app(_TEST_CONFIG)
        cls.ctx = cls.app.app_context()
        cls.ctx.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.ctx.pop()

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

        count = (
            db.session.query(Empleado)
            .filter_by(correo="guardia.demo@pacific.test")
            .count()
        )
        self.assertEqual(count, 1)

    def test_guardia_demo_cannot_access_admin_endpoints(self):
        from app.auth.auth_seed import seed_demo_users

        seed_demo_users()
        emp = db.session.execute(
            db.select(Empleado).where(Empleado.correo == "guardia.demo@pacific.test")
        ).scalar_one()
        headers = _jwt(emp.id_empleado)

        # Must be forbidden on admin-only route
        resp = self.client.post("/empleados", json={}, headers=headers)
        self.assertEqual(resp.status_code, 403)

    def test_guardia_demo_can_read_operative_info_without_jwt(self):
        """Operative endpoints work for any device — no login required."""
        from app.auth.auth_seed import seed_demo_users

        seed_demo_users()
        # Create a device to prove the operative endpoint is accessible
        puesto = _make_puesto("ED. TEST", "Dir Test")
        device = _make_device("TEST-01", puesto.id_puesto)
        db.session.commit()

        # No Authorization header needed
        resp = self.client.get(f"/operacion/dispositivos/{device.id_dispositivo}")
        self.assertEqual(resp.status_code, 200)
