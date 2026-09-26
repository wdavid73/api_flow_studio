import 'package:api_flow_studio/engine/flows/flow_runner.dart';
import 'package:api_flow_studio/engine/flows/flow_step_result.dart';
import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  late MockRequestExecutor executor;
  late FlowRunner runner;

  setUp(() {
    executor = MockRequestExecutor();
    runner = FlowRunner(executor: executor);
  });

  const checkUser = Endpoint(
    id: 'e-check',
    groupId: 'g-1',
    name: 'Check user exists',
    method: 'GET',
    url: '{{base_url}}/users/exists',
  );
  const sendOtp = Endpoint(
    id: 'e-otp',
    groupId: 'g-1',
    name: 'Send OTP',
    method: 'POST',
    url: '{{base_url}}/otp/send',
  );
  const createUser = Endpoint(
    id: 'e-create',
    groupId: 'g-1',
    name: 'Create user',
    method: 'POST',
    url: '{{base_url}}/users?token={{otp_token}}',
  );

  final endpoints = {
    checkUser.id: checkUser,
    sendOtp.id: sendOtp,
    createUser.id: createUser,
  };

  test('a variable extracted in step 1 is interpolated into step 3s outgoing request', () async {
    when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 200, body: {'exists': false}),
    );
    when(() => executor.execute(sendOtp, variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 200, body: {'token': 'otp-abc'}),
    );
    when(() => executor.execute(createUser, variables: captureAny(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 201));

    final flow = Flow(
      id: 'f-1',
      name: 'User Registration Flow',
      steps: [
        FlowStep(endpointId: checkUser.id, extract: const {'exists': 'response.body.exists'}),
        FlowStep(endpointId: sendOtp.id, extract: const {'otp_token': 'response.body.token'}),
        const FlowStep(endpointId: 'e-create'),
      ],
    );

    await runner.run(flow, endpoints: endpoints, initialVariables: {'base_url': 'https://api.dev'});

    final captured = verify(
      () => executor.execute(createUser, variables: captureAny(named: 'variables')),
    ).captured;
    final variablesPassedToStep3 = captured.single as Map<String, String>;
    expect(variablesPassedToStep3['otp_token'], 'otp-abc');
    expect(variablesPassedToStep3['base_url'], 'https://api.dev');
  });

  test('a step with an unmet assertion is marked failure', () async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 404));

    final flow = Flow(
      id: 'f-1',
      name: 'Flow',
      steps: [
        const FlowStep(endpointId: 'e-check', assertField: 'response.status', assertExpected: '200'),
      ],
    );

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults.single.status, FlowStepStatus.failure);
    expect(result.stepResults.single.failureReason, contains('Assertion failed'));
  });

  test('a step with a met assertion is marked success', () async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    final flow = Flow(
      id: 'f-1',
      name: 'Flow',
      steps: [
        const FlowStep(endpointId: 'e-check', assertField: 'response.status', assertExpected: '200'),
      ],
    );

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults.single.status, FlowStepStatus.success);
  });

  test('with no assertion configured, a transport-successful step is success regardless of status',
      () async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 500));

    final flow = Flow(id: 'f-1', name: 'Flow', steps: const [FlowStep(endpointId: 'e-check')]);

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults.single.status, FlowStepStatus.success);
  });

  test('stopOnFailure true skips every remaining step without executing them', () async {
    when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 404),
    );

    final flow = Flow(
      id: 'f-1',
      name: 'Flow',
      steps: [
        const FlowStep(
          endpointId: 'e-check',
          assertField: 'response.status',
          assertExpected: '200',
        ),
        const FlowStep(endpointId: 'e-otp'),
        const FlowStep(endpointId: 'e-create'),
      ],
    );

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults[0].status, FlowStepStatus.failure);
    expect(result.stepResults[1].status, FlowStepStatus.skipped);
    expect(result.stepResults[2].status, FlowStepStatus.skipped);
    verifyNever(() => executor.execute(sendOtp, variables: any(named: 'variables')));
    verifyNever(() => executor.execute(createUser, variables: any(named: 'variables')));
  });

  test('stopOnFailure false lets subsequent steps run after a failure', () async {
    when(() => executor.execute(checkUser, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 404));
    when(() => executor.execute(sendOtp, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    final flow = Flow(
      id: 'f-1',
      name: 'Flow',
      steps: [
        const FlowStep(
          endpointId: 'e-check',
          assertField: 'response.status',
          assertExpected: '200',
          stopOnFailure: false,
        ),
        const FlowStep(endpointId: 'e-otp'),
      ],
    );

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults[0].status, FlowStepStatus.failure);
    expect(result.stepResults[1].status, FlowStepStatus.success);
    verify(() => executor.execute(sendOtp, variables: any(named: 'variables'))).called(1);
  });

  test('a transport error is marked failure with a reason, even with no assertion configured',
      () async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(error: 'Connection refused'));

    final flow = Flow(id: 'f-1', name: 'Flow', steps: const [FlowStep(endpointId: 'e-check')]);

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults.single.status, FlowStepStatus.failure);
    expect(result.stepResults.single.failureReason, 'Connection refused');
  });

  test('a step whose endpointId does not resolve is a failure, not a crash', () async {
    final flow =
        Flow(id: 'f-1', name: 'Flow', steps: const [FlowStep(endpointId: 'does-not-exist')]);

    final result = await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    expect(result.stepResults.single.status, FlowStepStatus.failure);
    expect(result.stepResults.single.failureReason, contains('does-not-exist'));
    verifyNever(() => executor.execute(any(), variables: any(named: 'variables')));
  });

  test('variables accumulate across the whole run, not just to the next step', () async {
    when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 200, body: {'user_id': 'u-1'}),
    );
    when(() => executor.execute(sendOtp, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));
    when(() => executor.execute(createUser, variables: captureAny(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 201));

    final flow = Flow(
      id: 'f-1',
      name: 'Flow',
      steps: [
        FlowStep(endpointId: checkUser.id, extract: const {'user_id': 'response.body.user_id'}),
        const FlowStep(endpointId: 'e-otp'), // doesn't touch user_id
        const FlowStep(endpointId: 'e-create'), // step 3 should still see it
      ],
    );

    await runner.run(flow, endpoints: endpoints, initialVariables: const {});

    final variablesAtStep3 = verify(
      () => executor.execute(createUser, variables: captureAny(named: 'variables')),
    ).captured.single as Map<String, String>;
    expect(variablesAtStep3['user_id'], 'u-1');
  });
}
