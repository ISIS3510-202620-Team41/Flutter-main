import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and restores tokens and user id', () async {
    final store = SessionStore();
    await store.saveSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'user-1',
    );

    expect(await SessionStore().accessToken(), 'access');
    expect(await SessionStore().userId(), 'user-1');
  });

  test('stores and reads the last sync time', () async {
    final store = SessionStore();
    expect(await store.lastSyncAt(), isNull);

    final moment = DateTime.utc(2026, 10, 30, 12);
    await store.markSynced(moment);

    expect(await store.lastSyncAt(), moment);
  });

  test('clear removes everything, including user id and last sync', () async {
    final store = SessionStore();
    await store.saveSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'user-1',
    );
    await store.markSynced();

    await store.clear();

    expect(await store.accessToken(), isNull);
    expect(await store.userId(), isNull);
    expect(await store.lastSyncAt(), isNull);
  });
}