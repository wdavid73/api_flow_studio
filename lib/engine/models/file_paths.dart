import 'endpoint.dart';
import 'multipart_field.dart';
import 'request_body.dart';

/// The file name at the end of [path], whichever separator it uses (a request
/// saved on Windows can be sent from anywhere). Empty when [path] is empty or
/// ends in a separator.
String fileBaseName(String path) => path.split(RegExp(r'[/\\]')).last;

/// [endpoint] with the path of every file field of a multipart body emptied (the
/// field stays, as "no file chosen"). Anything that reads a file from someone else
/// must do this: a body sends a local file to its URL, and a path in a file that
/// was handed to you is not a file you chose to send. A path that is a
/// `{{variable}}` goes too, since the variable can point anywhere.
///
/// Returns [endpoint] itself when there is nothing to clear.
Endpoint withoutFilePaths(Endpoint endpoint) {
  final fields = endpoint.body.maybeMap(multipart: (b) => b.fields, orElse: () => null);
  if (fields == null || !fields.any((f) => f.kind == MultipartFieldKind.file && f.value.isNotEmpty)) {
    return endpoint;
  }
  return endpoint.copyWith(
    body: RequestBody.multipart([
      for (final f in fields) f.kind == MultipartFieldKind.file ? f.copyWith(value: '') : f,
    ]),
  );
}

/// How many file fields the person has to choose a file for after importing
/// [endpoints]: the enabled, named ones (disabled fields are not sent).
int filePathsToFill(Iterable<Endpoint> endpoints) {
  var count = 0;
  for (final endpoint in endpoints) {
    final fields = endpoint.body.maybeMap(multipart: (b) => b.fields, orElse: () => const <MultipartField>[]);
    count += fields.where((f) => f.kind == MultipartFieldKind.file && f.enabled && f.name.isNotEmpty).length;
  }
  return count;
}
