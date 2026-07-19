from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

from app.cache import RedisCache

db = SQLAlchemy()
migrate = Migrate()
cache = RedisCache()
