import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum NativePermissionState { granted, denied, permanentlyDenied }

class LocationResult {
  const LocationResult(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

abstract interface class NativeCapabilities {
  Future<NativePermissionState> requestLocationPermission();
  Future<bool> isLocationServiceEnabled();
  Future<LocationResult> currentLocation();
  Future<NativePermissionState> requestCameraPermission();
  Future<String?> takePhoto();
  Future<bool> openSettings();
  Future<bool> openLocationSettings();
}

class DeviceNativeCapabilities implements NativeCapabilities {
  DeviceNativeCapabilities({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  NativePermissionState _state(permissions.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return NativePermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return NativePermissionState.permanentlyDenied;
    }
    return NativePermissionState.denied;
  }

  @override
  Future<NativePermissionState> requestLocationPermission() async =>
      _state(await permissions.Permission.locationWhenInUse.request());
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationResult> currentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationResult(position.latitude, position.longitude);
  }

  @override
  Future<NativePermissionState> requestCameraPermission() async =>
      _state(await permissions.Permission.camera.request());
  @override
  Future<String?> takePhoto() async => (await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 1920,
  ))?.path;
  @override
  Future<bool> openSettings() => permissions.openAppSettings();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
