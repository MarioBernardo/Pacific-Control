from flask import Flask

from app.extensions import db, migrate
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


def create_app():
    app = Flask(__name__)

    app.config.from_object("config.Config")

    db.init_app(app)
    migrate.init_app(app, db)

    app.register_blueprint(main_bp)
    app.register_blueprint(empleados_bp)

    return app
