import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraStatus', () {
        const status = UvcCameraStatus(
            statusClass: UvcCameraStatusClass.controlCamera,
            event: 5,
            selector: 10,
            statusAttribute: UvcCameraStatusAttribute.failureChange,
        );

        test('constructor sets properties', () {
            expect(status.statusClass, UvcCameraStatusClass.controlCamera);
            expect(status.event, 5);
            expect(status.selector, 10);
            expect(status.statusAttribute, UvcCameraStatusAttribute.failureChange);
        });

        test('fromMap creates from map', () {
            final s = UvcCameraStatus.fromMap({
                'statusClass': 'control',
                'event': 1,
                'selector': 2,
                'statusAttribute': 'valueChange',
            });
            expect(s.statusClass, UvcCameraStatusClass.control);
            expect(s.event, 1);
            expect(s.selector, 2);
            expect(s.statusAttribute, UvcCameraStatusAttribute.valueChange);
        });

        test('toMap returns correct map', () {
            final map = status.toMap();
            expect(map['statusClass'], 'controlCamera');
            expect(map['event'], 5);
            expect(map['selector'], 10);
            expect(map['statusAttribute'], 'failureChange');
        });

        test('fromMap/toMap roundtrip', () {
            expect(UvcCameraStatus.fromMap(status.toMap()), status);
        });

        test('equality with same properties', () {
            const same = UvcCameraStatus(
                statusClass: UvcCameraStatusClass.controlCamera,
                event: 5, selector: 10,
                statusAttribute: UvcCameraStatusAttribute.failureChange,
            );
            expect(status, same);
            expect(status.hashCode, same.hashCode);
        });

        test('inequality with different event', () {
            const diff = UvcCameraStatus(
                statusClass: UvcCameraStatusClass.controlCamera,
                event: 99, selector: 10,
                statusAttribute: UvcCameraStatusAttribute.failureChange,
            );
            expect(status, isNot(diff));
        });

        test('props contains all fields', () {
            expect(status.props, [
                UvcCameraStatusClass.controlCamera,
                5, 10,
                UvcCameraStatusAttribute.failureChange,
            ]);
        });
    });

    group('UvcCameraStatusClass', () {
        test('has all values', () {
            expect(UvcCameraStatusClass.values, hasLength(3));
            expect(UvcCameraStatusClass.control, isNotNull);
            expect(UvcCameraStatusClass.controlCamera, isNotNull);
            expect(UvcCameraStatusClass.controlProcessing, isNotNull);
        });

        test('byName resolves', () {
            for (final v in UvcCameraStatusClass.values) {
                expect(UvcCameraStatusClass.values.byName(v.name), v);
            }
        });
    });

    group('UvcCameraStatusAttribute', () {
        test('has all values', () {
            expect(UvcCameraStatusAttribute.values, hasLength(4));
            expect(UvcCameraStatusAttribute.valueChange, isNotNull);
            expect(UvcCameraStatusAttribute.infoChange, isNotNull);
            expect(UvcCameraStatusAttribute.failureChange, isNotNull);
            expect(UvcCameraStatusAttribute.unknown, isNotNull);
        });

        test('byName resolves', () {
            for (final v in UvcCameraStatusAttribute.values) {
                expect(UvcCameraStatusAttribute.values.byName(v.name), v);
            }
        });
    });

    group('UvcCameraResolutionPreset', () {
        test('has all values', () {
            expect(UvcCameraResolutionPreset.values, hasLength(5));
        });

        test('values in expected order', () {
            expect(UvcCameraResolutionPreset.values, [
                UvcCameraResolutionPreset.min,
                UvcCameraResolutionPreset.low,
                UvcCameraResolutionPreset.medium,
                UvcCameraResolutionPreset.high,
                UvcCameraResolutionPreset.max,
            ]);
        });
    });
}
