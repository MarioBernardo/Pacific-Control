"""Add operational shift and assignment types.

Revision ID: a1b2c3d4e5f6
Revises: f11e05b3b0f5
"""
from alembic import op
import sqlalchemy as sa

revision = "a1b2c3d4e5f6"
down_revision = "f11e05b3b0f5"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("turnos") as batch_op:
        batch_op.add_column(sa.Column("tipo_turno", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("tipo_asignacion", sa.String(length=20), nullable=True))
    op.execute("UPDATE turnos SET tipo_turno = '24 HORAS', tipo_asignacion = 'FIJO'")
    with op.batch_alter_table("turnos") as batch_op:
        batch_op.alter_column("tipo_turno", nullable=False)
        batch_op.alter_column("tipo_asignacion", nullable=False)


def downgrade():
    with op.batch_alter_table("turnos") as batch_op:
        batch_op.drop_column("tipo_asignacion")
        batch_op.drop_column("tipo_turno")