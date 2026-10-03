# llamalla

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Backend user creation

The account creation screen calls `POST /api/auth/register` on the Backend

The default API URL targets an Android emulator:

```text
http://10.0.2.2:8080/api
```

For a physical device, provide the development machine's local network address:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>:8080/api
```

## Android build toolchain

Use a supported JDK for the Android build, such as JDK 17 or JDK 23. Do not
commit a machine-specific `org.gradle.java.home` path. If Flutter is pointing
to an incompatible JDK, configure it locally with:

```bash
flutter config --jdk-dir="<path-to-supported-jdk>"
flutter build apk --debug
```

The app can be analyzed and tested without the backend. Flows that register,
log in, refresh, or revoke a real session require the backend to be running.

## Google sign-in

The Android Google button authenticates with the native Google Sign-In SDK,
then sends the Google ID token to `POST /api/auth/google`. The backend must
verify the token and return the same token response used by password login.

For this Android-only app, provide the OAuth web/server client ID at runtime;
do not commit it:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>
```

The Android application must also be registered in Google Cloud with the
package name `com.example.llamalla` and the SHA-1 certificate for the build
you are using. The backend must use the web/server client ID as the token
audience and verify the signature, issuer, audience, expiration, and identity
claims before issuing the application's access and refresh tokens.

This implementation does not require iOS, macOS, or web configuration.

## Google Calendar sync contract

The profile schedule uses the authenticated user's Google Calendar in
read-only mode. Flutter obtains a Google server authorization code and sends
it to the backend; provider access and refresh tokens remain on the backend.
The client expects these endpoints under `/api`:

- `POST /schedules/sync/google` with `{ "authCode": "..." }` imports or
  refreshes the user's Google busy time blocks. The optional `tz` query
  parameter controls timezone conversion.
- `POST /schedules/sync/google/refresh` refreshes an existing Google
  connection without requiring another authorization code.
- `GET /schedules/me/gaps?date=YYYY-MM-DD&tz=America/Bogota` returns the
  calculated free intervals for the requested date.

The profile renders the returned free intervals for Monday through Friday.
When the backend has no schedule data, it shows an empty state rather than
falling back to mock events. Activities remain local to the existing
Activities screen and are not modified by calendar synchronization.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
