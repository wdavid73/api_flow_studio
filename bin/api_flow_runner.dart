import 'dart:io';

import 'package:api_flow_studio/cli/run_cli.dart';

/// Runs the flows of a workspace file from the terminal. See `--help`.
Future<void> main(List<String> args) async {
  final code = await runCli(args, out: stdout, err: stderr, environment: Platform.environment);
  // exit() does not wait for buffered output, which CI would then lose.
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
