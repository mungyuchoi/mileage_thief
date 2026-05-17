import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String communityPostLike = 'community_post_like';
  static const String communityPostComment = 'community_post_comment';
  static const String communityCommentReply = 'community_comment_reply';
  static const String communityCommentLike = 'community_comment_like';
  static const String radarAll = 'radar_all';
  static const String radarMileageSeat = 'radar_mileage_seat';
  static const String radarCancelAlert = 'radar_cancel_alert';
  static const String radarFlightDeal = 'radar_flight_deal';
  static const String radarGiftcard = 'radar_giftcard';
  static const String radarBenefitNews = 'radar_benefit_news';

  static const Map<String, bool> defaultPreferences = {
    communityPostLike: true,
    communityPostComment: true,
    communityCommentReply: true,
    communityCommentLike: true,
    radarAll: true,
    radarMileageSeat: true,
    radarCancelAlert: true,
    radarFlightDeal: true,
    radarGiftcard: true,
    radarBenefitNews: true,
  };

  static const Map<String, String> _legacyKeys = {
    communityPostLike: 'post_like_notification',
    communityPostComment: 'post_comment_notification',
    communityCommentReply: 'comment_reply_notification',
    communityCommentLike: 'comment_like_notification',
    radarAll: 'radar_notification',
  };

  static String _cacheKey(String key) => 'notification_preference_$key';

  static Future<Map<String, bool>> loadPreferences() async {
    final localPreferences = await loadLocalPreferences();
    final user = _auth.currentUser;
    if (user == null) {
      return localPreferences;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      final data = doc.data();
      final remoteRaw = data?['notificationPreferences'];
      if (remoteRaw is Map && remoteRaw.isNotEmpty) {
        final remotePreferences = _normalizePreferences(remoteRaw);
        final mergedPreferences = {
          ...defaultPreferences,
          ...remotePreferences,
        };
        await cachePreferences(mergedPreferences);
        if (remotePreferences.length != defaultPreferences.length) {
          await _writePreferences(user.uid, mergedPreferences);
        }
        return mergedPreferences;
      }

      await _writePreferences(user.uid, localPreferences);
      await cachePreferences(localPreferences);
      return localPreferences;
    } catch (_) {
      return localPreferences;
    }
  }

  static Future<Map<String, bool>> loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final values = Map<String, bool>.from(defaultPreferences);

    for (final key in defaultPreferences.keys) {
      final cached = prefs.getBool(_cacheKey(key));
      if (cached != null) {
        values[key] = cached;
      }
    }

    for (final entry in _legacyKeys.entries) {
      final cacheKey = _cacheKey(entry.key);
      if (prefs.getBool(cacheKey) != null) {
        continue;
      }
      final legacyValue = prefs.getBool(entry.value);
      if (legacyValue != null) {
        values[entry.key] = legacyValue;
      }
    }

    return values;
  }

  static Future<Map<String, bool>> setPreference(
    String key,
    bool enabled,
  ) async {
    if (!defaultPreferences.containsKey(key)) {
      throw ArgumentError('Unknown notification preference key: $key');
    }

    final preferences = await loadPreferences();
    preferences[key] = enabled;
    await cachePreferences(preferences);

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'notificationPreferences': {key: enabled},
        'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return preferences;
  }

  static Future<void> cachePreferences(Map<String, bool> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final mergedPreferences = {
      ...defaultPreferences,
      ...preferences,
    };

    for (final entry in mergedPreferences.entries) {
      await prefs.setBool(_cacheKey(entry.key), entry.value);
    }

    for (final entry in _legacyKeys.entries) {
      await prefs.setBool(entry.value, mergedPreferences[entry.key] ?? true);
    }
  }

  static Future<bool> isLocalEnabledForRemoteMessage(
    Map<String, dynamic> data,
  ) async {
    final preferences = await loadLocalPreferences();
    return _isEnabledForData(data, preferences);
  }

  static Future<bool> isEnabledForRemoteMessage(
    Map<String, dynamic> data,
  ) async {
    final preferences = await loadPreferences();
    return _isEnabledForData(data, preferences);
  }

  static bool _isEnabledForData(
    Map<String, dynamic> data,
    Map<String, bool> preferences,
  ) {
    final type = data['type']?.toString();
    final communityKey = _communityPreferenceKey(type);
    if (communityKey != null) {
      return preferences[communityKey] ?? true;
    }

    if (type == 'radar_match') {
      final radarType = data['radarType']?.toString();
      final radarKey = _radarPreferenceKey(radarType);
      return (preferences[radarAll] ?? true) &&
          (radarKey == null || (preferences[radarKey] ?? true));
    }

    if (type == 'giftcard_deal') {
      return (preferences[radarAll] ?? true) &&
          (preferences[radarGiftcard] ?? true);
    }

    return true;
  }

  static String? _communityPreferenceKey(String? type) {
    switch (type) {
      case 'post_like':
        return communityPostLike;
      case 'post_comment':
        return communityPostComment;
      case 'comment_reply':
        return communityCommentReply;
      case 'comment_like':
        return communityCommentLike;
      default:
        return null;
    }
  }

  static String? _radarPreferenceKey(String? radarType) {
    switch (radarType) {
      case 'mileageSeat':
        return radarMileageSeat;
      case 'cancelAlert':
        return radarCancelAlert;
      case 'flightDeal':
        return radarFlightDeal;
      case 'giftcard':
        return radarGiftcard;
      case 'benefitNews':
        return radarBenefitNews;
      default:
        return null;
    }
  }

  static Map<String, bool> _normalizePreferences(Map<dynamic, dynamic> raw) {
    final preferences = <String, bool>{};
    for (final key in defaultPreferences.keys) {
      final value = raw[key];
      if (value is bool) {
        preferences[key] = value;
      }
    }
    return preferences;
  }

  static Future<void> _writePreferences(
    String uid,
    Map<String, bool> preferences,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'notificationPreferences': {
        ...defaultPreferences,
        ...preferences,
      },
      'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
