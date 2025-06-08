import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isUpdatingName = false;
  User? _currentUser;
  int _currentPeanutCount = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadPeanutCount();
  }

  void _getCurrentUser() {
    setState(() {
      _currentUser = AuthService.currentUser;
    });
  }

  Future<void> _loadPeanutCount() async {
    final currentUser = AuthService.currentUser;
    
    if (currentUser != null) {
      // 로그인한 사용자: Firestore에서 peanutCount 가져오기
      try {
        final userData = await UserService.getUserFromFirestoreWithLimit(currentUser.uid);
        setState(() {
          _currentPeanutCount = userData?['peanutCount'] ?? 0;
        });
      } catch (error) {
        print('Firestore에서 peanutCount 로드 오류: $error');
        // Firestore 실패 시 SharedPreferences를 fallback으로 사용
        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          _currentPeanutCount = prefs.getInt('counter') ?? 3;
        });
      }
    } else {
      // 로그인하지 않은 사용자: SharedPreferences 사용
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentPeanutCount = prefs.getInt('counter') ?? 3;
      });
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthService.signInWithPlatform();
      
      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        
        // 사용자 확인 다이얼로그 표시
        final shouldSave = await _showConfirmDialog();
        
        if (shouldSave) {
          // FCM 토큰 가져오기
          final fcmToken = await FCMService.getCurrentToken();
          
          // Firestore에 사용자 정보와 FCM 토큰 저장
          await UserService.saveUserToFirestore(user, _currentPeanutCount, fcmToken: fcmToken);
          
          Fluttertoast.showToast(
            msg: "로그인 성공! 땅콩이 클라우드에 저장되었습니다.",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        } else {
          // FCM 토큰만 업데이트 (로그인은 했지만 땅콩은 저장 안함)
          final fcmToken = await FCMService.getCurrentToken();
          if (fcmToken != null) {
            await UserService.updateFcmToken(user.uid, fcmToken);
          }
          
          Fluttertoast.showToast(
            msg: "로그인 성공! (땅콩은 로컬에만 저장됩니다)",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.blue,
            textColor: Colors.white,
          );
        }
        
        _getCurrentUser();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "로그인 실패: ${e.toString()}",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '땅콩 클라우드 저장',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '현재 보유한 땅콩 $_currentPeanutCount개를 클라우드에 저장하시겠습니까?\n\n'
          '저장하면 다른 기기에서도 땅콩을 사용할 수 있습니다.',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '아니오',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '예',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      _getCurrentUser();
      
      Fluttertoast.showToast(
        msg: "로그아웃 되었습니다.",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "로그아웃 실패: ${e.toString()}",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController();
    nameController.text = _currentUser?.displayName ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '이름 편집',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: '이름을 입력하세요',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(context).pop(newName);
              }
            },
            child: const Text(
              '저장',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _updateDisplayName(result);
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    setState(() {
      _isUpdatingName = true;
    });

    try {
      final user = _currentUser;
      if (user == null) return;

      // Firebase Auth에서 displayName 업데이트
      await user.updateDisplayName(newName);
      
      // Firestore에서 displayName만 업데이트
      await UserService.updateDisplayName(user.uid, newName);
      
      // 로컬 상태 업데이트
      setState(() {
        _getCurrentUser();
      });
      
      Fluttertoast.showToast(
        msg: "이름이 '$newName'으로 변경되었습니다.",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "이름 변경 실패: ${e.toString()}",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isUpdatingName = false;
      });
    }
  }

  String _getLoginButtonText() {
    if (Platform.isAndroid) {
      return 'Google로 로그인';
    } else if (Platform.isIOS) {
      return 'Apple로 로그인';
    }
    return '로그인';
  }

  IconData _getLoginIcon() {
    if (Platform.isAndroid) {
      return Icons.login; // Google 아이콘 대신 일반 로그인 아이콘 사용
    } else if (Platform.isIOS) {
      return Icons.apple;
    }
    return Icons.login;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '로그인',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentUser == null) ...[
              Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
            ],
            
            if (_currentUser == null) ...[
              const Text(
                '로그인하여 땅콩을 클라우드에 저장하세요!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '현재 땅콩: $_currentPeanutCount개',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleLogin,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(_getLoginIcon()),
                  label: Text(
                    _isLoading ? '로그인 중...' : _getLoginButtonText(),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Platform.isAndroid 
                      ? const Color(0xFF4285F4)  // 구글 블루
                      : Colors.black,             // 애플 블랙
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 사용자 프로필 이미지
              CircleAvatar(
                radius: 50,
                backgroundImage: _currentUser!.photoURL != null 
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
                backgroundColor: Colors.grey[300],
                child: _currentUser!.photoURL == null 
                  ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                  : null,
              ),
              const SizedBox(height: 20),
              
              Text(
                '안녕하세요!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              
              // 사용자 이름과 편집 버튼
              Stack(
                children: [
                  // displayName (전체 폭을 차지하면서 중앙 정렬)
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      _currentUser!.displayName ?? _currentUser!.email ?? '사용자',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 편집 버튼 (displayName 바로 옆에 붙임)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentUser!.displayName ?? _currentUser!.email ?? '사용자',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.transparent, // 투명하게 해서 위치만 잡음
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 20), // 마진 추가
                        IconButton(
                          onPressed: _isUpdatingName ? null : _showEditNameDialog,
                          icon: _isUpdatingName 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                ),
                              )
                            : const Icon(Icons.edit, size: 18, color: Colors.grey),
                          splashRadius: 16,
                          tooltip: '이름 편집',
                          padding: EdgeInsets.zero, // 기존 padding 제거
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 사용자 정보 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_circle, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('로그인된 계정', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(_currentUser!.email ?? '이메일 없음', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Image.asset(
                          'asset/img/peanuts.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('보유 땅콩', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('$_currentPeanutCount개', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 