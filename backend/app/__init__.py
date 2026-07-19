from flask import Flask

from app.extensions import cache, db, jwt, migrate
from app.models import (
    Empleado,
    Puesto,
    Dispositivo,
    Turno,
    Asistencia,
    Novedad,
)
from app.routes.main_routes import main_bp
from app.routes.empleado_routes import empleados_bp
from app.routes.puesto_routes import puestos_bp
from app.routes.dispositivo_routes import dispositivos_bp
from app.routes.turno_routes import turnos_bp
from app.routes.asistencia_routes import asistencias_bp
from app.routes.novedad_routes import novedades_bp


def create_app():
    app = Flask(__name__)

    app.config.from_object("config.Config")

    db.init_app(app)
    migrate.init_app(app, db)
    cache.init_app(app)
    jwt.init_app(app)

    app.register_blueprint(main_bp)
    app.register_blueprint(empleados_bp)
    app.register_blueprint(puestos_bp)
    app.register_blueprint(dispositivos_bp)
    app.register_blueprint(turnos_bp)
    app.register_blueprint(asistencias_bp)
    app.register_blueprint(novedades_bp)

    return app
