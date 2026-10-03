import '../../engine/models/models.dart';
import 'collections_provider.dart';

/// Value of the method filter meaning "no method filter".
const String allMethods = 'ALL';

/// Whether [endpoint] passes both filters: its method equals [method] (unless
/// [method] is [allMethods]) and the lowercase [query] appears in its name,
/// method, URL or description. An empty [query] matches everything.
bool endpointMatches(Endpoint endpoint, {required String query, required String method}) {
  if (method != allMethods && endpoint.method.toUpperCase() != method) return false;
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  return [endpoint.name, endpoint.method, endpoint.url, endpoint.description]
      .any((field) => field.toLowerCase().contains(needle));
}

/// [nodes] reduced to the endpoints that pass [endpointMatches]. A folder is
/// kept only if it has a passing endpoint or a descendant folder that does,
/// so a nested match keeps all its ancestors. With neither filter set the
/// tree is returned untouched.
List<GroupTreeNode> filterTree(
  List<GroupTreeNode> nodes, {
  required String query,
  required String method,
}) {
  // With no filter at all the tree is shown as is, empty folders included.
  if (query.isEmpty && method == allMethods) return nodes;

  final result = <GroupTreeNode>[];
  for (final node in nodes) {
    final endpoints = node.endpoints.where((e) => endpointMatches(e, query: query, method: method)).toList();
    final children = filterTree(node.children, query: query, method: method);
    if (endpoints.isNotEmpty || children.isNotEmpty) {
      result.add(GroupTreeNode(group: node.group, children: children, endpoints: endpoints));
    }
  }
  return result;
}
