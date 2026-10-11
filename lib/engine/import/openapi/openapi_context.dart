import '../../models/models.dart';
import '../import_result.dart';
import '../variable_names.dart';
import 'openapi_refs.dart';
import 'openapi_schema.dart';

/// What every part of one OpenAPI import shares: the document, its references, the
/// sampler, the warnings, the name sanitiser and the variables the environment will have.
class OpenApiContext {
  OpenApiContext(this.document, this.warnings) {
    refs = OpenApiRefs(document, warnings);
    sampler = SchemaSampler(refs, warnings);
  }

  final Map<String, dynamic> document;
  final List<ImportWarning> warnings;
  final VariableNames names = VariableNames();
  late final OpenApiRefs refs;
  late final SchemaSampler sampler;

  /// Security schemes already warned about, so a scheme is reported once, not once per operation.
  final Set<String> warnedSchemes = {};

  /// The variables of the imported environment, in the order they were first needed.
  final Map<String, EnvironmentVariable> variables = {};

  /// Makes sure the environment has [name]. The first value given wins: two operations
  /// can use the same parameter name for different things, and only one value fits.
  void defineVariable(String name, String value, {bool secret = false}) {
    variables.putIfAbsent(name, () => EnvironmentVariable(value: value, secret: secret));
  }
}
