import 'dart:convert';

final class SyncConflictEntity {
  const SyncConflictEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localJson,
    required this.remoteJson,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String localJson;
  final String remoteJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;

  /// Parsed local payload JSON safely.
  Map<String, Object?> get localPayload {
    try {
      final Object? decoded = jsonDecode(localJson);
      return decoded is Map
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{};
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  /// Parsed remote payload JSON safely.
  Map<String, Object?> get remotePayload {
    try {
      final Object? decoded = jsonDecode(remoteJson);
      return decoded is Map
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{};
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  /// Human-readable entity type in Turkish.
  String get entityTypeLabel => switch (entityType.toLowerCase()) {
    'note' => 'Not',
    'card' => 'Kart',
    'board' => 'Pano',
    'column' => 'Kolon',
    'attachment' => 'Ek Dosya',
    'reminder' => 'Hatırlatıcı',
    _ => entityType,
  };

  /// Prominent human-friendly display title for the conflicting entity (Criterion 1).
  String get displayTitle {
    final String? localTitle = (localPayload['title'] as String?)?.trim();
    if (localTitle != null && localTitle.isNotEmpty) {
      return localTitle;
    }
    final String? remoteTitle = (remotePayload['title'] as String?)?.trim();
    if (remoteTitle != null && remoteTitle.isNotEmpty) {
      return remoteTitle;
    }
    if (entityType.toLowerCase() == 'attachment') {
      final String? fileName =
          (localPayload['fileName'] ?? remotePayload['fileName']) as String?;
      if (fileName != null && fileName.trim().isNotEmpty) {
        return fileName.trim();
      }
    }
    return switch (entityType.toLowerCase()) {
      'note' => 'Başlıksız Not',
      'card' => 'Başlıksız Kart',
      'board' => 'Başlıksız Pano',
      'column' => 'Başlıksız Kolon',
      _ =>
        '$entityTypeLabel (${entityId.length > 8 ? entityId.substring(0, 8) : entityId})',
    };
  }

  /// Extracted local update timestamp if present.
  DateTime? get localUpdatedAt {
    final Object? raw = localPayload['updatedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  /// Extracted remote update timestamp if present.
  DateTime? get remoteUpdatedAt {
    final Object? raw = remotePayload['updatedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  /// Local version number if present.
  int? get localVersion => (localPayload['version'] as num?)?.toInt();

  /// Remote version number if present.
  int? get remoteVersion => (remotePayload['version'] as num?)?.toInt();

  /// Whether this entity is a note.
  bool get isNote => entityType.toLowerCase() == 'note';

  /// Whether this entity is a card.
  bool get isCard => entityType.toLowerCase() == 'card';

  /// Whether this entity supports saving both versions as copy.
  bool get canResolveAsCopy => isNote || isCard;
}
