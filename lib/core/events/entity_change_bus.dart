import 'dart:async';

/// Lightweight invalidation bus for feature tables created with custom SQL.
///
/// Drift cannot infer dependencies for those tables, so repositories use this
/// bus to re-run reactive queries after local mutations or remote sync applies.
final class EntityChangeBus {
  EntityChangeBus();

  final StreamController<String> _controller =
      StreamController<String>.broadcast(sync: true);

  Stream<void> watch(String entityType) => _controller.stream
      .where((String changed) => changed == entityType)
      .map<void>((_) {});

  Stream<void> watchAny(Iterable<String> entityTypes) {
    final Set<String> accepted = entityTypes.toSet();
    return _controller.stream
        .where(accepted.contains)
        .map<void>((_) {});
  }

  void notify(String entityType) {
    if (!_controller.isClosed) _controller.add(entityType);
  }

  Future<void> dispose() => _controller.close();
}
