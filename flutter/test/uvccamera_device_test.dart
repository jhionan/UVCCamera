import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraDevice', () {
        const device = UvcCameraDevice(
            name: 'USB Camera',
            deviceClass: 14,
            deviceSubclass: 2,
            vendorId: 0x046d,
            productId: 0x0825,
        );

        test('constructor sets properties', () {
            expect(device.name, 'USB Camera');
            expect(device.deviceClass, 14);
            expect(device.deviceSubclass, 2);
            expect(device.vendorId, 0x046d);
            expect(device.productId, 0x0825);
        });

        test('fromMap creates device from map', () {
            final map = {
                'name': 'Logitech C920',
                'deviceClass': 14,
                'deviceSubclass': 1,
                'vendorId': 1133,
                'productId': 2093,
            };
            final d = UvcCameraDevice.fromMap(map);
            expect(d.name, 'Logitech C920');
            expect(d.deviceClass, 14);
            expect(d.deviceSubclass, 1);
            expect(d.vendorId, 1133);
            expect(d.productId, 2093);
        });

        test('toMap returns correct map', () {
            final map = device.toMap();
            expect(map['name'], 'USB Camera');
            expect(map['deviceClass'], 14);
            expect(map['deviceSubclass'], 2);
            expect(map['vendorId'], 0x046d);
            expect(map['productId'], 0x0825);
        });

        test('fromMap then toMap roundtrip', () {
            final map = device.toMap();
            final reconstructed = UvcCameraDevice.fromMap(map);
            expect(reconstructed, device);
        });

        test('equality with same properties', () {
            const other = UvcCameraDevice(
                name: 'USB Camera',
                deviceClass: 14,
                deviceSubclass: 2,
                vendorId: 0x046d,
                productId: 0x0825,
            );
            expect(device, other);
            expect(device.hashCode, other.hashCode);
        });

        test('inequality with different name', () {
            const other = UvcCameraDevice(
                name: 'Other Camera',
                deviceClass: 14,
                deviceSubclass: 2,
                vendorId: 0x046d,
                productId: 0x0825,
            );
            expect(device, isNot(other));
        });

        test('inequality with different vendorId', () {
            const other = UvcCameraDevice(
                name: 'USB Camera',
                deviceClass: 14,
                deviceSubclass: 2,
                vendorId: 0x1234,
                productId: 0x0825,
            );
            expect(device, isNot(other));
        });

        test('inequality with different productId', () {
            const other = UvcCameraDevice(
                name: 'USB Camera',
                deviceClass: 14,
                deviceSubclass: 2,
                vendorId: 0x046d,
                productId: 0x0001,
            );
            expect(device, isNot(other));
        });

        test('props contains all fields', () {
            expect(device.props, [
                'USB Camera',
                14,
                2,
                0x046d,
                0x0825,
            ]);
        });
    });
}
