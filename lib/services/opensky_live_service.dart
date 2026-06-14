import 'dart:convert';
import 'dart:io';

/// 실시간 항공(OpenSky)을 **디바이스에서 직접** 조회한다.
///
/// 왜 네이티브에서?
/// - 브라우저/웹뷰 JS는 OpenSky의 CORS 미지원 + GCP egress 타임아웃으로 직접 호출 불가.
/// - Flutter 네이티브 HTTP는 CORS가 없고 유저 디바이스 망을 쓰므로 둘 다 우회된다.
///
/// 호출 결과는 [WorldMapScreen]의 `liveFlights.fetch` 핸들러가
/// Firestore(`flightsLive/{key}`)에 단일 JSON으로 캐시한 뒤 웹뷰로 반환한다.
///
/// OAuth 자격증명은 `--dart-define-from-file=env/prod.json` 으로 주입한다:
///   OPENSKY_CLIENT_ID / OPENSKY_CLIENT_SECRET
/// 둘 다 비어 있으면 익명 모드(디바이스 IP당 하루 400 크레딧)로 동작한다.
class OpenSkyLiveService {
  OpenSkyLiveService._();

  static const String _clientId =
      String.fromEnvironment('OPENSKY_CLIENT_ID');
  static const String _clientSecret =
      String.fromEnvironment('OPENSKY_CLIENT_SECRET');

  static const int _maxFlights = 500;

  // 토큰 메모리 캐시(앱 프로세스 동안 재사용).
  static String? _token;
  static DateTime _tokenExp = DateTime.fromMillisecondsSinceEpoch(0);

  /// OAuth2 client_credentials 토큰. 실패 시 null(익명 폴백).
  static Future<String?> _getToken() async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) return null; // 익명
    if (_token != null && DateTime.now().isBefore(_tokenExp)) {
      return _token;
    }
    final uri = Uri.parse(
      'https://auth.opensky-network.org/auth/realms/opensky-network/'
      'protocol/openid-connect/token',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      final body = 'grant_type=client_credentials'
          '&client_id=${Uri.encodeQueryComponent(_clientId)}'
          '&client_secret=${Uri.encodeQueryComponent(_clientSecret)}';
      req.add(utf8.encode(body));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final text = await res.transform(utf8.decoder).join();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final token = json['access_token'] as String?;
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 1800;
      _token = token;
      _tokenExp = DateTime.now()
          .add(Duration(seconds: (expiresIn - 60).clamp(60, 3600).toInt()));
      return token;
    } catch (_) {
      return null; // 토큰 실패 → 익명으로 시도
    } finally {
      client.close(force: true);
    }
  }

  /// states/all 호출 → 비행 목록.
  ///
  /// 반환: `{ 'flights': List<Map>, 'time': int, 'error'?: dynamic }`
  /// flight 맵 구조는 웹의 `LiveFlight`와 동일:
  ///   id, callsign, country, lat, lng, heading, alt, vel
  static Future<Map<String, dynamic>> fetchStates({
    required int lamin,
    required int lomin,
    required int lamax,
    required int lomax,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('https://opensky-network.org/api/states/all')
        .replace(queryParameters: {
      'lamin': '$lamin',
      'lomin': '$lomin',
      'lamax': '$lamax',
      'lomax': '$lomax',
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return {
          'flights': <Map<String, dynamic>>[],
          'error': res.statusCode,
        };
      }
      final text = await res.transform(utf8.decoder).join();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final states = (json['states'] as List?) ?? const [];
      final flights = <Map<String, dynamic>>[];
      for (final s in states) {
        if (s is! List) continue;
        final lng = s.length > 5 ? s[5] : null;
        final lat = s.length > 6 ? s[6] : null;
        final onGround = s.length > 8 && s[8] == true;
        if (onGround || lat is! num || lng is! num) continue;
        final baro = s.length > 7 ? s[7] : null;
        final geo = s.length > 13 ? s[13] : null;
        flights.add({
          'id': s.isNotEmpty ? s[0] : '',
          'callsign': (s.length > 1 && s[1] != null)
              ? s[1].toString().trim()
              : '',
          'country': (s.length > 2 && s[2] != null) ? s[2].toString() : '',
          'lat': lat,
          'lng': lng,
          'heading': (s.length > 10 && s[10] is num) ? s[10] : 0,
          'alt': geo is num ? geo : (baro is num ? baro : null),
          'vel': (s.length > 9 && s[9] is num) ? s[9] : null,
        });
        if (flights.length >= _maxFlights) break;
      }
      final time = (json['time'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return {'flights': flights, 'time': time};
    } catch (_) {
      return {'flights': <Map<String, dynamic>>[], 'error': 'network'};
    } finally {
      client.close(force: true);
    }
  }
}
