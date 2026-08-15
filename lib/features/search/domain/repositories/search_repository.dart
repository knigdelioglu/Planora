import 'package:not_app/features/search/domain/entities/search_result.dart';

abstract interface class SearchRepository {
  Future<List<SearchResultEntity>> search(String query, {int limit = 60});
  Future<void> rebuildIndex();
}
