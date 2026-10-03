import 'package:integration_test/integration_test.dart';

import 'journeys/environments_journey.dart';
import 'journeys/history_journey.dart';
import 'journeys/navigation_journey.dart';
import 'journeys/production_journey.dart';
import 'journeys/send_request_journey.dart';
import 'journeys/session_journey.dart';
import 'support/disk_harness.dart';

/// Runs every user journey on the real desktop app, with the store on a real
/// temporary folder:
///
///     fvm flutter test integration_test -d windows
///
/// The same journeys run without a window from `test/integration/`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final harness = DiskHarness();

  defineNavigationJourney(() => harness);
  defineSendRequestJourney(() => harness);
  defineHistoryJourney(() => harness);
  defineEnvironmentsJourney(() => harness);
  defineProductionJourney(() => harness);
  defineSessionJourney(() => harness);
}
