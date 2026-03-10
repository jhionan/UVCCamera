import 'package:flutter/material.dart';
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

    group('UvcCameraPreview', () {
        testWidgets('shows empty container when not initialized', (tester) async {
            final controller = UvcCameraController(device: device);
            await tester.pumpWidget(
                MaterialApp(home: Scaffold(body: UvcCameraPreview(controller))),
            );
            // Should show empty Container since not initialized
            expect(find.byType(AspectRatio), findsNothing);
        });

        testWidgets('shows preview when initialized', (tester) async {
            final controller = UvcCameraController(device: device);
            await controller.initialize();
            await tester.pumpWidget(
                MaterialApp(home: Scaffold(body: UvcCameraPreview(controller))),
            );
            await tester.pump();
            expect(find.byType(AspectRatio), findsOneWidget);
            expect(find.byType(Texture), findsOneWidget);
            await controller.dispose();
        });

        testWidgets('renders child overlay', (tester) async {
            final controller = UvcCameraController(device: device);
            await controller.initialize();
            await tester.pumpWidget(
                MaterialApp(
                    home: Scaffold(
                        body: UvcCameraPreview(
                            controller,
                            child: const Text('Overlay'),
                        ),
                    ),
                ),
            );
            await tester.pump();
            expect(find.text('Overlay'), findsOneWidget);
            await controller.dispose();
        });

        testWidgets('uses correct aspect ratio from previewMode', (tester) async {
            mockPlatform.getPreviewModeResult = const UvcCameraMode(
                frameWidth: 640, frameHeight: 480, frameFormat: UvcCameraFrameFormat.mjpeg,
            );
            final controller = UvcCameraController(device: device);
            await controller.initialize();
            await tester.pumpWidget(
                MaterialApp(home: Scaffold(body: UvcCameraPreview(controller))),
            );
            await tester.pump();
            final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
            expect(aspectRatio.aspectRatio, 640 / 480);
            await controller.dispose();
        });
    });
}
