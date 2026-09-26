import '../models/models.dart';

/// Raised when [parseCurl] can't make sense of the input -- an unterminated
/// quote, or no URL found -- so the UI can show a specific, catchable
/// "couldn't parse this curl command" message instead of a silent wrong
/// result or an unhandled crash.
class CurlParseException implements Exception {
  const CurlParseException(this.message);

  final String message;

  @override
  String toString() => 'CurlParseException: $message';
}

/// Parses a `curl ...` command (as pasted from a browser devtools "Copy as
/// cURL" or written by hand) into an [Endpoint]. Returns `id`/`groupId` as
/// empty strings -- this is a pure, UI-agnostic engine function; the caller
/// (the paste-curl dialog) decides how to slot the result into the draft
/// provider or a saved collection.
///
/// Recognizes `-X`/`--request`, `-H`/`--header` (repeatable), `-d`/`--data`/
/// `--data-raw`/`--data-binary`/`--data-ascii`/`--data-urlencode`
/// (concatenated with `&` if repeated, and implying `POST` when no `-X` was
/// given), `-u`/`--user` (-> [AuthConfig.basic]), and `-b`/`--cookie`
/// (folded into a `Cookie` header). Any other flag (`--compressed`, `-s`,
/// `-k`, `-i`, `-L`, `-v`, ...) is recognized as a flag and skipped --
/// real "Copy as cURL" output routinely includes these, and they don't
/// affect the endpoint shape this parser cares about. `\`-continued
/// multi-line commands (the actual devtools copy-paste format) are joined
/// before tokenizing.
Endpoint parseCurl(String curlCommand) {
  final trimmed = curlCommand.trim();
  if (trimmed.isEmpty) {
    throw const CurlParseException('Empty input');
  }

  final joined = trimmed.replaceAll(RegExp(r'\\[ \t]*\r?\n'), ' ');
  final tokens = _tokenize(joined);

  String? url;
  String? method;
  final headers = <KeyValueEntry>[];
  final dataParts = <String>[];
  String? authUser;
  String? authPass;

  var i = tokens.isNotEmpty && tokens[0] == 'curl' ? 1 : 0;
  while (i < tokens.length) {
    final token = tokens[i];

    String nextValue(String flag) {
      i++;
      if (i >= tokens.length) {
        throw CurlParseException('Missing value for $flag');
      }
      return tokens[i];
    }

    if (token == '-X' || token == '--request') {
      method = nextValue(token);
    } else if (token == '-H' || token == '--header') {
      final headerLine = nextValue(token);
      final sep = headerLine.indexOf(':');
      if (sep == -1) {
        throw CurlParseException('Malformed header "$headerLine"');
      }
      headers.add(KeyValueEntry(
        key: headerLine.substring(0, sep).trim(),
        value: headerLine.substring(sep + 1).trim(),
      ));
    } else if (token == '-d' ||
        token == '--data' ||
        token == '--data-raw' ||
        token == '--data-binary' ||
        token == '--data-ascii' ||
        token == '--data-urlencode') {
      dataParts.add(nextValue(token));
    } else if (token == '-u' || token == '--user') {
      final credentials = nextValue(token);
      final sep = credentials.indexOf(':');
      if (sep == -1) {
        authUser = credentials;
        authPass = '';
      } else {
        authUser = credentials.substring(0, sep);
        authPass = credentials.substring(sep + 1);
      }
    } else if (token == '-b' || token == '--cookie') {
      headers.add(KeyValueEntry(key: 'Cookie', value: nextValue(token)));
    } else if (token.startsWith('-')) {
      // Unrecognized flag with no bearing on the endpoint shape -- skip it.
    } else {
      url ??= token;
    }
    i++;
  }

  if (url == null || url.isEmpty) {
    throw const CurlParseException('No URL found in curl command');
  }

  var body = const RequestBody.none();
  if (dataParts.isNotEmpty) {
    final combined = dataParts.join('&');
    final contentType = headers
        .cast<KeyValueEntry?>()
        .firstWhere((h) => h!.key.toLowerCase() == 'content-type', orElse: () => null)
        ?.value;
    body = contentType != null &&
            contentType.toLowerCase().contains('application/x-www-form-urlencoded')
        ? RequestBody.formUrlEncoded(_parseFormFields(combined))
        : RequestBody.json(combined);
    method ??= 'POST';
  }

  final authConfig = authUser != null
      ? AuthConfig.basic(username: authUser, password: authPass ?? '')
      : const AuthConfig.none();
  final resolvedMethod = method ?? 'GET';

  return Endpoint(
    id: '',
    groupId: '',
    name: '$resolvedMethod $url',
    method: resolvedMethod,
    url: url,
    headers: headers,
    body: body,
    authConfig: authConfig,
  );
}

List<KeyValueEntry> _parseFormFields(String data) {
  return [
    for (final pair in data.split('&'))
      if (pair.isNotEmpty)
        () {
          final sep = pair.indexOf('=');
          return sep == -1
              ? KeyValueEntry(key: pair, value: '')
              : KeyValueEntry(key: pair.substring(0, sep), value: pair.substring(sep + 1));
        }(),
  ];
}

/// Shell-like tokenizer: splits on whitespace outside of quotes, strips the
/// quote characters themselves, and honors backslash-escaping (bash rules
/// for `"..."` and bare unquoted text; a single-quoted `'...'` span is
/// fully literal, matching real shell behavior).
List<String> _tokenize(String input) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var hasContent = false;

  void flush() {
    if (hasContent) {
      tokens.add(buffer.toString());
      buffer.clear();
      hasContent = false;
    }
  }

  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else if (quote == '"' && ch == r'\' && i + 1 < input.length) {
        buffer.write(input[i + 1]);
        i++;
      } else {
        buffer.write(ch);
      }
      hasContent = true;
    } else if (ch == "'" || ch == '"') {
      quote = ch;
      hasContent = true;
    } else if (ch == r'\' && i + 1 < input.length) {
      buffer.write(input[i + 1]);
      i++;
      hasContent = true;
    } else if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
      flush();
    } else {
      buffer.write(ch);
      hasContent = true;
    }
    i++;
  }

  if (quote != null) {
    throw const CurlParseException('Unterminated quote in curl command');
  }
  flush();
  return tokens;
}
