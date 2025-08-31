import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static Timer? _tokenRefreshTimer;

  // 현재 사용자 가져오기
  static User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 토큰 자동 갱신 설정
  static void setupTokenRefresh() {
    // 기존 타이머가 있다면 취소
    _tokenRefreshTimer?.cancel();
    
    // 사용자가 로그인되어 있으면 토큰 갱신 타이머 시작
    final user = _auth.currentUser;
    if (user != null) {
      _startTokenRefreshTimer();
    }
    
    // 인증 상태 변경 감지
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _startTokenRefreshTimer();
      } else {
        _tokenRefreshTimer?.cancel();
      }
    });
  }

  // 토큰 갱신 타이머 시작
  static void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    
    // 30분마다 토큰 갱신 (더 안전한 간격으로 설정)
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // 토큰 강제 갱신
          await user.getIdToken(true);
          print('[토큰 갱신] 성공적으로 토큰이 갱신되었습니다.');
        } else {
          // 사용자가 로그아웃된 경우 타이머 중지
          timer.cancel();
        }
      } catch (e) {
        print('[토큰 갱신] 오류 발생: $e');
        // 토큰 갱신 실패 시 재시도
        await Future.delayed(const Duration(minutes: 5));
        try {
          final user = _auth.currentUser;
          if (user != null) {
            await user.getIdToken(true);
            print('[토큰 갱신] 재시도 성공');
          }
        } catch (retryError) {
          print('[토큰 갱신] 재시도 실패: $retryError');
          // 토큰 갱신이 계속 실패하면 사용자에게 알림
          _handleTokenRefreshFailure();
        }
      }
    });
  }

  // 토큰 갱신 실패 처리
  static void _handleTokenRefreshFailure() {
    print('[토큰 갱신] 토큰 갱신이 계속 실패하여 사용자에게 재로그인을 요청합니다.');
    // 여기서 사용자에게 재로그인을 요청하는 로직을 추가할 수 있습니다.
    // 예: 로그인 화면으로 이동하거나 알림을 표시
    
    // 토큰 갱신이 실패하면 10분 후에 다시 시도
    Timer(const Duration(minutes: 10), () async {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await user.getIdToken(true);
          print('[토큰 갱신] 지연 재시도 성공');
        }
      } catch (e) {
        print('[토큰 갱신] 지연 재시도 실패: $e');
      }
    });
  }

  // 토큰 상태 확인
  static Future<bool> isTokenValid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // 토큰을 가져와서 유효성 확인
      final token = await user.getIdToken();
      return token.isNotEmpty;
    } catch (e) {
      print('[토큰 확인] 토큰 유효성 확인 실패: $e');
      return false;
    }
  }

  // 토큰 강제 갱신
  static Future<bool> forceRefreshToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      await user.getIdToken(true);
      print('[토큰 강제 갱신] 성공');
      return true;
    } catch (e) {
      print('[토큰 강제 갱신] 실패: $e');
      return false;
    }
  }

  // 토큰 만료 시 자동 재로그인 시도
  static Future<bool> attemptAutoReauth() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // 현재 사용자의 자격 증명을 다시 확인
      final credential = await user.getIdToken();
      if (credential.isNotEmpty) {
        print('[자동 재인증] 성공');
        return true;
      }
      
      return false;
    } catch (e) {
      print('[자동 재인증] 실패: $e');
      return false;
    }
  }

  // 토큰 만료 시 자동 재로그인 시도 (더 강화된 버전)
  static Future<bool> attemptAutoReauthEnhanced() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // 현재 사용자의 자격 증명을 다시 확인
      final credential = await user.getIdToken();
      if (credential.isNotEmpty) {
        print('[자동 재인증] 성공');
        return true;
      }
      
      // 토큰이 없으면 강제로 갱신 시도
      try {
        await user.getIdToken(true);
        print('[자동 재인증] 강제 갱신 성공');
        return true;
      } catch (forceError) {
        print('[자동 재인증] 강제 갱신 실패: $forceError');
        return false;
      }
    } catch (e) {
      print('[자동 재인증] 실패: $e');
      return false;
    }
  }

  // 토큰 갱신 타이머 정리
  static void dispose() {
    _tokenRefreshTimer?.cancel();
  }

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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // SHA256 해시 (Apple 로그인용)
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
} 