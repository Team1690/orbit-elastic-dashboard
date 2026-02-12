import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';

class Marker {
  final double x;
  final double y;
  final Color color;
  final int shapeId;

  Marker({
    required this.x,
    required this.y,
    required this.color,
    required this.shapeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marker &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          color == other.color &&
          shapeId == other.shapeId;

  @override
  int get hashCode => Object.hash(x, y, color, shapeId);
}

// Manages topics for special markers.
class SpecialMarkerTopics {
  final NTConnection ntConnection;
  final double period;

  late final NT4Subscription subscription;

  SpecialMarkerTopics({required this.ntConnection, this.period = 0.1});

  void initialize() {
    subscription = ntConnection.subscribe(
      '/Match/SpecialMarkers/MarkerData',
      period,
    );
  }

  void dispose() {
    ntConnection.unSubscribe(subscription);
  }

  List<Marker> get markers {
    final List<num> rawData =
        (subscription.value as List<dynamic>?)?.cast<num>() ?? [];

    List<Marker> parsedMarkers = [];
    // The list is [x, y, r, g, b, shapeId, x2, y2, r2, g2, b2, shapeId2, ...]
    // so we iterate by 6.
    for (int i = 0; i < rawData.length - 5; i += 6) {
      final double x = (rawData[i]).toDouble();
      final double y = (rawData[i + 1]).toDouble();
      final int r = (rawData[i + 2]).toInt();
      final int g = (rawData[i + 3]).toInt();
      final int b = (rawData[i + 4]).toInt();
      final int shapeId = (rawData[i + 5]).toInt();

      parsedMarkers.add(
        Marker(
          x: x,
          y: y,
          color: Color.fromARGB(255, r, g, b),
          shapeId: shapeId,
        ),
      );
    }
    return parsedMarkers;
  }
}
