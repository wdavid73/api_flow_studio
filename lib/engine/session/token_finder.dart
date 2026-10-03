import 'dart:collection';

/// The most nodes [findTokens] looks at, so a huge response can't stall it.
const int _maxNodes = 300;

/// Looks through a decoded JSON value, breadth-first and at most [_maxNodes]
/// objects/arrays, for the first non-blank string under `accessToken` or
/// `access_token` and under `refreshToken` or `refresh_token`. Shallower
/// matches win; within one object camelCase wins over snake_case. Either
/// result may be null.
({String? accessToken, String? refreshToken}) findTokens(Object? json) {
  String? accessToken;
  String? refreshToken;

  String? tokenAt(Map<dynamic, dynamic> node, List<String> keys) {
    for (final key in keys) {
      final value = node[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  final queue = Queue<Object?>()..add(json);
  var seen = 0;
  while (queue.isNotEmpty && seen < _maxNodes) {
    final node = queue.removeFirst();
    if (node is! Map && node is! List) continue;
    seen++;

    if (node is Map) {
      accessToken ??= tokenAt(node, const ['accessToken', 'access_token']);
      refreshToken ??= tokenAt(node, const ['refreshToken', 'refresh_token']);
      if (accessToken != null && refreshToken != null) break;
      queue.addAll(node.values);
    } else if (node is List) {
      queue.addAll(node);
    }
  }

  return (accessToken: accessToken, refreshToken: refreshToken);
}
