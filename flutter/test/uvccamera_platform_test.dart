import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';
import 'package:uvccamera/src/uvccamera_platform.dart';

void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    late UvcCameraPlatform platform;
    final List<MethodCall> methodCalls = [];

    setUp(() {
        platform = UvcCameraPlatform();
        methodCalls.clear();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('uvccamera/native'),
                (MethodCall call) async {
                    methodCalls.add(call);
                    switch (call.method) {
                        case 'isSupported':
                            return true;
                        case 'getDevices':
                            return <String, dynamic>{
                                'dev1': {
                                    'name': 'cam1', 'deviceClass': 14,
                                    'deviceSubclass': 0, 'vendorId': 1, 'productId': 2,
                                },
                            };
                        case 'requestDevicePermission':
                            return true;
                        case 'openCamera':
                            return 42;
                        case 'getCameraTextureId':
                            return 99;
                        case 'getPreviewMode':
                            return {
                                'frameWidth': 1920, 'frameHeight': 1080, 'frameFormat': 'mjpeg',
                            };
                        case 'getSupportedModes':
                            return [
                                {'frameWidth': 640, 'frameHeight': 480, 'frameFormat': 'yuyv'},
                                {'frameWidth': 1920, 'frameHeight': 1080, 'frameFormat': 'mjpeg'},
                            ];
                        case 'takePicture':
                            return '/tmp/test.jpg';
                        case 'startVideoRecording':
                            return '/tmp/test.mp4';
                        case 'stopVideoRecording':
                            return null;
                        default:
                            return null;
                    }
                },
            );
    });

    tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('uvccamera/native'), null);
    });

    const device = UvcCameraDevice(
        name: 'cam1', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
    );
    const mode = UvcCameraMode(
        frameWidth: 1920, frameHeight: 1080, frameFormat: UvcCameraFrameFormat.mjpeg,
    );

    group('UvcCameraPlatform', () {
        test('isSupported calls native method', () async {
            final result = await platform.isSupported();
            expect(result, true);
            expect(methodCalls.last.method, 'isSupported');
        });

        test('getDevices returns device map', () async {
            final devices = await platform.getDevices();
            expect(devices, hasLength(1));
            expect(devices['dev1']!.name, 'cam1');
            expect(methodCalls.last.method, 'getDevices');
        });

        test('requestDevicePermission passes device name', () async {
            final result = await platform.requestDevicePermission(device);
            expect(result, true);
            expect(methodCalls.last.arguments['deviceName'], 'cam1');
        });

        test('openCamera passes device and preset', () async {
            final id = await platform.openCamera(device, UvcCameraResolutionPreset.high);
            expect(id, 42);
            expect(methodCalls.last.arguments['deviceName'], 'cam1');
            expect(methodCalls.last.arguments['resolutionPreset'], 'high');
        });

        test('closeCamera calls native and cleans up channels', () async {
            await platform.closeCamera(42);
            expect(methodCalls.last.method, 'closeCamera');
            expect(methodCalls.last.arguments['cameraId'], 42);
        });

        test('getCameraTextureId returns texture id', () async {
            final id = await platform.getCameraTextureId(42);
            expect(id, 99);
            expect(methodCalls.last.arguments['cameraId'], 42);
        });

        test('getPreviewMode returns mode', () async {
            final result = await platform.getPreviewMode(42);
            expect(result.frameWidth, 1920);
            expect(result.frameHeight, 1080);
            expect(result.frameFormat, UvcCameraFrameFormat.mjpeg);
        });

        test('getSupportedModes returns list', () async {
            final modes = await platform.getSupportedModes(42);
            expect(modes, hasLength(2));
            expect(modes[0].frameWidth, 640);
            expect(modes[1].frameWidth, 1920);
        });

        test('setPreviewMode calls native', () async {
            await platform.setPreviewMode(42, mode);
            expect(methodCalls.last.method, 'setPreviewMode');
            expect(methodCalls.last.arguments['cameraId'], 42);
        });

        test('takePicture returns XFile', () async {
            final file = await platform.takePicture(42);
            expect(file.path, '/tmp/test.jpg');
        });

        test('startVideoRecording stores file', () async {
            await platform.startVideoRecording(42, mode);
            expect(methodCalls.last.method, 'startVideoRecording');
        });

        test('stopVideoRecording returns stored XFile', () async {
            await platform.startVideoRecording(42, mode);
            final file = await platform.stopVideoRecording(42);
            expect(file.path, '/tmp/test.mp4');
        });

        test('stopVideoRecording throws when no recording', () {
            expect(
                () => platform.stopVideoRecording(99),
                throwsA(isA<PlatformException>()),
            );
        });

        test('deviceEventStream returns broadcast stream', () {
            final stream = platform.deviceEventStream;
            expect(stream, isA<Stream<UvcCameraDeviceEvent>>());
            // Calling again returns the same cached stream
            expect(platform.deviceEventStream, same(stream));
        });
    });
}
