import '../../integration_test/journeys/environments_journey.dart';
import '../../integration_test/journeys/flow_journey.dart';
import '../../integration_test/journeys/history_journey.dart';
import '../../integration_test/journeys/hosts_journey.dart';
import '../../integration_test/journeys/keyboard_journey.dart';
import '../../integration_test/journeys/navigation_journey.dart';
import '../../integration_test/journeys/persistence_journey.dart';
import '../../integration_test/journeys/production_journey.dart';
import '../../integration_test/journeys/projects_journey.dart';
import '../../integration_test/journeys/send_request_journey.dart';
import '../../integration_test/journeys/session_journey.dart';
import 'in_memory_harness.dart';

/// Runs every user journey against the whole app without a window, with an
/// in-memory store. The same journeys run on the real Windows app from
/// `integration_test/app_test.dart`.
void main() {
  final harness = InMemoryHarness();

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
