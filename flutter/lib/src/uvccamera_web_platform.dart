import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webhid/flutter_webhid.dart';
import 'package:web/web.dart' as web;

import 'uvccamera_button_event.dart';
import 'uvccamera_device.dart';
import 'uvccamera_device_event.dart';
import 'uvccamera_device_event_type.dart';
import 'uvccamera_error_event.dart';
import 'uvccamera_frame_format.dart';
import 'uvccamera_mode.dart';
import 'uvccamera_platform_interface.dart';
import 'uvccamera_resolution_preset.dart';
import 'uvccamera_status_event.dart';

// ---------------------------------------------------------------------------
// JS interop helpers for getUserMedia constraints
// ---------------------------------------------------------------------------

extension type _ConstrainDOMString._(JSObject _) implements JSObject {
    external factory _ConstrainDOMString({JSString exact});
}

extension type _ConstrainULong._(JSObject _) implements JSObject {
    external factory _ConstrainULong({JSNumber ideal});
}

extension type _VideoConstraints._(JSObject _) implements JSObject {
    external factory _VideoConstraints({JSAny? deviceId, JSAny? width, JSAny? height});
}

// ---------------------------------------------------------------------------
// Internal state per open camera
// ---------------------------------------------------------------------------

class _HidButtonMapping {
    final int reportId;
    final int shutterBitOffset;
    final int? autofocusBitOffset;

    _HidButtonMapping({
        required this.reportId,
        required this.shutterBitOffset,
        this.autofocusBitOffset,
    });
}

class _WebCameraState {
    final int cameraId;
    final String mediaDeviceId;
    final UvcCameraDevice device;

    web.MediaStream? stream;
    web.HTMLVideoElement? videoElement;
    web.MediaStreamTrack? videoTrack;
    UvcCameraMode? currentMode;

    // Button HID
    StreamController<UvcCameraButtonEvent>? buttonController;
    Device? hidDevice;
    StreamSubscription<InputReportEvent>? hidSubscription;

    // Recording
    web.MediaRecorder? mediaRecorder;
    final List<web.Blob> recordingChunks = [];
    Completer<XFile>? recordingCompleter;

    // Event stream controllers
    StreamController<UvcCameraErrorEvent>? errorController;
    StreamController<UvcCameraStatusEvent>? statusController;

    _WebCameraState({
        required this.cameraId,
        required this.mediaDeviceId,
        required this.device,
    });
}

// ---------------------------------------------------------------------------
// Constants — HID Camera Control page (USB HID Usage Tables 1.7, page 0x0090)
// Full 32-bit usage = (usagePage << 16) | usageId
// ---------------------------------------------------------------------------

const int _usageCameraShutter = 0x00900021;
const int _usageCameraAutofocus = 0x00900020;

// ---------------------------------------------------------------------------
// Web platform implementation
// ---------------------------------------------------------------------------

class UvcCameraWebPlatform extends UvcCameraPlatformInterface {
    static void registerWith(dynamic registrar) {
        UvcCameraPlatformInterface.instance = UvcCameraWebPlatform();
    }

    int _nextCameraId = 0;
    final Map<int, _WebCameraState> _cameras = {};

    // Maps UvcCameraDevice.name → browser MediaDevices deviceId
    final Map<String, String> _nameToBrowserDeviceId = {};

    // Maps UvcCameraDevice.name → WebHID Device list granted via requestDevicePermission
    final Map<String, List<Device>> _hidDevicesForDeviceName = {};

    final StreamController<UvcCameraDeviceEvent> _deviceEventController =
        StreamController<UvcCameraDeviceEvent>.broadcast();
    Set<String> _knownBrowserDeviceIds = {};

    UvcCameraWebPlatform() {
        _setupDeviceChangeListener();
    }

    void _setupDeviceChangeListener() {
        web.window.navigator.mediaDevices.addEventListener(
            'devicechange',
            ((web.Event _) {
                _emitDeviceChangeEvents();
            }).toJS,
        );
    }

    Future<void> _emitDeviceChangeEvents() async {
        final newDevices = await _enumerateVideoInputs();
        final newIds = newDevices.keys.toSet();

        for (final deviceId in newIds.difference(_knownBrowserDeviceIds)) {
            final info = newDevices[deviceId]!;
            _deviceEventController.add(UvcCameraDeviceEvent(
                device: _makeDevice(deviceId, info.label),
                type: UvcCameraDeviceEventType.attached,
            ));
        }
        for (final deviceId in _knownBrowserDeviceIds.difference(newIds)) {
            _deviceEventController.add(UvcCameraDeviceEvent(
                device: _makeDevice(deviceId, deviceId),
                type: UvcCameraDeviceEventType.detached,
            ));
        }
        _knownBrowserDeviceIds = newIds;
    }

    Future<Map<String, web.MediaDeviceInfo>> _enumerateVideoInputs() async {
        final jsDevices =
            await web.window.navigator.mediaDevices.enumerateDevices().toDart;
        final result = <String, web.MediaDeviceInfo>{};
        for (final d in jsDevices.toDart) {
            if (d.kind == 'videoinput' && d.deviceId.isNotEmpty) {
                result[d.deviceId] = d;
            }
        }
        return result;
    }

    String _deviceName(String deviceId, String label) =>
        label.isNotEmpty ? label : deviceId;

    UvcCameraDevice _makeDevice(String deviceId, String label) {
        return UvcCameraDevice(
            name: _deviceName(deviceId, label),
            deviceClass: 0x0e, // USB Video Class
            deviceSubclass: 0,
            vendorId: 0, // not available from MediaDevices API
            productId: 0,
        );
    }

    // -----------------------------------------------------------------------
    // UvcCameraPlatformInterface implementation
    // -----------------------------------------------------------------------

    @override
    Future<bool> isSupported() async => true; // web platform is only active on web

    @override
    Future<Map<String, UvcCameraDevice>> getDevices() async {
        final inputs = await _enumerateVideoInputs();
        final result = <String, UvcCameraDevice>{};
        for (final entry in inputs.entries) {
            final name = _deviceName(entry.key, entry.value.label);
            _nameToBrowserDeviceId[name] = entry.key;
            result[name] = _makeDevice(entry.key, entry.value.label);
        }
        _knownBrowserDeviceIds = inputs.keys.toSet();
        return result;
    }

    @override
    Future<bool> requestDevicePermission(UvcCameraDevice device) async {
        // Trigger the browser camera permission prompt
        try {
            final stream = await web.window.navigator.mediaDevices
                .getUserMedia(
                    web.MediaStreamConstraints(
                        video: true.toJS,
                        audio: false.toJS,
                    ),
                )
                .toDart;
            // Stop the probe stream immediately — we just needed the permission
            for (final track in stream.getTracks().toDart) {
                track.stop();
            }
        } catch (_) {
            return false;
        }

        // WebHID permission for button events is NOT requested here because it
        // shows a blocking browser dialog even when no HID devices are available.
        // Instead, HID is requested lazily via requestHidPermission() which
        // should be called from a user gesture when button events are needed.

        return true;
    }

    /// Requests WebHID permission for camera button events.
    ///
    /// Must be called from a user gesture context (e.g. button tap).
    /// Returns `true` if at least one HID device with camera controls was granted.
    Future<bool> requestHidPermission(UvcCameraDevice device) async {
        final hid = WebHID.instance;
        if (hid == null) return false;

        try {
            final hidDevices = await hid.requestDevice(
                RequestOptions(
                    filters: [DeviceFilter(usagePage: 0x0090)],
                ),
            );
            if (hidDevices.isNotEmpty) {
                _hidDevicesForDeviceName[device.name] = hidDevices;
                return true;
            }
        } catch (_) {
            // User denied or no matching HID device
        }
        return false;
    }

    @override
    Future<int> openCamera(
        UvcCameraDevice device,
        UvcCameraResolutionPreset resolutionPreset,
    ) async {
        final browserDeviceId =
            _nameToBrowserDeviceId[device.name] ?? device.name;
        final (idealWidth, idealHeight) = _resolutionForPreset(resolutionPreset);

        final videoConstraints = _VideoConstraints(
            deviceId: _ConstrainDOMString(exact: browserDeviceId.toJS) as JSAny,
            width: _ConstrainULong(ideal: idealWidth.toJS) as JSAny,
            height: _ConstrainULong(ideal: idealHeight.toJS) as JSAny,
        );

        final stream = await web.window.navigator.mediaDevices
            .getUserMedia(
                web.MediaStreamConstraints(
                    video: videoConstraints as JSAny,
                    audio: false.toJS,
                ),
            )
            .toDart;

        final tracks = stream.getVideoTracks().toDart;
        if (tracks.isEmpty) {
            throw Exception('No video tracks returned for device: ${device.name}');
        }
        final videoTrack = tracks.first;

        final videoElement = web.HTMLVideoElement()
            ..autoplay = true
            ..muted = true
            ..playsInline = true;
        videoElement.style.width = '100%';
        videoElement.style.height = '100%';
        videoElement.style.objectFit = 'cover';
        videoElement.srcObject = stream;
        await videoElement.play().toDart;

        final cameraId = _nextCameraId++;
        ui_web.platformViewRegistry.registerViewFactory(
            'uvccamera-preview-$cameraId',
            (int _) => videoElement,
        );

        _cameras[cameraId] = _WebCameraState(
            cameraId: cameraId,
            mediaDeviceId: browserDeviceId,
            device: device,
        )
            ..stream = stream
            ..videoElement = videoElement
            ..videoTrack = videoTrack
            ..currentMode = _modeFromSettings(videoTrack.getSettings());

        return cameraId;
    }

    @override
    Future<void> closeCamera(int cameraId) async {
        final state = _cameras.remove(cameraId);
        if (state == null) return;

        await state.hidSubscription?.cancel();
        state.hidSubscription = null;
        try {
            await state.hidDevice?.close();
        } catch (_) {}
        state.hidDevice = null;

        state.mediaRecorder?.stop();
        state.recordingCompleter?.completeError(
            Exception('Camera closed while recording'),
        );

        for (final track in state.stream?.getTracks().toDart ?? []) {
            track.stop();
        }

        state.buttonController?.close();
        state.errorController?.close();
        state.statusController?.close();
    }

    @override
    Future<int> getCameraTextureId(int cameraId) async {
        // Web uses HtmlElementView, not Flutter textures — return sentinel -1
        return -1;
    }

    @override
    Widget buildCameraPreview(int cameraId, int textureId) {
        return HtmlElementView(viewType: 'uvccamera-preview-$cameraId');
    }

    @override
    Future<Stream<UvcCameraErrorEvent>> attachToCameraErrorCallback(
        int cameraId,
    ) async {
        final controller = StreamController<UvcCameraErrorEvent>.broadcast();
        _cameras[cameraId]?.errorController = controller;
        return controller.stream;
    }

    @override
    Future<void> detachFromCameraErrorCallback(int cameraId) async {
        _cameras[cameraId]?.errorController?.close();
        _cameras[cameraId]?.errorController = null;
    }

    @override
    Future<Stream<UvcCameraStatusEvent>> attachToCameraStatusCallback(
        int cameraId,
    ) async {
        // No UVC status callbacks available via browser APIs
        final controller = StreamController<UvcCameraStatusEvent>.broadcast();
        _cameras[cameraId]?.statusController = controller;
        return controller.stream;
    }

    @override
    Future<void> detachFromCameraStatusCallback(int cameraId) async {
        _cameras[cameraId]?.statusController?.close();
        _cameras[cameraId]?.statusController = null;
    }

    @override
    Future<Stream<UvcCameraButtonEvent>> attachToCameraButtonCallback(
        int cameraId,
    ) async {
        final controller = StreamController<UvcCameraButtonEvent>.broadcast();
        final state = _cameras[cameraId];
        state?.buttonController = controller;

        final hid = WebHID.instance;
        if (hid == null) {
            return controller.stream;
        }

        Device? hidDevice;

        // 1. Use HID devices pre-associated via requestDevicePermission
        if (state != null) {
            final preAssociated = _hidDevicesForDeviceName[state.device.name];
            if (preAssociated != null && preAssociated.isNotEmpty) {
                hidDevice = preAssociated.first;
            }
        }

        // 2. Fall back to any previously-granted Camera Control device
        if (hidDevice == null) {
            final granted = await hid.getDevices();
            outer:
            for (final d in granted) {
                for (final coll in d.collections) {
                    if (coll.usagePage == 0x0090) {
                        hidDevice = d;
                        break outer;
                    }
                }
            }
        }

        if (hidDevice == null || state == null) {
            return controller.stream;
        }

        // 3. Parse the HID report descriptor to locate the Camera Shutter bit
        _HidButtonMapping? mapping;
        outer:
        for (final coll in hidDevice.collections) {
            if (coll.usagePage != 0x0090) continue;
            for (final report in coll.inputReports ?? <ReportInfo>[]) {
                final shutterBit = _findButtonBitOffset(report, _usageCameraShutter);
                if (shutterBit != null) {
                    mapping = _HidButtonMapping(
                        reportId: report.reportId,
                        shutterBitOffset: shutterBit,
                        autofocusBitOffset: _findButtonBitOffset(
                            report,
                            _usageCameraAutofocus,
                        ),
                    );
                    break outer;
                }
            }
        }

        if (mapping == null) {
            return controller.stream;
        }

        // 4. Open the HID device (no-op if already open)
        try {
            if (!hidDevice.opened) {
                await hidDevice.open();
            }
        } catch (_) {
            return controller.stream;
        }

        state.hidDevice = hidDevice;

        // 5. Listen for input reports and emit press/release button events
        final m = mapping;
        bool prevShutter = false;
        bool prevAutofocus = false;

        state.hidSubscription = hidDevice.onInputReport.listen((event) {
            // reportId == 0 means the device uses no report IDs (single report)
            if (m.reportId != 0 && event.reportId != m.reportId) return;

            final shutter = _readBit(event.data, m.shutterBitOffset);
            if (shutter != prevShutter) {
                prevShutter = shutter;
                controller.add(UvcCameraButtonEvent(
                    cameraId: cameraId,
                    button: 0, // Camera Shutter (HID usage 0x0021)
                    state: shutter ? 1 : 0,
                ));
            }

            if (m.autofocusBitOffset != null) {
                final af = _readBit(event.data, m.autofocusBitOffset!);
                if (af != prevAutofocus) {
                    prevAutofocus = af;
                    controller.add(UvcCameraButtonEvent(
                        cameraId: cameraId,
                        button: 1, // Camera Autofocus (HID usage 0x0020)
                        state: af ? 1 : 0,
                    ));
                }
            }
        });

        return controller.stream;
    }

    @override
    Future<void> detachFromCameraButtonCallback(int cameraId) async {
        final state = _cameras[cameraId];
        if (state == null) return;

        await state.hidSubscription?.cancel();
        state.hidSubscription = null;
        try {
            await state.hidDevice?.close();
        } catch (_) {}
        state.hidDevice = null;
        state.buttonController?.close();
        state.buttonController = null;
    }

    @override
    Future<List<UvcCameraMode>> getSupportedModes(int cameraId) async {
        final state = _cameras[cameraId];
        if (state?.videoTrack == null) return [];

        final caps = state!.videoTrack!.getCapabilities();
        final widthRange = caps.width;
        final heightRange = caps.height;

        const commonResolutions = [
            (320, 240),
            (640, 480),
            (1280, 720),
            (1920, 1080),
            (3840, 2160),
        ];

        return [
            for (final (w, h) in commonResolutions)
                if (w >= widthRange.min &&
                    w <= widthRange.max &&
                    h >= heightRange.min &&
                    h <= heightRange.max)
                    UvcCameraMode(
                        frameWidth: w,
                        frameHeight: h,
                        frameFormat: UvcCameraFrameFormat.mjpeg,
                    ),
        ];
    }

    @override
    Future<UvcCameraMode> getPreviewMode(int cameraId) async {
        return _cameras[cameraId]?.currentMode ??
            UvcCameraMode(
                frameWidth: 640,
                frameHeight: 480,
                frameFormat: UvcCameraFrameFormat.mjpeg,
            );
    }

    @override
    Future<void> setPreviewMode(int cameraId, UvcCameraMode previewMode) async {
        final state = _cameras[cameraId];
        if (state?.videoTrack == null) return;

        await state!.videoTrack!
            .applyConstraints(
                web.MediaTrackConstraints(
                    width: previewMode.frameWidth.toJS,
                    height: previewMode.frameHeight.toJS,
                ),
            )
            .toDart;
        state.currentMode = previewMode;
    }

    @override
    Future<XFile> takePicture(int cameraId) async {
        final state = _cameras[cameraId];
        final video = state?.videoElement;
        if (video == null) throw Exception('Camera $cameraId is not open');

        final vw = video.videoWidth;
        final vh = video.videoHeight;
        if (vw == 0 || vh == 0) {
            throw Exception('Video has no dimensions ($vw x $vh) — not ready');
        }

        final canvas = web.HTMLCanvasElement()
            ..width = vw
            ..height = vh;

        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
        ctx.drawImage(video, 0, 0);

        final dataUrl = canvas.toDataURL('image/jpeg', (0.95).toJS);
        return XFile(dataUrl, mimeType: 'image/jpeg', name: 'picture.jpg');
    }

    @override
    Future<void> startVideoRecording(
        int cameraId,
        UvcCameraMode videoRecordingMode,
    ) async {
        final state = _cameras[cameraId];
        if (state?.stream == null) throw Exception('Camera $cameraId is not open');

        state!.recordingChunks.clear();
        final mimeType = _pickMimeType();
        final completer = Completer<XFile>();
        state.recordingCompleter = completer;

        final recorder = web.MediaRecorder(
            state.stream!,
            web.MediaRecorderOptions(mimeType: mimeType),
        );

        recorder.ondataavailable = ((web.Event e) {
            final blob = (e as web.BlobEvent).data;
            if (blob.size > 0) state.recordingChunks.add(blob);
        }).toJS;

        recorder.onstop = ((web.Event _) {
            final parts = state.recordingChunks.toJS as JSArray<JSAny>;
            final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
            final url = web.URL.createObjectURL(blob);
            completer.complete(
                XFile(url, mimeType: mimeType, name: 'recording.webm'),
            );
        }).toJS;

        state.mediaRecorder = recorder;
        recorder.start(1000); // collect chunks every second
    }

    @override
    Future<XFile> stopVideoRecording(int cameraId) async {
        final state = _cameras[cameraId];
        if (state == null) throw Exception('Camera $cameraId is not open');

        final completer = state.recordingCompleter;
        if (completer == null) {
            throw Exception('No active recording for camera $cameraId');
        }

        state.mediaRecorder?.stop();
        state.mediaRecorder = null;
        state.recordingCompleter = null;

        return completer.future;
    }

    @override
    Stream<UvcCameraDeviceEvent> get deviceEventStream =>
        _deviceEventController.stream;

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    (int, int) _resolutionForPreset(UvcCameraResolutionPreset preset) =>
        switch (preset) {
            UvcCameraResolutionPreset.min => (320, 240),
            UvcCameraResolutionPreset.low => (640, 480),
            UvcCameraResolutionPreset.medium => (1280, 720),
            UvcCameraResolutionPreset.high => (1920, 1080),
            UvcCameraResolutionPreset.max => (4096, 2160),
        };

    UvcCameraMode _modeFromSettings(web.MediaTrackSettings settings) {
        final w = settings.width.toInt();
        final h = settings.height.toInt();
        return UvcCameraMode(
            frameWidth: w != 0 ? w : 640,
            frameHeight: h != 0 ? h : 480,
            frameFormat: UvcCameraFrameFormat.mjpeg,
        );
    }

    /// Walk a HID report's items and return the bit offset of [targetUsage].
    /// [targetUsage] is 32-bit encoded: (usagePage << 16) | usageId.
    int? _findButtonBitOffset(ReportInfo report, int targetUsage) {
        int bitOffset = 0;
        for (final item in report.items) {
            if (!item.isArray && (item.usages?.contains(targetUsage) ?? false)) {
                return bitOffset;
            }
            bitOffset += item.reportCount * item.reportSize;
        }
        return null;
    }

    /// Read a single bit from a HID report's [Uint8List] at [bitOffset].
    bool _readBit(Uint8List data, int bitOffset) {
        final byteIndex = bitOffset ~/ 8;
        final bitIndex = bitOffset % 8;
        if (byteIndex >= data.length) return false;
        return (data[byteIndex] >> bitIndex) & 1 == 1;
    }

    /// Pick the best MIME type supported by this browser's MediaRecorder.
    String _pickMimeType() {
        const candidates = [
            'video/webm;codecs=vp9',
            'video/webm;codecs=vp8',
            'video/webm',
            'video/mp4',
        ];
        for (final t in candidates) {
            if (web.MediaRecorder.isTypeSupported(t)) return t;
        }
        return 'video/webm';
    }
}
