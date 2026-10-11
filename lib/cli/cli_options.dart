import 'package:args/args.dart';

/// The outcome of reading the command line: [CliOptions] or a [CliUsageError].
sealed class CliParseResult {
  const CliParseResult();
}

/// What the person asked the runner to do.
class CliOptions extends CliParseResult {
  const CliOptions({
    required this.workspace,
    this.env,
    this.flows = const [],
    this.vars = const {},
    this.timeout = const Duration(seconds: 30),
    this.failFast = false,
    this.allowProduction = false,
    this.junit,
    this.json,
    this.verbose = false,
    this.list = false,
    this.help = false,
  });

  /// The workspace file; empty only with [help].
  final String workspace;
  final String? env;
  final List<String> flows;
  final Map<String, String> vars;
  final Duration timeout;
  final bool failFast;
  final bool allowProduction;
  final String? junit;
  final String? json;
  final bool verbose;
  final bool list;
  final bool help;
}

/// The arguments cannot be used; [message] says why, in plain words.
class CliUsageError extends CliParseResult {
  const CliUsageError(this.message);

  final String message;
}

final ArgParser _parser = ArgParser()
  ..addOption('workspace', abbr: 'w', valueHelp: 'file', help: 'Workspace file exported by the app (required).')
  ..addOption('env', abbr: 'e', valueHelp: 'name', help: 'Environment to use; required if the file has more than one.')
  ..addMultiOption('flow', abbr: 'f', valueHelp: 'name|id', help: 'Flow to run; repeatable. Default: all.')
  ..addMultiOption('var', valueHelp: 'name=value', help: 'Override a variable; repeatable.')
  ..addOption('timeout', valueHelp: 'seconds', defaultsTo: '30', help: 'Time limit per request.')
  ..addFlag('fail-fast', negatable: false, help: 'Stop after the first flow that fails.')
  ..addFlag('allow-production', negatable: false, help: 'Required for environments named prod, production or prd.')
  ..addOption('junit', valueHelp: 'file', help: 'Write a JUnit XML report.')
  ..addOption('json', valueHelp: 'file', help: 'Write a JSON report.')
  ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Print each request (method and URL).')
  ..addFlag('list', negatable: false, help: 'List environments and flows, run nothing.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// The text of `--help`.
final String usageText = 'Usage: api_flow_runner --workspace <file> [options]\n\n${_parser.usage}';

/// Turns the command line into [CliOptions], or a [CliUsageError] saying what is wrong.
CliParseResult parseCliArgs(List<String> args) {
  final ArgResults results;
  try {
    results = _parser.parse(args);
  } on ArgParserException catch (e) {
    return CliUsageError(e.message);
  }

  if (results['help'] as bool) return const CliOptions(workspace: '', help: true);

  if (results.rest.isNotEmpty) {
    return CliUsageError('unexpected argument "${results.rest.first}"');
  }
  final workspace = results['workspace'] as String?;
  if (workspace == null || workspace.isEmpty) return const CliUsageError('missing required option --workspace');

  final timeoutText = results['timeout'] as String;
  final seconds = double.tryParse(timeoutText);
  if (seconds == null || seconds <= 0 || !seconds.isFinite) {
    return CliUsageError('--timeout must be a positive number of seconds, got "$timeoutText"');
  }

  final vars = <String, String>{};
  for (final entry in results['var'] as List<String>) {
    final split = entry.indexOf('=');
    if (split <= 0) return CliUsageError('--var must look like name=value, got "$entry"');
    vars[entry.substring(0, split)] = entry.substring(split + 1);
  }

  return CliOptions(
    workspace: workspace,
    env: results['env'] as String?,
    flows: results['flow'] as List<String>,
    vars: vars,
    timeout: Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round()),
    failFast: results['fail-fast'] as bool,
    allowProduction: results['allow-production'] as bool,
    junit: results['junit'] as String?,
    json: results['json'] as String?,
    verbose: results['verbose'] as bool,
    list: results['list'] as bool,
  );
}
