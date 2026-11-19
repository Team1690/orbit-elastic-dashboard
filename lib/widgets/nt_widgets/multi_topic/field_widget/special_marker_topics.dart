import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_topics.dart';

class Marker {
  final double x;
  final double y;
  final Color color;
  final int shapeId;
  final double size;

  Marker({
    required this.x,
    required this.y,
    required this.color,
    required this.shapeId,
    required this.size,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marker &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          color == other.color &&
          shapeId == other.shapeId &&
          size == other.size;

  @override
  int get hashCode => Object.hash(x, y, color, shapeId, size);
}

// Manages topics for special markers.
class SpecialMarkerTopics {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<List<dynamic>> _markerData;

  NT4Subscription get subscription => _markerData.subscription;

  SpecialMarkerTopics({required this.ntConnection, this.period = 0.1}) {
    _markerData = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/MarkerData',
      defaultValue: const [],
      period: period,
    );
  }

  void initialize() {
    _markerData.subscribe();
  }

  void dispose() {
    _markerData.unsubscribe();
  }

  List<Marker> get markers {
    final List<num> rawData = _markerData.value.cast<num>();

    List<Marker> parsedMarkers = [];
    // The list is [x, y, r, g, b, shapeId, size, x2, y2, r2, g2, b2, shapeId2, size2, ...]
    // so we iterate by 7.
    for (int i = 0; i < rawData.length - 6; i += 7) {
      final double x = (rawData[i]).toDouble();
      final double y = (rawData[i + 1]).toDouble();
      final int r = (rawData[i + 2]).toInt();
      final int g = (rawData[i + 3]).toInt();
      final int b = (rawData[i + 4]).toInt();
      final int shapeId = (rawData[i + 5]).toInt();
      final double size = (rawData[i + 6]).toDouble();

      parsedMarkers.add(
        Marker(
          x: x,
          y: y,
          color: Color.fromARGB(255, r, g, b),
          shapeId: shapeId,
          size: size,
        ),
      );
    }
    return parsedMarkers;
  }
}
