import io
import tempfile
import unittest
from datetime import date, time
from unittest.mock import patch

from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import cache, db
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno


class Semana14OperacionTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.uploads = tempfile.TemporaryDirectory()
        cls.app = create_app({
            "TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite://", "CACHE_ENABLED": False,
            "NOVEDAD_UPLOAD_FOLDER": cls.uploads.name, "DEVICE_LINK_TTL": 2592000,
        })
        cls.context = cls.app.app_context(); cls.context.push(); db.create_all()

    @classmethod
    def tearDownClass(cls):
        db.session.remove(); db.drop_all(); cls.context.pop(); cls.uploads.cleanup()

    def setUp(self):
        db.drop_all(); db.create_all(); self.client = self.app.test_client()
        puesto = Puesto(nombre_puesto="ED. BAVIERA", direccion="Baviera", estado="activo")
        db.session.add(puesto); db.session.flush()
        self.device = Dispositivo(codigo_dispositivo="BAVIERA-01", modelo="Terminal", estado="activo", id_puesto=puesto.id_puesto, usuario_operativo="baviera", password_operativo_hash=generate_password_hash("BavieraOperativa2026!"))
        guard = Empleado(cedula="0999999999", nombres="DIEGO MARCELO", apellidos="TIPANTUÑA TACO", correo="d@test.local", password_hash=generate_password_hash("x"), telefono="0999999999", cargo="GUARDIA", estado=True)
        db.session.add_all([self.device, guard]); db.session.flush()
        self.turno = Turno(fecha=date.today(), hora_inicio=time(0), hora_fin=time(0), estado="activo", tipo_turno="12 HORAS", tipo_asignacion="FIJO", id_empleado=guard.id_empleado, id_puesto=puesto.id_puesto)
        db.session.add(self.turno); db.session.commit()
        self.store = {}
        self.cache_patches = (
            patch.object(cache, "set_json", side_effect=lambda key, value, ttl=None: not self.store.update({key: value})),
            patch.object(cache, "get_json", side_effect=lambda key: self.store.get(key)),
            patch.object(cache, "delete", side_effect=lambda *keys: any(self.store.pop(key, None) is not None for key in keys)),
        )
        for item in self.cache_patches: item.start()

    def tearDown(self):
        for item in reversed(self.cache_patches): item.stop()

    def _login(self, password="BavieraOperativa2026!"):
        return self.client.post("/operacion/login", json={"usuario": "baviera", "password": password})

    def _headers(self):
        token = self._login().get_json()["data"]["session_token"]
        return {"X-Device-Session": token}

    def _identify(self, headers):
        return self.client.post(f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar", headers=headers, json={"id_empleado": self.turno.id_empleado, "tipo_turno": "12 HORAS"})

    def test_login_correcto_incorrecto_y_sesion_restaurable(self):
        self.assertEqual(self._login("incorrecta").status_code, 401)
        response = self._login(); self.assertEqual(response.status_code, 200)
        data = response.get_json()["data"]
        self.assertEqual(data["dispositivo"]["codigo_dispositivo"], "BAVIERA-01")
        restored = self.client.get(f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion", headers={"X-Device-Session": data["session_token"]})
        self.assertEqual(restored.status_code, 200)

    def test_logout_invalida_vinculo(self):
        response = self._login(); token = response.get_json()["data"]["session_token"]
        headers = {"X-Device-Session": token}
        self.assertEqual(self.client.post(f"/operacion/dispositivos/{self.device.id_dispositivo}/logout", headers=headers).status_code, 200)
        self.assertEqual(self.client.get(f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion", headers=headers).status_code, 401)

    def test_coordenadas_invalidas_devuelven_400(self):
        headers = self._headers(); self._identify(headers)
        for latitude, longitude in ((91, 0), (-91, 0), (0, 181), (0, -181), ("x", 0)):
            response = self.client.post(f"/operacion/dispositivos/{self.device.id_dispositivo}/asistencias", headers=headers, json={"operation_id": "20000000-0000-4000-8000-000000000001", "latitud": latitude, "longitud": longitude})
            self.assertEqual(response.status_code, 400)

    @patch("app.tasks.process_novedad.delay")
    def test_novedad_sin_foto_y_jpeg_seguro(self, _delay):
        headers = self._headers(); self._identify(headers)
        path = f"/operacion/dispositivos/{self.device.id_dispositivo}/novedades-con-foto"
        plain = self.client.post(path, headers=headers, data={"operation_id": "20000000-0000-4000-8000-000000000002", "tipo": "CONTROL", "descripcion": "Sin foto"})
        self.assertEqual(plain.status_code, 201)
        jpeg = b"\xff\xd8\xff\xe0" + b"test-image"
        photo = self.client.post(path, headers=headers, data={"operation_id": "20000000-0000-4000-8000-000000000003", "tipo": "CONTROL", "descripcion": "Con foto", "foto": (io.BytesIO(jpeg), "../../malicioso.jpg")}, content_type="multipart/form-data")
        self.assertEqual(photo.status_code, 201, photo.get_json())
        reference = photo.get_json()["data"]["evidencia_foto"]
        self.assertTrue(reference.startswith("uploads/novedades/")); self.assertNotIn("..", reference)

    def test_archivo_invalido_es_rechazado(self):
        headers = self._headers(); self._identify(headers)
        response = self.client.post(f"/operacion/dispositivos/{self.device.id_dispositivo}/novedades-con-foto", headers=headers, data={"operation_id": "20000000-0000-4000-8000-000000000004", "tipo": "CONTROL", "descripcion": "Archivo", "foto": (io.BytesIO(b"not-an-image"), "x.exe")}, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)


if __name__ == "__main__": unittest.main()
