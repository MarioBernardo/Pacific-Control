import unittest

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.puesto import Puesto


TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class DispositivoCrudTestCase(unittest.TestCase):
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
        db.session.query(Dispositivo).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()
        self.puesto = Puesto(
            nombre_puesto="Puesto de prueba",
            direccion="Av. Principal 100",
            estado="activo",
        )
        db.session.add(self.puesto)
        db.session.commit()

    def _employee(self, cargo: str) -> Empleado:
        empleado = Empleado(
            cedula=str(1000000000 + len(cargo)),
            nombres="Usuario",
            apellidos="Prueba",
            correo=f"{cargo.lower().replace(' ', '')}@dispositivo.test",
            password_hash=generate_password_hash("clave-segura"),
            telefono="0999999999",
            cargo=cargo,
            estado=True,
        )
        db.session.add(empleado)
        db.session.commit()
        return empleado

    def _headers(self, cargo: str = "ADMINISTRADOR") -> dict[str, str]:
        empleado = self._employee(cargo)
        token = create_access_token(identity=str(empleado.id_empleado))
        return {"Authorization": f"Bearer {token}"}

    def _payload(self, codigo: str = "DISP-001") -> dict:
        return {
            "codigo_dispositivo": codigo,
            "modelo": "Android",
            "estado": "activo",
            "id_puesto": self.puesto.id_puesto,
        }

    def test_admin_can_create_list_get_update_and_change_status(self):
        headers = self._headers()
        created = self.client.post(
            "/dispositivos", json=self._payload(), headers=headers
        )
        self.assertEqual(created.status_code, 201)
        dispositivo_id = created.get_json()["data"]["id_dispositivo"]
        self.assertEqual(created.get_json()["data"]["id_puesto"], self.puesto.id_puesto)

        listed = self.client.get("/dispositivos", headers=headers)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.get_json()["data"]), 1)

        fetched = self.client.get(f"/dispositivos/{dispositivo_id}", headers=headers)
        self.assertEqual(fetched.status_code, 200)

        updated = self.client.put(
            f"/dispositivos/{dispositivo_id}",
            json={"modelo": "Android actualizado"},
            headers=headers,
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.get_json()["data"]["modelo"], "Android actualizado")

        status = self.client.patch(
            f"/dispositivos/{dispositivo_id}/estado",
            json={"estado": "inactivo"},
            headers=headers,
        )
        self.assertEqual(status.status_code, 200)
        self.assertEqual(status.get_json()["data"]["estado"], "inactivo")

    def test_invalid_payload_and_unknown_puesto_return_400(self):
        headers = self._headers()
        invalid = self.client.post(
            "/dispositivos",
            json={"codigo_dispositivo": "DISP-001"},
            headers=headers,
        )
        self.assertEqual(invalid.status_code, 400)
        self.assertIn("detalles", invalid.get_json())

        unknown_puesto = self.client.post(
            "/dispositivos",
            json={**self._payload("DISP-002"), "id_puesto": 9999},
            headers=headers,
        )
        self.assertEqual(unknown_puesto.status_code, 400)

    def test_duplicate_code_returns_409(self):
        headers = self._headers()
        first = self.client.post(
            "/dispositivos", json=self._payload(), headers=headers
        )
        self.assertEqual(first.status_code, 201)
        duplicate = self.client.post(
            "/dispositivos", json=self._payload(), headers=headers
        )
        self.assertEqual(duplicate.status_code, 409)

    def test_missing_device_returns_404(self):
        response = self.client.get("/dispositivos/9999", headers=self._headers())
        self.assertEqual(response.status_code, 404)

    def test_guardia_can_read_but_cannot_mutate(self):
        headers = self._headers("GUARDIA")
        self.assertEqual(self.client.get("/dispositivos", headers=headers).status_code, 200)
        response = self.client.post(
            "/dispositivos", json=self._payload(), headers=headers
        )
        self.assertEqual(response.status_code, 403)

    def test_supervisor_can_manage_and_unknown_cargo_is_forbidden(self):
        supervisor_headers = self._headers("SUPERVISOR")
        created = self.client.post(
            "/dispositivos", json=self._payload(), headers=supervisor_headers
        )
        self.assertEqual(created.status_code, 201)

        unknown_headers = self._headers("Sin matriz definida")
        response = self.client.get("/dispositivos", headers=unknown_headers)
        self.assertEqual(response.status_code, 403)


if __name__ == "__main__":
    unittest.main()