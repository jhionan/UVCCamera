import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';

import 'uvccamera_device.dart';
import 'uvccamera_mode.dart';

part 'uvccamera_controller_state.g.dart';

/// The state of a [UvcCameraController].
@CopyWith(copyWithNull: true)
@immutable
class UvcCameraControllerState {
  /// True after [UvcCameraController.initialize] has completed successfully.
  final bool isInitialized;

  /// The UVC device controlled by the controller.
  final UvcCameraDevice device;

  /// The current preview mode of the camera.
  ///
  /// Is `null` until [isInitialized] is `true`.
  final UvcCameraMode? previewMode;

  /// True if the camera is currently recording video.
  final bool isRecordingVideo;

  /// Camera video recording mode.
  final UvcCameraMode? videoRecordingMode;

  /// Camera video recording file.
  final XFile? videoRecordingFile;

  /// True if the camera is currently taking a picture.
  final bool isTakingPicture;

  /// Creates a new [UvcCameraControllerState] object.
  const UvcCameraControllerState({
    required this.isInitialized,
    required this.device,
    this.previewMode,
    required this.isRecordingVideo,
    this.videoRecordingMode,
    this.videoRecordingFile,
    required this.isTakingPicture,
  });

  /// Creates a [UvcCameraControllerState] object for an uninitialized controller.
  const UvcCameraControllerState.uninitialized(UvcCameraDevice device)
    : this(
        isInitialized: false,
        device: device,
        previewMode: null,
        isRecordingVideo: false,
        videoRecordingMode: null,
        videoRecordingFile: null,
        isTakingPicture: false,
      );

  @override
  String toString() {
    return '${objectRuntimeType(this, 'UvcCameraControllerState')}('
        'isInitialized: $isInitialized, '
        'device: $device, '
        'previewMode: $previewMode, '
        'isRecordingVideo: $isRecordingVideo, '
        'videoRecordingMode: $videoRecordingMode, '
        'videoRecordingFile: $videoRecordingFile, '
        'isTakingPicture: $isTakingPicture'
        ')';
  }
}
