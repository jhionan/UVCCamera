import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';
import 'package:uvccamera/src/uvccamera_platform_interface.dart';

import 'mock_uvccamera_platform.dart';

void main() {
    late MockUvcCameraPlatform mockPlatform;
    late UvcCameraController controller;

    const device = UvcCameraDevice(
        name: 'cam', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
    );
    const mode = UvcCameraMode(
        frameWidth: 1920, frameHeight: 1080, frameFormat: UvcCameraFrameFormat.mjpeg,
    );

    setUp(() {
        mockPlatform = MockUvcCameraPlatform();
        UvcCameraPlatformInterface.instance = mockPlatform;
        controller = UvcCameraController(device: device);
    });

    tearDown(() async {
        try {
            await controller.dispose();
        } catch (_) {}
    });

    group('constructor', () {
        test('sets device', () {
            expect(controller.device, device);
        });

        test('default resolution preset is max', () {
            expect(controller.resolutionPreset, UvcCameraResolutionPreset.max);
        });

        test('custom resolution preset', () {
            final c = UvcCameraController(
                device: device, resolutionPreset: UvcCameraResolutionPreset.low,
            );
            expect(c.resolutionPreset, UvcCameraResolutionPreset.low);
        });

        test('initial state is uninitialized', () {
            expect(controller.value.isInitialized, false);
            expect(controller.value.device, device);
        });
    });

    group('initialize', () {
        test('calls platform methods in order', () async {
            await controller.initialize();
            expect(mockPlatform.calls, [
                'openCamera',
                'getCameraTextureId',
                'getPreviewMode',
                'attachToCameraErrorCallback',
                'attachToCameraStatusCallback',
                'attachToCameraButtonCallback',
            ]);
        });

        test('sets state to initialized', () async {
            await controller.initialize();
            expect(controller.value.isInitialized, true);
        });

        test('sets previewMode from platform', () async {
            await controller.initialize();
            expect(controller.value.previewMode, mockPlatform.getPreviewModeResult);
        });

        test('throws InitializedException when called twice', () async {
            await controller.initialize();
            expect(
                () => controller.initialize(),
                throwsA(isA<UvcCameraControllerInitializedException>()),
            );
        });

        test('throws DisposedException when disposed', () async {
            await controller.dispose();
            expect(
                () => controller.initialize(),
                throwsA(isA<UvcCameraControllerDisposedException>()),
            );
        });
    });

    group('dispose', () {
        test('detaches all callbacks and closes camera', () async {
            await controller.initialize();
            mockPlatform.reset();
            await controller.dispose();
            expect(mockPlatform.calls, contains('detachFromCameraButtonCallback'));
            expect(mockPlatform.calls, contains('detachFromCameraStatusCallback'));
            expect(mockPlatform.calls, contains('detachFromCameraErrorCallback'));
            expect(mockPlatform.calls, contains('closeCamera'));
        });

        test('double dispose is no-op', () async {
            await controller.initialize();
            await controller.dispose();
            // Second dispose should not throw
            await controller.dispose();
        });

        test('dispose before initialize is no-op', () async {
            await controller.dispose();
            // Should not throw, and should not call closeCamera
            expect(mockPlatform.calls, isEmpty);
        });
    });

    group('cameraId', () {
        test('returns id after initialize', () async {
            await controller.initialize();
            expect(controller.cameraId, mockPlatform.openCameraResult);
        });

        test('throws NotInitializedException before initialize', () {
            expect(
                () => controller.cameraId,
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });

        test('throws DisposedException after dispose', () async {
            await controller.initialize();
            await controller.dispose();
            expect(
                () => controller.cameraId,
                throwsA(isA<UvcCameraControllerDisposedException>()),
            );
        });
    });

    group('textureId', () {
        test('returns texture id after initialize', () async {
            await controller.initialize();
            expect(controller.textureId, mockPlatform.getCameraTextureIdResult);
        });

        test('throws NotInitializedException before initialize', () {
            expect(
                () => controller.textureId,
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });
    });

    group('event streams', () {
        test('cameraErrorEvents returns stream after init', () async {
            await controller.initialize();
            expect(controller.cameraErrorEvents, isA<Stream<UvcCameraErrorEvent>>());
        });

        test('cameraStatusEvents returns stream after init', () async {
            await controller.initialize();
            expect(controller.cameraStatusEvents, isA<Stream<UvcCameraStatusEvent>>());
        });

        test('cameraButtonEvents returns stream after init', () async {
            await controller.initialize();
            expect(controller.cameraButtonEvents, isA<Stream<UvcCameraButtonEvent>>());
        });

        test('cameraErrorEvents throws when not initialized', () {
            expect(
                () => controller.cameraErrorEvents,
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });

        test('cameraStatusEvents throws when not initialized', () {
            expect(
                () => controller.cameraStatusEvents,
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });

        test('cameraButtonEvents throws when not initialized', () {
            expect(
                () => controller.cameraButtonEvents,
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });
    });

    group('takePicture', () {
        test('returns XFile from platform', () async {
            await controller.initialize();
            final file = await controller.takePicture();
            expect(file.path, mockPlatform.takePictureResult.path);
            expect(mockPlatform.calls, contains('takePicture'));
        });

        test('sets isTakingPicture during capture', () async {
            await controller.initialize();
            // After takePicture completes, isTakingPicture should be false
            await controller.takePicture();
            expect(controller.value.isTakingPicture, false);
        });

        test('throws when not initialized', () {
            expect(
                () => controller.takePicture(),
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });

        test('throws when already taking picture', () async {
            await controller.initialize();
            // We need to simulate concurrent calls. This is tricky without
            // controlling the mock timing, so we test the state check directly.
            // Manually set isTakingPicture via a start call that doesn't complete
            // We can test by setting state directly since it's a ValueNotifier.
            controller.value = controller.value.copyWith(isTakingPicture: true);
            expect(
                () => controller.takePicture(),
                throwsA(isA<UvcCameraControllerIllegalStateException>()),
            );
        });
    });

    group('startVideoRecording', () {
        test('calls platform and updates state', () async {
            await controller.initialize();
            await controller.startVideoRecording(mode);
            expect(controller.value.isRecordingVideo, true);
            expect(controller.value.videoRecordingMode, mode);
            expect(mockPlatform.calls, contains('startVideoRecording'));
        });

        test('throws when not initialized', () {
            expect(
                () => controller.startVideoRecording(mode),
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });

        test('throws when already recording', () async {
            await controller.initialize();
            await controller.startVideoRecording(mode);
            expect(
                () => controller.startVideoRecording(mode),
                throwsA(isA<UvcCameraControllerIllegalStateException>()),
            );
        });
    });

    group('stopVideoRecording', () {
        test('returns XFile and resets state', () async {
            await controller.initialize();
            await controller.startVideoRecording(mode);
            mockPlatform.reset();
            final file = await controller.stopVideoRecording();
            expect(file.path, mockPlatform.stopVideoRecordingResult.path);
            expect(controller.value.isRecordingVideo, false);
            expect(controller.value.videoRecordingMode, isNull);
            expect(mockPlatform.calls, contains('stopVideoRecording'));
        });

        test('throws when not recording', () async {
            await controller.initialize();
            expect(
                () => controller.stopVideoRecording(),
                throwsA(isA<UvcCameraControllerIllegalStateException>()),
            );
        });

        test('throws when not initialized', () {
            expect(
                () => controller.stopVideoRecording(),
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });
    });

    group('buildPreview', () {
        test('delegates to platform.buildCameraPreview', () async {
            await controller.initialize();
            final widget = controller.buildPreview();
            expect(widget, isA<Texture>());
            expect(mockPlatform.calls, contains('buildCameraPreview'));
        });

        test('throws when not initialized', () {
            expect(
                () => controller.buildPreview(),
                throwsA(isA<UvcCameraControllerNotInitializedException>()),
            );
        });
    });
}
