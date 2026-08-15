abstract final class FractionalIndexingHelper {
  static const double spacing = 1024;

  static double between(double? before, double? after) {
    if (before == null && after == null) return spacing;
    if (before == null) return after! - spacing;
    if (after == null) return before + spacing;

    final result = before + ((after - before) / 2);
    if (result == before || result == after) {
      throw StateError('Ranking space exhausted; controlled rebalance required.');
    }
    return result;
  }
}
