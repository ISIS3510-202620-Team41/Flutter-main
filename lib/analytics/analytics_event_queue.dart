abstract interface class AnalyticsEventQueue {
  Future<void> initialize();

  Future<void> enqueueEvent(Map<String, dynamic> event);

  Future<List<Map<String, dynamic>>> readBatch({
    int limit = 200,
  });

  Future<void> removeEventsById(Set<String> eventIds);

  Future<void> enqueuePendingCrash(
    Map<String, dynamic> crash,
  );

  Future<List<Map<String, dynamic>>> readPendingCrashes();

  Future<void> clearPendingCrashes();
}