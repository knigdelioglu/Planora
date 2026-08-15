import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';

void main() {
  test('creates a rank between two neighbors', () {
    expect(FractionalIndexingHelper.between(1000, 2000), 1500);
  });

  test('creates initial rank when there are no neighbors', () {
    expect(FractionalIndexingHelper.between(null, null), 1024);
  });
}
