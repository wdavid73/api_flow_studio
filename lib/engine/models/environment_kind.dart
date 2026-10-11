/// True when [name] denotes a production environment (case-insensitive,
/// surrounding whitespace ignored). Detection is by name so the persisted
/// environment model doesn't need a flag. Lives in the engine so the terminal
/// runner can ask it too.
bool isProductionEnvironment(String name) {
  const names = {'prod', 'production', 'prd'};
  return names.contains(name.trim().toLowerCase());
}
