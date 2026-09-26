import io
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch

from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import cache, db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno


class Prototipo15TestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.uploads = tempfile.TemporaryDirectory()
        cls.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "CACHE_ENABLED": False,
            "NOVEDAD_UPLOAD_FOLDER": cls.uploads.name,
        })
        cls.context = cls.app.app_context()
        cls.context.push()

    @classmethod
    def tearDownClass(cls):
        cls.context.pop()
        cls.uploads.cleanup()

    def setUp(self):
        db.session.remove()
        db.drop_all()
        db.create_all()
        self.client = self.app.test_client()
        puesto = Puesto(nombre_puesto="P15", direccion="Quito", estado="activo")
        otro_puesto = Puesto(nombre_puesto="OTRO", direccion="Quito", estado="activo")
        db.session.add_all([puesto, otro_puesto])
        db.session.flush()
        self.device = Dispositivo(
            codigo_dispositivo="P15-DEVICE",
            modelo="Terminal",
            estado="activo",
            id_puesto=puesto.id_puesto,
            usuario_operativo="p15",
            password_operativo_hash=generate_password_hash("P15-test-password"),
        )
        self.guard = Empleado(
            cedula="0900000015", nombres="Guardia", apellidos="P15",
            correo="p15@pacific.test", password_hash=generate_password_hash("x"),
            telefono="0990000015", cargo="GUARDIA", estado=True,
        )
        other_guard = Empleado(
            cedula="0900000016", nombres="Otro", apellidos="Puesto",
            correo="otro@pacific.test", password_hash=generate_password_hash("x"),
            telefono="0990000016", cargo="GUARDIA", estado=True,
        )
        db.session.add_all([self.device, self.guard, other_guard])
        db.session.flush()
        self.turno_12 = Turno(
            fecha=date.today(), hora_inicio=None, hora_fin=None, estado="activo",
            tipo_turno="12 HORAS", tipo_asignacion="FIJO",
            id_empleado=self.guard.id_empleado, id_puesto=puesto.id_puesto,
        )
        self.turno_24 = Turno(
            fecha=date.today(), hora_inicio=None, hora_fin=None, estado="activo",
            tipo_turno="24 HORAS", tipo_asignacion="FIJO",
            id_empleado=self.guard.id_empleado, id_puesto=puesto.id_puesto,
        )
        other_turno = Turno(
            fecha=date.today(), hora_inicio=None, hora_fin=None, estado="activo",
            tipo_turno="12 HORAS", tipo_asignacion="FIJO",
            id_empleado=other_guard.id_empleado, id_puesto=otro_puesto.id_puesto,
        )
        db.session.add_all([self.turno_12, self.turno_24, other_turno])
        db.session.commit()

        self.cache_data = {}
        self.cache_patches = (
            patch.object(cache, "set_json", side_effect=self._cache_set),
            patch.object(cache, "get_json", side_effect=self.cache_data.get),
            patch.object(cache, "delete", side_effect=self._cache_delete),
        )
        for cache_patch in self.cache_patches:
            cache_patch.start()
        login = self.client.post(
            "/operacion/login",
            json={"usuario": "p15", "password": "P15-test-password"},
        )
        self.headers = {
            "X-Device-Session": login.get_json()["data"]["session_token"]
        }

    def tearDown(self):
        for cache_patch in reversed(self.cache_patches):
            cache_patch.stop()

    def _cache_set(self, key, value, ttl=None):
        self.cache_data[key] = value
        return True

    def _cache_delete(self, *keys):
        for key in keys:
            self.cache_data.pop(key, None)
        return True

    def _identify(self, shift):
        return self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/sesion/identificar",
            headers=self.headers,
            json={"id_empleado": self.guard.id_empleado, "tipo_turno": shift},
        )

    def test_p15_01_guardias_validos_segun_puesto(self):
        response = self.client.get(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/guardias",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 200)
        guards = response.get_json()["data"]
        self.assertEqual([item["id_empleado"] for item in guards], [self.guard.id_empleado])

    def test_p15_02_seleccion_y_propagacion_turno_12_24(self):
        for shift, turno in (("12 HORAS", self.turno_12), ("24 HORAS", self.turno_24)):
            with self.subTest(shift=shift):
                response = self._identify(shift)
                selected = response.get_json()["data"]["guardia_identificado"]
                self.assertEqual(response.status_code, 200)
                self.assertEqual(selected["tipo_turno"], shift)
                self.assertEqual(selected["id_turno"], turno.id_turno)

    def test_p15_03_asistencia_ubicacion_payload_y_persistencia(self):
        self._identify("12 HORAS")
        operation_id = "30000000-0000-4000-8000-000000000003"
        response = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/asistencias",
            headers=self.headers,
            json={"operation_id": operation_id, "latitud": "-0.180653", "longitud": "-78.467834"},
        )
        stored = db.session.scalar(
            db.select(Asistencia).where(Asistencia.operation_id == operation_id)
        )
        self.assertEqual(response.status_code, 201, response.get_json())
        self.assertIsNotNone(stored)
        self.assertEqual(stored.id_turno, self.turno_12.id_turno)
        self.assertEqual(stored.id_dispositivo, self.device.id_dispositivo)

    @patch("app.tasks.process_novedad.delay")
    def test_p15_04_novedad_multipart_archivo_seguro_y_asociado(self, _delay):
        self._identify("24 HORAS")
        operation_id = "30000000-0000-4000-8000-000000000004"
        response = self.client.post(
            f"/operacion/dispositivos/{self.device.id_dispositivo}/novedades-con-foto",
            headers=self.headers,
            data={
                "operation_id": operation_id,
                "tipo": "CONTROL",
                "descripcion": "P15 evidencia",
                "fecha_hora": "2026-09-25T10:30:00",
                "foto": (io.BytesIO(b"\xff\xd8\xff\xe0p15"), "../../p15.jpg"),
            },
            content_type="multipart/form-data",
        )
        stored = db.session.scalar(
            db.select(Novedad).where(Novedad.operation_id == operation_id)
        )
        self.assertEqual(response.status_code, 201, response.get_json())
        self.assertEqual(stored.id_dispositivo, self.device.id_dispositivo)
        self.assertEqual(stored.id_turno, self.turno_24.id_turno)
        self.assertEqual(stored.fecha_hora.isoformat(), "2026-09-25T10:30:00")
        self.assertNotIn("..", stored.evidencia_foto)
        self.assertTrue((Path(self.uploads.name) / Path(stored.evidencia_foto).name).is_file())

    def test_p15_05_reintento_idempotente_crea_un_registro(self):
        self._identify("12 HORAS")
        operation_id = "30000000-0000-4000-8000-000000000005"
        payload = {"operation_id": operation_id, "latitud": "0", "longitud": "0"}
        path = f"/operacion/dispositivos/{self.device.id_dispositivo}/asistencias"
        first = self.client.post(path, headers=self.headers, json=payload)
        second = self.client.post(path, headers=self.headers, json=payload)
        count = db.session.scalar(
            db.select(db.func.count()).select_from(Asistencia).where(
                Asistencia.operation_id == operation_id
            )
        )
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 201)
        self.assertEqual(first.get_json()["data"]["id_asistencia"], second.get_json()["data"]["id_asistencia"])
        self.assertEqual(count, 1)


if __name__ == "__main__":
    unittest.main()
