import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';
import 'package:uvccamera/src/uvccamera_platform_interface.dart';

import 'mock_uvccamera_platform.dart';

void main() {
    const device = UvcCameraDevice(
        name: 'cam', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
    );
    const mode = UvcCameraMode(
        frameWidth: 640, frameHeight: 480, frameFormat: UvcCameraFrameFormat.yuyv,
    );

    group('UvcCameraPlatformInterface', () {
        test('default instance is UvcCameraPlatform', () {
            // After test setup may have changed it, just verify the type system
            expect(UvcCameraPlatformInterface.instance, isNotNull);
        });

        test('instance setter accepts MockPlatformInterfaceMixin', () {
            final mock = MockUvcCameraPlatform();
            UvcCameraPlatformInterface.instance = mock;
            expect(UvcCameraPlatformInterface.instance, mock);
        });

        group('default methods throw UnimplementedError', () {
            late _BasePlatform platform;

            setUp(() {
                platform = _BasePlatform();
            });

            test('isSupported', () {
                expect(() => platform.isSupported(), throwsA(isA<UnimplementedError>()));
            });

            test('getDevices', () {
                expect(() => platform.getDevices(), throwsA(isA<UnimplementedError>()));
            });

            test('requestDevicePermission', () {
                expect(
                    () => platform.requestDevicePermission(device),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('openCamera', () {
                expect(
                    () => platform.openCamera(device, UvcCameraResolutionPreset.max),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('closeCamera', () {
                expect(() => platform.closeCamera(1), throwsA(isA<UnimplementedError>()));
            });

            test('getCameraTextureId', () {
                expect(() => platform.getCameraTextureId(1), throwsA(isA<UnimplementedError>()));
            });

            test('attachToCameraErrorCallback', () {
                expect(
                    () => platform.attachToCameraErrorCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('detachFromCameraErrorCallback', () {
                expect(
                    () => platform.detachFromCameraErrorCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('attachToCameraStatusCallback', () {
                expect(
                    () => platform.attachToCameraStatusCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('detachFromCameraStatusCallback', () {
                expect(
                    () => platform.detachFromCameraStatusCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('attachToCameraButtonCallback', () {
                expect(
                    () => platform.attachToCameraButtonCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('detachFromCameraButtonCallback', () {
                expect(
                    () => platform.detachFromCameraButtonCallback(1),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('getSupportedModes', () {
                expect(() => platform.getSupportedModes(1), throwsA(isA<UnimplementedError>()));
            });

            test('getPreviewMode', () {
                expect(() => platform.getPreviewMode(1), throwsA(isA<UnimplementedError>()));
            });

            test('setPreviewMode', () {
                expect(
                    () => platform.setPreviewMode(1, mode),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('takePicture', () {
                expect(() => platform.takePicture(1), throwsA(isA<UnimplementedError>()));
            });

            test('startVideoRecording', () {
                expect(
                    () => platform.startVideoRecording(1, mode),
                    throwsA(isA<UnimplementedError>()),
                );
            });

            test('stopVideoRecording', () {
                expect(() => platform.stopVideoRecording(1), throwsA(isA<UnimplementedError>()));
            });

            test('deviceEventStream', () {
                expect(() => platform.deviceEventStream, throwsA(isA<UnimplementedError>()));
            });
        });

        test('buildCameraPreview default returns Texture', () {
            final platform = _BasePlatformWithPreview();
            final widget = platform.buildCameraPreview(1, 42);
            expect(widget, isA<Texture>());
        });
    });
}

/// Minimal subclass that doesn't override anything — used to test defaults.
class _BasePlatform extends UvcCameraPlatformInterface {}

/// Subclass that only exercises the default buildCameraPreview.
class _BasePlatformWithPreview extends UvcCameraPlatformInterface {}
