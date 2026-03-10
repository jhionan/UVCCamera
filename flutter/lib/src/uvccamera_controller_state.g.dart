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

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UvcCameraControllerState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UvcCameraControllerState(...).copyWith(id: 12, name: "My name")
  /// ````
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

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUvcCameraControllerState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUvcCameraControllerState.copyWith.fieldName(...)`
class _$UvcCameraControllerStateCWProxyImpl
    implements _$UvcCameraControllerStateCWProxy {
  const _$UvcCameraControllerStateCWProxyImpl(this._value);

  final UvcCameraControllerState _value;

  @override
  UvcCameraControllerState isInitialized(bool isInitialized) =>
      this(isInitialized: isInitialized);

  @override
  UvcCameraControllerState device(UvcCameraDevice device) =>
      this(device: device);

  @override
  UvcCameraControllerState previewMode(UvcCameraMode? previewMode) =>
      this(previewMode: previewMode);

  @override
  UvcCameraControllerState isRecordingVideo(bool isRecordingVideo) =>
      this(isRecordingVideo: isRecordingVideo);

  @override
  UvcCameraControllerState videoRecordingMode(
          UvcCameraMode? videoRecordingMode) =>
      this(videoRecordingMode: videoRecordingMode);

  @override
  UvcCameraControllerState videoRecordingFile(XFile? videoRecordingFile) =>
      this(videoRecordingFile: videoRecordingFile);

  @override
  UvcCameraControllerState isTakingPicture(bool isTakingPicture) =>
      this(isTakingPicture: isTakingPicture);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UvcCameraControllerState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UvcCameraControllerState(...).copyWith(id: 12, name: "My name")
  /// ````
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
      isInitialized: isInitialized == const $CopyWithPlaceholder()
          ? _value.isInitialized
          // ignore: cast_nullable_to_non_nullable
          : isInitialized as bool,
      device: device == const $CopyWithPlaceholder()
          ? _value.device
          // ignore: cast_nullable_to_non_nullable
          : device as UvcCameraDevice,
      previewMode: previewMode == const $CopyWithPlaceholder()
          ? _value.previewMode
          // ignore: cast_nullable_to_non_nullable
          : previewMode as UvcCameraMode?,
      isRecordingVideo: isRecordingVideo == const $CopyWithPlaceholder()
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
      isTakingPicture: isTakingPicture == const $CopyWithPlaceholder()
          ? _value.isTakingPicture
          // ignore: cast_nullable_to_non_nullable
          : isTakingPicture as bool,
    );
  }
}

extension $UvcCameraControllerStateCopyWith on UvcCameraControllerState {
  /// Returns a callable class that can be used as follows: `instanceOfUvcCameraControllerState.copyWith(...)` or like so:`instanceOfUvcCameraControllerState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UvcCameraControllerStateCWProxy get copyWith =>
      _$UvcCameraControllerStateCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `UvcCameraControllerState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UvcCameraControllerState(...).copyWithNull(firstField: true, secondField: true)
  /// ````
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
