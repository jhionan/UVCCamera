import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraException', () {
        test('toString with message', () {
            const e = UvcCameraException('test error');
            expect(e.toString(), contains('test error'));
            expect(e.message, 'test error');
        });

        test('toString without message', () {
            const e = UvcCameraException();
            expect(e.toString(), 'UvcCameraException');
            expect(e.message, isNull);
        });

        test('implements Exception', () {
            const e = UvcCameraException('x');
            expect(e, isA<Exception>());
        });
    });

    group('UvcCameraControllerDisposedException', () {
        test('has correct message', () {
            const e = UvcCameraControllerDisposedException();
            expect(e.message, 'UvcCameraController is disposed');
        });

        test('extends UvcCameraException', () {
            const e = UvcCameraControllerDisposedException();
            expect(e, isA<UvcCameraException>());
        });

        test('toString contains type and message', () {
            const e = UvcCameraControllerDisposedException();
            expect(e.toString(), contains('UvcCameraController is disposed'));
        });
    });

    group('UvcCameraControllerNotInitializedException', () {
        test('has correct message', () {
            const e = UvcCameraControllerNotInitializedException();
            expect(e.message, 'UvcCameraController is not initialized');
        });

        test('extends UvcCameraException', () {
            const e = UvcCameraControllerNotInitializedException();
            expect(e, isA<UvcCameraException>());
        });
    });

    group('UvcCameraControllerInitializedException', () {
        test('has correct message', () {
            const e = UvcCameraControllerInitializedException();
            expect(e.message, 'UvcCameraController is already initialized');
        });

        test('extends UvcCameraException', () {
            const e = UvcCameraControllerInitializedException();
            expect(e, isA<UvcCameraException>());
        });
    });

    group('UvcCameraControllerIllegalStateException', () {
        test('has custom message', () {
            const e = UvcCameraControllerIllegalStateException('custom msg');
            expect(e.message, 'custom msg');
        });

        test('has null message when none provided', () {
            const e = UvcCameraControllerIllegalStateException();
            expect(e.message, isNull);
        });

        test('extends UvcCameraException', () {
            const e = UvcCameraControllerIllegalStateException();
            expect(e, isA<UvcCameraException>());
        });
    });
}
