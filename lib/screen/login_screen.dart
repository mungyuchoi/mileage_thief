import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../helper/AdHelper.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isUpdatingName = false;
  bool _isAdLoading = false;
  User? _currentUser;
  int _currentPeanutCount = 0;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  late BannerAd _banner;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadPeanutCount();
    _loadRewardedAd();
    _banner = BannerAd(
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, err) => setState(() => _isBannerLoaded = false),
      ),
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
    )..load();
    _loadFullScreenAd();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _banner.dispose();
    super.dispose();
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
        await user.reload();
        final updatedUser = AuthService.currentUser;
        setState(() {
          _currentUser = updatedUser;
        });
        
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
            backgroundColor: Colors.black38,
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
            backgroundColor: Colors.black38,
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

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthService.signInWithApple();
      
      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        await user.reload();
        final updatedUser = AuthService.currentUser;
        setState(() {
          _currentUser = updatedUser;
        });
        
        // 사용자 확인 다이얼로그 표시
        final shouldSave = await _showConfirmDialog();
        
        if (shouldSave) {
          // FCM 토큰 가져오기
          final fcmToken = await FCMService.getCurrentToken();
          
          // Firestore에 사용자 정보와 FCM 토큰 저장
          await UserService.saveUserToFirestore(user, _currentPeanutCount, fcmToken: fcmToken);
          
          Fluttertoast.showToast(
            msg: "Apple 로그인 성공! 땅콩이 클라우드에 저장되었습니다.",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black38,
            textColor: Colors.white,
          );
        } else {
          // FCM 토큰만 업데이트 (로그인은 했지만 땅콩은 저장 안함)
          final fcmToken = await FCMService.getCurrentToken();
          if (fcmToken != null) {
            await UserService.updateFcmToken(user.uid, fcmToken);
          }
          
          Fluttertoast.showToast(
            msg: "Apple 로그인 성공! (땅콩은 로컬에만 저장됩니다)",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black38,
            textColor: Colors.white,
          );
        }
        
        _getCurrentUser();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Apple 로그인 실패: ${e.toString()}",
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

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthService.signInWithGoogle();
      
      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        await user.reload();
        final updatedUser = AuthService.currentUser;
        setState(() {
          _currentUser = updatedUser;
        });
        
        // 사용자 확인 다이얼로그 표시
        final shouldSave = await _showConfirmDialog();
        
        if (shouldSave) {
          // FCM 토큰 가져오기
          final fcmToken = await FCMService.getCurrentToken();
          
          // Firestore에 사용자 정보와 FCM 토큰 저장
          await UserService.saveUserToFirestore(user, _currentPeanutCount, fcmToken: fcmToken);
          
          Fluttertoast.showToast(
            msg: "Google 로그인 성공! 땅콩이 클라우드에 저장되었습니다.",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black38,
            textColor: Colors.white,
          );
        } else {
          // FCM 토큰만 업데이트 (로그인은 했지만 땅콩은 저장 안함)
          final fcmToken = await FCMService.getCurrentToken();
          if (fcmToken != null) {
            await UserService.updateFcmToken(user.uid, fcmToken);
          }
          
          Fluttertoast.showToast(
            msg: "Google 로그인 성공! (땅콩은 로컬에만 저장됩니다)",
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black38,
            textColor: Colors.white,
          );
        }
        
        _getCurrentUser();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Google 로그인 실패: ${e.toString()}",
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

  void _loadFullScreenAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerDanAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {},
      ),
    );
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        _loadFullScreenAd();
        print('ad onAdShowedFullScreenContent.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        _incrementPeanutCount(10); // 전면광고 완료 시 +10 보상
        setState(() {
          ad.dispose();
        });
        _loadFullScreenAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        _incrementPeanutCount(10);
        setState(() {
          ad.dispose();
        });
        _loadFullScreenAd();
      },
      onAdImpression: (InterstitialAd ad) => print('$ad impression occurred.'),
    );
    _interstitialAd?.show();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedDanAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              setState(() {
                ad.dispose();
                _rewardedAd = null;
              });
              _loadRewardedAd();
            },
          );

          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
          print('Failed to load a rewarded ad: ${err.message}');
        },
      ),
    );
  }

  Future<void> _showFrontAd() async {
    _loadFullScreenAd();
    print("showFrontAd _:$_interstitialAd");
    _interstitialAd?.show();
  }

  void _showRewardsAd() {
    print("showRewardsAd _rewardedAd:$_rewardedAd");
    _rewardedAd?.show(onUserEarnedReward: (_, reward) {
      _incrementPeanutCount(30); // +10에서 +30으로 증가
    });
  }

  Future<void> _incrementPeanutCount(int peanuts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final currentUser = AuthService.currentUser;
    
    setState(() {
      _currentPeanutCount = (_currentPeanutCount) + peanuts;
    });
    
    await prefs.setInt('counter', _currentPeanutCount);
    
    // 로그인 상태 확인 후 Firestore 업데이트
    if (currentUser != null) {
      try {
        await UserService.updatePeanutCount(currentUser.uid, _currentPeanutCount);
      } catch (error) {
        print('Firestore 업데이트 오류: $error');
      }
    }
    
    // 땅콩 수 다시 로드하여 동기화
    await _loadPeanutCount();
    
    Fluttertoast.showToast(
      msg: "땅콩 $peanuts개를 얻었습니다.",
      timeInSecForIosWeb: 5,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black38,
      textColor: Colors.white,
    );
  }

  String _getLoginButtonText() {
    if (Platform.isAndroid) {
      return 'Google로 로그인';
    } else if (Platform.isIOS) {
      return 'Apple로 로그인';
    }
    return '로그인';
  }

  Widget _getLoginIcon() {
    if (Platform.isAndroid) {
      return const FaIcon(FontAwesomeIcons.google, size: 20);
    } else if (Platform.isIOS) {
      return const FaIcon(FontAwesomeIcons.apple, size: 20);
    }
    return const Icon(Icons.login);
  }

  Future<void> _handleDeleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('정말로 회원탈퇴 하시겠습니까?\n\n모든 정보가 삭제되며 복구할 수 없습니다.', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Firestore 유저 데이터 삭제
      await UserService.deleteUserFromFirestore(user.uid);
      // Firebase Auth 계정 삭제
      await user.delete();
      // SharedPreferences(로컬) 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // 상태 초기화
      setState(() {
        _currentUser = null;
        _currentPeanutCount = 3;
      });
      Fluttertoast.showToast(
        msg: "회원탈퇴가 완료되었습니다.",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      // 로그인 화면으로 이동(필요시)
    } catch (e) {
      Fluttertoast.showToast(
        msg: "회원탈퇴 실패: "+e.toString(),
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // 동의 다이얼로그 함수 추가
  Future<void> _showAgreementDialog({String loginType = 'Google'}) async {
    bool agreeNoAbuse = false;
    bool agreePolicy = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                '$loginType 로그인 - 서비스 이용 동의',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: agreeNoAbuse,
                    onChanged: (val) => setState(() => agreeNoAbuse = val!),
                    title: const Text(
                      '본인은 불쾌한 콘텐츠 또는 악의적 사용자에 대한 무관용 정책에 동의합니다. (필수)',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      '불쾌한 콘텐츠, 욕설, 혐오, 차별, 악의적 사용자는 허용되지 않으며, 위반 시 이용이 제한될 수 있습니다.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.black,
                  ),
                  CheckboxListTile(
                    value: agreePolicy,
                    onChanged: (val) => setState(() => agreePolicy = val!),
                    title: const Text(
                      '개인정보처리방침 동의 (필수)',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                    subtitle: GestureDetector(
                      onTap: () async {
                        const url = 'https://moonque.tistory.com/entry/%EB%A7%88%EC%9D%BC%EB%A6%AC%EC%A7%80%EB%8F%84%EB%91%91-%EA%B0%9C%EC%9D%B8%EC%A0%95%EB%B3%B4%EC%B2%98%EB%A6%AC%EB%B0%A9%EC%B9%A8';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        '개인정보처리방침 보기',
                        style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.black,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: (agreeNoAbuse && agreePolicy)
                      ? () {
                          Navigator.of(context).pop();
                          if (loginType == 'Apple') {
                            _handleAppleLogin();
                          } else if (loginType == 'Google') {
                            _handleGoogleLogin();
                          } else {
                            _handleLogin();
                          }
                        }
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: (agreeNoAbuse && agreePolicy) ? Colors.black : Colors.grey[300],
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
        child: SingleChildScrollView(
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
                // iOS는 Apple+Google, Android는 Google만 노출
                if (Platform.isIOS) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showAgreementDialog(loginType: 'Apple'),
                      icon: const FaIcon(FontAwesomeIcons.apple, size: 20),
                      label: Text(
                        _isLoading ? '로그인 중...' : 'Apple로 로그인',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showAgreementDialog(loginType: 'Google'),
                      icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                      label: Text(
                        _isLoading ? '로그인 중...' : 'Google로 로그인',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showAgreementDialog(loginType: 'Google'),
                      icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const FaIcon(FontAwesomeIcons.google, size: 20),
                      label: Text(
                        _isLoading ? '로그인 중...' : 'Google로 로그인',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 광고 버튼들 (+2, +10)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: _interstitialAd == null || _isAdLoading
                          ? null
                          : () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('알림', style: TextStyle(color: Colors.black)),
                                  content: const Text('광고를 시청하고 땅콩을 얻겠습니까?', style: TextStyle(color: Colors.black)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('아니오', style: TextStyle(color: Colors.black)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('예', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                ),
                              );
                              if (result == true) {
                                setState(() {
                                  _isAdLoading = true;
                                });
                                try {
                                  _interstitialAd?.show();
                                } finally {
                                  setState(() {
                                    _isAdLoading = false;
                                    _interstitialAd = null;
                                  });
                                  _loadFullScreenAd();
                                }
                              }
                            },
                      label: const Text("+ 10", style: TextStyle(color: Colors.black87)),
                      backgroundColor: _interstitialAd == null ? Colors.grey[300] : Colors.white,
                      elevation: 3,
                      icon: Image.asset('asset/img/peanut.png', scale: 19),
                    ),
                    FloatingActionButton.extended(
                      onPressed: _rewardedAd == null
                          ? null
                          : () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('알림', style: TextStyle(color: Colors.black)),
                                  content: const Text('광고를 시청하고 땅콩을 얻겠습니까?', style: TextStyle(color: Colors.black)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('아니오', style: TextStyle(color: Colors.black)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('예', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                ),
                              );
                              if (result == true) {
                                _showRewardsAd();
                              }
                            },
                      label: const Text("+ 30",
                          style: TextStyle(color: Colors.black87)),
                      backgroundColor: _rewardedAd == null ? Colors.grey[300] : Colors.white,
                      elevation: 3,
                      icon: Image.asset(
                        'asset/img/peanuts.png',
                        scale: 19,
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
                                Text('$_currentPeanutCount개', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                // iOS에서만 회원탈퇴 버튼 노출
                if (Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _handleDeleteAccount,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text(
                        '회원탈퇴',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isBannerLoaded
          ? SafeArea(
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                width: double.infinity,
                height: _banner.size.height.toDouble(),
                child: AdWidget(ad: _banner),
              ),
            )
          : null,
    );
  }
} 