enum AnalyticsIngestionResult {
  accepted,
  discarded,
  retained,
}

abstract interface class AnalyticsIngestionService {
  Future<AnalyticsIngestionResult> sendBatch({
    required List<Map<String, dynamic>> events,
    required String userId,
  });
}