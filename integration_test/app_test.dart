import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'journeys/environments_journey.dart';
import 'journeys/flow_journey.dart';
import 'journeys/history_journey.dart';
import 'journeys/hosts_journey.dart';
import 'journeys/keyboard_journey.dart';
import 'journeys/navigation_journey.dart';
import 'journeys/persistence_journey.dart';
import 'journeys/production_journey.dart';
import 'journeys/projects_journey.dart';
import 'journeys/send_request_journey.dart';
import 'journeys/session_journey.dart';
import 'support/disk_harness.dart';
import 'support/journey_harness.dart' show watchingJourneys;

/// Runs every user journey on the real desktop app, with the store on a real
/// temporary folder:
///
///     fvm flutter test integration_test -d windows
///
/// To watch it work, add `--dart-define=JOURNEY_PAUSE_MS=400` (a pause after
/// every step, see `AppDriver.settle`); the real window size is used then.
///
/// The same journeys run without a window from `test/integration/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Watching: draw every frame in the real window.
  if (watchingJourneys) binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final harness = DiskHarness();

  defineNavigationJourney(() => harness);
  defineSendRequestJourney(() => harness);
  defineHistoryJourney(() => harness);
  defineEnvironmentsJourney(() => harness);
  defineProductionJourney(() => harness);
  defineSessionJourney(() => harness);
  defineFlowJourney(() => harness);
  defineHostsJourney(() => harness);
  definePersistenceJourney(() => harness);
  defineKeyboardJourney(() => harness);
  defineProjectsJourney(() => harness);
}
