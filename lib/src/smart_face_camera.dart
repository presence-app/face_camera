import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../face_camera.dart';
import 'controllers/face_camera_state.dart';
import 'paints/face_painter.dart';
import 'paints/hole_painter.dart';
import 'res/builders.dart';

class SmartFaceCamera extends StatefulWidget {
  /// Set false to hide all controls.
  final bool showControls;

  /// Set false to hide capture control icon.
  final bool showCaptureControl;

  /// Set false to hide flash control control icon.
  final bool showFlashControl;

  /// Set false to hide camera lens control icon.
  final bool showCameraLensControl;

  /// Use this pass a message above the camera.
  final String? message;

  /// Style applied to the message widget.
  final TextStyle messageStyle;

  /// Use this to build custom widgets for capture control.
  final CaptureControlBuilder? captureControlBuilder;

  /// Use this to render a custom widget for camera lens control.
  final Widget? lensControlIcon;

  /// Use this to build custom widgets for flash control based on camera flash mode.
  final FlashControlBuilder? flashControlBuilder;

  /// Use this to build custom messages based on face position.
  final MessageBuilder? messageBuilder;

  /// Use this to change the shape of the face indicator.
  final IndicatorShape indicatorShape;

  /// Use this to pass an asset image when IndicatorShape is set to image.
  final String? indicatorAssetImage;

  /// Use this to build custom widgets for the face indicator
  final IndicatorBuilder? indicatorBuilder;

  /// Scale factor for the face indicator size. Default is 1.0 (100%).
  /// Use values like 0.8 for 80% size or 1.2 for 120% size.
  final double indicatorScale;

  /// Set true to automatically disable capture control widget when no face is detected.
  final bool autoDisableCaptureControl;

  /// The controller for the [SmartFaceCamera] widget.
  final FaceCameraController controller;

  /// How the camera preview should be inscribed into the space allocated during layout.
  final BoxFit fit;

  /// The aspect ratio of the camera preview. If null, uses the screen's aspect ratio.
  final double? aspectRatio;

  const SmartFaceCamera(
      {required this.controller,
      this.showControls = true,
      this.showCaptureControl = true,
      this.showFlashControl = true,
      this.showCameraLensControl = true,
      this.message,
      this.messageStyle = const TextStyle(
          fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
      this.captureControlBuilder,
      this.lensControlIcon,
      this.flashControlBuilder,
      this.messageBuilder,
      this.indicatorShape = IndicatorShape.defaultShape,
      this.indicatorAssetImage,
      this.indicatorBuilder,
      this.indicatorScale = 1.0,
      this.autoDisableCaptureControl = false,
      this.fit = BoxFit.fitHeight,
      this.aspectRatio,
      Key? key})
      : assert(
            indicatorShape != IndicatorShape.image ||
                indicatorAssetImage != null,
            'IndicatorAssetImage must be provided when IndicatorShape is set to image.'),
        super(key: key);

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    widget.controller.initialize();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stopImageStream();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      widget.controller.stopImageStream();
    } else if (state == AppLifecycleState.paused) {
      widget.controller.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      widget.controller.startImageStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ValueListenableBuilder<FaceCameraState>(
      valueListenable: widget.controller,
      builder: (BuildContext context, FaceCameraState value, Widget? child) {
        final CameraController? cameraController = value.cameraController;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (cameraController != null &&
                cameraController.value.isInitialized) ...[
              Transform.scale(
                scale: 1.0,
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio ?? size.aspectRatio,
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: widget.fit,
                      child: SizedBox(
                        width: size.width,
                        height: size.width * cameraController.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            _cameraDisplayWidget(value),
                            if (value.detectedFace != null &&
                                widget.indicatorShape !=
                                    IndicatorShape.none) ...[
                              SizedBox(
                                  width:
                                      cameraController.value.previewSize!.width,
                                  height: cameraController
                                      .value.previewSize!.height,
                                  child: widget.indicatorBuilder?.call(
                                          context,
                                          value.detectedFace,
                                          Size(
                                            cameraController
                                                .value.previewSize!.height,
                                            cameraController
                                                .value.previewSize!.width,
                                          )) ??
                                      CustomPaint(
                                        painter: FacePainter(
                                            face: value.detectedFace!.face,
                                            indicatorShape:
                                                widget.indicatorShape,
                                            indicatorAssetImage:
                                                widget.indicatorAssetImage,
                                            indicatorScale:
                                                widget.indicatorScale,
                                            imageSize: Size(
                                              cameraController
                                                  .value.previewSize!.height,
                                              cameraController
                                                  .value.previewSize!.width,
                                            )),
                                      ))
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
            if (widget.showControls) ...[
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showFlashControl) ...[
                        _flashControlWidget(value)
                      ],
                      if (widget.showCaptureControl) ...[
                        const SizedBox(width: 15),
                        _captureControlWidget(value),
                        const SizedBox(width: 15)
                      ],
                      if (widget.showCameraLensControl) ...[
                        _lensControlWidget()
                      ],
                    ],
                  ),
                ),
              )
            ]
          ],
        );
      },
    );
  }

  /// Render camera.
  Widget _cameraDisplayWidget(FaceCameraState value) {
    final CameraController? cameraController = value.cameraController;
    if (cameraController != null && cameraController.value.isInitialized) {
      return CameraPreview(
        cameraController,
        Platform.isIOS ? null : DeviceOrientation.portraitUp,
        child: Builder(builder: (context) {
          if (widget.messageBuilder != null) {
            return widget.messageBuilder!.call(context, value.detectedFace);
          }
          if (widget.message != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
              child: Text(widget.message!,
                  textAlign: TextAlign.center, style: widget.messageStyle),
            );
          }
          return const SizedBox.shrink();
        }),
      );
    }
    return const SizedBox.shrink();
  }

  /// Determines when to disable the capture control button.
  bool get _disableCapture =>
      widget.autoDisableCaptureControl &&
      widget.controller.value.detectedFace?.face == null;

  /// Determines the camera controls color.
  Color? get iconColor =>
      widget.controller.enableControls ? null : Theme.of(context).disabledColor;

  /// Display the control buttons to take pictures.
  Widget _captureControlWidget(FaceCameraState value) {
    final canCapture = widget.controller.enableControls &&
        !_disableCapture &&
        value.detectedFace?.wellPositioned == true;

    return IconButton(
      icon: widget.captureControlBuilder?.call(context, value.detectedFace) ??
          CircleAvatar(
              radius: 35,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.camera_alt, size: 35),
              )),
      onPressed: canCapture ? widget.controller.captureImage : null,
    );
  }

  /// Display the control buttons to switch between flash modes.
  Widget _flashControlWidget(FaceCameraState value) {
    final availableFlashMode = value.availableFlashMode;
    final currentFlashMode = value.currentFlashMode;
    final icon = availableFlashMode[currentFlashMode] == CameraFlashMode.always
        ? Icons.flash_on
        : availableFlashMode[currentFlashMode] == CameraFlashMode.off
            ? Icons.flash_off
            : Icons.flash_auto;

    return IconButton(
      icon: widget.flashControlBuilder
              ?.call(context, availableFlashMode[currentFlashMode]) ??
          CircleAvatar(
              radius: 25,
              foregroundColor: iconColor,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(icon, size: 25),
              )),
      onPressed: widget.controller.enableControls
          ? widget.controller.changeFlashMode
          : null,
    );
  }

  /// Display the control buttons to switch between camera lens.
  Widget _lensControlWidget() {
    return IconButton(
        icon: widget.lensControlIcon ??
            CircleAvatar(
                radius: 25,
                foregroundColor: iconColor,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.switch_camera_sharp, size: 25),
                )),
        onPressed: widget.controller.enableControls
            ? widget.controller.changeCameraLens
            : null);
  }
}
