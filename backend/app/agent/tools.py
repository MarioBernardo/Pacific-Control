from datetime import datetime

from app.services.report_service import ReportService


class OperationalAgentTools:
    """Allowlisted read-only tools. No model-generated SQL is accepted."""

    def __init__(self, reports: ReportService | None = None):
        self.reports = reports or ReportService()

    def dashboard(self) -> dict:
        return self.reports.dashboard()

    def personnel_on_shift(self) -> list[dict]:
        return self.reports.personnel_on_shift()

    def recent_incidents(self) -> list[dict]:
        return self.reports.recent_incidents()

    def attendances_today(self) -> list[dict]:
        return self.reports.attendances_today()

    def guard_summary(self, employee_id: int, month: int | None = None,
                      year: int | None = None) -> dict:
        now = datetime.now()
        return self.reports.monthly_summary(
            employee_id, month or now.month, year or now.year
        )
