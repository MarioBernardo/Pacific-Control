import unittest
from datetime import date, time

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno


TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class TurnoCrudTestCase(unittest.TestCase):
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
        db.session.query(Turno).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()
        self.empleado = self._create_employee("ADMINISTRADOR", "admin")
        self.puesto = Puesto(
            nombre_puesto="Puesto de prueba",
            direccion="Av. Principal 100",
            estado="activo",
        )
        db.session.add(self.puesto)
        db.session.commit()

    def _create_employee(self, cargo: str, name: str) -> Empleado:
        empleado = Empleado(
            cedula=str(1000000000 + len(name) + len(cargo)),
            nombres=name.title(),
            apellidos="Prueba",
            correo=f"{name}@turno.test",
            password_hash=generate_password_hash("clave-segura"),
            telefono="0999999999",
            cargo=cargo,
            estado=True,
        )
        db.session.add(empleado)
        db.session.commit()
        return empleado

    def _headers(self, cargo: str = "ADMINISTRADOR") -> dict[str, str]:
        empleado = self.empleado if cargo == "ADMINISTRADOR" else self._create_employee(cargo, cargo.lower())
        token = create_access_token(identity=str(empleado.id_empleado))
        return {"Authorization": f"Bearer {token}"}

    def _payload(self, **overrides) -> dict:
        payload = {
            "fecha": "2026-09-13",
            "hora_inicio": "08:00:00",
            "hora_fin": "16:00:00",
            "estado": "activo",
            "id_empleado": self.empleado.id_empleado,
            "id_puesto": self.puesto.id_puesto,
        }
        payload.update(overrides)
        return payload

    def test_admin_can_create_list_get_update_and_change_status(self):
        headers = self._headers()
        created = self.client.post("/turnos", json=self._payload(), headers=headers)
        self.assertEqual(created.status_code, 201)
        turno_id = created.get_json()["data"]["id_turno"]

        listed = self.client.get("/turnos", headers=headers)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.get_json()["data"]), 1)

        fetched = self.client.get(f"/turnos/{turno_id}", headers=headers)
        self.assertEqual(fetched.status_code, 200)

        updated = self.client.put(
            f"/turnos/{turno_id}",
            json={"estado": "activo"},
            headers=headers,
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.get_json()["data"]["estado"], "activo")

        status = self.client.patch(
            f"/turnos/{turno_id}/estado",
            json={"estado": "inactivo"},
            headers=headers,
        )
        self.assertEqual(status.status_code, 200)
        self.assertEqual(status.get_json()["data"]["estado"], "inactivo")

    def test_required_unknown_and_invalid_fields_return_400(self):
        headers = self._headers()
        for payload in (
            {"fecha": "2026-09-13"},
            {**self._payload(), "campo": "no permitido"},
            {**self._payload(), "fecha": "13/09/2026"},
            {**self._payload(), "hora_inicio": "ocho"},
            {**self._payload(), "id_empleado": "1"},
        ):
            with self.subTest(payload=payload):
                response = self.client.post("/turnos", json=payload, headers=headers)
                self.assertEqual(response.status_code, 400)

    def test_missing_references_on_create_return_400(self):
        headers = self._headers()
        missing_employee = self.client.post(
            "/turnos",
            json=self._payload(id_empleado=9999),
            headers=headers,
        )
        missing_puesto = self.client.post(
            "/turnos",
            json=self._payload(id_puesto=9999),
            headers=headers,
        )
        self.assertEqual(missing_employee.status_code, 400)
        self.assertEqual(missing_puesto.status_code, 400)

    def test_missing_turno_returns_404(self):
        response = self.client.get("/turnos/9999", headers=self._headers())
        self.assertEqual(response.status_code, 404)

    def test_invalid_status_payload_returns_400_including_non_object_json(self):
        headers = self._headers()
        turno = Turno(
            fecha=date(2026, 9, 13),
            hora_inicio=time(8),
            hora_fin=time(16),
            estado="activo",
            id_empleado=self.empleado.id_empleado,
            id_puesto=self.puesto.id_puesto,
        )
        db.session.add(turno)
        db.session.commit()

        for payload in (["estado"], {"estado": "activo", "otro": True}):
            with self.subTest(payload=payload):
                response = self.client.patch(
                    f"/turnos/{turno.id_turno}/estado",
                    json=payload,
                    headers=headers,
                )
                self.assertEqual(response.status_code, 400)

    def test_supervisor_can_manage_guardia_can_read_only_and_unknown_is_forbidden(self):
        supervisor_headers = self._headers("SUPERVISOR")
        guardia_headers = self._headers("GUARDIA")
        unknown_headers = self._headers("Sin matriz definida")

        supervisor_create = self.client.post(
            "/turnos", json=self._payload(), headers=supervisor_headers
        )
        self.assertEqual(supervisor_create.status_code, 201)
        self.assertEqual(self.client.get("/turnos", headers=guardia_headers).status_code, 200)
        guardia_create = self.client.post(
            "/turnos", json=self._payload(), headers=guardia_headers
        )
        self.assertEqual(guardia_create.status_code, 403)
        self.assertEqual(self.client.get("/turnos", headers=unknown_headers).status_code, 403)


if __name__ == "__main__":
    unittest.main()
