import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt_connection.dart';

// Manages a single NT subscription and its value.
class SubscribedTopic<T extends Object?> {
  final NTConnection ntConnection;
  final String topic;
  final T defaultValue;
  final double period;

  late NT4Subscription subscription;

  SubscribedTopic({
    required this.ntConnection,
    required this.topic,
    required this.defaultValue,
    this.period = 0.1,
  });

  void subscribe() {
    subscription = ntConnection.subscribe(topic, period);
  }

  void unsubscribe() {
    ntConnection.unSubscribe(subscription);
  }

  T get value {
    final subValue = subscription.value;
    if (subValue is T) {
      return subValue;
    }
    return defaultValue;
  }
}

// Manages all vision-related NT topics.
class VisionTopics {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<double> closeCamX;
  late final SubscribedTopic<double> closeCamY;
  late final SubscribedTopic<double> farCamX;
  late final SubscribedTopic<double> farCamY;
  late final SubscribedTopic<double> leftCamX;
  late final SubscribedTopic<double> leftCamY;
  late final SubscribedTopic<double> rightCamX;
  late final SubscribedTopic<double> rightCamY;

  late final SubscribedTopic<bool> rightCamLocation;
  late final SubscribedTopic<bool> rightCamHeading;
  late final SubscribedTopic<bool> leftCamLocation;
  late final SubscribedTopic<bool> leftCamHeading;
  late final SubscribedTopic<bool> closeCamLocation;
  late final SubscribedTopic<bool> closeCamHeading;
  late final SubscribedTopic<bool> farCamLocation;
  late final SubscribedTopic<bool> farCamHeading;

  late final List<SubscribedTopic> topics;

  VisionTopics({required this.ntConnection, this.period = 0.1}) {
    closeCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/CloseCamX',
      defaultValue: 0.0,
    );
    closeCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/CloseCamY',
      defaultValue: 0.0,
    );
    farCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/FarCamX',
      defaultValue: 0.0,
    );
    farCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/FarCamY',
      defaultValue: 0.0,
    );
    leftCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/LeftCamX',
      defaultValue: 0.0,
    );
    leftCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/LeftCamY',
      defaultValue: 0.0,
    );
    rightCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/RightCamX',
      defaultValue: 0.0,
    );
    rightCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/RightCamY',
      defaultValue: 0.0,
    );

    rightCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/RightLime/Location',
      defaultValue: false,
    );
    rightCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/RightLime/Heading',
      defaultValue: false,
    );
    leftCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/LeftLime/Location',
      defaultValue: false,
    );
    leftCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/LeftLime/Heading',
      defaultValue: false,
    );
    closeCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/CloseCam/Location',
      defaultValue: false,
    );
    closeCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/CloseCam/Heading',
      defaultValue: false,
    );
    farCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/FarCam/Location',
      defaultValue: false,
    );
    farCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/FarCam/Heading',
      defaultValue: false,
    );

    topics = [
      closeCamX,
      closeCamY,
      farCamX,
      farCamY,
      leftCamX,
      leftCamY,
      rightCamX,
      rightCamY,
      rightCamLocation,
      rightCamHeading,
      leftCamLocation,
      leftCamHeading,
      closeCamLocation,
      closeCamHeading,
      farCamLocation,
      farCamHeading,
    ];
  }

  void initialize() {
    for (var topic in topics) {
      topic.subscribe();
    }
  }

  void dispose() {
    for (var topic in topics) {
      topic.unsubscribe();
    }
  }

  List<Listenable> get listenables =>
      topics.map((topic) => topic.subscription).toList();

  Offset get closeCamPose => Offset(closeCamX.value, closeCamY.value);
  Offset get farCamPose => Offset(farCamX.value, farCamY.value);
  Offset get leftCamPose => Offset(leftCamX.value, leftCamY.value);
  Offset get rightCamPose => Offset(rightCamX.value, rightCamY.value);
}

// Manages all game-piece-related NT topics.
class GamePieceTopics {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<List<Object?>> gamePieces;

  GamePieceTopics({required this.ntConnection, this.period = 0.1}) {
    gamePieces = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/GamePiecePos',
      defaultValue: [],
    );
  }

  void initialize() => gamePieces.subscribe();
  void dispose() => gamePieces.unsubscribe();

  List<Listenable> get listenables => [gamePieces.subscription];

  List<Offset> get value {
    List<String> raw = gamePieces.value.whereType<String>().toList();
    if (raw.isEmpty) {
      return [];
    }

    try {
      return raw
          .map((e) => e.split(' '))
          .map((e) => Offset(double.parse(e[1]), double.parse(e[3])))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// Manages the FMS alliance color topic.
class AllianceTopic {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<bool> isRedAlliance;

  AllianceTopic({required this.ntConnection, this.period = 0.1}) {
    isRedAlliance = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/FMSInfo/IsRedAlliance',
      defaultValue: false,
    );
  }

  void initialize() => isRedAlliance.subscribe();
  void dispose() => isRedAlliance.unsubscribe();

  List<Listenable> get listenables => [isRedAlliance.subscription];

  bool get value => isRedAlliance.value;
}

// Manages topics for commanding the robot pose.
class CommanderTopics {
  final NTConnection ntConnection;

  late final NT4Topic robotX;
  late final NT4Topic robotY;
  late final NT4Topic setNewPose;

  CommanderTopics({required this.ntConnection}) {
    robotX = ntConnection.publishNewTopic(
      '/Match/Commander/RobotPosResetX',
      NT4Type.double(),
    );
    robotY = ntConnection.publishNewTopic(
      '/Match/Commander/RobotPosResetY',
      NT4Type.double(),
    );
    setNewPose = ntConnection.publishNewTopic(
      '/Match/Commander/NewPosData',
      NT4Type.boolean(),
    );
  }

  void unpublish() {
    ntConnection.unpublishTopic(robotX);
    ntConnection.unpublishTopic(robotY);
    ntConnection.unpublishTopic(setNewPose);
  }

  void set(Offset pose) {
    ntConnection.updateDataFromTopic(robotX, pose.dx);
    ntConnection.updateDataFromTopic(robotY, pose.dy);
    ntConnection.updateDataFromTopic(setNewPose, true);
  }
}

extension _SizeUtils on Size {
  Offset get toOffset => Offset(width, height);

  Size rotateBy(double angle) => Size(
    (width * cos(angle) - height * sin(angle)).abs(),
    (height * cos(angle) + width * sin(angle)).abs(),
  );
}

class FieldWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = 'Field';

  String get robotTopicName => '$topic/Robot';
  late NT4Subscription robotSubscription;
  ui.Image? _robotImage;

  final List<String> _otherObjectTopics = [];
  final List<NT4Subscription> _otherObjectSubscriptions = [];

  late final VisionTopics visionTopics;
  late final GamePieceTopics gamePieceTopics;
  late final AllianceTopic allianceTopic;
  late final CommanderTopics commanderTopics;

  @override
  List<NT4Subscription> get subscriptions => [
    robotSubscription,
    ..._otherObjectSubscriptions,
    ...visionTopics.listenables.whereType<NT4Subscription>(),
    ...gamePieceTopics.listenables.whereType<NT4Subscription>(),
    ...allianceTopic.listenables.whereType<NT4Subscription>(),
  ];

  bool rendered = false;

  late Function(NT4Topic topic) topicAnnounceListener;

  static const String _defaultGame = 'Crescendo';
  String _fieldGame = _defaultGame;
  late Field _field;

  String? _robotImagePath;
  double _robotWidthMeters = 0.85;
  double _robotLengthMeters = 0.85;

  bool _showOtherObjects = true;
  bool _showTrajectories = true;

  bool _showVisionTargets = false;
  bool _showGamePieces = false;

  double _fieldRotation = 0.0;

  Color _robotColor = Colors.red;
  Color _trajectoryColor = Colors.white;
  Color _visionTargetColor = Colors.green;
  Color _gamePieceColor = Colors.yellow;
  Color _bestGamePieceColor = Colors.orange;

  final double _otherObjectSize = 0.55;
  final double _trajectoryPointSize = 0.08;
  final double _visionMarkerSize = 15.0;
  final double _gamePieceMarkerSize = 15.0;

  Size? widgetSize;

  ui.Image? get robotImage => _robotImage;

  String? get robotImagePath => _robotImagePath;

  set robotImagePath(String? value) {
    _robotImagePath = value;
    _loadImage();
    refresh();
  }

  double get robotWidthMeters => _robotWidthMeters;

  set robotWidthMeters(double value) {
    _robotWidthMeters = value;
    refresh();
  }

  double get robotLengthMeters => _robotLengthMeters;

  set robotLengthMeters(double value) {
    _robotLengthMeters = value;
    refresh();
  }

  bool get showOtherObjects => _showOtherObjects;

  set showOtherObjects(bool value) {
    _showOtherObjects = value;
    refresh();
  }

  bool get showTrajectories => _showTrajectories;

  set showTrajectories(bool value) {
    _showTrajectories = value;
    refresh();
  }

  bool get showVisionTargets => _showVisionTargets;

  set showVisionTargets(bool value) {
    _showVisionTargets = value;
    refresh();
  }

  bool get showGamePieces => _showGamePieces;

  set showGamePieces(bool value) {
    _showGamePieces = value;
    refresh();
  }

  double get fieldRotation => _fieldRotation;

  set fieldRotation(double value) {
    _fieldRotation = value;
    refresh();
  }

  Color get robotColor => _robotColor;

  set robotColor(Color value) {
    _robotColor = value;
    refresh();
  }

  Color get trajectoryColor => _trajectoryColor;

  set trajectoryColor(Color value) {
    _trajectoryColor = value;
    refresh();
  }

  Color get visionTargetColor => _visionTargetColor;

  set visionTargetColor(Color value) {
    _visionTargetColor = value;
    refresh();
  }

  Color get gamePieceColor => _gamePieceColor;

  set gamePieceColor(Color value) {
    _gamePieceColor = value;
    refresh();
  }

  Color get bestGamePieceColor => _bestGamePieceColor;

  set bestGamePieceColor(Color value) {
    _bestGamePieceColor = value;
    refresh();
  }

  double get otherObjectSize => _otherObjectSize;

  double get trajectoryPointSize => _trajectoryPointSize;

  double get visionMarkerSize => _visionMarkerSize;

  double get gamePieceMarkerSize => _gamePieceMarkerSize;

  Field get field => _field;

  bool isPoseStruct(String topic) =>
      ntConnection.getTopicFromName(topic)?.type.serialize() == 'struct:Pose2d';

  bool isPoseArrayStruct(String topic) =>
      ntConnection.getTopicFromName(topic)?.type.serialize() ==
      'struct:Pose2d[]';

  FieldWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String? fieldGame,
    String? robotImagePath,
    bool showOtherObjects = true,
    bool showTrajectories = true,
    bool showVisionTargets = false,
    bool showGamePieces = false,
    double robotWidthMeters = 0.85,
    double robotLengthMeters = 0.85,
    double fieldRotation = 0.0,
    Color robotColor = Colors.red,
    Color trajectoryColor = Colors.white,
    Color visionTargetColor = Colors.green,
    Color gamePieceColor = Colors.yellow,
    Color bestGamePieceColor = Colors.orange,
    super.period,
  }) : _showTrajectories = showTrajectories,
       _showOtherObjects = showOtherObjects,
       _showVisionTargets = showVisionTargets,
       _showGamePieces = showGamePieces,
       _robotImagePath = robotImagePath,
       _robotWidthMeters = robotWidthMeters,
       _robotLengthMeters = robotLengthMeters,
       _fieldRotation = fieldRotation,
       _robotColor = robotColor,
       _trajectoryColor = trajectoryColor,
       _visionTargetColor = visionTargetColor,
       _gamePieceColor = gamePieceColor,
       _bestGamePieceColor = bestGamePieceColor,
       super() {
    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    final Field? field = FieldImages.getFieldFromGame(_fieldGame);

    if (field == null) {
      if (FieldImages.fields.isNotEmpty) {
        _field = FieldImages.fields.first;
      } else {
        throw Exception('No field images loaded, cannot create Field Widget');
      }
    } else {
      _field = field;
    }

    visionTopics = VisionTopics(ntConnection: ntConnection, period: period);
    gamePieceTopics = GamePieceTopics(
      ntConnection: ntConnection,
      period: period,
    );
    allianceTopic = AllianceTopic(ntConnection: ntConnection, period: period);
    commanderTopics = CommanderTopics(ntConnection: ntConnection);
  }

  FieldWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    visionTopics = VisionTopics(
      ntConnection: ntConnection,
      period: super.period,
    );
    gamePieceTopics = GamePieceTopics(
      ntConnection: ntConnection,
      period: super.period,
    );
    allianceTopic = AllianceTopic(
      ntConnection: ntConnection,
      period: super.period,
    );
    commanderTopics = CommanderTopics(ntConnection: ntConnection);

    _fieldGame = tryCast(jsonData['field_game']) ?? _fieldGame;

    _robotImagePath = tryCast(jsonData['robot_image_path']);
    _robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.85;
    _robotLengthMeters =
        tryCast(jsonData['robot_length']) ??
        tryCast(jsonData['robot_height']) ??
        0.85;

    _showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    _showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;
    _showVisionTargets = tryCast(jsonData['show_vision_targets']) ?? false;
    _showGamePieces = tryCast(jsonData['show_game_pieces']) ?? false;

    _fieldRotation = tryCast(jsonData['field_rotation']) ?? 0.0;

    _robotColor = Color(
      tryCast(jsonData['robot_color']) ?? Colors.red.toARGB32(),
    );
    _trajectoryColor = Color(
      tryCast(jsonData['trajectory_color']) ?? Colors.white.toARGB32(),
    );
    _visionTargetColor = Color(
      tryCast(jsonData['vision_target_color']) ?? Colors.green.toARGB32(),
    );
    _gamePieceColor = Color(
      tryCast(jsonData['game_piece_color']) ?? Colors.yellow.toARGB32(),
    );
    _bestGamePieceColor = Color(
      tryCast(jsonData['best_game_piece_color']) ?? Colors.orange.toARGB32(),
    );

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    final Field? field = FieldImages.getFieldFromGame(_fieldGame);

    if (field == null) {
      if (FieldImages.fields.isNotEmpty) {
        _field = FieldImages.fields.first;
      } else {
        throw Exception('No field images loaded, cannot create Field Widget');
      }
    } else {
      _field = field;
    }
  }

  @override
  void init() {
    super.init();
    _loadImage();

    topicAnnounceListener = (nt4Topic) {
      if (nt4Topic.name.startsWith(topic) &&
          !nt4Topic.name.endsWith('Robot') &&
          !nt4Topic.name.contains('.') &&
          !_otherObjectTopics.contains(nt4Topic.name)) {
        _otherObjectTopics.add(nt4Topic.name);
        _otherObjectSubscriptions.add(
          ntConnection.subscribe(nt4Topic.name, super.period),
        );
        refresh();
      }
    };

    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  Future<void> _loadImage() async {
    if (_robotImagePath == null || _robotImagePath!.isEmpty) {
      _robotImage = null;
      return;
    }

    try {
      final Image assetImage = Image.asset(_robotImagePath!);

      final Completer<ui.Image> completer = Completer<ui.Image>();
      assetImage.image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((info, _) {
              completer.complete(info.image);
            }),
          );

      _robotImage = await completer.future;
      refresh();
    } catch (e) {
      _robotImage = null;
    }
  }

  @override
  void initializeSubscriptions() {
    _otherObjectSubscriptions.clear();

    robotSubscription = ntConnection.subscribe(robotTopicName, super.period);

    visionTopics.initialize();
    gamePieceTopics.initialize();
    allianceTopic.initialize();
  }

  @override
  void resetSubscription() {
    _otherObjectTopics.clear();

    super.resetSubscription();

    visionTopics.dispose();
    gamePieceTopics.dispose();
    allianceTopic.dispose();
    commanderTopics.unpublish();

    ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void softDispose({bool deleting = false}) async {
    super.softDispose(deleting: deleting);

    if (deleting) {
      await _field.dispose();
      ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
      visionTopics.dispose();
      gamePieceTopics.dispose();
      allianceTopic.dispose();
      commanderTopics.unpublish();
    }

    widgetSize = null;
    rendered = false;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'field_game': _fieldGame,
    'robot_image_path': _robotImagePath,
    'robot_width': _robotWidthMeters,
    'robot_length': _robotLengthMeters,
    'show_other_objects': _showOtherObjects,
    'show_trajectories': _showTrajectories,
    'show_vision_targets': _showVisionTargets,
    'show_game_pieces': _showGamePieces,
    'field_rotation': _fieldRotation,
    'robot_color': robotColor.toARGB32(),
    'trajectory_color': trajectoryColor.toARGB32(),
    'vision_target_color': _visionTargetColor.toARGB32(),
    'game_piece_color': _gamePieceColor.toARGB32(),
    'best_game_piece_color': _bestGamePieceColor.toARGB32(),
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Center(
      child: RichText(
        text: TextSpan(
          text: 'Field Image (',
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            WidgetSpan(
              child: Tooltip(
                waitDuration: const Duration(milliseconds: 750),
                richMessage: WidgetSpan(
                  child: Builder(
                    builder: (context) => Text(
                      _field.sourceURL ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.black),
                    ),
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    text: 'Source',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        if (_field.sourceURL == null) {
                          return;
                        }
                        Uri? url = Uri.tryParse(_field.sourceURL!);
                        if (url == null) {
                          return;
                        }
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                  ),
                ),
              ),
            ),
            TextSpan(
              text: ')',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
    DialogDropdownChooser<String?>(
      onSelectionChanged: (value) async {
        if (value == null) {
          return;
        }

        Field? newField = FieldImages.getFieldFromGame(value);

        if (newField == null) {
          return;
        }

        _fieldGame = value;
        await _field.dispose();
        _field = newField;

        widgetSize = null;
        rendered = false;

        refresh();
      },
      choices: FieldImages.fields.map((e) => e.game).toList(),
      initialValue: _field.game,
    ),
    const SizedBox(height: 5),
    DialogTextInput(
      onSubmit: (value) {
        robotImagePath = value;
      },
      label: 'Robot Image Path',
      initialText: _robotImagePath ?? '',
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newWidth = double.tryParse(value);

              if (newWidth == null) {
                return;
              }
              robotWidthMeters = newWidth;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Robot Width (meters)',
            initialText: _robotWidthMeters.toString(),
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newLength = double.tryParse(value);

              if (newLength == null) {
                return;
              }
              robotLengthMeters = newLength;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Robot Length (meters)',
            initialText: _robotLengthMeters.toString(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Non-Robot Objects',
            initialValue: _showOtherObjects,
            onToggle: (value) {
              showOtherObjects = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Trajectories',
            initialValue: _showTrajectories,
            onToggle: (value) {
              showTrajectories = value;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Vision Targets',
            initialValue: _showVisionTargets,
            onToggle: (value) {
              showVisionTargets = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Game Pieces',
            initialValue: _showGamePieces,
            onToggle: (value) {
              showGamePieces = value;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Left'),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
              onPressed: () {
                double newRotation = fieldRotation - 90;
                if (newRotation < -180) {
                  newRotation += 360;
                }
                fieldRotation = newRotation;
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Right'),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              onPressed: () {
                double newRotation = fieldRotation + 90;
                if (newRotation > 180) {
                  newRotation -= 360;
                }
                fieldRotation = newRotation;
              },
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                robotColor = color;
              },
              label: 'Robot Color',
              initialColor: robotColor,
              defaultColor: Colors.red,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                trajectoryColor = color;
              },
              label: 'Trajectory Color',
              initialColor: trajectoryColor,
              defaultColor: Colors.white,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                visionTargetColor = color;
              },
              label: 'Vision Target Color',
              initialColor: _visionTargetColor,
              defaultColor: Colors.green,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                gamePieceColor = color;
              },
              label: 'Game Piece Color',
              initialColor: _gamePieceColor,
              defaultColor: Colors.yellow,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                bestGamePieceColor = color;
              },
              label: 'Best Game Piece Color',
              initialColor: _bestGamePieceColor,
              defaultColor: Colors.orange,
            ),
          ),
        ),
      ],
    ),
  ];
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
          List<Object?> robotPositionRaw =
              model.robotSubscription.value?.tryCast<List<Object?>>() ?? [];

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

          FittedSizes fittedSizes = applyBoxFit(
            BoxFit.contain,
            model.field.fieldImageSize ?? const Size(0, 0),
            size,
          );

          FittedSizes rotatedFittedSizes = applyBoxFit(
            BoxFit.contain,
            model.field.fieldImageSize?.rotateBy(
                  -radians(model.fieldRotation),
                ) ??
                const Size(0, 0),
            size,
          );

          Offset fittedCenter = fittedSizes.destination.toOffset / 2;
          Offset fieldCenter = model.field.center;

          double scaleReduction =
              (fittedSizes.destination.width / fittedSizes.source.width);
          double rotatedScaleReduction =
              (rotatedFittedSizes.destination.width /
              rotatedFittedSizes.source.width);

          if (scaleReduction.isNaN) {
            scaleReduction = 0;
          }
          if (rotatedScaleReduction.isNaN) {
            rotatedScaleReduction = 0;
          }

          if (!model.rendered &&
              model.widgetSize != null &&
              size != const Size(0, 0) &&
              size.width > 100.0 &&
              scaleReduction != 0.0 &&
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
                in model._otherObjectSubscriptions) {
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
                      scaleReduction: scaleReduction,
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
                      scaleReduction: scaleReduction,
                    ),
                  );
                }
              }
              if (objectTrajectory.isNotEmpty) {
                trajectoryPoints.add(objectTrajectory);
              }
            }
          }

          return GestureDetector(
            onTapDown: (details) {
              if (model.ntConnection.isNT4Connected) {
                Offset tapPosition = details.localPosition;
                double realX =
                    (tapPosition.dx - fittedCenter.dx) /
                        scaleReduction /
                        model.field.pixelsPerMeterHorizontal +
                    model.field.center.dx /
                        model.field.pixelsPerMeterHorizontal;
                double realY =
                    (fittedCenter.dy - tapPosition.dy) /
                        scaleReduction /
                        model.field.pixelsPerMeterVertical +
                    model.field.center.dy / model.field.pixelsPerMeterVertical;

                model.commanderTopics.set(Offset(realX, realY));
              }
            },
            child: Transform.scale(
              scale: rotatedScaleReduction / scaleReduction,
              child: Transform.rotate(
                angle: radians(model.fieldRotation),
                child: Transform(
                  transform: Matrix4.diagonal3Values(
                    1,
                    model.allianceTopic.value ? -1 : 1,
                    1,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: fittedSizes.destination.width,
                        height: fittedSizes.destination.height,
                        child: child!,
                      ),
                      if (model.showTrajectories)
                        for (List<Offset> points in trajectoryPoints)
                          CustomPaint(
                            size: fittedSizes.destination,
                            painter: TrajectoryPainter(
                              center: fittedCenter,
                              color: model.trajectoryColor,
                              points: points,
                              strokeWidth:
                                  model.trajectoryPointSize *
                                  model.field.pixelsPerMeterHorizontal *
                                  scaleReduction,
                            ),
                          ),
                      if (model.showGamePieces)
                        CustomPaint(
                          size: fittedSizes.destination,
                          painter: GamePiecePainter(
                            center: fittedCenter,
                            field: model.field,
                            gamePieces: model.gamePieceTopics.value,
                            gamePieceColor: model.gamePieceColor,
                            bestGamePieceColor: model.bestGamePieceColor,
                            markerSize: model.gamePieceMarkerSize,
                            scale: scaleReduction,
                          ),
                        ),
                      if (model.showVisionTargets)
                        CustomPaint(
                          size: fittedSizes.destination,
                          painter: VisionPainter(
                            center: fittedCenter,
                            field: model.field,
                            poses: [
                              model.visionTopics.closeCamPose,
                              model.visionTopics.farCamPose,
                              model.visionTopics.leftCamPose,
                              model.visionTopics.rightCamPose,
                            ],
                            statuses: [
                              [
                                model.visionTopics.closeCamLocation.value,
                                model.visionTopics.closeCamHeading.value,
                              ],
                              [
                                model.visionTopics.farCamLocation.value,
                                model.visionTopics.farCamHeading.value,
                              ],
                              [
                                model.visionTopics.leftCamLocation.value,
                                model.visionTopics.leftCamHeading.value,
                              ],
                              [
                                model.visionTopics.rightCamLocation.value,
                                model.visionTopics.rightCamHeading.value,
                              ],
                            ],
                            color: model.visionTargetColor,
                            markerSize: model.visionMarkerSize,
                            scale: scaleReduction,
                          ),
                        ),
                      if (model.showOtherObjects)
                        CustomPaint(
                          size: fittedSizes.destination,
                          painter: OtherObjectsPainter(
                            center: fittedCenter,
                            field: model.field,
                            subscriptions: model._otherObjectSubscriptions,
                            isPoseStruct: model.isPoseStruct,
                            isPoseArrayStruct: model.isPoseArrayStruct,
                            robotColor: model.robotColor,
                            objectSize: model.otherObjectSize,
                            scale: scaleReduction,
                          ),
                        ),
                      CustomPaint(
                        size: fittedSizes.destination,
                        painter: RobotPainter(
                          center: fittedCenter,
                          field: model.field,
                          robotPose: Offset(robotX, robotY),
                          robotAngle: robotTheta,
                          robotSize: Size(
                            model.robotWidthMeters,
                            model.robotLengthMeters,
                          ),
                          robotColor: model.robotColor,
                          robotImage: model.robotImage,
                          scale: scaleReduction,
                        ),
                      ),
                    ],
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

class RobotPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final Offset robotPose;
  final double robotAngle;
  final Size robotSize;
  final Color robotColor;
  final ui.Image? robotImage;
  final double scale;

  RobotPainter({
    required this.center,
    required this.field,
    required this.robotPose,
    required this.robotAngle,
    required this.robotSize,
    required this.robotColor,
    required this.robotImage,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double x = robotPose.dx;
    double y = robotPose.dy;
    double angle = robotAngle;

    if (!x.isFinite || x.isNaN) x = 0;
    if (!y.isFinite || y.isNaN) y = 0;
    if (!angle.isFinite || angle.isNaN) angle = 0;

    double xFromCenter =
        (x * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
    double yFromCenter =
        (field.center.dy - (y * field.pixelsPerMeterVertical)) * scale;

    double width = robotSize.width * field.pixelsPerMeterHorizontal * scale;
    double length = robotSize.height * field.pixelsPerMeterVertical * scale;

    canvas.save();
    canvas.translate(center.dx + xFromCenter, center.dy + yFromCenter);
    canvas.rotate(-angle);

    if (robotImage != null) {
      final ui.Rect outputRect = Rect.fromCenter(
        center: Offset.zero,
        width: length,
        height: width,
      );
      final Size imageSize = Size(
        robotImage!.width.toDouble(),
        robotImage!.height.toDouble(),
      );
      final FittedSizes fittedSizes = applyBoxFit(
        BoxFit.cover,
        imageSize,
        outputRect.size,
      );
      final Rect sourceRect = Alignment.center.inscribe(
        fittedSizes.source,
        Offset.zero & imageSize,
      );
      canvas.drawImageRect(robotImage!, sourceRect, outputRect, Paint());
    } else {
      // Fallback to drawing a shape if no image is provided
      final Paint paint = Paint()
        ..color = robotColor
        ..style = PaintingStyle.fill;
      final Rect robotRect = Rect.fromCenter(
        center: Offset.zero,
        width: length,
        height: width,
      );
      canvas.drawRect(robotRect, paint);

      // Draw a triangle for heading
      final Paint trianglePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final Path trianglePath = Path()
        ..moveTo(length / 2, 0)
        ..lineTo(length / 4, -width / 4)
        ..lineTo(length / 4, width / 4)
        ..close();
      canvas.drawPath(trianglePath, trianglePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPainter oldDelegate) =>
      oldDelegate.robotPose != robotPose ||
      oldDelegate.robotAngle != robotAngle ||
      oldDelegate.robotSize != robotSize ||
      oldDelegate.robotColor != robotColor ||
      oldDelegate.robotImage != robotImage ||
      oldDelegate.scale != scale;
}

class VisionPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<Offset> poses;
  final List<List<bool>> statuses;
  final Color color;
  final double markerSize;
  final double scale;

  VisionPainter({
    required this.center,
    required this.field,
    required this.poses,
    required this.statuses,
    required this.color,
    required this.markerSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < poses.length; i++) {
      final Offset pose = poses[i];
      final bool locationAligned = statuses[i][0];
      final bool headingAligned = statuses[i][1];

      double xFromCenter =
          (pose.dx * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
      double yFromCenter =
          (field.center.dy - (pose.dy * field.pixelsPerMeterVertical)) * scale;

      final Offset markerCenter = Offset(
        center.dx + xFromCenter,
        center.dy + yFromCenter,
      );

      if (locationAligned) {
        if (headingAligned) {
          // Triangle
          final Path trianglePath = Path()
            ..moveTo(markerCenter.dx, markerCenter.dy - markerSize / 2)
            ..lineTo(
              markerCenter.dx + markerSize / 2,
              markerCenter.dy + markerSize / 2,
            )
            ..lineTo(
              markerCenter.dx - markerSize / 2,
              markerCenter.dy + markerSize / 2,
            )
            ..close();
          canvas.drawPath(trianglePath, paint);
        } else {
          // Circle
          canvas.drawCircle(markerCenter, markerSize / 2, paint);
        }
      } else {
        // Rectangle
        final Rect rect = Rect.fromCenter(
          center: markerCenter,
          width: markerSize,
          height: markerSize,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant VisionPainter oldDelegate) =>
      oldDelegate.poses != poses ||
      oldDelegate.statuses != statuses ||
      oldDelegate.color != color;
}

class GamePiecePainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<Offset> gamePieces;
  final Color gamePieceColor;
  final Color bestGamePieceColor;
  final double markerSize;
  final double scale;

  GamePiecePainter({
    required this.center,
    required this.field,
    required this.gamePieces,
    required this.gamePieceColor,
    required this.bestGamePieceColor,
    required this.markerSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < gamePieces.length; i++) {
      final Offset piece = gamePieces[i];
      final bool isBest = i == 0;

      paint.color = isBest ? bestGamePieceColor : gamePieceColor;
      paint.strokeWidth = isBest ? 5 : 2;

      double xFromCenter =
          (piece.dx * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
      double yFromCenter =
          (field.center.dy - (piece.dy * field.pixelsPerMeterVertical)) * scale;

      final Offset markerCenter = Offset(
        center.dx + xFromCenter,
        center.dy + yFromCenter,
      );
      canvas.drawCircle(markerCenter, markerSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamePiecePainter oldDelegate) =>
      oldDelegate.gamePieces != gamePieces ||
      oldDelegate.gamePieceColor != gamePieceColor ||
      oldDelegate.bestGamePieceColor != bestGamePieceColor;
}

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter({
    this.strokeColor = Colors.white,
    this.strokeWidth = 3,
    this.paintingStyle = PaintingStyle.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) => Path()
    ..moveTo(0, 0)
    ..lineTo(x, y / 2)
    ..lineTo(0, y)
    ..lineTo(0, 0)
    ..lineTo(x, y / 2);

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.paintingStyle != paintingStyle ||
      oldDelegate.strokeWidth != strokeWidth;
}

class TrajectoryPainter extends CustomPainter {
  final Offset center;
  final List<Offset> points;
  final double strokeWidth;
  final Color color;

  TrajectoryPainter({
    required this.center,
    required this.points,
    required this.strokeWidth,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    Paint trajectoryPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path trajectoryPath = Path();

    trajectoryPath.moveTo(points[0].dx + center.dx, points[0].dy + center.dy);

    for (Offset point in points) {
      trajectoryPath.lineTo(point.dx + center.dx, point.dy + center.dy);
    }
    canvas.drawPath(trajectoryPath, trajectoryPaint);
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color;
}

class OtherObjectsPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<NT4Subscription> subscriptions;
  final bool Function(String) isPoseStruct;
  final bool Function(String) isPoseArrayStruct;
  final Color robotColor;
  final double objectSize;
  final double scale;

  OtherObjectsPainter({
    required this.center,
    required this.field,
    required this.subscriptions,
    required this.isPoseStruct,
    required this.isPoseArrayStruct,
    required this.robotColor,
    required this.objectSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (NT4Subscription objectSubscription in subscriptions) {
      List<Object?>? objectPositionRaw = objectSubscription.value
          ?.tryCast<List<Object?>>();

      if (objectPositionRaw == null) {
        continue;
      }

      bool isTrajectory = objectSubscription.topic.toLowerCase().endsWith(
        'trajectory',
      );
      bool isStructArray = isPoseArrayStruct(objectSubscription.topic);
      bool isStructObject =
          isPoseStruct(objectSubscription.topic) || isStructArray;

      if (isStructObject) {
        isTrajectory =
            isTrajectory ||
            (isStructArray &&
                objectPositionRaw.length ~/ Pose2dStruct.length > 8);
      } else {
        isTrajectory = isTrajectory || objectPositionRaw.length > 24;
      }
      if (isTrajectory) {
        continue;
      }

      if (isStructObject) {
        List<int> structBytes = objectPositionRaw.whereType<int>().toList();
        if (isStructArray) {
          List<Pose2dStruct> poses = Pose2dStruct.listFromBytes(
            Uint8List.fromList(structBytes),
          );
          for (Pose2dStruct pose in poses) {
            _drawObject(canvas, pose.x, pose.y, pose.angle);
          }
        } else {
          Pose2dStruct pose = Pose2dStruct.valueFromBytes(
            Uint8List.fromList(structBytes),
          );
          _drawObject(canvas, pose.x, pose.y, pose.angle);
        }
      } else {
        List<double> objectPosition = objectPositionRaw
            .whereType<double>()
            .toList();
        for (int i = 0; i < objectPosition.length - 2; i += 3) {
          _drawObject(
            canvas,
            objectPosition[i],
            objectPosition[i + 1],
            radians(objectPosition[i + 2]),
          );
        }
      }
    }
  }

  void _drawObject(Canvas canvas, double x, double y, double angle) {
    if (!x.isFinite || x.isNaN) x = 0;
    if (!y.isFinite || y.isNaN) y = 0;
    if (!angle.isFinite || angle.isNaN) angle = 0;

    double xFromCenter =
        (x * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
    double yFromCenter =
        (field.center.dy - (y * field.pixelsPerMeterVertical)) * scale;

    double width = objectSize * field.pixelsPerMeterHorizontal * scale;
    double length = objectSize * field.pixelsPerMeterVertical * scale;

    canvas.save();
    canvas.translate(center.dx + xFromCenter, center.dy + yFromCenter);
    canvas.rotate(-angle);

    final Paint paint = Paint()
      ..color = robotColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: length,
      height: width,
    );
    canvas.drawRect(rect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OtherObjectsPainter oldDelegate) =>
      oldDelegate.subscriptions != subscriptions ||
      oldDelegate.robotColor != robotColor;
}
