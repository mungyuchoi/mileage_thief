import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract class AnalyticsClient {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  Future<void> logScreenView({
    String? screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  });

  Future<void> setUserId(String? id);

  Future<void> setUserProperty({
    required String name,
    required String? value,
  });
}

class FirebaseAnalyticsClient implements AnalyticsClient {
  FirebaseAnalyticsClient([FirebaseAnalytics? analytics])
      : _analytics = analytics;

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get _resolvedAnalytics {
    if (Firebase.apps.isEmpty) return null;
    return _analytics ??= FirebaseAnalytics.instance;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    final analytics = _resolvedAnalytics;
    if (analytics == null) return;
    await analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    String? screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    final analytics = _resolvedAnalytics;
    if (analytics == null) return;
    await analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }

  @override
  Future<void> setUserId(String? id) async {
    final analytics = _resolvedAnalytics;
    if (analytics == null) return;
    await analytics.setUserId(id: id);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    final analytics = _resolvedAnalytics;
    if (analytics == null) return;
    await analytics.setUserProperty(name: name, value: value);
  }
}

class AnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track(previousRoute);
  }

  void _track(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return;

    final screenName = AnalyticsService.screenNameForRoute(route.settings);
    if (screenName == null) return;

    unawaited(
      AnalyticsService.instance.logScreenView(
        screenName,
        screenClass: route.runtimeType.toString(),
        source: 'navigator',
      ),
    );
  }
}

class AnalyticsService {
  AnalyticsService({
    AnalyticsClient? client,
    bool Function()? isLoggedInProvider,
  })  : _client = client ?? FirebaseAnalyticsClient(),
        _isLoggedInProvider = isLoggedInProvider;

  static final AnalyticsRouteObserver routeObserver = AnalyticsRouteObserver();

  static AnalyticsService instance = AnalyticsService();

  static const Map<String, String> _routeScreenNames = {
    '/': 'home',
    '/splash': 'splash',
    '/community_board_select': 'community_board_select',
    '/community/detail': 'community_detail',
    '/community/create_v3': 'community_post_create',
    '/community/chat': 'community_chat',
    '/cards': 'card_hub',
    '/card': 'card_hub',
    '/my-cards': 'my_card_dashboard',
    '/card/detail': 'card_detail',
    '/giftcard/deal': 'giftcard_deal_detail',
  };

  static const Map<String, String> _reservedEventAliases = {
    'notification_open': 'notification_opened',
    'screen_view': 'manual_screen_view',
  };

  static const Set<String> _allowedIdKeys = {
    'entity_id',
    'post_id',
    'comment_id',
    'board_id',
    'card_id',
    'deal_id',
    'branch_id',
    'giftcard_id',
    'label_key',
    'target_id',
    'route',
    'has_image',
    'has_text',
    'image_count',
    'image_count_bucket',
    'link_type',
    'notification_type',
    'channel_id',
  };

  static const List<String> _blockedKeyParts = [
    'email',
    'mail',
    'phone',
    'display_name',
    'nickname',
    'photo',
    'image',
    'url',
    'uri',
    'link',
    'content',
    'body',
    'text',
    'subject',
    'memo',
    'message',
    'token',
    'uid',
    'author',
    'reporter',
    'title',
    'description',
  ];

  static const List<String> _moneyKeyParts = [
    'amount',
    'price',
    'total',
    'unit',
    'fee',
    'cost',
    'profit',
    'value',
    'won',
  ];

  final AnalyticsClient _client;
  final bool Function()? _isLoggedInProvider;
  StreamSubscription<User?>? _authSubscription;
  String? _lastScreenName;
  DateTime? _lastScreenLoggedAt;

  static String? screenNameForRoute(RouteSettings settings) {
    final routeName = settings.name?.trim();
    if (routeName == null || routeName.isEmpty) return null;
    return _routeScreenNames[routeName] ?? _normalizeName(routeName);
  }

  static String screenNameForWidget(Widget screen) {
    return _normalizeName(screen.runtimeType.toString());
  }

  static String amountBucket(num? amount) {
    if (amount == null || amount <= 0) return '0';
    final value = amount.abs();
    if (value < 10000) return 'lt_10k';
    if (value < 50000) return '10k_50k';
    if (value < 100000) return '50k_100k';
    if (value < 500000) return '100k_500k';
    if (value < 1000000) return '500k_1m';
    if (value < 5000000) return '1m_5m';
    return 'gte_5m';
  }

  static String quantityBucket(num? quantity) {
    if (quantity == null || quantity <= 0) return '0';
    final value = quantity.abs();
    if (value <= 1) return '1';
    if (value <= 5) return '2_5';
    if (value <= 10) return '6_10';
    if (value <= 50) return '11_50';
    return 'gte_51';
  }

  Future<void> startUserTracking() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    await _applyAuthUser(currentUser);
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        unawaited(_applyAuthUser(user));
      },
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> setUserId(String uid) async {
    await _safeCall(() => _client.setUserId(uid));
  }

  Future<void> clearUserId() async {
    await _safeCall(() => _client.setUserId(null));
  }

  Future<void> setUserProperties(Map<String, Object?> properties) async {
    for (final entry in properties.entries) {
      final key = _sanitizeKey(entry.key);
      if (key == null) continue;

      final value = entry.value;
      final String? propertyValue;
      if (value == null) {
        propertyValue = null;
      } else if (value is bool) {
        propertyValue = value ? 'true' : 'false';
      } else {
        propertyValue = _truncate(value.toString().trim(), 36);
      }

      await _safeCall(
        () => _client.setUserProperty(name: key, value: propertyValue),
      );
    }
  }

  Future<void> logScreenView(
    String screenName, {
    String? screenClass,
    String? source,
    Map<String, Object?>? parameters,
  }) async {
    final normalizedScreenName = _normalizeName(screenName);
    final now = DateTime.now();
    if (_lastScreenName == normalizedScreenName &&
        _lastScreenLoggedAt != null &&
        now.difference(_lastScreenLoggedAt!) <
            const Duration(milliseconds: 800)) {
      return;
    }
    _lastScreenName = normalizedScreenName;
    _lastScreenLoggedAt = now;

    final sanitized = _sanitizeParameters({
      if (source != null) 'source': source,
      if (parameters != null) ...parameters,
    });
    await _safeCall(
      () => _client.logScreenView(
        screenName: normalizedScreenName,
        screenClass: screenClass,
        parameters: sanitized,
      ),
    );
  }

  Future<void> logTabSelected(
    String tabGroup,
    String tabName, {
    String? source,
  }) {
    final normalizedGroup = _normalizeName(tabGroup);
    final eventName = switch (normalizedGroup) {
      'home' => 'home_tab_selected',
      'giftcard' => 'giftcard_subtab_selected',
      _ => 'sub_tab_selected',
    };
    return logAction(
      eventName,
      params: {
        'tab_group': normalizedGroup,
        'tab': _normalizeName(tabName),
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> logContentOpen(
    String type,
    String id, {
    String? source,
    Map<String, Object?>? extra,
  }) {
    return logAction(
      'content_open',
      params: {
        'entity_type': _normalizeName(type),
        'entity_id': id,
        if (source != null) 'source': source,
        if (extra != null) ...extra,
      },
    );
  }

  Future<void> logAction(
    String name, {
    Map<String, Object?>? params,
  }) async {
    final eventName = _normalizeEventName(name);
    final sanitized = _sanitizeParameters(params);
    await _safeCall(
      () => _client.logEvent(name: eventName, parameters: sanitized),
    );
  }

  Future<void> logResult(
    String name, {
    required String result,
    String? errorCode,
    Map<String, Object?>? params,
  }) {
    return logAction(
      name,
      params: {
        if (params != null) ...params,
        'result': _normalizeName(result),
        if (errorCode != null) 'error_code': errorCode,
      },
    );
  }

  Future<void> _applyAuthUser(User? user) async {
    if (user == null) {
      await clearUserId();
      await setUserProperties({'is_logged_in': false});
      return;
    }

    await setUserId(user.uid);
    await setUserProperties({
      'is_logged_in': true,
      'auth_provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'unknown',
    });
  }

  Map<String, Object>? _sanitizeParameters(Map<String, Object?>? parameters) {
    final sanitized = <String, Object>{
      'is_logged_in': _isLoggedIn() ? 1 : 0,
      'platform': _platformName(),
    };

    parameters?.forEach((rawKey, rawValue) {
      final key = _sanitizeKey(rawKey);
      if (key == null || rawValue == null || _isBlockedKey(key)) return;

      final value = _sanitizeValue(key, rawValue);
      if (value == null) return;

      if (value is _BucketedValue) {
        sanitized[value.key] = value.value;
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized.isEmpty ? null : sanitized;
  }

  Object? _sanitizeValue(String key, Object value) {
    if (value is bool) return value ? 1 : 0;
    if (value is int) return _bucketIfNeeded(key, value);
    if (value is double) return _bucketIfNeeded(key, value);
    if (value is num) return _bucketIfNeeded(key, value);
    if (value is DateTime) return null;

    final text = value.toString().trim();
    if (text.isEmpty || _looksSensitive(text)) return null;
    return _truncate(text, 100);
  }

  Object _bucketIfNeeded(String key, num value) {
    if (key.endsWith('_bucket')) return _truncate(value.toString(), 100);
    if (key == 'qty' || key == 'quantity') {
      return _BucketedValue('${key}_bucket', quantityBucket(value));
    }
    if (_moneyKeyParts.any((part) => key.contains(part))) {
      return _BucketedValue('${key}_bucket', amountBucket(value));
    }
    return value;
  }

  bool _isLoggedIn() {
    final provider = _isLoggedInProvider;
    if (provider != null) return provider();
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      debugPrint('AnalyticsService ignored error: $error');
    }
  }

  static String _normalizeEventName(String value) {
    final aliased = _reservedEventAliases[value] ?? value;
    final normalized = _normalizeName(aliased);
    return normalized.length <= 40 ? normalized : normalized.substring(0, 40);
  }

  static String _normalizeName(String value) {
    final withSeparators = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll('/', '_')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    final cleaned = withSeparators
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    if (cleaned.isEmpty) return 'unknown';
    if (RegExp(r'^[a-zA-Z]').hasMatch(cleaned)) return cleaned;
    return 'p_$cleaned';
  }

  static String? _sanitizeKey(String key) {
    final sanitized = _normalizeName(key);
    if (sanitized.isEmpty) return null;
    return sanitized.length <= 40 ? sanitized : sanitized.substring(0, 40);
  }

  bool _isBlockedKey(String key) {
    if (_allowedIdKeys.contains(key)) return false;
    return _blockedKeyParts.any((part) => key.contains(part));
  }

  bool _looksSensitive(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(lower)) {
      return true;
    }
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  static String _truncate(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}

class _BucketedValue {
  const _BucketedValue(this.key, this.value);

  final String key;
  final String value;
}
