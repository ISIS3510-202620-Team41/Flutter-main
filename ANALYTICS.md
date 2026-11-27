# Flutter analytics

The app sends the Flutter-owned Analytics-engine v1 events:

- `app_loading_time` once after the first interactive frame.
- `screen_view` when a named route or dashboard tab becomes visible.
- `crash` on the next startup after an uncaught Flutter or platform error.

Events are persisted in `SharedPreferences`, sent in batches of up to 200, and
retried in the background. The normal app flow does not depend on the
analytics engine being available. Events remain queued until a user ID can be
derived from the authenticated access-token JWT.

Activity creation emits `plan_creation_attempted` through `AnalyticsFacade`
with the BQ14 context and a UUID `attemptId`. The same ID is sent to the
backend and retained with offline `CREATE_ACTIVITY` actions; retries reuse it
without emitting another attempt event. The backend owns
`plan_creation_result`. The context records the selected category, selected
activity duration as `freeTimeMinutes`, location coordinates, and available
versus selected available friends.

## Configuration

Copy `.env.example` to `.env` and set the engine settings there:

```text
ANALYTICS_BASE_URL=http://10.0.2.2:8000
ANALYTICS_INGEST_KEY=local-ingest-key
```

Use the analytics host machine's LAN IP instead of `10.0.2.2` on a physical
device. The default URL is the Android emulator URL shown above. The ingest
key is optional in local development and is sent as `X-API-Key` when present.
