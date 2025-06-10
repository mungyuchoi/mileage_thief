import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 사용자 가져오기
  static User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 구글 로그인 (Android)
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // 구글 계정 선택
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // 사용자가 취소함
      }

      // 구글 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 자격 증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('구글 로그인 오류: $e');
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