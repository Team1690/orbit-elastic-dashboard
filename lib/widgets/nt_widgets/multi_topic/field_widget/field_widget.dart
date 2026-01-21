import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_painters.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

extension _SizeUtils on Size {
  Offset get toOffset => Offset(width, height);

  Size rotateBy(double angle) => Size(
    (width * cos(angle)).abs() + (height * sin(angle)).abs(),
    (width * sin(angle)).abs() + (height * cos(angle)).abs(),
  );
}

class FieldWidget extends NTWidget {
  static const String widgetType = 'Field';

  const FieldWidget({super.key});

  Offset _getTrajectoryPointOffset(
    FieldWidgetModel model, {
    required double x,
    required double y,
    required Offset fieldCenter,
    required double scaleReduction,
  }) {
    if (!x.isFinite) {
      x = 0;
    }
    if (!y.isFinite) {
      y = 0;
    }
    double xFromCenter =
        (x * model.field.pixelsPerMeterHorizontal - fieldCenter.dx) *
        scaleReduction;

    double yFromCenter =
        (fieldCenter.dy - (y * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    return Offset(xFromCenter, yFromCenter);
  }

  @override
  Widget build(BuildContext context) {
    FieldWidgetModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge(model.subscriptions),
        child: model.field.fieldImage,
        builder: (context, child) {
          List<Object?> robotPositionRaw = [
            model.robotXSubscription.value,
            model.robotYSubscription.value,
            model.robotHeadingSubscription.value,
          ];

          double robotX = 0;
          double robotY = 0;
          double robotTheta = 0;

          if (model.isPoseStruct(model.robotTopicName)) {
            List<int> poseBytes = robotPositionRaw.whereType<int>().toList();
            Pose2dStruct poseStruct = Pose2dStruct.valueFromBytes(
              Uint8List.fromList(poseBytes),
            );

            robotX = poseStruct.x;
            robotY = poseStruct.y;
            robotTheta = poseStruct.angle;
          } else {
            List<double> robotPosition = robotPositionRaw
                .whereType<double>()
                .toList();

            if (robotPosition.length >= 3) {
              robotX = robotPosition[0];
              robotY = robotPosition[1];
              robotTheta = radians(robotPosition[2]);
            }
          }

          Size size = Size(constraints.maxWidth, constraints.maxHeight);

          model.widgetSize = size;

          final imageSize = model.field.fieldImageSize ?? const Size(0, 0);

          double rotation = -radians(model.fieldRotation);

          final rotatedImageBoundingBox = imageSize.rotateBy(rotation);

          double scale = 1.0;

          if (rotatedImageBoundingBox.width > 0) {
            scale = size.width / rotatedImageBoundingBox.width;
          }

          if (rotatedImageBoundingBox.height > 0) {
            scale = min(scale, size.height / rotatedImageBoundingBox.height);
          }

          if (scale.isNaN) {
            scale = 0;
          }

          Size imageDisplaySize = imageSize * scale;

          Offset fieldCenter = model.field.center;

          if (!model.rendered &&
              model.widgetSize != null &&
              size != const Size(0, 0) &&
              size.width > 100.0 &&
              scale != 0.0 &&
              fieldCenter != const Offset(0.0, 0.0) &&
              model.field.fieldImageLoaded) {
            model.rendered = true;
          }

          if (!model.rendered && !isUnitTest) {
            Future.delayed(const Duration(milliseconds: 100), model.refresh);
          }

          List<List<Offset>> trajectoryPoints = [];
          if (model.showTrajectories) {
            for (NT4Subscription objectSubscription
                in model.otherObjectSubscriptions) {
              List<Object?>? objectPositionRaw = objectSubscription.value
                  ?.tryCast<List<Object?>>();

              if (objectPositionRaw == null) {
                continue;
              }

              bool isTrajectory = objectSubscription.topic
                  .toLowerCase()
                  .endsWith('trajectory');

              bool isStructArray = model.isPoseArrayStruct(
                objectSubscription.topic,
              );
              bool isStructObject =
                  model.isPoseStruct(objectSubscription.topic) || isStructArray;

              if (isStructObject) {
                isTrajectory =
                    isTrajectory ||
                    (isStructArray &&
                        objectPositionRaw.length ~/ Pose2dStruct.length > 8);
              } else {
                isTrajectory = isTrajectory || objectPositionRaw.length > 24;
              }

              if (!isTrajectory) {
                continue;
              }

              List<Offset> objectTrajectory = [];

              if (isStructObject) {
                List<int> structArrayBytes = objectPositionRaw
                    .whereType<int>()
                    .toList();
                List<Pose2dStruct> poseArray = Pose2dStruct.listFromBytes(
                  Uint8List.fromList(structArrayBytes),
                );
                for (Pose2dStruct pose in poseArray) {
                  objectTrajectory.add(
                    _getTrajectoryPointOffset(
                      model,
                      x: pose.x,
                      y: pose.y,
                      fieldCenter: fieldCenter,
                      scaleReduction: scale,
                    ),
                  );
                }
              } else {
                List<double> objectPosition = objectPositionRaw
                    .whereType<double>()
                    .toList();
                for (int i = 0; i < objectPosition.length - 2; i += 3) {
                  objectTrajectory.add(
                    _getTrajectoryPointOffset(
                      model,
                      x: objectPosition[i],
                      y: objectPosition[i + 1],
                      fieldCenter: fieldCenter,
                      scaleReduction: scale,
                    ),
                  );
                }
              }
              if (objectTrajectory.isNotEmpty) {
                trajectoryPoints.add(objectTrajectory);
              }
            }
          }

          final finalSize = rotatedImageBoundingBox * scale;

          return GestureDetector(
            onTapDown: (details) {
              if (model.ntConnection.isNT4Connected) {
                // The tap details are in the coordinate space of the GestureDetector,
                // which is the size of the whole widget. We need to translate
                // this to the coordinate space of the field itself.
                final tapInWidget = details.localPosition;

                // The field is centered in the widget, so translate the tap
                // to be relative to the center of the widget.
                final centerOfWidget = size.toOffset / 2.0;
                final tapFromCenter = tapInWidget - centerOfWidget;

                // The field is in a SizedBox of finalSize, so the tap
                // might be outside the field.
                if (!Rect.fromCenter(
                  center: Offset.zero,
                  width: finalSize.width,
                  height: finalSize.height,
                ).contains(tapFromCenter)) {
                  return;
                }

                // Now, go from the coordinate space of the centered field back
                // to the un-rotated, un-scaled field space.
                final angle = -radians(model.fieldRotation);
                final xUnrotated =
                    tapFromCenter.dx * cos(angle) -
                    tapFromCenter.dy * sin(angle);
                final yUnrotated =
                    tapFromCenter.dx * sin(angle) +
                    tapFromCenter.dy * cos(angle);

                // Un-mirror if necessary
                final xUnmirrored = model.allianceTopic.value
                    ? -xUnrotated
                    : xUnrotated;

                // Un-scale from display pixels to image pixels
                final xImage = xUnmirrored / scale;
                final yImage = yUnrotated / scale;

                // Go from image pixels relative to center to image pixels relative to TL
                final xImageFromTL = xImage + model.field.center.dx;
                final yImageFromTL = -yImage + model.field.center.dy;

                // Go from image pixels to meters
                final xMeters =
                    xImageFromTL / model.field.pixelsPerMeterHorizontal;
                final yMeters =
                    yImageFromTL / model.field.pixelsPerMeterVertical;

                model.commanderTopics.set(Offset(xMeters, yMeters));
              }
            },
            child: Center(
              child: SizedBox(
                width: finalSize.width,
                height: finalSize.height,
                child: ClipRect(
                  child: UnconstrainedBox(
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: (model.fieldRotation / 90.0).round(),
                        child: Transform(
                          transform: Matrix4.diagonal3Values(
                            model.allianceTopic.value ? -1 : 1,
                            1,
                            1,
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: imageDisplaySize.width,
                                height: imageDisplaySize.height,
                                child: child!,
                              ),
                              if (model.showTrajectories)
                                for (List<Offset> points in trajectoryPoints)
                                  CustomPaint(
                                    size: imageDisplaySize,
                                    painter: TrajectoryPainter(
                                      center: imageDisplaySize.toOffset / 2,
                                      color: model.trajectoryColor,
                                      points: points,
                                      strokeWidth:
                                          model.trajectoryPointSize *
                                          model.field.pixelsPerMeterHorizontal *
                                          scale,
                                    ),
                                  ),
                              if (model.showGamePieces)
                                CustomPaint(
                                  size: imageDisplaySize,
                                  painter: GamePiecePainter(
                                    center: imageDisplaySize.toOffset / 2,
                                    field: model.field,
                                    gamePieces: model.gamePieceTopics.value,
                                    gamePieceColor: model.gamePieceColor,
                                    bestGamePieceColor:
                                        model.bestGamePieceColor,
                                    markerSize: model.gamePieceMarkerSize,
                                    scale: scale,
                                  ),
                                ),
                              if (model.showVisionTargets)
                                CustomPaint(
                                  size: imageDisplaySize,
                                  painter: VisionPainter(
                                    center: imageDisplaySize.toOffset / 2,
                                    field: model.field,
                                    poses: [
                                      model.visionTopics.closeCamPose,
                                      model.visionTopics.farCamPose,
                                      model.visionTopics.leftCamPose,
                                      model.visionTopics.rightCamPose,
                                    ],
                                    statuses: [
                                      [
                                        model
                                            .visionTopics
                                            .closeCamLocation
                                            .value,
                                        model
                                            .visionTopics
                                            .closeCamHeading
                                            .value,
                                      ],
                                      [
                                        model.visionTopics.farCamLocation.value,
                                        model.visionTopics.farCamHeading.value,
                                      ],
                                      [
                                        model
                                            .visionTopics
                                            .leftCamLocation
                                            .value,
                                        model.visionTopics.leftCamHeading.value,
                                      ],
                                      [
                                        model
                                            .visionTopics
                                            .rightCamLocation
                                            .value,
                                        model
                                            .visionTopics
                                            .rightCamHeading
                                            .value,
                                      ],
                                    ],
                                    color: model.visionTargetColor,
                                    markerSize: model.visionMarkerSize,
                                    scale: scale,
                                  ),
                                ),
                              if (model.showOtherObjects)
                                CustomPaint(
                                  size: imageDisplaySize,
                                  painter: OtherObjectsPainter(
                                    center: imageDisplaySize.toOffset / 2,
                                    field: model.field,
                                    subscriptions:
                                        model.otherObjectSubscriptions,
                                    isPoseStruct: model.isPoseStruct,
                                    isPoseArrayStruct: model.isPoseArrayStruct,
                                    robotColor: model.robotColor,
                                    objectSize: model.otherObjectSize,
                                    scale: scale,
                                  ),
                                ),
                              CustomPaint(
                                size: imageDisplaySize,
                                painter: RobotPainter(
                                  center: imageDisplaySize.toOffset / 2,
                                  field: model.field,
                                  robotPose: Offset(robotX, robotY),
                                  robotAngle: robotTheta,
                                  robotSize: Size(
                                    model.robotWidthMeters,
                                    model.robotLengthMeters,
                                  ),
                                  robotColor: model.robotColor,
                                  robotImage: model.robotImage,
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
