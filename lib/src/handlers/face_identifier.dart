import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face_camera/src/extension/nv21_converter.dart';

import '../models/detected_image.dart';

class FaceIdentifier {
  static Future<DetectedFace?> scanImage(
      {required CameraImage cameraImage,
      required CameraController? controller,
      required FaceDetectorMode performanceMode}) async {
    final imageSize =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    DetectedFace? result;
    final face = await _detectFace(
        performanceMode: performanceMode,
        imageSize: imageSize,
        visionImage:
            _inputImageFromCameraImage(cameraImage, controller, orientations));
    if (face != null) {
      result = face;
    }

    return result;
  }

  static InputImage? _inputImageFromCameraImage(CameraImage image,
      CameraController? controller, Map<DeviceOrientation, int> orientations) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) {
        // Default to portrait up if orientation is not available
        rotationCompensation = orientations[DeviceOrientation.portraitUp]!;
      }
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;
    if (image.planes.isEmpty) return null;

    final bytes = Platform.isAndroid
        ? (image.planes.length >= 3
            ? image.getNv21Uint8List()
            : image.planes.first.bytes)
        : Uint8List.fromList(
            image.planes.fold(
                <int>[],
                (List<int> previousValue, element) =>
                    previousValue..addAll(element.bytes)),
          );

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: Platform.isIOS
            ? format
            : (image.planes.length >= 3 ? InputImageFormat.nv21 : format),
        bytesPerRow: image.planes.first.bytesPerRow, // used only in iOS
      ),
    );
  }

  static Future<DetectedFace?> _detectFace(
      {required InputImage? visionImage,
      required FaceDetectorMode performanceMode,
      required Size imageSize}) async {
    if (visionImage == null) return null;
    final options = FaceDetectorOptions(
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: performanceMode);
    final faceDetector = FaceDetector(options: options);
    try {
      final List<Face> faces = await faceDetector.processImage(visionImage);
      final faceDetect = _extractFace(faces, imageSize);
      return faceDetect;
    } catch (error) {
      debugPrint(error.toString());
      return null;
    }
  }

  static _extractFace(List<Face> faces, Size imageSize) {
    //List<Rect> rect = [];
    bool wellPositioned = faces.isNotEmpty;
    Face? detectedFace;

    for (Face face in faces) {
      // rect.add(face.boundingBox);
      detectedFace = face;

      // Check face size - should be 20-70% of image width
      final faceWidthRatio = face.boundingBox.width / imageSize.width;
      if (faceWidthRatio < 0.2 || faceWidthRatio > 0.7) {
        wellPositioned = false;
      }

      // Head is rotated to the right rotY degrees (relaxed to ±15 for maximum flexibility)
      if (face.headEulerAngleY! > 15 || face.headEulerAngleY! < -15) {
        wellPositioned = false;
      }

      // Head is tilted sideways rotZ degrees (relaxed to ±15 for maximum flexibility)
      if (face.headEulerAngleZ! > 15 || face.headEulerAngleZ! < -15) {
        wellPositioned = false;
      }

      // Check for key facial landmarks (at least 3 out of 6 should be detected)
      final FaceLandmark? leftEar = face.landmarks[FaceLandmarkType.leftEar];
      final FaceLandmark? rightEar = face.landmarks[FaceLandmarkType.rightEar];
      final FaceLandmark? bottomMouth =
          face.landmarks[FaceLandmarkType.bottomMouth];
      final FaceLandmark? rightMouth =
          face.landmarks[FaceLandmarkType.rightMouth];
      final FaceLandmark? leftMouth =
          face.landmarks[FaceLandmarkType.leftMouth];
      final FaceLandmark? noseBase = face.landmarks[FaceLandmarkType.noseBase];

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

      // Check if eyes are reasonably open (relaxed threshold)
      if (face.leftEyeOpenProbability != null) {
        if (face.leftEyeOpenProbability! < 0.3) {
          wellPositioned = false;
        }
      }

      if (face.rightEyeOpenProbability != null) {
        if (face.rightEyeOpenProbability! < 0.3) {
          wellPositioned = false;
        }
      }

      if (wellPositioned) {
        break;
      }
    }

    return DetectedFace(
      wellPositioned: wellPositioned,
      face: detectedFace,
    );
  }
}
