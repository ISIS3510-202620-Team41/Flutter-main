import 'package:flutter_dotenv/flutter_dotenv.dart';

/// El backend arma la URL de las fotos con PUBLIC_BASE_URL, que por defecto es
/// http://localhost:8080. En el emulador "localhost" es el propio emulador y no
/// el computador, entonces la foto sube bien pero nunca se ve.
/// Acá cambiamos ese host por el del API que ya usa la app (API_BASE_URL).
String? resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  final media = Uri.tryParse(url);
  if (media == null || !media.hasAuthority) return url;

  const localHosts = {'localhost', '127.0.0.1'};
  if (!localHosts.contains(media.host)) return url;

  final api = Uri.parse(_apiBaseUrl());
  return media
      .replace(scheme: api.scheme, host: api.host, port: api.port)
      .toString();
}

String _apiBaseUrl() {
  final fromEnv = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
  return (fromEnv == null || fromEnv.isEmpty)
      ? 'http://10.0.2.2:8080/api'
      : fromEnv;
}