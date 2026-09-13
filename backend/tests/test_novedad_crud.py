import unittest
from datetime import date, time
from unittest.mock import patch

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno

TEST_JWT_SECRET_KEY = "TEST_ONLY_JWT_SECRET_KEY_0123456789_abcdefghijklmnopqrstuvwxyz"


class NovedadCrudTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite://", "CACHE_ENABLED": False, "JWT_SECRET_KEY": TEST_JWT_SECRET_KEY})
        cls.context = cls.app.app_context()
        cls.context.push()
        db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        db.drop_all()
        cls.context.pop()

    def setUp(self):
        self.employee_sequence = 0
        db.session.query(Novedad).delete()
        db.session.query(Turno).delete()
        db.session.query(Puesto).delete()
        db.session.query(Empleado).delete()
        db.session.commit()
        self.client = self.app.test_client()
        self.employee = self._employee("ADMINISTRADOR", "admin")
        self.puesto = Puesto(nombre_puesto="Garita", direccion="Calle 1", estado="activo")
        db.session.add(self.puesto)
        db.session.commit()
        self.turno = Turno(fecha=date(2026, 9, 13), hora_inicio=time(8), hora_fin=time(16), estado="activo", id_empleado=self.employee.id_empleado, id_puesto=self.puesto.id_puesto)
        db.session.add(self.turno)
        db.session.commit()

    def _employee(self, cargo, name):
        self.employee_sequence += 1
        employee = Empleado(cedula=str(1000000000 + self.employee_sequence), nombres=name, apellidos="Prueba", correo=f"{name}{self.employee_sequence}@novedad.test", password_hash=generate_password_hash("clave"), telefono="0999999999", cargo=cargo, estado=True)
        db.session.add(employee)
        db.session.commit()
        return employee

    def _headers(self, cargo="ADMINISTRADOR"):
        employee = self.employee if cargo == "ADMINISTRADOR" else self._employee(cargo, cargo.lower())
        return {"Authorization": f"Bearer {create_access_token(identity=str(employee.id_empleado))}"}

    def _payload(self, **overrides):
        payload = {"tipo": "Incidencia", "descripcion": "Novedad de prueba", "fecha_hora": "2026-09-13T09:00:00", "estado": "abierta", "id_empleado": self.employee.id_empleado, "id_turno": self.turno.id_turno}
        payload.update(overrides)
        return payload

    @patch("app.tasks.process_novedad.delay")
    def test_admin_can_create_list_get_update_and_change_status(self, delay):
        headers = self._headers()
        created = self.client.post("/novedades", json=self._payload(), headers=headers)
        self.assertEqual(created.status_code, 201)
        delay.assert_called_once()
        record_id = created.get_json()["data"]["id_novedad"]
        self.assertEqual(self.client.get("/novedades", headers=headers).status_code, 200)
        self.assertEqual(self.client.get(f"/novedades/{record_id}", headers=headers).status_code, 200)
        updated = self.client.put(f"/novedades/{record_id}", json={"descripcion": "Actualizada"}, headers=headers)
        self.assertEqual(updated.status_code, 200)
        status = self.client.patch(f"/novedades/{record_id}/estado", json={"estado": "cerrada"}, headers=headers)
        self.assertEqual(status.status_code, 200)

    def test_invalid_payload_and_missing_references_return_400(self):
        headers = self._headers()
        invalid = self.client.post("/novedades", json={"tipo": ""}, headers=headers)
        missing = self.client.post("/novedades", json=self._payload(id_turno=9999), headers=headers)
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(missing.status_code, 400)

    @patch("app.tasks.process_novedad.delay")
    def test_guardia_reads_but_cannot_update_and_unknown_is_forbidden(self, delay):
        created = self.client.post("/novedades", json=self._payload(), headers=self._headers())
        record_id = created.get_json()["data"]["id_novedad"]
        self.assertEqual(self.client.get("/novedades", headers=self._headers("GUARDIA")).status_code, 200)
        self.assertEqual(self.client.put(f"/novedades/{record_id}", json={"descripcion": "x"}, headers=self._headers("GUARDIA")).status_code, 403)
        self.assertEqual(self.client.get("/novedades", headers=self._headers("Sin matriz definida")).status_code, 403)

    def test_missing_record_returns_404(self):
        self.assertEqual(self.client.get("/novedades/9999", headers=self._headers()).status_code, 404)


if __name__ == "__main__":
    unittest.main()
