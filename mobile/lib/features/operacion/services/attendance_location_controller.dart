import 'dart:async';

import 'native_capabilities.dart';

enum AttendanceLocationStatus {
  success,
  denied,
  permanentlyDenied,
  gpsDisabled,
  timeout,
  error,
}

class AttendanceLocationOutcome {
  const AttendanceLocationOutcome(this.status, {this.error});

  final AttendanceLocationStatus status;
  final Object? error;
}

class AttendanceLocationController {
  AttendanceLocationController({
    required this.native,
    this.positionTimeout = const Duration(seconds: 15),
    this.operationTimeout = const Duration(seconds: 30),
  });

  final NativeCapabilities native;
  final Duration positionTimeout;
  final Duration operationTimeout;

  bool loading = false;

  Future<AttendanceLocationOutcome> submit(
    Future<void> Function(LocationResult location) registerAttendance,
  ) async {
    if (loading) {
      return const AttendanceLocationOutcome(AttendanceLocationStatus.error);
    }

    loading = true;
    try {
      final gpsEnabled = await native.isLocationServiceEnabled().timeout(
        operationTimeout,
      );
      if (!gpsEnabled) {
        return const AttendanceLocationOutcome(
          AttendanceLocationStatus.gpsDisabled,
        );
      }

      final permission = await native.requestLocationPermission().timeout(
        operationTimeout,
      );
      if (permission == NativePermissionState.permanentlyDenied) {
        return const AttendanceLocationOutcome(
          AttendanceLocationStatus.permanentlyDenied,
        );
      }
      if (permission != NativePermissionState.granted) {
        return const AttendanceLocationOutcome(AttendanceLocationStatus.denied);
      }

      final location = await native.currentLocation().timeout(positionTimeout);
      await registerAttendance(location).timeout(operationTimeout);
      return const AttendanceLocationOutcome(AttendanceLocationStatus.success);
    } on TimeoutException catch (error) {
      return AttendanceLocationOutcome(
        AttendanceLocationStatus.timeout,
        error: error,
      );
    } catch (error) {
      return AttendanceLocationOutcome(
        AttendanceLocationStatus.error,
        error: error,
      );
    } finally {
      loading = false;
    }
  }
}
