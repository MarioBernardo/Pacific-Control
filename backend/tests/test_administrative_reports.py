import unittest
from datetime import date, datetime, time, timedelta

from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash

from app import create_app
from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.services.report_service import ReportService


JWT_SECRET = "TEST_ONLY_REPORT_SECRET_0123456789_abcdefghijklmnopqrstuvwxyz"


class AdministrativeReportsTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
            "CACHE_ENABLED": False,
            "JWT_SECRET_KEY": JWT_SECRET,
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
        for model in (Novedad, Asistencia, Turno, Dispositivo, Puesto, Empleado):
            db.session.query(model).delete()
        admin = Empleado(cedula="1000000001", nombres="Ana", apellidos="Admin", correo="admin@report.test", password_hash=generate_password_hash("secret"), telefono="0999999999", cargo="ADMINISTRADOR", estado=True)
        supervisor = Empleado(cedula="1000000002", nombres="Sonia", apellidos="Supervisor", correo="supervisor@report.test", password_hash=generate_password_hash("secret"), telefono="0999999998", cargo="SUPERVISOR", estado=True)
        guard = Empleado(cedula="1000000003", nombres="Diego", apellidos="Tipantuña", correo="guard@report.test", password_hash=generate_password_hash("secret"), telefono="0999999997", cargo="GUARDIA", estado=True)
        position = Puesto(nombre_puesto="ED. BAVIERA", direccion="Quito", estado="activo")
        db.session.add_all([admin, supervisor, guard, position])
        db.session.flush()
        device = Dispositivo(codigo_dispositivo="BAVIERA-01", estado="activo", id_puesto=position.id_puesto)
        db.session.add(device)
        db.session.flush()
        shift12 = Turno(fecha=date.today(), hora_inicio=time(7), hora_fin=time(19), estado="activo", tipo_turno="12 HORAS", tipo_asignacion="FIJO", id_empleado=guard.id_empleado, id_puesto=position.id_puesto)
        shift24 = Turno(fecha=date.today(), hora_inicio=time(7), hora_fin=time(7), estado="activo", tipo_turno="24 HORAS", tipo_asignacion="FIJO", id_empleado=guard.id_empleado, id_puesto=position.id_puesto)
        db.session.add_all([shift12, shift24])
        db.session.flush()
        self.admin, self.supervisor, self.guard = admin, supervisor, guard
        self.position, self.device = position, device
        self.shift12, self.shift24 = shift12, shift24
        db.session.commit()
        self.client = self.app.test_client()

    def _headers(self, employee):
        return {"Authorization": f"Bearer {create_access_token(identity=str(employee.id_empleado))}"}

    def _attendance(self, when, shift, state="registrada"):
        item = Asistencia(fecha_hora=when, latitud=-0.18, longitud=-78.48, observacion="Ingreso", estado=state, id_empleado=self.guard.id_empleado, id_turno=shift.id_turno, id_dispositivo=self.device.id_dispositivo)
        db.session.add(item)
        db.session.commit()
        return item

    def test_attendance_list_and_detail_are_enriched(self):
        item = self._attendance(datetime.now(), self.shift12)
        response = self.client.get("/asistencias", headers=self._headers(self.supervisor))
        data = response.get_json()["data"][0]
        self.assertEqual(data["guardia"]["nombre_completo"], "Tipantuña Diego")
        self.assertEqual(data["puesto"]["nombre_puesto"], "ED. BAVIERA")
        self.assertEqual(data["turno"]["tipo_turno"], "12 HORAS")
        detail = self.client.get(f"/asistencias/{item.id_asistencia}", headers=self._headers(self.admin)).get_json()["data"]
        self.assertEqual(detail["dispositivo"]["codigo_dispositivo"], "BAVIERA-01")

    def test_personnel_on_shift_handles_12_24_and_expired_latest(self):
        now = datetime(2026, 9, 20, 12)
        self._attendance(now - timedelta(hours=2), self.shift12)
        active = ReportService().personnel_on_shift(now)
        self.assertEqual(len(active), 1)
        self.assertEqual(active[0]["tipo_turno"], "12 HORAS")
        db.session.query(Asistencia).delete()
        db.session.commit()
        self._attendance(now - timedelta(hours=20), self.shift24)
        self.assertEqual(len(ReportService().personnel_on_shift(now)), 1)
        self._attendance(now - timedelta(hours=13), self.shift12)
        self.assertEqual(ReportService().personnel_on_shift(now), [])

    def test_monthly_summary_counts_valid_attendances_without_duplicates(self):
        now = datetime.now()
        self._attendance(datetime(now.year, now.month, 5, 7), self.shift12)
        self._attendance(datetime(now.year, now.month, 6, 7), self.shift24)
        self._attendance(datetime(now.year, now.month, 7, 7), self.shift12, "anulada")
        summary = ReportService().monthly_summary(self.guard.id_empleado, now.month, now.year)
        self.assertEqual(summary["total_turnos"], 2)
        self.assertEqual(summary["turnos_12_horas"], 1)
        self.assertEqual(summary["turnos_24_horas"], 1)
        self.assertEqual(summary["horas_derivadas"], 36)
        self.assertEqual(summary["puestos"], ["ED. BAVIERA"])

    def test_reports_require_admin_or_supervisor(self):
        self.assertEqual(self.client.get("/reportes/dashboard").status_code, 401)
        self.assertEqual(self.client.get("/reportes/dashboard", headers=self._headers(self.guard)).status_code, 403)
        self.assertEqual(self.client.get("/reportes/dashboard", headers=self._headers(self.supervisor)).status_code, 200)


if __name__ == "__main__":
    unittest.main()
