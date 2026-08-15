import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';

void main() {
  test('retry delay grows and stays bounded', () {
    final first = DriftSyncQueueRepository.retryDelay(1, 1);
    final later = DriftSyncQueueRepository.retryDelay(8, 1);
    final extreme = DriftSyncQueueRepository.retryDelay(100, 1);
    expect(later, greaterThan(first));
    expect(extreme, lessThanOrEqualTo(const Duration(hours: 1)));
  });
}
