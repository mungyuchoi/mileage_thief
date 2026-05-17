import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/services/analytics_service.dart';

class _LoggedEvent {
  const _LoggedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object>? parameters;
}

class _FakeAnalyticsClient implements AnalyticsClient {
  final events = <_LoggedEvent>[];
  final screenViews = <_LoggedEvent>[];
  final userIds = <String?>[];
  final userProperties = <String, String?>{};

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_LoggedEvent(name, parameters));
  }

  @override
  Future<void> logScreenView({
    String? screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    screenViews.add(_LoggedEvent(screenName ?? '', parameters));
  }

  @override
  Future<void> setUserId(String? id) async {
    userIds.add(id);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    userProperties[name] = value;
  }
}

void main() {
  group('AnalyticsService', () {
    test('removes null, empty, URL, email, and PII-like parameters', () async {
      final fake = _FakeAnalyticsClient();
      final service = AnalyticsService(
        client: fake,
        isLoggedInProvider: () => true,
      );

      await service.logAction('community_post_open', params: {
        'post_id': 'post_123',
        'email': 'user@example.com',
        'display_name': 'Tester',
        'memo': 'free form memo',
        'link_value': 'https://example.com',
        'has_image': true,
        'empty': '',
        'nullable': null,
        'board_id': 'free',
      });

      final params = fake.events.single.parameters!;
      expect(params['post_id'], 'post_123');
      expect(params['board_id'], 'free');
      expect(params['has_image'], 1);
      expect(params['is_logged_in'], 1);
      expect(params.containsKey('email'), isFalse);
      expect(params.containsKey('display_name'), isFalse);
      expect(params.containsKey('memo'), isFalse);
      expect(params.containsKey('link_value'), isFalse);
      expect(params.containsKey('empty'), isFalse);
      expect(params.containsKey('nullable'), isFalse);
    });

    test('buckets monetary and quantity values instead of sending raw values',
        () async {
      final fake = _FakeAnalyticsClient();
      final service = AnalyticsService(
        client: fake,
        isLoggedInProvider: () => false,
      );

      await service.logAction('gift_buy_saved', params: {
        'buy_total': 965000,
        'qty': 7,
        'face_value': 100000,
      });

      final params = fake.events.single.parameters!;
      expect(params['buy_total_bucket'], '500k_1m');
      expect(params['qty_bucket'], '6_10');
      expect(params['face_value_bucket'], '100k_500k');
      expect(params.containsKey('buy_total'), isFalse);
      expect(params.containsKey('qty'), isFalse);
      expect(params.containsKey('face_value'), isFalse);
      expect(params['is_logged_in'], 0);
    });

    test('sets and clears the Firebase user id', () async {
      final fake = _FakeAnalyticsClient();
      final service = AnalyticsService(client: fake);

      await service.setUserId('uid_123');
      await service.clearUserId();

      expect(fake.userIds, ['uid_123', null]);
    });

    test('aliases reserved Firebase event names', () async {
      final fake = _FakeAnalyticsClient();
      final service = AnalyticsService(client: fake);

      await service.logAction('notification_open');

      expect(fake.events.single.name, 'notification_opened');
    });

    test('ignores default client calls before Firebase is initialized',
        () async {
      final service = AnalyticsService(isLoggedInProvider: () => false);

      await service.logScreenView('splash', source: 'navigator');
      await service.logAction('app_open');
      await service.setUserId('uid_123');
    });
  });
}
