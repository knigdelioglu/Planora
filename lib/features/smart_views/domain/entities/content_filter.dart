import 'dart:convert';

enum ContentScope { notes, cards, all }

enum ContentSortField { updatedAt, title }

enum ContentSortDirection { ascending, descending }

final class ContentFilter {
  const ContentFilter({
    this.version = currentVersion,
    this.scope = ContentScope.all,
    this.textQuery,
    this.allTagIds = const <String>[],
    this.anyTagIds = const <String>[],
    this.noneTagIds = const <String>[],
    this.hasTags,
    this.favorite,
    this.hasReminder,
    this.hasAttachment,
    this.updatedWithinDays,
    this.boardId,
    this.columnId,
    this.sortField = ContentSortField.updatedAt,
    this.sortDirection = ContentSortDirection.descending,
  });

  static const int currentVersion = 1;

  final int version;
  final ContentScope scope;
  final String? textQuery;
  final List<String> allTagIds;
  final List<String> anyTagIds;
  final List<String> noneTagIds;
  final bool? hasTags;
  final bool? favorite;
  final bool? hasReminder;
  final bool? hasAttachment;
  final int? updatedWithinDays;
  final String? boardId;
  final String? columnId;
  final ContentSortField sortField;
  final ContentSortDirection sortDirection;

  bool get isEmpty =>
      scope == ContentScope.all &&
      textQuery == null &&
      allTagIds.isEmpty &&
      anyTagIds.isEmpty &&
      noneTagIds.isEmpty &&
      hasTags == null &&
      favorite == null &&
      hasReminder == null &&
      hasAttachment == null &&
      updatedWithinDays == null &&
      boardId == null &&
      columnId == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'scope': scope.name,
    'textQuery': textQuery,
    'tags': <String, Object?>{
      'all': allTagIds,
      'any': anyTagIds,
      'none': noneTagIds,
      'hasTags': hasTags,
    },
    'favorite': favorite,
    'hasReminder': hasReminder,
    'hasAttachment': hasAttachment,
    'updatedWithinDays': updatedWithinDays,
    'boardId': boardId,
    'columnId': columnId,
    'sort': <String, Object?>{
      'field': sortField.name,
      'direction': sortDirection.name,
    },
  };

  String encode() => jsonEncode(toJson());

  factory ContentFilter.decode(String value) {
    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is Map<String, Object?>) {
        return ContentFilter.fromJson(decoded);
      }
      if (decoded is Map<Object?, Object?>) {
        return ContentFilter.fromJson(
          decoded.map(
            (Object? key, Object? value) =>
                MapEntry<String, Object?>(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Corrupt persisted views fall back to a harmless empty filter.
    }
    return const ContentFilter();
  }

  factory ContentFilter.fromJson(Map<String, Object?> json) {
    final int version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > currentVersion) {
      throw StateError('Unsupported smart-view query version: $version');
    }

    final Map<String, Object?> tags = _stringMap(json['tags']);
    final Map<String, Object?> sort = _stringMap(json['sort']);
    return ContentFilter(
      version: version,
      scope: _enumByName(
        ContentScope.values,
        json['scope']?.toString(),
        ContentScope.all,
      ),
      textQuery: _nullableText(json['textQuery']),
      allTagIds: _stringList(tags['all']),
      anyTagIds: _stringList(tags['any']),
      noneTagIds: _stringList(tags['none']),
      hasTags: tags['hasTags'] as bool?,
      favorite: json['favorite'] as bool?,
      hasReminder: json['hasReminder'] as bool?,
      hasAttachment: json['hasAttachment'] as bool?,
      updatedWithinDays: (json['updatedWithinDays'] as num?)?.toInt(),
      boardId: _nullableText(json['boardId']),
      columnId: _nullableText(json['columnId']),
      sortField: _enumByName(
        ContentSortField.values,
        sort['field']?.toString(),
        ContentSortField.updatedAt,
      ),
      sortDirection: _enumByName(
        ContentSortDirection.values,
        sort['direction']?.toString(),
        ContentSortDirection.descending,
      ),
    );
  }

  ContentFilter copyWith({
    ContentScope? scope,
    String? textQuery,
    bool clearTextQuery = false,
    List<String>? allTagIds,
    List<String>? anyTagIds,
    List<String>? noneTagIds,
    bool? hasTags,
    bool clearHasTags = false,
    bool? favorite,
    bool clearFavorite = false,
    bool? hasReminder,
    bool clearHasReminder = false,
    bool? hasAttachment,
    bool clearHasAttachment = false,
    int? updatedWithinDays,
    bool clearUpdatedWithinDays = false,
    String? boardId,
    bool clearBoardId = false,
    String? columnId,
    bool clearColumnId = false,
    ContentSortField? sortField,
    ContentSortDirection? sortDirection,
  }) => ContentFilter(
    version: version,
    scope: scope ?? this.scope,
    textQuery: clearTextQuery ? null : textQuery ?? this.textQuery,
    allTagIds: allTagIds ?? this.allTagIds,
    anyTagIds: anyTagIds ?? this.anyTagIds,
    noneTagIds: noneTagIds ?? this.noneTagIds,
    hasTags: clearHasTags ? null : hasTags ?? this.hasTags,
    favorite: clearFavorite ? null : favorite ?? this.favorite,
    hasReminder: clearHasReminder ? null : hasReminder ?? this.hasReminder,
    hasAttachment: clearHasAttachment
        ? null
        : hasAttachment ?? this.hasAttachment,
    updatedWithinDays: clearUpdatedWithinDays
        ? null
        : updatedWithinDays ?? this.updatedWithinDays,
    boardId: clearBoardId ? null : boardId ?? this.boardId,
    columnId: clearColumnId ? null : columnId ?? this.columnId,
    sortField: sortField ?? this.sortField,
    sortDirection: sortDirection ?? this.sortDirection,
  );
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map<Object?, Object?>) {
    return value.map(
      (Object? key, Object? item) =>
          MapEntry<String, Object?>(key.toString(), item),
    );
  }
  return const <String, Object?>{};
}

List<String> _stringList(Object? value) {
  if (value is! Iterable<Object?>) return const <String>[];
  return value
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _nullableText(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
