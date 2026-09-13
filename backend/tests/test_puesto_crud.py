import unittest

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.empleado import Empleado
from app.models.puesto import Puesto


TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class PuestoCrudTestCase(unittest.TestCase):
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
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()

    def _employee(self, cargo: str) -> Empleado:
        empleado = Empleado(
            cedula=str(1000000000 + len(cargo)),
            nombres="Usuario",
            apellidos="Prueba",
            correo=f"{cargo.lower()}@puesto.test",
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

    def test_admin_can_create_list_update_and_change_status(self):
        headers = self._headers()
        created = self.client.post(
            "/puestos",
            json={
                "nombre_puesto": "Garita Norte",
                "direccion": "Av. Principal 100",
                "estado": "activo",
            },
            headers=headers,
        )
        self.assertEqual(created.status_code, 201)
        puesto_id = created.get_json()["data"]["id_puesto"]

        listed = self.client.get("/puestos", headers=headers)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(listed.get_json()["data"][0]["nombre_puesto"], "Garita Norte")

        updated = self.client.put(
            f"/puestos/{puesto_id}",
            json={"nombre_puesto": "Garita Sur"},
            headers=headers,
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.get_json()["data"]["nombre_puesto"], "Garita Sur")

        status = self.client.patch(
            f"/puestos/{puesto_id}/estado",
            json={"estado": "inactivo"},
            headers=headers,
        )
        self.assertEqual(status.status_code, 200)
        self.assertEqual(status.get_json()["data"]["estado"], "inactivo")

    def test_invalid_payload_returns_400(self):
        response = self.client.post(
            "/puestos",
            json={"nombre_puesto": " incompleto "},
            headers=self._headers(),
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("detalles", response.get_json())

    def test_missing_puesto_returns_404(self):
        response = self.client.get("/puestos/9999", headers=self._headers())
        self.assertEqual(response.status_code, 404)

    def test_guardia_can_read_but_cannot_mutate(self):
        puesto = Puesto(nombre_puesto="Garita", direccion="Calle 1", estado="activo")
        db.session.add(puesto)
        db.session.commit()
        headers = self._headers("GUARDIA")
        self.assertEqual(self.client.get("/puestos", headers=headers).status_code, 200)
        response = self.client.post(
            "/puestos",
            json={"nombre_puesto": "Otra", "direccion": "Calle 2", "estado": "activo"},
            headers=headers,
        )
        self.assertEqual(response.status_code, 403)

    def test_unknown_cargo_cannot_read_or_mutate(self):
        headers = self._headers("Sin matriz definida")
        response = self.client.get("/puestos", headers=headers)
        self.assertEqual(response.status_code, 403)


if __name__ == "__main__":
    unittest.main()