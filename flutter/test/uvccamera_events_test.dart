import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraButtonEvent', () {
        const event = UvcCameraButtonEvent(cameraId: 1, button: 0, state: 1);

        test('constructor sets properties', () {
            expect(event.cameraId, 1);
            expect(event.button, 0);
            expect(event.state, 1);
        });

        test('fromMap creates from map', () {
            final e = UvcCameraButtonEvent.fromMap({'cameraId': 2, 'button': 1, 'state': 0});
            expect(e.cameraId, 2);
            expect(e.button, 1);
            expect(e.state, 0);
        });

        test('toMap returns correct map', () {
            final map = event.toMap();
            expect(map, {'cameraId': 1, 'button': 0, 'state': 1});
        });

        test('fromMap/toMap roundtrip', () {
            expect(UvcCameraButtonEvent.fromMap(event.toMap()), event);
        });

        test('equality', () {
            const same = UvcCameraButtonEvent(cameraId: 1, button: 0, state: 1);
            const diff = UvcCameraButtonEvent(cameraId: 1, button: 0, state: 0);
            expect(event, same);
            expect(event.hashCode, same.hashCode);
            expect(event, isNot(diff));
        });

        test('props', () {
            expect(event.props, [1, 0, 1]);
        });
    });

    group('UvcCameraDeviceEvent', () {
        const device = UvcCameraDevice(
            name: 'cam', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
        );
        const event = UvcCameraDeviceEvent(
            device: device, type: UvcCameraDeviceEventType.attached,
        );

        test('constructor sets properties', () {
            expect(event.device, device);
            expect(event.type, UvcCameraDeviceEventType.attached);
        });

        test('fromMap creates from map', () {
            final map = {
                'device': {
                    'name': 'cam2', 'deviceClass': 14, 'deviceSubclass': 0,
                    'vendorId': 3, 'productId': 4,
                },
                'type': 'detached',
            };
            final e = UvcCameraDeviceEvent.fromMap(map);
            expect(e.device.name, 'cam2');
            expect(e.type, UvcCameraDeviceEventType.detached);
        });

        test('toMap returns correct map', () {
            final map = event.toMap();
            expect(map['type'], 'attached');
            expect(map['device'], isA<Map>());
        });

        test('fromMap/toMap roundtrip', () {
            expect(UvcCameraDeviceEvent.fromMap(event.toMap()), event);
        });

        test('equality', () {
            const same = UvcCameraDeviceEvent(device: device, type: UvcCameraDeviceEventType.attached);
            const diff = UvcCameraDeviceEvent(device: device, type: UvcCameraDeviceEventType.detached);
            expect(event, same);
            expect(event, isNot(diff));
        });

        test('props', () {
            expect(event.props, [device, UvcCameraDeviceEventType.attached]);
        });
    });

    group('UvcCameraErrorEvent', () {
        const error = UvcCameraError(type: UvcCameraErrorType.previewInterrupted, reason: 'test');
        const event = UvcCameraErrorEvent(cameraId: 5, error: error);

        test('constructor sets properties', () {
            expect(event.cameraId, 5);
            expect(event.error, error);
        });

        test('fromMap creates from map', () {
            final e = UvcCameraErrorEvent.fromMap({
                'cameraId': 3,
                'error': {'type': 'previewInterrupted', 'reason': 'fail'},
            });
            expect(e.cameraId, 3);
            expect(e.error.type, UvcCameraErrorType.previewInterrupted);
            expect(e.error.reason, 'fail');
        });

        test('toMap returns correct map', () {
            final map = event.toMap();
            expect(map['cameraId'], 5);
            expect(map['error'], isA<Map>());
        });

        test('equality', () {
            const same = UvcCameraErrorEvent(cameraId: 5, error: error);
            expect(event, same);
        });

        test('props', () {
            expect(event.props, [5, error]);
        });
    });

    group('UvcCameraStatusEvent', () {
        const status = UvcCameraStatus(
            statusClass: UvcCameraStatusClass.control,
            event: 1, selector: 2,
            statusAttribute: UvcCameraStatusAttribute.valueChange,
        );
        const event = UvcCameraStatusEvent(cameraId: 7, payload: status);

        test('constructor sets properties', () {
            expect(event.cameraId, 7);
            expect(event.payload, status);
        });

        test('fromMap creates from map', () {
            final e = UvcCameraStatusEvent.fromMap({
                'cameraId': 8,
                'payload': {
                    'statusClass': 'controlCamera',
                    'event': 3, 'selector': 4,
                    'statusAttribute': 'infoChange',
                },
            });
            expect(e.cameraId, 8);
            expect(e.payload.statusClass, UvcCameraStatusClass.controlCamera);
            expect(e.payload.statusAttribute, UvcCameraStatusAttribute.infoChange);
        });

        test('toMap returns correct map', () {
            final map = event.toMap();
            expect(map['cameraId'], 7);
            expect(map['payload'], isA<Map>());
        });

        test('fromMap/toMap roundtrip', () {
            expect(UvcCameraStatusEvent.fromMap(event.toMap()), event);
        });

        test('equality', () {
            const same = UvcCameraStatusEvent(cameraId: 7, payload: status);
            expect(event, same);
        });

        test('props', () {
            expect(event.props, [7, status]);
        });
    });

    group('UvcCameraDeviceEventType', () {
        test('has all values', () {
            expect(UvcCameraDeviceEventType.values, hasLength(4));
            expect(UvcCameraDeviceEventType.attached, isNotNull);
            expect(UvcCameraDeviceEventType.detached, isNotNull);
            expect(UvcCameraDeviceEventType.connected, isNotNull);
            expect(UvcCameraDeviceEventType.disconnected, isNotNull);
        });

        test('byName resolves', () {
            for (final v in UvcCameraDeviceEventType.values) {
                expect(UvcCameraDeviceEventType.values.byName(v.name), v);
            }
        });
    });
}
