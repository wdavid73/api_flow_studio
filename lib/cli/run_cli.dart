import 'dart:io';

import 'package:dio/dio.dart';

import '../engine/flows/flow_runner.dart';
import '../engine/http/request_executor.dart';
import '../engine/models/models.dart';
import '../engine/workspace/workspace_file.dart';
import 'cli_options.dart';
import 'redactor.dart';
import 'reporters/console_reporter.dart';
import 'reporters/json_reporter.dart';
import 'reporters/junit_reporter.dart';
import 'run_report.dart';
import 'selection.dart';

/// Runs the flows of a workspace file from the terminal and returns the exit
/// code: 0 when everything passed, 1 when a flow failed, 2 when the run could not
/// be made (bad arguments, unreadable file, nothing to run, a report that could
/// not be written).
///
/// Everything from the outside world comes in as a parameter, so the whole thing
/// is testable without a process or a network: [out] and [err] are where text
/// goes, [environment] the process environment, [executor] the HTTP layer (a real
/// one with the `--timeout` when null) and [now] the clock for the report's
/// start time. Only `bin/` calls `exit`.
Future<int> runCli(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  Map<String, String> environment = const {},
  RequestExecutor? executor,
  DateTime Function()? now,
}) async {
  final parsed = parseCliArgs(args);
  if (parsed is CliUsageError) {
    err.writeln('error: ${parsed.message}');
    err.writeln('Run with --help for usage.');
    return 2;
  }
  final options = parsed as CliOptions;
  if (options.help) {
    out.writeln(usageText);
    return 0;
  }

  final String text;
  try {
    text = await File(options.workspace).readAsString();
  } on FileSystemException catch (e) {
    err.writeln('error: cannot read ${options.workspace}: ${e.osError?.message ?? e.message}');
    return 2;
  } on FormatException {
    err.writeln('error: cannot read ${options.workspace}: it is not valid UTF-8 text');
    return 2;
  }

  final WorkspaceFile file;
  try {
    file = WorkspaceFile.parse(text);
  } on WorkspaceFileException catch (e) {
    err.writeln('error: ${e.message}');
    return 2;
  }

  if (options.list) {
    _printList(file, out);
    return 0;
  }

  final selected = selectRun(file, options, environment);
  if (selected is SelectionError) {
    err.writeln('error: ${selected.message}');
    return 2;
  }
  final selection = selected as RunSelection;

  for (final name in selection.emptySecrets) {
    err.writeln('warning: secret variable "$name" has no value');
  }

  final redactor = Redactor.forSelection(selection);
  final runner = FlowRunner(executor: executor ?? _realExecutor(options.timeout));
  final endpoints = {for (final e in file.endpoints) e.id: e};

  final startedAt = (now ?? DateTime.now)();
  final total = Stopwatch()..start();
  final flowReports = <FlowReport>[];

  for (final flow in selection.flows) {
    out.writeln(formatFlowHeader(flow.name, flow.steps.length, redactor));
    final watch = Stopwatch()..start();
    final steps = <StepReport>[];

    await runner.run(
      flow,
      endpoints: endpoints,
      initialVariables: selection.variables,
      onStepResult: (index, result) {
        // A credential this step extracted must be masked in this step's own lines.
        redactor.learn(result.extractedVariables);
        final step = flow.steps[index];
        final report = stepReportFrom(index: index + 1, step: step, endpoint: endpoints[step.endpointId], result: result);
        steps.add(report);
        out.writeln(formatStep(report, redactor, verbose: options.verbose));
      },
    );

    final report = FlowReport(id: flow.id, name: flow.name, steps: steps, duration: watch.elapsed);
    flowReports.add(report);
    if (!report.passed && options.failFast) break;
  }

  final run = RunReport(
    workspace: file.name,
    environment: selection.environment?.name,
    startedAt: startedAt,
    duration: total.elapsed,
    flows: flowReports,
  );
  out.writeln();
  out.writeln(formatSummary(run, redactor));

  var reportsWritten = true;
  if (options.junit != null) {
    reportsWritten &= await _writeReport(options.junit!, junitReport(run, redactor), err);
  }
  if (options.json != null) {
    reportsWritten &= await _writeReport(options.json!, jsonReport(run, redactor), err);
  }

  if (!reportsWritten) return 2;
  return run.passed ? 0 : 1;
}

RequestExecutor _realExecutor(Duration timeout) => RequestExecutor(
      dio: Dio(BaseOptions(connectTimeout: timeout, sendTimeout: timeout, receiveTimeout: timeout)),
    );

Future<bool> _writeReport(String path, String content, StringSink err) async {
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return true;
  } on FileSystemException catch (e) {
    err.writeln('error: cannot write $path: ${e.osError?.message ?? e.message}');
    return false;
  }
}

void _printList(WorkspaceFile file, StringSink out) {
  String steps(Flow flow) => '${flow.steps.length} ${flow.steps.length == 1 ? 'step' : 'steps'}';
  out.writeln('Environments:');
  for (final environment in file.environments) {
    out.writeln('  ${environment.name}');
  }
  out.writeln('Flows:');
  for (final flow in file.flows) {
    out.writeln('  ${flow.name} (${flow.id}, ${steps(flow)})');
  }
}
