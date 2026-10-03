import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';

EnvironmentVariable _v(String value) => EnvironmentVariable(value: value);

/// Three environments: `Dev` (active), `QA` and `Prod`. Every one has
/// `base_url` and `AUTH_HOST`; `MARKET_HOST` is missing in `QA` on purpose, so
/// the hosts dialog has a warning to show.
final List<Environment> seedEnvironments = [
  Environment(id: 'dev', name: 'Dev', variables: {
    'base_url': _v('https://dev.api.test'),
    'AUTH_HOST': _v('https://auth.dev.test'),
    'MARKET_HOST': _v('https://market.dev.test'),
  }),
  Environment(id: 'qa', name: 'QA', variables: {
    'base_url': _v('https://qa.api.test'),
    'AUTH_HOST': _v('https://auth.qa.test'),
  }),
  Environment(id: 'prod', name: 'Prod', variables: {
    'base_url': _v('https://api.test'),
    'AUTH_HOST': _v('https://auth.test'),
    'MARKET_HOST': _v('https://market.test'),
  }),
];

const Group seedGroup = Group(id: 'g-demo', name: 'Demo API');

/// The requests of the demo collection. They all hang off `{{base_url}}`.
final List<Endpoint> seedEndpoints = [
  for (final (id, name, method, path) in const [
    ('e-items', 'List items', 'GET', '/items'),
    ('e-login', 'Log in', 'POST', '/login'),
    ('e-me', 'My profile', 'GET', '/me'),
    ('e-boom', 'Always fails', 'GET', '/boom'),
    ('e-flaky', 'Server error', 'GET', '/flaky'),
  ])
    Endpoint(id: id, groupId: 'g-demo', name: name, method: method, url: '{{base_url}}$path'),
];

/// A three-step flow: log in, read the profile, list the items.
const Flow seedFlow = Flow(
  id: 'f-signup',
  name: 'Sign up',
  steps: [
    FlowStep(endpointId: 'e-login'),
    FlowStep(endpointId: 'e-me'),
    FlowStep(endpointId: 'e-items'),
  ],
);

/// Writes the standard demo data into [store]: the three environments with `Dev`
/// active, the demo collection and the flow.
Future<void> seedStore(JsonStore store, {String? activeEnvironmentId = 'dev'}) async {
  await store.writeEnvironments(seedEnvironments);
  await store.writeActiveEnvironmentId(activeEnvironmentId);
  await store.writeCollections(groups: const [seedGroup], endpoints: seedEndpoints);
  await store.writeFlows(const [seedFlow]);
}
