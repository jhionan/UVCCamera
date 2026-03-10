import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    group('UvcCameraMode', () {
        const mode = UvcCameraMode(
            frameWidth: 1920,
            frameHeight: 1080,
            frameFormat: UvcCameraFrameFormat.mjpeg,
        );

        test('constructor sets properties', () {
            expect(mode.frameWidth, 1920);
            expect(mode.frameHeight, 1080);
            expect(mode.frameFormat, UvcCameraFrameFormat.mjpeg);
        });

        test('aspectRatio is calculated correctly', () {
            expect(mode.aspectRatio, 1920 / 1080);
        });

        test('aspectRatio for 4:3', () {
            const mode43 = UvcCameraMode(
                frameWidth: 640,
                frameHeight: 480,
                frameFormat: UvcCameraFrameFormat.yuyv,
            );
            expect(mode43.aspectRatio, 640 / 480);
        });

        test('fromMap creates mode from map', () {
            final map = {
                'frameWidth': 1280,
                'frameHeight': 720,
                'frameFormat': 'yuyv',
            };
            final m = UvcCameraMode.fromMap(map);
            expect(m.frameWidth, 1280);
            expect(m.frameHeight, 720);
            expect(m.frameFormat, UvcCameraFrameFormat.yuyv);
        });

        test('toMap returns correct map', () {
            final map = mode.toMap();
            expect(map['frameWidth'], 1920);
            expect(map['frameHeight'], 1080);
            expect(map['frameFormat'], 'mjpeg');
        });

        test('fromMap then toMap roundtrip', () {
            final map = mode.toMap();
            final reconstructed = UvcCameraMode.fromMap(map);
            expect(reconstructed, mode);
        });

        test('equality with same properties', () {
            const other = UvcCameraMode(
                frameWidth: 1920,
                frameHeight: 1080,
                frameFormat: UvcCameraFrameFormat.mjpeg,
            );
            expect(mode, other);
            expect(mode.hashCode, other.hashCode);
        });

        test('inequality with different width', () {
            const other = UvcCameraMode(
                frameWidth: 1280,
                frameHeight: 1080,
                frameFormat: UvcCameraFrameFormat.mjpeg,
            );
            expect(mode, isNot(other));
        });

        test('inequality with different format', () {
            const other = UvcCameraMode(
                frameWidth: 1920,
                frameHeight: 1080,
                frameFormat: UvcCameraFrameFormat.yuyv,
            );
            expect(mode, isNot(other));
        });

        test('props contains all fields', () {
            expect(mode.props, [1920, 1080, UvcCameraFrameFormat.mjpeg]);
        });
    });

    group('UvcCameraFrameFormat', () {
        test('has yuyv value', () {
            expect(UvcCameraFrameFormat.yuyv, isNotNull);
            expect(UvcCameraFrameFormat.yuyv.name, 'yuyv');
        });

        test('has mjpeg value', () {
            expect(UvcCameraFrameFormat.mjpeg, isNotNull);
            expect(UvcCameraFrameFormat.mjpeg.name, 'mjpeg');
        });

        test('values contains exactly two formats', () {
            expect(UvcCameraFrameFormat.values, hasLength(2));
        });

        test('byName resolves correctly', () {
            expect(UvcCameraFrameFormat.values.byName('yuyv'), UvcCameraFrameFormat.yuyv);
            expect(UvcCameraFrameFormat.values.byName('mjpeg'), UvcCameraFrameFormat.mjpeg);
        });
    });
}
