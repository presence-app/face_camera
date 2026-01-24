import 'package:flutter/material.dart';

import '../../face_camera.dart';
import '../res/app_images.dart';

class FacePainter extends CustomPainter {
  FacePainter(
      {required this.imageSize,
      this.face,
      required this.indicatorShape,
      this.indicatorAssetImage,
      this.indicatorScale = 1.0});
  final Size imageSize;
  double? scaleX, scaleY;
  final Face? face;
  final IndicatorShape indicatorShape;
  final String? indicatorAssetImage;
  final double indicatorScale;
  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;

    Paint paint;

    // Check if face is well positioned using the same logic as face_identifier
    bool wellPositioned = true;

    // Check face size - should be 20-70% of image width, adjusted for indicator scale
    // If indicator is scaled down (e.g., 0.8), the acceptable face size range should be proportionally smaller
    final faceWidthRatio = face!.boundingBox.width / imageSize.width;
    final minRatio = 0.2 * indicatorScale;
    final maxRatio = 0.7 * indicatorScale;
    if (faceWidthRatio < minRatio || faceWidthRatio > maxRatio) {
      wellPositioned = false;
    }

    // Check head rotation (Y-axis) - relaxed to ±15 degrees for maximum flexibility
    if (face!.headEulerAngleY! > 15 || face!.headEulerAngleY! < -15) {
      wellPositioned = false;
    }

    // Check head tilt (Z-axis) - relaxed to ±15 degrees for maximum flexibility
    if (face!.headEulerAngleZ! > 15 || face!.headEulerAngleZ! < -15) {
      wellPositioned = false;
    }

    // Check for key facial landmarks (at least 3 out of 6 should be detected)
    final leftEar = face!.landmarks[FaceLandmarkType.leftEar];
    final rightEar = face!.landmarks[FaceLandmarkType.rightEar];
    final bottomMouth = face!.landmarks[FaceLandmarkType.bottomMouth];
    final rightMouth = face!.landmarks[FaceLandmarkType.rightMouth];
    final leftMouth = face!.landmarks[FaceLandmarkType.leftMouth];
    final noseBase = face!.landmarks[FaceLandmarkType.noseBase];

    int detectedLandmarks = 0;
    if (leftEar != null) detectedLandmarks++;
    if (rightEar != null) detectedLandmarks++;
    if (bottomMouth != null) detectedLandmarks++;
    if (rightMouth != null) detectedLandmarks++;
    if (leftMouth != null) detectedLandmarks++;
    if (noseBase != null) detectedLandmarks++;

    if (detectedLandmarks < 3) {
      wellPositioned = false;
    }

    // Check if eyes are reasonably open - relaxed threshold
    if (face!.leftEyeOpenProbability != null) {
      if (face!.leftEyeOpenProbability! < 0.3) {
        wellPositioned = false;
      }
    }

    if (face!.rightEyeOpenProbability != null) {
      if (face!.rightEyeOpenProbability! < 0.3) {
        wellPositioned = false;
      }
    }

    paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = wellPositioned ? Colors.green : Colors.red;

    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    switch (indicatorShape) {
      case IndicatorShape.defaultShape:
        canvas.drawPath(
          _defaultPath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              indicatorScale: indicatorScale),
          paint, // Adjust color as needed
        );
        break;
      case IndicatorShape.square:
        canvas.drawRRect(
            _scaleRect(
                rect: face!.boundingBox,
                widgetSize: size,
                scaleX: scaleX,
                scaleY: scaleY,
                indicatorScale: indicatorScale),
            paint);
        break;
      case IndicatorShape.circle:
        canvas.drawCircle(
          _circleOffset(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY),
          face!.boundingBox.width / 2 * scaleX! * indicatorScale,
          paint, // Adjust color as needed
        );
        break;
      case IndicatorShape.triangle:
      case IndicatorShape.triangleInverted:
        canvas.drawPath(
          _trianglePath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              indicatorScale: indicatorScale,
              isInverted: indicatorShape == IndicatorShape.triangleInverted),
          paint, // Adjust color as needed
        );
        break;
      case IndicatorShape.image:
        final AssetImage image =
            AssetImage(indicatorAssetImage ?? AppImages.faceNet);
        final ImageStream imageStream = image.resolve(ImageConfiguration.empty);

        imageStream.addListener(
            ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
          final rect = face!.boundingBox;
          final Rect destinationRect = Rect.fromPoints(
            Offset(size.width - rect.left.toDouble() * scaleX!,
                rect.top.toDouble() * scaleY!),
            Offset(size.width - rect.right.toDouble() * scaleX!,
                rect.bottom.toDouble() * scaleY!),
          );

          canvas.drawImageRect(
            imageInfo.image,
            Rect.fromLTRB(0, 0, imageInfo.image.width.toDouble(),
                imageInfo.image.height.toDouble()),
            destinationRect,
            Paint(),
          );
        }));
        break;
      case IndicatorShape.none:
        break;
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.face != face;
  }
}

Path _defaultPath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    double indicatorScale = 1.0}) {
  double cornerExtension =
      30.0; // Adjust the length of the corner extensions as needed

  double centerX = widgetSize.width - rect.center.dx * scaleX!;
  double centerY = rect.center.dy * scaleY!;
  // Increase size by 20% for better visibility
  double halfWidth = (rect.width * scaleX * indicatorScale * 1.2) / 2;
  double halfHeight = (rect.height * scaleY * indicatorScale * 1.2) / 2;

  double left = centerX - halfWidth;
  double right = centerX + halfWidth;
  double top = centerY - halfHeight;
  double bottom = centerY + halfHeight;

  return Path()
    // Top-left corner (L-shape)
    ..moveTo(left + cornerExtension, top)
    ..lineTo(left, top)
    ..lineTo(left, top + cornerExtension)
    // Top-right corner (L-shape)
    ..moveTo(right - cornerExtension, top)
    ..lineTo(right, top)
    ..lineTo(right, top + cornerExtension)
    // Bottom-left corner (L-shape)
    ..moveTo(left, bottom - cornerExtension)
    ..lineTo(left, bottom)
    ..lineTo(left + cornerExtension, bottom)
    // Bottom-right corner (L-shape)
    ..moveTo(right, bottom - cornerExtension)
    ..lineTo(right, bottom)
    ..lineTo(right - cornerExtension, bottom);
}

RRect _scaleRect(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    double indicatorScale = 1.0}) {
  double centerX = widgetSize.width - rect.center.dx * scaleX!;
  double centerY = rect.center.dy * scaleY!;
  // Increase size by 10% for better visibility
  double halfWidth = (rect.width * scaleX * indicatorScale * 1.1) / 2;
  double halfHeight = (rect.height * scaleY * indicatorScale * 1.1) / 2;

  return RRect.fromLTRBR(centerX - halfWidth, centerY - halfHeight,
      centerX + halfWidth, centerY + halfHeight, const Radius.circular(10));
}

Offset _circleOffset(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY}) {
  return Offset(
    (widgetSize.width - rect.center.dx * scaleX!),
    rect.center.dy * scaleY!,
  );
}

Path _trianglePath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    double indicatorScale = 1.0,
    bool isInverted = false}) {
  double centerX = widgetSize.width - rect.center.dx * scaleX!;
  double centerY = rect.center.dy * scaleY!;
  // Increase size by 10% for better visibility
  double halfWidth = (rect.width * scaleX * indicatorScale * 1.1) / 2;
  double halfHeight = (rect.height * scaleY * indicatorScale * 1.1) / 2;

  if (isInverted) {
    return Path()
      ..moveTo(centerX, centerY + halfHeight)
      ..lineTo(centerX - halfWidth, centerY - halfHeight)
      ..lineTo(centerX + halfWidth, centerY - halfHeight)
      ..close();
  }
  return Path()
    ..moveTo(centerX, centerY - halfHeight)
    ..lineTo(centerX - halfWidth, centerY + halfHeight)
    ..lineTo(centerX + halfWidth, centerY + halfHeight)
    ..close();
}
