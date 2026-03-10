import 'dart:async';
import 'dart:convert';
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

extension type _CanvasCapturable._(JSObject _) implements JSObject {
    external web.MediaStream captureStream(JSNumber frameRate);
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

    // Browser-mode (getUserMedia) state
    web.MediaStream? stream;
    web.HTMLVideoElement? videoElement;
    web.MediaStreamTrack? videoTrack;
    UvcCameraMode? currentMode;

    // Helper-mode (native helper MJPEG) state
    bool useHelper = false;
    int? helperPort;
    web.HTMLImageElement? imgElement;
    web.HTMLCanvasElement? recordingCanvas;

    // Button HID
    StreamController<UvcCameraButtonEvent>? buttonController;
    Device? hidDevice;
    StreamSubscription<InputReportEvent>? hidSubscription;

    // Button WebSocket fallback
    web.WebSocket? wsButtonSocket;

    // Keyboard fallback listeners (stored for cleanup)
    JSFunction? keydownListener;
    JSFunction? keyupListener;

    // Visibility change listener (stops helper camera on tab switch)
    JSFunction? visibilityListener;

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

    /// Parse vendorId:productId from a device label like "Integrated Webcam (0c45:64ab)".
    static (int vendorId, int productId) _parseUsbIds(String label) {
        final match = RegExp(r'\(([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\)').firstMatch(label);
        if (match == null) return (0, 0);
        return (
            int.parse(match.group(1)!, radix: 16),
            int.parse(match.group(2)!, radix: 16),
        );
    }

    UvcCameraDevice _makeDevice(String deviceId, String label) {
        final (vendorId, productId) = _parseUsbIds(label);
        return UvcCameraDevice(
            name: _deviceName(deviceId, label),
            deviceClass: 0x0e, // USB Video Class
            deviceSubclass: 0,
            vendorId: vendorId,
            productId: productId,
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
        // If the native helper is running, no browser camera permission needed —
        // the helper owns the camera and streams video over HTTP.
        final helperPort = await _detectHelper();
        if (helperPort != null) return true;

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

        return true;
    }

    /// Requests WebHID permission for camera button events.
    ///
    /// Must be called from a user gesture context (e.g. button tap).
    /// Tries multiple filter strategies:
    ///   1. Camera Control usage page (0x0090) — most specific
    ///   2. vendorId/productId from device label — matches any HID interface
    /// Returns `true` if at least one HID device was granted.
    Future<bool> requestHidPermission(UvcCameraDevice device) async {
        final hid = WebHID.instance;
        if (hid == null) return false;

        // Build a list of filter strategies to try in order.
        final filters = <List<DeviceFilter>>[
            // 1. Camera Control usage page
            [DeviceFilter(usagePage: 0x0090)],
        ];

        // 2. Match by vendorId/productId parsed from the device label
        final (vendorId, productId) = _parseUsbIds(device.name);
        if (vendorId != 0) {
            filters.add([
                DeviceFilter(vendorId: vendorId, productId: productId != 0 ? productId : null),
            ]);
        }

        for (final filter in filters) {
            try {
                final hidDevices = await hid.requestDevice(
                    RequestOptions(filters: filter),
                );
                if (hidDevices.isNotEmpty) {
                    _hidDevicesForDeviceName[device.name] = hidDevices;
                    return true;
                }
            } catch (_) {
                // User denied or no matching HID device — try next filter
            }
        }
        return false;
    }

    /// Check if the native helper is running on any of the candidate ports.
    /// Returns the port number if found, or null.
    Future<int?> _detectHelper() async {
        const ports = [8765, 8766, 8767];
        for (final port in ports) {
            try {
                final response = await web.window
                    .fetch('http://localhost:$port/devices'.toJS)
                    .toDart;
                if (!response.ok) continue;
                // Verify this is actually our helper by checking the response format
                final body = (await response.text().toDart).toDart;
                final data = jsonDecode(body) as Map<String, dynamic>;
                if (data['type'] == 'hello' && data['devices'] is List) {
                    return port;
                }
            } catch (_) {}
        }
        return null;
    }

    @override
    Future<int> openCamera(
        UvcCameraDevice device,
        UvcCameraResolutionPreset resolutionPreset,
    ) async {
        final browserDeviceId =
            _nameToBrowserDeviceId[device.name] ?? device.name;
        final cameraId = _nextCameraId++;

        // Check if native helper is available — if so, use its MJPEG stream
        // instead of getUserMedia (avoids USB driver conflicts for button support).
        final helperPort = await _detectHelper();

        if (helperPort != null) {
            return _openCameraViaHelper(cameraId, browserDeviceId, device, helperPort);
        }
        return _openCameraViaBrowser(cameraId, browserDeviceId, device, resolutionPreset);
    }

    Future<int> _openCameraViaHelper(
        int cameraId,
        String browserDeviceId,
        UvcCameraDevice device,
        int helperPort,
    ) async {
        // Fetch device info from helper to get resolution
        UvcCameraMode? mode;
        try {
            final response = await web.window
                .fetch('http://localhost:$helperPort/devices'.toJS)
                .toDart;
            final body = (await response.text().toDart).toDart;
            final data = jsonDecode(body) as Map<String, dynamic>;
            final devices = data['devices'] as List<dynamic>? ?? [];
            if (devices.isNotEmpty) {
                final d = devices.first as Map<String, dynamic>;
                mode = UvcCameraMode(
                    frameWidth: d['width'] as int? ?? 640,
                    frameHeight: d['height'] as int? ?? 480,
                    frameFormat: UvcCameraFrameFormat.mjpeg,
                );
            }
        } catch (_) {}

        final effectiveMode = mode ?? UvcCameraMode(
            frameWidth: 640,
            frameHeight: 480,
            frameFormat: UvcCameraFrameFormat.mjpeg,
        );

        // Create an <img> element that auto-refreshes from the helper's /snapshot.
        // This is more reliable than multipart/x-mixed-replace MJPEG which has
        // inconsistent browser support.
        final imgElement = web.HTMLImageElement();
        imgElement.style.width = '100%';
        imgElement.style.height = '100%';
        imgElement.style.objectFit = 'cover';
        imgElement.crossOrigin = 'anonymous';

        // Tell the helper to start streaming (in case it was stopped)
        try {
            await web.window.fetch(
                'http://localhost:$helperPort/start'.toJS,
                web.RequestInit(method: 'POST'),
            ).toDart;
        } catch (_) {}

        // Start the img refresh loop
        _startImgRefreshLoop(imgElement, helperPort);

        ui_web.platformViewRegistry.registerViewFactory(
            'uvccamera-preview-$cameraId',
            (int _) => imgElement,
        );

        final state = _WebCameraState(
            cameraId: cameraId,
            mediaDeviceId: browserDeviceId,
            device: device,
        )
            ..useHelper = true
            ..helperPort = helperPort
            ..imgElement = imgElement
            ..currentMode = effectiveMode;

        // Register visibility change listener to stop/restart camera on tab switch
        final visibilityListener = ((web.Event _) {
            if (web.document.hidden) {
                // Tab hidden — stop helper camera
                state.imgElement?.onload = null;
                state.imgElement?.onerror = null;
                state.imgElement?.src = '';
                web.window.fetch(
                    'http://localhost:$helperPort/stop'.toJS,
                    web.RequestInit(method: 'POST'),
                );
            } else {
                // Tab visible — restart if camera state still exists
                if (_cameras.containsKey(cameraId)) {
                    web.window.fetch(
                        'http://localhost:$helperPort/start'.toJS,
                        web.RequestInit(method: 'POST'),
                    );
                    if (state.imgElement != null) {
                        _startImgRefreshLoop(state.imgElement!, helperPort);
                    }
                }
            }
        }).toJS;
        web.document.addEventListener('visibilitychange', visibilityListener);
        state.visibilityListener = visibilityListener;

        _cameras[cameraId] = state;

        return cameraId;
    }

    Future<int> _openCameraViaBrowser(
        int cameraId,
        String browserDeviceId,
        UvcCameraDevice device,
        UvcCameraResolutionPreset resolutionPreset,
    ) async {
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

        // Stop the img element refresh loop (helper mode) — must happen FIRST
        // to prevent ongoing /snapshot requests from keeping the connection alive
        if (state.imgElement != null) {
            state.imgElement!.onload = null;
            state.imgElement!.onerror = null;
            state.imgElement!.src = '';
            state.imgElement = null;
        }

        // Remove visibility change listener
        if (state.visibilityListener != null) {
            web.document.removeEventListener('visibilitychange', state.visibilityListener!);
            state.visibilityListener = null;
        }

        // Remove keyboard fallback listeners
        if (state.keydownListener != null) {
            web.document.removeEventListener('keydown', state.keydownListener!);
            state.keydownListener = null;
        }
        if (state.keyupListener != null) {
            web.document.removeEventListener('keyup', state.keyupListener!);
            state.keyupListener = null;
        }

        // Helper mode: tell the helper to stop streaming (turns LED off)
        if (state.useHelper && state.helperPort != null) {
            try {
                await web.window.fetch(
                    'http://localhost:${state.helperPort}/stop'.toJS,
                    web.RequestInit(method: 'POST'),
                ).toDart;
            } catch (e) {
                debugPrint('UvcCameraWebPlatform: failed to stop helper: $e');
            }
        }

        await state.hidSubscription?.cancel();
        state.hidSubscription = null;
        try {
            await state.hidDevice?.close();
        } catch (_) {}
        state.hidDevice = null;

        try {
            state.wsButtonSocket?.close();
        } catch (_) {}
        state.wsButtonSocket = null;

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

        // --- WebHID-based button detection ---
        _tryAttachHidButtons(cameraId, state, controller);

        // --- Native helper WebSocket fallback ---
        // Connects to uvc_button_helper.py running on localhost.
        _tryAttachWebSocketButtons(cameraId, state, controller);

        // --- Keyboard fallback for cameras without HID button interface ---
        // Emits shutter press/release on Space key down/up.
        _attachKeyboardFallback(cameraId, state, controller);

        return controller.stream;
    }

    Future<void> _tryAttachHidButtons(
        int cameraId,
        _WebCameraState? state,
        StreamController<UvcCameraButtonEvent> controller,
    ) async {
        final hid = WebHID.instance;
        if (hid == null || state == null) return;

        Device? hidDevice;

        // 1. Use HID devices pre-associated via requestHidPermission
        final preAssociated = _hidDevicesForDeviceName[state.device.name];
        if (preAssociated != null && preAssociated.isNotEmpty) {
            hidDevice = preAssociated.first;
        }

        // 2. Fall back to any previously-granted HID device
        if (hidDevice == null) {
            final granted = await hid.getDevices();
            if (granted.isNotEmpty) {
                hidDevice = granted.first;
            }
        }

        if (hidDevice == null) return;

        // 3. Parse HID report descriptor — first try Camera Control (0x0090),
        //    then scan ALL collections for any input report with known usages.
        _HidButtonMapping? mapping;

        // Try Camera Control page first
        for (final coll in hidDevice.collections) {
            if (coll.usagePage == 0x0090) {
                mapping = _findMappingInCollection(coll);
                if (mapping != null) break;
            }
        }

        // If not found, try any collection that has input reports
        if (mapping == null) {
            for (final coll in hidDevice.collections) {
                if (coll.usagePage == 0x0090) continue; // already tried
                mapping = _findMappingInCollection(coll);
                if (mapping != null) break;
            }
        }

        // If still no specific mapping, use generic mode: treat any input
        // report change as a button event (press on data received).
        final useGenericMode = mapping == null;

        // 4. Open the HID device
        try {
            if (!hidDevice.opened) {
                await hidDevice.open();
            }
        } catch (_) {
            return;
        }

        state.hidDevice = hidDevice;

        if (useGenericMode) {
            // Generic mode: any input report = shutter press, then auto-release
            state.hidSubscription = hidDevice.onInputReport.listen((event) {
                controller.add(UvcCameraButtonEvent(
                    cameraId: cameraId,
                    button: 0,
                    state: 1, // pressed
                ));
                // Auto-release after a short delay
                Future.delayed(const Duration(milliseconds: 100), () {
                    controller.add(UvcCameraButtonEvent(
                        cameraId: cameraId,
                        button: 0,
                        state: 0, // released
                    ));
                });
            });
        } else {
            // Specific mode: parse individual button bits
            final m = mapping;
            bool prevShutter = false;
            bool prevAutofocus = false;

            state.hidSubscription = hidDevice.onInputReport.listen((event) {
                if (m.reportId != 0 && event.reportId != m.reportId) return;

                final shutter = _readBit(event.data, m.shutterBitOffset);
                if (shutter != prevShutter) {
                    prevShutter = shutter;
                    controller.add(UvcCameraButtonEvent(
                        cameraId: cameraId,
                        button: 0,
                        state: shutter ? 1 : 0,
                    ));
                }

                if (m.autofocusBitOffset != null) {
                    final af = _readBit(event.data, m.autofocusBitOffset!);
                    if (af != prevAutofocus) {
                        prevAutofocus = af;
                        controller.add(UvcCameraButtonEvent(
                            cameraId: cameraId,
                            button: 1,
                            state: af ? 1 : 0,
                        ));
                    }
                }
            });
        }
    }

    /// Finds a button mapping within a single HID collection.
    _HidButtonMapping? _findMappingInCollection(CollectionInfo coll) {
        for (final report in coll.inputReports ?? <ReportInfo>[]) {
            final shutterBit = _findButtonBitOffset(report, _usageCameraShutter);
            if (shutterBit != null) {
                return _HidButtonMapping(
                    reportId: report.reportId,
                    shutterBitOffset: shutterBit,
                    autofocusBitOffset: _findButtonBitOffset(report, _usageCameraAutofocus),
                );
            }
        }
        return null;
    }

    /// Keyboard fallback: Space key triggers shutter button events.
    void _attachKeyboardFallback(
        int cameraId,
        _WebCameraState? state,
        StreamController<UvcCameraButtonEvent> controller,
    ) {
        if (state == null) return;

        final keydownListener = ((web.KeyboardEvent e) {
            if (e.code == 'Space' && !e.repeat) {
                e.preventDefault();
                controller.add(UvcCameraButtonEvent(
                    cameraId: cameraId,
                    button: 0,
                    state: 1, // pressed
                ));
            }
        }).toJS;

        final keyupListener = ((web.KeyboardEvent e) {
            if (e.code == 'Space') {
                e.preventDefault();
                controller.add(UvcCameraButtonEvent(
                    cameraId: cameraId,
                    button: 0,
                    state: 0, // released
                ));
            }
        }).toJS;

        state.keydownListener = keydownListener;
        state.keyupListener = keyupListener;

        web.document.addEventListener('keydown', keydownListener);
        web.document.addEventListener('keyup', keyupListener);
    }

    /// Connects to the native uvc_button_helper WebSocket server on localhost.
    /// Falls back silently if the helper is not running.
    void _tryAttachWebSocketButtons(
        int cameraId,
        _WebCameraState? state,
        StreamController<UvcCameraButtonEvent> controller,
    ) {
        if (state == null) return;

        const ports = [8765, 8766, 8767];
        _tryConnectWebSocket(cameraId, state, controller, ports, 0);
    }

    void _tryConnectWebSocket(
        int cameraId,
        _WebCameraState state,
        StreamController<UvcCameraButtonEvent> controller,
        List<int> ports,
        int portIndex,
    ) {
        if (portIndex >= ports.length) return; // No helper found

        final port = ports[portIndex];
        final ws = web.WebSocket('ws://localhost:$port/ws');
        state.wsButtonSocket = ws;

        ws.onopen = ((web.Event _) {
            // Connected to helper
        }).toJS;

        ws.onmessage = ((web.MessageEvent e) {
            try {
                final data = jsonDecode(e.data.dartify().toString()) as Map<String, dynamic>;
                final type = data['type'] as String?;

                if (type == 'button') {
                    // Match by vendorId/productId if available
                    final eventCameraId = data['cameraId'] as int?;
                    controller.add(UvcCameraButtonEvent(
                        cameraId: eventCameraId ?? cameraId,
                        button: data['button'] as int? ?? 0,
                        state: data['state'] as int? ?? 0,
                    ));
                }
            } catch (_) {}
        }).toJS;

        ws.onerror = ((web.Event _) {
            // Try next port
            ws.close();
            state.wsButtonSocket = null;
            _tryConnectWebSocket(cameraId, state, controller, ports, portIndex + 1);
        }).toJS;

        ws.onclose = ((web.Event _) {
            state.wsButtonSocket = null;
        }).toJS;
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

        try {
            state.wsButtonSocket?.close();
        } catch (_) {}
        state.wsButtonSocket = null;

        // Remove keyboard fallback listeners
        if (state.keydownListener != null) {
            web.document.removeEventListener('keydown', state.keydownListener!);
            state.keydownListener = null;
        }
        if (state.keyupListener != null) {
            web.document.removeEventListener('keyup', state.keyupListener!);
            state.keyupListener = null;
        }

        state.buttonController?.close();
        state.buttonController = null;
    }

    @override
    Future<List<UvcCameraMode>> getSupportedModes(int cameraId) async {
        final state = _cameras[cameraId];
        if (state == null) return [];

        // Helper mode: return the single mode the helper negotiated
        if (state.useHelper && state.currentMode != null) {
            return [state.currentMode!];
        }

        if (state.videoTrack == null) return [];

        final caps = state.videoTrack!.getCapabilities();
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
        if (state == null) return;

        // Helper mode: resolution is fixed by the helper, just update local state
        if (state.useHelper) {
            state.currentMode = previewMode;
            return;
        }

        if (state.videoTrack == null) return;

        await state.videoTrack!
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
        if (state == null) throw Exception('Camera $cameraId is not open');

        // Helper mode: fetch snapshot from the native helper
        if (state.useHelper && state.helperPort != null) {
            final response = await web.window
                .fetch('http://localhost:${state.helperPort}/snapshot'.toJS)
                .toDart;
            if (!response.ok) {
                throw Exception('Snapshot failed: HTTP ${response.status}');
            }
            final blob = await response.blob().toDart;
            final url = web.URL.createObjectURL(blob);
            return XFile(url, mimeType: 'image/jpeg', name: 'picture.jpg');
        }

        // Browser mode: capture from video element
        final video = state.videoElement;
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
        if (state == null) throw Exception('Camera $cameraId is not open');

        // Helper mode: use canvas.captureStream() to create a recordable MediaStream
        if (state.useHelper) {
            final img = state.imgElement;
            if (img == null) throw Exception('Camera $cameraId has no preview element');

            final w = state.currentMode?.frameWidth ?? 640;
            final h = state.currentMode?.frameHeight ?? 480;
            final canvas = web.HTMLCanvasElement()
                ..width = w
                ..height = h;
            final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
            state.recordingCanvas = canvas;

            // Draw each loaded frame to the canvas for recording
            final originalOnload = img.onload;
            img.onload = ((web.Event e) {
                ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
                // Call original onload to continue the snapshot refresh loop
                if (originalOnload != null) {
                    originalOnload.callAsFunction(null, e);
                }
            }).toJS;

            // canvas.captureStream(30) — not in package:web, use extension type
            final captureStream = (canvas as _CanvasCapturable).captureStream(30.toJS);
            state.stream = captureStream;

            _startRecorderOnStream(state, captureStream);
            return;
        }

        if (state.stream == null) throw Exception('Camera $cameraId has no stream');
        _startRecorderOnStream(state, state.stream!);
    }

    void _startRecorderOnStream(_WebCameraState state, web.MediaStream stream) {
        state.recordingChunks.clear();
        final mimeType = _pickMimeType();
        final completer = Completer<XFile>();
        state.recordingCompleter = completer;

        final recorder = web.MediaRecorder(
            stream,
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

        // Clean up helper-mode recording canvas
        if (state.useHelper) {
            state.recordingCanvas = null;
            state.stream = null;
        }

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

    /// Start (or restart) the img element refresh loop for helper mode.
    /// Each loaded frame triggers a requestAnimationFrame → fetch next snapshot.
    void _startImgRefreshLoop(web.HTMLImageElement imgElement, int helperPort) {
        final snapshotUrl = 'http://localhost:$helperPort/snapshot';
        void scheduleNextFrame() {
            imgElement.src = '$snapshotUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        }

        imgElement.onload = ((web.Event _) {
            web.window.requestAnimationFrame(((JSNumber _) {
                scheduleNextFrame();
            }).toJS);
        }).toJS;

        imgElement.onerror = ((web.Event _) {
            Future.delayed(const Duration(milliseconds: 200), scheduleNextFrame);
        }).toJS;

        // Kick off the first frame
        scheduleNextFrame();
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
