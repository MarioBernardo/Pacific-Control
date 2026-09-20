import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../models/administrative_reports.dart';
import '../services/administrative_report_service.dart';

final administrativeReportServiceProvider = Provider(
  (ref) =>
      AdministrativeReportService(ref.read(authenticatedApiClientProvider)),
);

final administrativeDashboardProvider = FutureProvider<AdministrativeDashboard>(
  (ref) => ref.read(administrativeReportServiceProvider).dashboard(),
);

final personnelOnShiftProvider = FutureProvider<List<PersonnelOnShift>>(
  (ref) => ref.read(administrativeReportServiceProvider).personnelOnShift(),
);

final guardMonthlySummaryProvider =
    FutureProvider.family<
      GuardMonthlySummary,
      ({int employeeId, int month, int year})
    >(
      (ref, query) => ref
          .read(administrativeReportServiceProvider)
          .monthlySummary(query.employeeId, query.month, query.year),
    );
