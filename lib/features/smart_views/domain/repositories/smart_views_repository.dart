import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view_result.dart';

abstract interface class SmartViewsRepository {
  Stream<List<SmartViewEntity>> watchViews();

  Stream<List<SmartViewResult>> watchResults(ContentFilter filter);

  Future<List<SmartViewResult>> query(ContentFilter filter);

  Future<String> createView({
    required String name,
    required ContentFilter filter,
    String iconKey = 'filter_alt',
  });

  Future<void> updateView({
    required String viewId,
    required String name,
    required ContentFilter filter,
    String? iconKey,
  });

  Future<void> deleteView(String viewId);
}
