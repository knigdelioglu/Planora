import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';

void main() {
  test('between generates a stable ordered key', () {
    final String a = FractionalIndexing.encode(1000);
    final String b = FractionalIndexing.encode(2000);
    final String middle = FractionalIndexing.between(a, b);
    expect(a.compareTo(middle), lessThan(0));
    expect(middle.compareTo(b), lessThan(0));
  });

  test('rebalance returns strictly ascending fixed-width keys', () {
    final values = FractionalIndexing.rebalance(500);
    expect(values, hasLength(500));
    expect(
      values.every((key) => key.length == FractionalIndexing.width),
      isTrue,
    );
    for (int index = 1; index < values.length; index++) {
      expect(values[index - 1].compareTo(values[index]), lessThan(0));
    }
  });
}
