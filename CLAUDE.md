# UVCCamera

> USB Video Class (UVC) camera library for Android + Flutter plugin

## Fork Context

This is a **personal/private fork** of `alexey-pelykh/UVCCamera` (which is itself a hard fork of `saki4510t/UVCCamera`).

- **Upstream**: `alexey-pelykh/UVCCamera` — follow for upstream bug fixes and cherry-picks
- **CI/CD**: Not configured for this fork — no automated builds, no publish pipelines
- **Distribution**: Not published — no Maven Central, pub.dev, or GitHub Packages releases
- **Purpose**: Local development and custom feature additions (e.g., Flutter web support)
- Upstream submodules in `upstreams/` for reference. Community improvements are cherry-picked with attribution trailers.

## Project Context

| Attribute | Value |
|-----------|-------|
| **License** | Apache-2.0 |
| **Min SDK** | 21 (Android 5.0) |
| **Compile SDK** | 34 (Android 14) |
| **Java Compatibility** | 11 (build requires JDK 17) |
| **Target ABIs** | armeabi-v7a, arm64-v8a |
| **Gradle** | 8.13, Kotlin DSL, version catalog |
| **Flutter** | >=3.24.0, Dart SDK >=3.5.0 |
| **Platforms** | Android (production), Web (in development) |

## Structure

| Path | Purpose |
|------|---------|
| `lib/` | Android library module (`org.uvccamera.lib`) |
| `lib/src/main/java/` | Java API (UVCCamera, USBMonitor, DeviceFilter) |
| `lib/src/main/jni/` | Native C/C++ (libuvc, libusb, libjpeg, UVCCamera JNI) |
| `flutter/` | Flutter plugin (`uvccamera`) |
| `flutter/lib/` | Dart API |
| `flutter/lib/src/` | Platform interface + all data models, events, exceptions |
| `flutter/lib/src/uvccamera_web_platform.dart` | Flutter Web platform implementation (Dart, via `package:web` + `flutter_webhid`) |
| `flutter/android/` | Flutter Android platform implementation (Java) |
| `flutter/example/` | Flutter example app |
| `usbCameraCommon/` | Shared Android UI utilities for test apps |
| `usbCameraTest*/` | Android test/demo applications |
| `upstreams/` | Git submodules referencing upstream forks |
| `gh-pages/` | GitHub Pages build assets |
| `gradle/libs.versions.toml` | Dependency version catalog |

## Flutter Plugin Architecture

The plugin uses the **platform interface pattern** (`plugin_platform_interface`):

- `UvcCameraPlatformInterface` — abstract base defining all 16 methods + device event stream
- `UvcCameraPlatform` — Android implementation (MethodChannel + EventChannels)
- Web implementation to be added as `UvcCameraWebPlatform` in `flutter/lib/src/uvccamera_web_platform.dart`

Key Dart classes:
- `UvcCameraController` — `ValueNotifier`-based controller; manages init, capture, recording, preview
- `UvcCameraDevice` — immutable device descriptor (name, vendorId, productId, class, subclass)
- `UvcCameraPreview` — `StatelessWidget` wrapping `Texture` (Android) or `HtmlElementView` (web)
- Method channel: `uvccamera/native`
- Event channels: `uvccamera/device_events`, `uvccamera/camera@{id}/error_events`, etc.

## Web Support Plan

UVC cameras appear as standard `videoinput` devices in the browser's `MediaDevices` API — no special handling needed. The approach:

- **Library**: `flutter_webrtc` (pub.dev) — provides `Helper.cameras` enumeration, `deviceId`-based selection, `getUserMedia` with full constraints, and `RTCVideoRenderer` widget. Falls back to `package:web` for `MediaRecorder`.
- **Preview**: `RTCVideoRenderer` + `HtmlElementView`
- **Still capture**: `ImageCapture` API or canvas snapshot
- **Video recording**: `MediaRecorder` API (outputs webm/mp4)
- **Camera buttons**: UVC hardware buttons are not accessible via browser APIs — web will skip button events
- **Status/error events**: Mapped to stream-equivalent browser events
- **Constraints**: Requires HTTPS (or localhost). No UVC protocol-level control (no raw UVC commands via browser).

## Conventions

### Commits

Format: `(type) scope: description`

| Type | Meaning |
|------|---------|
| `fix` | Bug fix |
| `imp` | Improvement/enhancement |
| `chore` | Maintenance (deps, CI, tooling) |
| `docs` | Documentation |

Scope prefix when targeting a specific module: `flutter:`, `ci:`, `lib:`

Cherry-picked commits from upstream use trailers:
```
Cherry-picked-from: source/repo@sha (or source/repo#PR)
Co-authored-by: Original Author <email>
```

### Branches

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/description` | `feat/flutter/pause-resume-preview` |
| Fix | `fix/description` | `fix/preview-size-comparison` |
| Cherry-pick | `cherry-pick/source-description` | `cherry-pick/hthetiot-fix-rotation` |

### Naming

- Java packages: `com.serenegiant.usb` / `com.serenegiant.utils` (legacy upstream)
- Library namespace: `org.uvccamera.lib`
- Flutter plugin package: `org.uvccamera.flutter`
- Dart files: `uvccamera_*.dart` (snake_case with prefix)
- Gradle modules: camelCase (`usbCameraTest`, `usbCameraCommon`)

### Code Style

Per `.editorconfig`: 4-space indent, 120 char max, LF line endings, UTF-8. YAML uses 2-space indent.

## Development

### Build Android library

```shell
./gradlew :lib:assembleRelease
```

### Publish to local Maven (required before Flutter build)

```shell
./gradlew :lib:publishToMavenLocal
```

### Build Flutter example (Android)

```shell
cd flutter/example
flutter build apk
```

### Run Flutter example (Web)

```shell
cd flutter/example
flutter run -d chrome
```

### Run full build chain (Android)

```shell
./gradlew assembleRelease publishToMavenLocal && cd flutter/example && flutter build apk
```

## CI / Release

CI and release pipelines are **not configured** for this fork.

To build manually:
- Android library: `./gradlew :lib:assembleRelease`
- Flutter plugin: `cd flutter && flutter build`

If you want to set up CI in the future, refer to the upstream `.github/workflows/` as a reference:
- `ci.yaml` — Build lib, publish snapshots
- `release.yaml` — Full release: build, sign, publish to Maven Central + pub.dev

## Native Layer

The native code uses ndk-build (not CMake). Entry point: `lib/src/main/jni/Android.mk`.

Key native libraries:
- **libuvc** — USB Video Class protocol implementation
- **libusb** — USB device access
- **libjpeg** — JPEG encoding/decoding
- **UVCCamera** — JNI bridge and pipeline system

The pipeline architecture (`lib/src/main/jni/UVCCamera/pipeline/`) handles frame processing with buffered, preview, capture, and callback pipelines.
