import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraError', () {
        const error = UvcCameraError(type: UvcCameraErrorType.previewInterrupted, reason: 'device lost');

        test('constructor sets properties', () {
            expect(error.type, UvcCameraErrorType.previewInterrupted);
            expect(error.reason, 'device lost');
        });

        test('constructor with null reason', () {
            const e = UvcCameraError(type: UvcCameraErrorType.previewInterrupted);
            expect(e.reason, isNull);
        });

        test('fromMap creates from map', () {
            final e = UvcCameraError.fromMap({
                'type': 'previewInterrupted',
                'reason': 'some reason',
            });
            expect(e.type, UvcCameraErrorType.previewInterrupted);
            expect(e.reason, 'some reason');
        });

        test('fromMap with null reason', () {
            final e = UvcCameraError.fromMap({
                'type': 'previewInterrupted',
                'reason': null,
            });
            expect(e.reason, isNull);
        });

        test('toMap returns correct map', () {
            final map = error.toMap();
            expect(map['type'], 'previewInterrupted');
        });

        test('equality uses type only', () {
            const a = UvcCameraError(type: UvcCameraErrorType.previewInterrupted, reason: 'a');
            const b = UvcCameraError(type: UvcCameraErrorType.previewInterrupted, reason: 'b');
            // props only contains type, so a == b
            expect(a, b);
        });

        test('props contains type', () {
            expect(error.props, [UvcCameraErrorType.previewInterrupted]);
        });
    });

    group('UvcCameraErrorType', () {
        test('has previewInterrupted', () {
            expect(UvcCameraErrorType.previewInterrupted, isNotNull);
            expect(UvcCameraErrorType.values, hasLength(1));
        });

        test('byName resolves', () {
            expect(
                UvcCameraErrorType.values.byName('previewInterrupted'),
                UvcCameraErrorType.previewInterrupted,
            );
        });
    });
}
