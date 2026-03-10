// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uvccamera_controller_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UvcCameraControllerStateCWProxy {
  UvcCameraControllerState isInitialized(bool isInitialized);

  UvcCameraControllerState device(UvcCameraDevice device);

  UvcCameraControllerState previewMode(UvcCameraMode? previewMode);

  UvcCameraControllerState isRecordingVideo(bool isRecordingVideo);

  UvcCameraControllerState videoRecordingMode(
      UvcCameraMode? videoRecordingMode);

  UvcCameraControllerState videoRecordingFile(XFile? videoRecordingFile);

  UvcCameraControllerState isTakingPicture(bool isTakingPicture);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `UvcCameraControllerState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// UvcCameraControllerState(...).copyWith(id: 12, name: "My name")
  /// ```
  UvcCameraControllerState call({
    bool isInitialized,
    UvcCameraDevice device,
    UvcCameraMode? previewMode,
    bool isRecordingVideo,
    UvcCameraMode? videoRecordingMode,
    XFile? videoRecordingFile,
    bool isTakingPicture,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfUvcCameraControllerState.copyWith(...)` or call `instanceOfUvcCameraControllerState.copyWith.fieldName(value)` for a single field.
class _$UvcCameraControllerStateCWProxyImpl
    implements _$UvcCameraControllerStateCWProxy {
  const _$UvcCameraControllerStateCWProxyImpl(this._value);

  final UvcCameraControllerState _value;

  @override
  UvcCameraControllerState isInitialized(bool isInitialized) =>
      call(isInitialized: isInitialized);

  @override
  UvcCameraControllerState device(UvcCameraDevice device) =>
      call(device: device);

  @override
  UvcCameraControllerState previewMode(UvcCameraMode? previewMode) =>
      call(previewMode: previewMode);

  @override
  UvcCameraControllerState isRecordingVideo(bool isRecordingVideo) =>
      call(isRecordingVideo: isRecordingVideo);

  @override
  UvcCameraControllerState videoRecordingMode(
          UvcCameraMode? videoRecordingMode) =>
      call(videoRecordingMode: videoRecordingMode);

  @override
  UvcCameraControllerState videoRecordingFile(XFile? videoRecordingFile) =>
      call(videoRecordingFile: videoRecordingFile);

  @override
  UvcCameraControllerState isTakingPicture(bool isTakingPicture) =>
      call(isTakingPicture: isTakingPicture);

  @override

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `UvcCameraControllerState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// UvcCameraControllerState(...).copyWith(id: 12, name: "My name")
  /// ```
  UvcCameraControllerState call({
    Object? isInitialized = const $CopyWithPlaceholder(),
    Object? device = const $CopyWithPlaceholder(),
    Object? previewMode = const $CopyWithPlaceholder(),
    Object? isRecordingVideo = const $CopyWithPlaceholder(),
    Object? videoRecordingMode = const $CopyWithPlaceholder(),
    Object? videoRecordingFile = const $CopyWithPlaceholder(),
    Object? isTakingPicture = const $CopyWithPlaceholder(),
  }) {
    return UvcCameraControllerState(
      isInitialized:
          isInitialized == const $CopyWithPlaceholder() || isInitialized == null
              ? _value.isInitialized
              // ignore: cast_nullable_to_non_nullable
              : isInitialized as bool,
      device: device == const $CopyWithPlaceholder() || device == null
          ? _value.device
          // ignore: cast_nullable_to_non_nullable
          : device as UvcCameraDevice,
      previewMode: previewMode == const $CopyWithPlaceholder()
          ? _value.previewMode
          // ignore: cast_nullable_to_non_nullable
          : previewMode as UvcCameraMode?,
      isRecordingVideo: isRecordingVideo == const $CopyWithPlaceholder() ||
              isRecordingVideo == null
          ? _value.isRecordingVideo
          // ignore: cast_nullable_to_non_nullable
          : isRecordingVideo as bool,
      videoRecordingMode: videoRecordingMode == const $CopyWithPlaceholder()
          ? _value.videoRecordingMode
          // ignore: cast_nullable_to_non_nullable
          : videoRecordingMode as UvcCameraMode?,
      videoRecordingFile: videoRecordingFile == const $CopyWithPlaceholder()
          ? _value.videoRecordingFile
          // ignore: cast_nullable_to_non_nullable
          : videoRecordingFile as XFile?,
      isTakingPicture: isTakingPicture == const $CopyWithPlaceholder() ||
              isTakingPicture == null
          ? _value.isTakingPicture
          // ignore: cast_nullable_to_non_nullable
          : isTakingPicture as bool,
    );
  }
}

extension $UvcCameraControllerStateCopyWith on UvcCameraControllerState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfUvcCameraControllerState.copyWith(...)` or `instanceOfUvcCameraControllerState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UvcCameraControllerStateCWProxy get copyWith =>
      _$UvcCameraControllerStateCWProxyImpl(this);

  /// Returns a copy of the object with the selected fields set to `null`.
  /// A flag set to `false` leaves the field unchanged. Prefer `copyWith(field: null)` or `copyWith.fieldName(null)` for single-field updates.
  ///
  /// Example:
  /// ```dart
  /// UvcCameraControllerState(...).copyWithNull(firstField: true, secondField: true)
  /// ```
  UvcCameraControllerState copyWithNull({
    bool previewMode = false,
    bool videoRecordingMode = false,
    bool videoRecordingFile = false,
  }) {
    return UvcCameraControllerState(
      isInitialized: isInitialized,
      device: device,
      previewMode: previewMode == true ? null : this.previewMode,
      isRecordingVideo: isRecordingVideo,
      videoRecordingMode:
          videoRecordingMode == true ? null : this.videoRecordingMode,
      videoRecordingFile:
          videoRecordingFile == true ? null : this.videoRecordingFile,
      isTakingPicture: isTakingPicture,
    );
  }
}
