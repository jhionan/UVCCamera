import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvccamera/uvccamera.dart';

void main() {
    const device = UvcCameraDevice(
        name: 'cam', deviceClass: 14, deviceSubclass: 0, vendorId: 1, productId: 2,
    );
    const mode = UvcCameraMode(
        frameWidth: 1920, frameHeight: 1080, frameFormat: UvcCameraFrameFormat.mjpeg,
    );

    group('UvcCameraControllerState', () {
        test('uninitialized factory sets defaults', () {
            final state = UvcCameraControllerState.uninitialized(device);
            expect(state.isInitialized, false);
            expect(state.device, device);
            expect(state.previewMode, isNull);
            expect(state.isRecordingVideo, false);
            expect(state.videoRecordingMode, isNull);
            expect(state.videoRecordingFile, isNull);
            expect(state.isTakingPicture, false);
        });

        test('constructor with all fields', () {
            final file = XFile('/tmp/test.mp4');
            final state = UvcCameraControllerState(
                isInitialized: true,
                device: device,
                previewMode: mode,
                isRecordingVideo: true,
                videoRecordingMode: mode,
                videoRecordingFile: file,
                isTakingPicture: true,
            );
            expect(state.isInitialized, true);
            expect(state.device, device);
            expect(state.previewMode, mode);
            expect(state.isRecordingVideo, true);
            expect(state.videoRecordingMode, mode);
            expect(state.videoRecordingFile, file);
            expect(state.isTakingPicture, true);
        });

        group('copyWith', () {
            test('copies all fields when none specified', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith();
                expect(copy.isInitialized, state.isInitialized);
                expect(copy.device, state.device);
                expect(copy.previewMode, state.previewMode);
                expect(copy.isRecordingVideo, state.isRecordingVideo);
                expect(copy.isTakingPicture, state.isTakingPicture);
            });

            test('overrides isInitialized', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(isInitialized: true);
                expect(copy.isInitialized, true);
                expect(copy.device, device);
            });

            test('overrides device', () {
                const otherDevice = UvcCameraDevice(
                    name: 'other', deviceClass: 14, deviceSubclass: 0,
                    vendorId: 3, productId: 4,
                );
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(device: otherDevice);
                expect(copy.device, otherDevice);
            });

            test('overrides previewMode', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(previewMode: mode);
                expect(copy.previewMode, mode);
            });

            test('overrides isRecordingVideo', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(isRecordingVideo: true);
                expect(copy.isRecordingVideo, true);
            });

            test('overrides videoRecordingMode', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(videoRecordingMode: mode);
                expect(copy.videoRecordingMode, mode);
            });

            test('overrides videoRecordingFile', () {
                final file = XFile('/tmp/test.mp4');
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(videoRecordingFile: file);
                expect(copy.videoRecordingFile, file);
            });

            test('overrides isTakingPicture', () {
                final state = UvcCameraControllerState.uninitialized(device);
                final copy = state.copyWith(isTakingPicture: true);
                expect(copy.isTakingPicture, true);
            });

            test('nullifies nullable fields via copyWith', () {
                final state = UvcCameraControllerState(
                    isInitialized: true,
                    device: device,
                    previewMode: mode,
                    isRecordingVideo: true,
                    videoRecordingMode: mode,
                    videoRecordingFile: XFile('/tmp/test.mp4'),
                    isTakingPicture: false,
                );
                final copy = state.copyWith(videoRecordingMode: null);
                expect(copy.videoRecordingMode, isNull);
                expect(copy.previewMode, mode); // unchanged
            });

            test('nullifies via copyWithNull', () {
                final state = UvcCameraControllerState(
                    isInitialized: true,
                    device: device,
                    previewMode: mode,
                    isRecordingVideo: true,
                    videoRecordingMode: mode,
                    videoRecordingFile: XFile('/tmp/test.mp4'),
                    isTakingPicture: false,
                );
                final copy = state.copyWithNull(
                    videoRecordingMode: true,
                    videoRecordingFile: true,
                );
                expect(copy.videoRecordingMode, isNull);
                expect(copy.videoRecordingFile, isNull);
                expect(copy.previewMode, mode); // unchanged
            });
        });

        test('toString contains all field names', () {
            final state = UvcCameraControllerState.uninitialized(device);
            final str = state.toString();
            expect(str, contains('isInitialized'));
            expect(str, contains('device'));
            expect(str, contains('previewMode'));
            expect(str, contains('isRecordingVideo'));
            expect(str, contains('videoRecordingMode'));
            expect(str, contains('videoRecordingFile'));
            expect(str, contains('isTakingPicture'));
        });
    });
}
