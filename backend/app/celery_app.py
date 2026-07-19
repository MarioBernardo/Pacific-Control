from celery import Celery

from app import create_app


def make_celery(app):
    celery = Celery(
        app.import_name,
        broker=app.config["REDIS_URL"],
        backend=app.config["REDIS_URL"],
    )
    celery.conf.update(
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
    )

    class ContextTask(celery.Task):
        abstract = True

        def __call__(self, *args, **kwargs):
            with app.app_context():
                return super().__call__(*args, **kwargs)

    celery.Task = ContextTask
    return celery


app = create_app()
celery = make_celery(app)

# Import tasks to ensure they are registered with the Celery app.
import app.tasks  # noqa: F401
