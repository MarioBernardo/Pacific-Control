"""semana 14 login operativo y evidencia

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
"""
from alembic import op
import sqlalchemy as sa

revision = "c3d4e5f6a7b8"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("dispositivos") as batch:
        batch.add_column(sa.Column("usuario_operativo", sa.String(50), nullable=True))
        batch.add_column(sa.Column("password_operativo_hash", sa.String(255), nullable=True))
        batch.create_unique_constraint("uq_dispositivos_usuario_operativo", ["usuario_operativo"])
    with op.batch_alter_table("novedades") as batch:
        batch.add_column(sa.Column("evidencia_foto", sa.String(255), nullable=True))
        batch.add_column(sa.Column("id_dispositivo", sa.Integer(), nullable=True))
        batch.create_foreign_key("fk_novedades_dispositivo", "dispositivos", ["id_dispositivo"], ["id_dispositivo"])


def downgrade():
    with op.batch_alter_table("novedades") as batch:
        batch.drop_constraint("fk_novedades_dispositivo", type_="foreignkey")
        batch.drop_column("id_dispositivo")
        batch.drop_column("evidencia_foto")
    with op.batch_alter_table("dispositivos") as batch:
        batch.drop_constraint("uq_dispositivos_usuario_operativo", type_="unique")
        batch.drop_column("password_operativo_hash")
        batch.drop_column("usuario_operativo")
