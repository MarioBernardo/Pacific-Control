"""idempotencia operativa y turnos sin hora obligatoria

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
"""
from alembic import op
import sqlalchemy as sa


revision = "d4e5f6a7b8c9"
down_revision = "c3d4e5f6a7b8"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("asistencias") as batch:
        batch.add_column(sa.Column("operation_id", sa.String(36), nullable=True))
        batch.create_unique_constraint(
            "uq_asistencias_operation_id", ["operation_id"]
        )
    with op.batch_alter_table("novedades") as batch:
        batch.add_column(sa.Column("operation_id", sa.String(36), nullable=True))
        batch.create_unique_constraint("uq_novedades_operation_id", ["operation_id"])
    with op.batch_alter_table("turnos") as batch:
        batch.alter_column("hora_inicio", existing_type=sa.Time(), nullable=True)
        batch.alter_column("hora_fin", existing_type=sa.Time(), nullable=True)


def downgrade():
    with op.batch_alter_table("turnos") as batch:
        batch.alter_column("hora_fin", existing_type=sa.Time(), nullable=False)
        batch.alter_column("hora_inicio", existing_type=sa.Time(), nullable=False)
    with op.batch_alter_table("novedades") as batch:
        batch.drop_constraint("uq_novedades_operation_id", type_="unique")
        batch.drop_column("operation_id")
    with op.batch_alter_table("asistencias") as batch:
        batch.drop_constraint("uq_asistencias_operation_id", type_="unique")
        batch.drop_column("operation_id")
