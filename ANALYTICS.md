# Flutter analytics

The app sends the Flutter-owned Analytics-engine v1 events:

- `app_loading_time` once after the first interactive frame.
- `screen_view` when a named route or dashboard tab becomes visible.
- `feature_used` for Friend Availability, loading/selecting recommendations,
  and joins.
- `crash` on the next startup after an uncaught Flutter or platform error.

Events are persisted in `SharedPreferences`, sent in batches of up to 200, and
retried in the background. The normal app flow does not depend on the
analytics engine being available. Events remain queued until a user ID can be
derived from the authenticated access-token JWT.

BQ8 uses these `screen_view` and `feature_used` events to calculate screen and
feature adoption. Recommendations are a feature on `Home`, not a separate
screen, so their adoption is recorded as `activity_recommendations` rather
than a virtual `Recommendations` screen view. Friend Availability plan
creation is additionally attributed by the backend as
`friend_availability_used` with action `plan_created`; when creation is queued
offline, `ActivityRepository.syncPending()` reuses the stored
`friend_availability` source so the backend records the same action.

The Analytics-engine's initial screen catalog still contains `Recommendations`.
Because the app has no separate route for it, that catalog entry can appear as
an underutilized screen until the engine catalog is aligned with the app.

Activity creation emits `plan_creation_attempted` through `AnalyticsFacade`
with the BQ14 context and a UUID `attemptId`. The same ID is sent to the
backend and retained with offline `CREATE_ACTIVITY` actions; retries reuse it
without emitting another attempt event. The backend owns
`plan_creation_result`. The context records the selected category, selected
category, `recommendationFreeMinutes`, location coordinates, and available
versus selected available friends. When recommendation free time is unavailable,
the activity can still be created, but Flutter omits `plan_creation_attempted`
because the Analytics-engine BQ14 event requires `freeTimeMinutes`.

## Configuration

Copy `.env.example` to `.env` and set the engine settings there:

```text
ANALYTICS_BASE_URL=http://10.0.2.2:8000
ANALYTICS_INGEST_KEY=local-ingest-key
```

Use the analytics host machine's LAN IP instead of `10.0.2.2` on a physical
device. The default URL is the Android emulator URL shown above. The ingest
key is optional in local development and is sent as `X-API-Key` when present.
