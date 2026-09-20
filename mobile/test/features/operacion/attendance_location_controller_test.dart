import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/operacion/services/attendance_location_controller.dart';
import 'package:mobile/features/operacion/services/native_capabilities.dart';

class _FakeNativeCapabilities implements NativeCapabilities {
  NativePermissionState permission = NativePermissionState.granted;
  bool gpsEnabled = true;
  LocationResult location = const LocationResult(-0.1807, -78.4678);
  Object? locationError;
  bool locationNeverCompletes = false;
  int locationPermissionRequests = 0;

  @override
  Future<NativePermissionState> requestLocationPermission() async {
    locationPermissionRequests++;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => gpsEnabled;

  @override
  Future<LocationResult> currentLocation() {
    if (locationNeverCompletes) return Completer<LocationResult>().future;
    if (locationError != null) return Future.error(locationError!);
    return Future.value(location);
  }

  @override
  Future<NativePermissionState> requestCameraPermission() async =>
      NativePermissionState.granted;

  @override
  Future<String?> takePhoto() async => null;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  AttendanceLocationController controller(_FakeNativeCapabilities native) =>
      AttendanceLocationController(
        native: native,
        positionTimeout: const Duration(milliseconds: 20),
        operationTimeout: const Duration(milliseconds: 50),
      );

  test('A: registra solamente cuando obtiene ubicación real', () async {
    final native = _FakeNativeCapabilities();
    final subject = controller(native);
    LocationResult? registered;

    final outcome = await subject.submit((location) async {
      registered = location;
    });

    expect(outcome.status, AttendanceLocationStatus.success);
    expect(registered?.latitude, -0.1807);
    expect(registered?.longitude, -78.4678);
    expect(subject.loading, isFalse);
  });

  test('B: permiso denegado restaura loading y no registra', () async {
    final native = _FakeNativeCapabilities()
      ..permission = NativePermissionState.denied;
    final subject = controller(native);
    var registrations = 0;

    final first = await subject.submit((_) async => registrations++);
    final retry = await subject.submit((_) async => registrations++);

    expect(first.status, AttendanceLocationStatus.denied);
    expect(retry.status, AttendanceLocationStatus.denied);
    expect(registrations, 0);
    expect(subject.loading, isFalse);
  });

  test('C: permiso permanente restaura loading y no registra', () async {
    final native = _FakeNativeCapabilities()
      ..permission = NativePermissionState.permanentlyDenied;
    final subject = controller(native);
    var registrations = 0;

    final outcome = await subject.submit((_) async => registrations++);

    expect(outcome.status, AttendanceLocationStatus.permanentlyDenied);
    expect(registrations, 0);
    expect(subject.loading, isFalse);
  });

  test('D: GPS desactivado restaura loading y no registra', () async {
    final native = _FakeNativeCapabilities()..gpsEnabled = false;
    final subject = controller(native);
    var registrations = 0;

    final outcome = await subject.submit((_) async => registrations++);

    expect(outcome.status, AttendanceLocationStatus.gpsDisabled);
    expect(registrations, 0);
    expect(native.locationPermissionRequests, 0);
    expect(subject.loading, isFalse);
  });

  test(
    'E: timeout de posición restaura loading y permite reintentar',
    () async {
      final native = _FakeNativeCapabilities()..locationNeverCompletes = true;
      final subject = controller(native);
      var registrations = 0;

      final timeout = await subject.submit((_) async => registrations++);
      native.locationNeverCompletes = false;
      final retry = await subject.submit((_) async => registrations++);

      expect(timeout.status, AttendanceLocationStatus.timeout);
      expect(retry.status, AttendanceLocationStatus.success);
      expect(registrations, 1);
      expect(subject.loading, isFalse);
    },
  );

  test('F: excepción del plugin restaura loading y no registra', () async {
    final native = _FakeNativeCapabilities()
      ..locationError = StateError('plugin unavailable');
    final subject = controller(native);
    var registrations = 0;

    final outcome = await subject.submit((_) async => registrations++);

    expect(outcome.status, AttendanceLocationStatus.error);
    expect(registrations, 0);
    expect(subject.loading, isFalse);
  });
}
