import 'package:not_app/core/error/exceptions.dart';

/// Fixed-width base-36 sortable keys.
///
/// Lexicographic order is identical to numeric order because every key has
/// the same width. A move only updates the moved entity. When adjacent keys
/// have no numeric gap, callers run [rebalance] for that list.
final class FractionalIndexing {
  const FractionalIndexing._();

  static const int width = 12;
  static const String alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  static final BigInt _base = BigInt.from(36);
  static final BigInt maxValue = _base.pow(width) - BigInt.one;
  static final BigInt middleValue = maxValue ~/ BigInt.two;
  static final String middle = encode(middleValue);

  static String between(String? previous, String? next) {
    final BigInt low = previous == null ? BigInt.zero : decode(previous);
    final BigInt high = next == null ? maxValue : decode(next);
    if (low >= high) {
      throw ArgumentError('Previous rank must sort before next rank.');
    }
    if (high - low <= BigInt.one) {
      throw const RankSpaceExhaustedException();
    }
    return encode((low + high) ~/ BigInt.two);
  }

  static List<String> rebalance(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count');
    }
    if (count == 0) {
      return const <String>[];
    }
    final BigInt step = maxValue ~/ BigInt.from(count + 1);
    if (step <= BigInt.one) {
      throw const RankSpaceExhaustedException();
    }
    return List<String>.generate(
      count,
      (int index) => encode(step * BigInt.from(index + 1)),
      growable: false,
    );
  }

  static String encode(BigInt value) {
    if (value < BigInt.zero || value > maxValue) {
      throw RangeError.value(
        value,
        'value',
        'Rank must be between 0 and $maxValue.',
      );
    }
    BigInt remaining = value;
    final List<String> chars = List<String>.filled(width, '0');
    for (int index = width - 1; index >= 0; index--) {
      final int digit = (remaining % _base).toInt();
      chars[index] = alphabet[digit];
      remaining ~/= _base;
    }
    return chars.join();
  }

  static BigInt decode(String key) {
    if (key.length != width) {
      throw FormatException(
        'Rank must contain exactly $width characters.',
        key,
      );
    }
    BigInt value = BigInt.zero;
    for (final int codeUnit in key.codeUnits) {
      final String char = String.fromCharCode(codeUnit);
      final int digit = alphabet.indexOf(char);
      if (digit < 0) {
        throw FormatException('Invalid rank character.', key);
      }
      value = (value * _base) + BigInt.from(digit);
    }
    return value;
  }
}
