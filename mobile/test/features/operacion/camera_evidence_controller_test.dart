import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/operacion/services/camera_evidence_controller.dart';
import 'package:mobile/features/operacion/services/native_capabilities.dart';

class _FakeNativeCapabilities implements NativeCapabilities {
  NativePermissionState cameraPermission = NativePermissionState.granted;
  String? photoPath = '/tmp/evidence.jpg';
  Object? cameraError;

  @override
  Future<NativePermissionState> requestCameraPermission() async =>
      cameraPermission;

  @override
  Future<String?> takePhoto() async {
    if (cameraError != null) throw cameraError!;
    return photoPath;
  }

  @override
  Future<NativePermissionState> requestLocationPermission() async =>
      NativePermissionState.granted;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationResult> currentLocation() async => const LocationResult(0, 0);
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  test('camara concedida devuelve la fotografia capturada', () async {
    final controller = CameraEvidenceController(
      native: _FakeNativeCapabilities(),
    );
    final outcome = await controller.capture();
    expect(outcome.status, CameraEvidenceStatus.captured);
    expect(outcome.path, '/tmp/evidence.jpg');
    expect(controller.loading, isFalse);
  });

  test('camara denegada permite degradar a novedad sin foto', () async {
    final native = _FakeNativeCapabilities()
      ..cameraPermission = NativePermissionState.denied;
    final outcome = await CameraEvidenceController(native: native).capture();
    expect(outcome.status, CameraEvidenceStatus.denied);
    expect(outcome.path, isNull);
  });

  test('camara permanentemente denegada se distingue de denegada', () async {
    final native = _FakeNativeCapabilities()
      ..cameraPermission = NativePermissionState.permanentlyDenied;
    final outcome = await CameraEvidenceController(native: native).capture();
    expect(outcome.status, CameraEvidenceStatus.permanentlyDenied);
  });

  test('cancelar image picker conserva el flujo sin foto', () async {
    final native = _FakeNativeCapabilities()..photoPath = null;
    final outcome = await CameraEvidenceController(native: native).capture();
    expect(outcome.status, CameraEvidenceStatus.cancelled);
  });

  test('error del plugin de camara se controla', () async {
    final native = _FakeNativeCapabilities()
      ..cameraError = StateError('camera unavailable');
    final controller = CameraEvidenceController(native: native);
    final outcome = await controller.capture();
    expect(outcome.status, CameraEvidenceStatus.error);
    expect(outcome.error, isA<StateError>());
    expect(controller.loading, isFalse);
  });
}
