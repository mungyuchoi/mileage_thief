import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:mileage_thief/services/user_service.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static const String _appScheme = 'milecatchoauth';
  static const String _functionsRegion = 'asia-northeast3';
  static const String _naverClientId =
      String.fromEnvironment('NAVER_CLIENT_ID');

  // 현재 사용자 가져오기
  static User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 구글 로그인 (Android)
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('[구글 로그인] 시작');

      // 구글 계정 선택
      print('[구글 로그인] 계정 선택 시작');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('[구글 로그인] 사용자가 취소함');
        return null; // 사용자가 취소함
      }

      print('[구글 로그인] 계정 선택 완료: ${googleUser.email}');

      // 구글 인증 정보 가져오기
      print('[구글 로그인] 인증 정보 가져오기 시작');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print('[구글 로그인] 인증 정보 가져오기 완료');

      // Firebase 자격 증명 생성
      print('[구글 로그인] Firebase 자격 증명 생성');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      print('[구글 로그인] Firebase 로그인 시작');
      final result = await _auth.signInWithCredential(credential);
      print('[구글 로그인] Firebase 로그인 완료: ${result.user?.email}');

      return result;
    } catch (e) {
      print('[구글 로그인] 오류 발생: $e');
      print('[구글 로그인] 오류 타입: ${e.runtimeType}');
      rethrow;
    }
  }

  // Apple 로그인 (iOS)
  static Future<UserCredential?> signInWithApple() async {
    try {
      // Apple 로그인에 필요한 nonce 생성
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Apple ID 자격 증명 요청
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Firebase 자격 증명 생성
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase에 로그인
      return await _auth.signInWithCredential(oauthCredential);
    } catch (e) {
      print('Apple 로그인 오류: $e');
      rethrow;
    }
  }

  // Naver 로그인 (OAuth code + Firebase Custom Token)
  static Future<UserCredential?> signInWithNaver() async {
    print('[네이버 로그인] 시작');
    if (_naverClientId.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-naver-client-id',
        message: 'NAVER_CLIENT_ID dart-define 값이 비어 있습니다.',
      );
    }

    final state = _generateNonce(24);
    final projectId = Firebase.app().options.projectId;
    final redirectUri =
        'https://$_functionsRegion-$projectId.cloudfunctions.net/naverOauthBridge';
    print('[네이버 로그인] redirectUri: $redirectUri');

    final authorizeUri = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': _naverClientId,
      'redirect_uri': redirectUri,
      'state': state,
    });
    print('[네이버 로그인] authorizeUri 생성 완료');

    String callbackResult;
    try {
      print('[네이버 로그인] FlutterWebAuth2.authenticate 호출');
      callbackResult = await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: _appScheme,
      );
      print('[네이버 로그인] callbackResult 수신: $callbackResult');
    } on PlatformException catch (e) {
      final lowerCode = e.code.toLowerCase();
      final lowerMessage = (e.message ?? '').toLowerCase();
      if (lowerCode == 'canceled' ||
          lowerCode == 'cancelled' ||
          lowerMessage.contains('canceled') ||
          lowerMessage.contains('cancelled')) {
        print('[네이버 로그인] 사용자 취소 처리: code=${e.code}, message=${e.message}');
        return null;
      }
      print(
          '[네이버 로그인] PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      rethrow;
    }
    final callbackUri = Uri.parse(callbackResult);
    print('[네이버 로그인] callbackUri: $callbackUri');

    final authError = callbackUri.queryParameters['error'];
    if (authError != null && authError.isNotEmpty) {
      final authErrorDescription =
          callbackUri.queryParameters['error_description'] ?? '네이버 인증 실패';
      throw FirebaseAuthException(
        code: 'naver-auth-failed',
        message: '$authError: $authErrorDescription',
      );
    }

    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];
    print(
        '[네이버 로그인] callback params: code=${code != null}, state=${returnedState != null}');

    if (code == null || returnedState == null) {
      throw FirebaseAuthException(
        code: 'naver-callback-invalid',
        message: '네이버 콜백에서 code/state를 찾을 수 없습니다.',
      );
    }

    if (returnedState != state) {
      print('[네이버 로그인] state mismatch: expected=$state, actual=$returnedState');
      throw FirebaseAuthException(
        code: 'naver-state-mismatch',
        message: '네이버 state 검증에 실패했습니다.',
      );
    }

    print('[네이버 로그인] createNaverCustomToken 호출 시작');
    final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
        .httpsCallable('createNaverCustomToken');
    final callableResult = await callable.call({
      'code': code,
      'state': returnedState,
      'redirectUri': redirectUri,
    });
    print('[네이버 로그인] createNaverCustomToken 호출 완료');

    final data = Map<String, dynamic>.from(callableResult.data as Map);
    final firebaseToken = (data['firebaseToken'] ?? '').toString();
    if (firebaseToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'naver-custom-token-missing',
        message: 'Firebase custom token 응답이 비어 있습니다.',
      );
    }

    final credential = await _auth.signInWithCustomToken(firebaseToken);
    print('[네이버 로그인] signInWithCustomToken 완료: uid=${credential.user?.uid}');
    final user = credential.user;

    if (user != null) {
      final profile = Map<String, dynamic>.from(
          (data['providerProfile'] as Map?) ?? const {});
      final nickname = (profile['nickname'] ?? '').toString().trim();
      final displayName = nickname.isNotEmpty
          ? nickname
          : UserService.generateTravelDisplayName();

      if ((user.displayName ?? '').trim().isEmpty ||
          (user.displayName ?? '').trim() == '네이버사용자') {
        try {
          await user.updateDisplayName(displayName);
          await user.reload();
        } catch (_) {
          // displayName 업데이트 실패는 로그인 전체 실패로 취급하지 않음.
        }
      }
    }

    return credential;
  }

  // 로그아웃
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
      rethrow;
    }
  }

  // 계정 삭제
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print('계정 삭제 오류: $e');
      rethrow;
    }
  }

  // 플랫폼별 로그인 메서드
  static Future<UserCredential?> signInWithPlatform() async {
    if (Platform.isAndroid) {
      return await signInWithGoogle();
    } else if (Platform.isIOS) {
      return await signInWithApple();
    }
    return null;
  }

  // nonce 생성기 (Apple 로그인용)
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // SHA256 해시 (Apple 로그인용)
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
