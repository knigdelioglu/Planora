abstract interface class KanbanRemoteDataSource {
  Future<void> pushCardMutation({
    required String cardId,
    required Map<String, Object?> payload,
    required int? baseVersion,
  });
}
