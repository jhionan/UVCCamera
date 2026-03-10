import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';
import 'package:uvccamera/src/uvccamera_platform_interface.dart';

import 'mock_uvccamera_platform.dart';

void main() {
    late MockUvcCameraPlatform mockPlatform;

    const device = UvcCameraDevice(
        name: 'cam', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
    );

    setUp(() {
        mockPlatform = MockUvcCameraPlatform();
        UvcCameraPlatformInterface.instance = mockPlatform;
    });

    group('UvcCamera', () {
        test('isSupported delegates to platform', () async {
            mockPlatform.isSupportedResult = true;
            expect(await UvcCamera.isSupported(), true);

            mockPlatform.isSupportedResult = false;
            expect(await UvcCamera.isSupported(), false);

            expect(mockPlatform.calls.where((c) => c == 'isSupported').length, 2);
        });

        test('getDevices delegates to platform', () async {
            mockPlatform.getDevicesResult = {'dev1': device};
            final devices = await UvcCamera.getDevices();
            expect(devices, hasLength(1));
            expect(devices['dev1'], device);
            expect(mockPlatform.calls, contains('getDevices'));
        });

        test('getDevices returns empty map when no devices', () async {
            mockPlatform.getDevicesResult = {};
            final devices = await UvcCamera.getDevices();
            expect(devices, isEmpty);
        });

        test('requestDevicePermission delegates to platform', () async {
            mockPlatform.requestDevicePermissionResult = true;
            expect(await UvcCamera.requestDevicePermission(device), true);

            mockPlatform.requestDevicePermissionResult = false;
            expect(await UvcCamera.requestDevicePermission(device), false);
        });

        test('deviceEventStream delegates to platform', () {
            final stream = UvcCamera.deviceEventStream;
            expect(stream, isA<Stream<UvcCameraDeviceEvent>>());
        });

        test('deviceEventStream emits events', () async {
            final events = <UvcCameraDeviceEvent>[];
            final sub = UvcCamera.deviceEventStream.listen(events.add);

            const event = UvcCameraDeviceEvent(
                device: device, type: UvcCameraDeviceEventType.attached,
            );
            mockPlatform.deviceEventStreamController.add(event);

            await Future<void>.delayed(Duration.zero);
            expect(events, [event]);
            await sub.cancel();
        });
    });
}
