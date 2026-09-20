import 'native_capabilities.dart';

enum CameraEvidenceStatus {
  captured,
  denied,
  permanentlyDenied,
  cancelled,
  error,
}

class CameraEvidenceOutcome {
  const CameraEvidenceOutcome(this.status, {this.path, this.error});

  final CameraEvidenceStatus status;
  final String? path;
  final Object? error;
}

class CameraEvidenceController {
  CameraEvidenceController({required this.native});

  final NativeCapabilities native;
  bool loading = false;

  Future<CameraEvidenceOutcome> capture() async {
    if (loading) {
      return const CameraEvidenceOutcome(CameraEvidenceStatus.error);
    }
    loading = true;
    try {
      final permission = await native.requestCameraPermission();
      if (permission == NativePermissionState.permanentlyDenied) {
        return const CameraEvidenceOutcome(
          CameraEvidenceStatus.permanentlyDenied,
        );
      }
      if (permission != NativePermissionState.granted) {
        return const CameraEvidenceOutcome(CameraEvidenceStatus.denied);
      }

      final path = await native.takePhoto();
      if (path == null) {
        return const CameraEvidenceOutcome(CameraEvidenceStatus.cancelled);
      }
      return CameraEvidenceOutcome(CameraEvidenceStatus.captured, path: path);
    } catch (error) {
      return CameraEvidenceOutcome(CameraEvidenceStatus.error, error: error);
    } finally {
      loading = false;
    }
  }
}
