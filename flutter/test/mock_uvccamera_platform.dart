import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uvccamera/uvccamera.dart';
import 'package:uvccamera/src/uvccamera_platform_interface.dart';

/// Mock platform for testing. Records method calls and returns configurable results.
class MockUvcCameraPlatform extends UvcCameraPlatformInterface with MockPlatformInterfaceMixin {
    // Configurable return values
    bool isSupportedResult = true;
    Map<String, UvcCameraDevice> getDevicesResult = {};
    bool requestDevicePermissionResult = true;
    int openCameraResult = 1;
    int getCameraTextureIdResult = 42;
    UvcCameraMode getPreviewModeResult = const UvcCameraMode(
        frameWidth: 1920, frameHeight: 1080, frameFormat: UvcCameraFrameFormat.mjpeg,
    );
    List<UvcCameraMode> getSupportedModesResult = [];
    XFile takePictureResult = XFile('/tmp/test.jpg');
    XFile stopVideoRecordingResult = XFile('/tmp/test.mp4');

    // Call tracking
    final List<String> calls = [];

    // Event stream controllers
    final StreamController<UvcCameraDeviceEvent> deviceEventStreamController =
        StreamController<UvcCameraDeviceEvent>.broadcast();
    final StreamController<UvcCameraErrorEvent> errorEventStreamController =
        StreamController<UvcCameraErrorEvent>.broadcast();
    final StreamController<UvcCameraStatusEvent> statusEventStreamController =
        StreamController<UvcCameraStatusEvent>.broadcast();
    final StreamController<UvcCameraButtonEvent> buttonEventStreamController =
        StreamController<UvcCameraButtonEvent>.broadcast();

    // Error simulation
    Object? throwOnCall;

    void reset() {
        calls.clear();
        throwOnCall = null;
    }

    void _track(String method) {
        calls.add(method);
        if (throwOnCall != null) {
            throw throwOnCall!;
        }
    }

    @override
    Future<bool> isSupported() async {
        _track('isSupported');
        return isSupportedResult;
    }

    @override
    Future<Map<String, UvcCameraDevice>> getDevices() async {
        _track('getDevices');
        return getDevicesResult;
    }

    @override
    Future<bool> requestDevicePermission(UvcCameraDevice device) async {
        _track('requestDevicePermission');
        return requestDevicePermissionResult;
    }

    @override
    Future<int> openCamera(UvcCameraDevice device, UvcCameraResolutionPreset resolutionPreset) async {
        _track('openCamera');
        return openCameraResult;
    }

    @override
    Future<void> closeCamera(int cameraId) async {
        _track('closeCamera');
    }

    @override
    Future<int> getCameraTextureId(int cameraId) async {
        _track('getCameraTextureId');
        return getCameraTextureIdResult;
    }

    @override
    Widget buildCameraPreview(int cameraId, int textureId) {
        _track('buildCameraPreview');
        return Texture(textureId: textureId);
    }

    @override
    Future<Stream<UvcCameraErrorEvent>> attachToCameraErrorCallback(int cameraId) async {
        _track('attachToCameraErrorCallback');
        return errorEventStreamController.stream;
    }

    @override
    Future<void> detachFromCameraErrorCallback(int cameraId) async {
        _track('detachFromCameraErrorCallback');
    }

    @override
    Future<Stream<UvcCameraStatusEvent>> attachToCameraStatusCallback(int cameraId) async {
        _track('attachToCameraStatusCallback');
        return statusEventStreamController.stream;
    }

    @override
    Future<void> detachFromCameraStatusCallback(int cameraId) async {
        _track('detachFromCameraStatusCallback');
    }

    @override
    Future<Stream<UvcCameraButtonEvent>> attachToCameraButtonCallback(int cameraId) async {
        _track('attachToCameraButtonCallback');
        return buttonEventStreamController.stream;
    }

    @override
    Future<void> detachFromCameraButtonCallback(int cameraId) async {
        _track('detachFromCameraButtonCallback');
    }

    @override
    Future<List<UvcCameraMode>> getSupportedModes(int cameraId) async {
        _track('getSupportedModes');
        return getSupportedModesResult;
    }

    @override
    Future<UvcCameraMode> getPreviewMode(int cameraId) async {
        _track('getPreviewMode');
        return getPreviewModeResult;
    }

    @override
    Future<void> setPreviewMode(int cameraId, UvcCameraMode previewMode) async {
        _track('setPreviewMode');
    }

    @override
    Future<XFile> takePicture(int cameraId) async {
        _track('takePicture');
        return takePictureResult;
    }

    @override
    Future<void> startVideoRecording(int cameraId, UvcCameraMode videoRecordingMode) async {
        _track('startVideoRecording');
    }

    @override
    Future<XFile> stopVideoRecording(int cameraId) async {
        _track('stopVideoRecording');
        return stopVideoRecordingResult;
    }

    @override
    Stream<UvcCameraDeviceEvent> get deviceEventStream => deviceEventStreamController.stream;
}
