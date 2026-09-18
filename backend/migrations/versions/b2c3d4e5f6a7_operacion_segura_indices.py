"""Credencial operativa e índices de consultas frecuentes.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
"""
from alembic import op
import sqlalchemy as sa

revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None

def upgrade():
    with op.batch_alter_table("dispositivos") as batch:
        batch.add_column(sa.Column("token_operativo_hash", sa.String(255), nullable=True))
        batch.create_index("ix_dispositivos_puesto_estado", ["id_puesto", "estado"])
    with op.batch_alter_table("turnos") as batch:
        batch.create_index("ix_turnos_operacion", ["id_puesto", "fecha", "estado"])
        batch.create_index("ix_turnos_empleado", ["id_empleado"])
    with op.batch_alter_table("asistencias") as batch:
        batch.create_index("ix_asistencias_empleado_fecha", ["id_empleado", "fecha_hora"])
    with op.batch_alter_table("novedades") as batch:
        batch.create_index("ix_novedades_estado_fecha", ["estado", "fecha_hora"])

def downgrade():
    with op.batch_alter_table("novedades") as batch: batch.drop_index("ix_novedades_estado_fecha")
    with op.batch_alter_table("asistencias") as batch: batch.drop_index("ix_asistencias_empleado_fecha")
    with op.batch_alter_table("turnos") as batch:
        batch.drop_index("ix_turnos_empleado"); batch.drop_index("ix_turnos_operacion")
    with op.batch_alter_table("dispositivos") as batch:
        batch.drop_index("ix_dispositivos_puesto_estado"); batch.drop_column("token_operativo_hash")
