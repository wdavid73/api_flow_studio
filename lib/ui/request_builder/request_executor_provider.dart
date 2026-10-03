import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/http/request_executor.dart';

/// The raw HTTP executor. Overridden in tests with a mocked [RequestExecutor];
/// the real app uses the default `dio`-backed instance. Sends go through
/// `sessionExecutorProvider`, which wraps this one with the login session.
final requestExecutorProvider = Provider<RequestExecutor>((ref) => RequestExecutor());
