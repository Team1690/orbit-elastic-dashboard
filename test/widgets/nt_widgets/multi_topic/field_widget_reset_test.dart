import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_model.dart';

// Uses a real NTConnection (never connects) so that the subscription
// use-count and unsubscribe logic is exercised. The mock in test_util.dart
// makes unSubscribe a no-op and cannot catch this regression.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FieldImages.loadFields('assets/fields/');
  });

  final markerTopic = NT4Topic(
    name: '/Match/Pose/MarkerData',
    type: NT4Type.array(NT4Type.double()),
    properties: {},
  );
  final robotXTopic = NT4Topic(
    name: '/Match/Pose/RobotX',
    type: NT4Type.double(),
    properties: {},
  );
  final allianceTopic = NT4Topic(
    name: '/FMSInfo/IsRedAlliance',
    type: NT4Type.boolean(),
    properties: {},
  );

  test('Field widget helper subscriptions survive resetSubscription', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final ntConnection = NTConnection('10.3.5.32');

    final model = FieldWidgetModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: '/Match/Pose',
      period: 0.06,
      showSpecialMarkers: true,
    );

    ntConnection.updateDataFromTopic(markerTopic, [
      1.0,
      1.0,
      200.0,
      0.0,
      0.0,
      0.0,
    ]);
    expect(model.specialMarkerTopics.markers.length, 1);
    expect(model.specialMarkerTopics.markers.first.x, 1.0);

    // Same as the Edit Properties dialog's Topic/Period field losing focus.
    model.resetSubscription();

    ntConnection.updateDataFromTopic(robotXTopic, 3.0);
    ntConnection.updateDataFromTopic(allianceTopic, true);
    ntConnection.updateDataFromTopic(markerTopic, [
      2.0,
      2.5,
      0.0,
      200.0,
      0.0,
      1.0,
    ]);

    expect(model.robotXSubscription.value, 3.0);
    expect(ntConnection.subscriptions, contains(model.robotXSubscription));
    expect(
      ntConnection.subscriptions,
      contains(model.specialMarkerTopics.subscription),
    );
    expect(
      ntConnection.subscriptions,
      contains(model.allianceTopic.listenables.first),
    );

    expect(model.allianceTopic.value, isTrue);
    expect(model.specialMarkerTopics.markers.length, 1);
    expect(model.specialMarkerTopics.markers.first.x, 2.0);
    expect(model.specialMarkerTopics.markers.first.y, 2.5);
    expect(model.specialMarkerTopics.markers.first.shapeId, 1);

    // Commander topics must still be published so field taps keep working.
    expect(
      ntConnection.isTopicPublished(model.commanderTopics.setNewPose),
      isTrue,
    );
  });
}
