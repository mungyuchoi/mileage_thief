import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../helper/AdHelper.dart';
import 'community_detail_screen.dart';
import 'follower_list_screen.dart';
import 'following_list_screen.dart';
import 'level_detail_screen.dart';
import 'sky_effect_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/image_compressor.dart';
import '../screen/peanut_history_screen.dart';
import '../utils/ad_removal_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  TabController? _tabController;
  
  // 페이징 관련 변수 추가
  final int _pageSize = 50;

  // 게시글 페이징
  List<DocumentSnapshot> _userPosts = [];
  DocumentSnapshot? _lastPostDoc;
  bool _hasMorePosts = true;
  bool _isPostsLoading = false;
  final ScrollController _postsScrollController = ScrollController();

  // 댓글 페이징
  List<DocumentSnapshot> _userComments = [];
  DocumentSnapshot? _lastCommentDoc;
  bool _hasMoreComments = true;
  bool _isCommentsLoading = false;
  final ScrollController _commentsScrollController = ScrollController();

  // 좋아요 페이징
  List<DocumentSnapshot> _likedPosts = [];
  DocumentSnapshot? _lastLikedDoc;
  bool _hasMoreLikedPosts = true;
  bool _isLikedPostsLoading = false;
  final ScrollController _likedPostsScrollController = ScrollController();

  // 북마크 페이징
  List<DocumentSnapshot> _bookmarkedPosts = [];
  DocumentSnapshot? _lastBookmarkDoc;
  bool _hasMoreBookmarks = true;
  bool _isBookmarksLoading = false;
  final ScrollController _bookmarksScrollController = ScrollController();
  
  bool _isUpdatingProfileImage = false;
  bool _isUpdatingDisplayName = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  BannerAd? _myPageBannerAd;
  bool _isMyPageBannerAdLoaded = false;
  
  // 광고 관리 관련 변수
  bool _isAdRemovalActive = false;
  String? _adRemovalExpiryTime;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // 광고 위젯 생성 함수
  Widget _buildBannerAd(String adUnitId) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Text(
          '광고 영역 ($adUnitId)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTabController();
    _loadUserProfile();
    _loadAllTabData();
    _postsScrollController.addListener(_onPostsScroll);
    _commentsScrollController.addListener(_onCommentsScroll);
    _likedPostsScrollController.addListener(_onLikedPostsScroll);
    _bookmarksScrollController.addListener(_onBookmarksScroll);
    _initAdState();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.dispose();
    _postsScrollController.dispose();
    _commentsScrollController.dispose();
    _likedPostsScrollController.dispose();
    _bookmarksScrollController.dispose();
    _myPageBannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화될 때 프로필 새로 로드
      _loadUserProfile();
      _checkAdRemovalStatus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 포커스될 때마다 프로필 새로 로드
    _loadUserProfile();
  }

  void _initializeTabController() {
    _tabController = TabController(length: 4, vsync: this);
  }

  void _onPostsScroll() {
    if (_postsScrollController.position.pixels >= _postsScrollController.position.maxScrollExtent - 200) {
      if (!_isPostsLoading && _hasMorePosts) {
        _loadUserPosts(loadMore: true);
      }
    }
  }
  void _onCommentsScroll() {
    if (_commentsScrollController.position.pixels >= _commentsScrollController.position.maxScrollExtent - 200) {
      if (!_isCommentsLoading && _hasMoreComments) {
        _loadUserComments(loadMore: true);
      }
    }
  }
  void _onLikedPostsScroll() {
    if (_likedPostsScrollController.position.pixels >= _likedPostsScrollController.position.maxScrollExtent - 200) {
      if (!_isLikedPostsLoading && _hasMoreLikedPosts) {
        _loadLikedPosts(loadMore: true);
      }
    }
  }

  void _onBookmarksScroll() {
    if (_bookmarksScrollController.position.pixels >= _bookmarksScrollController.position.maxScrollExtent - 200) {
      if (!_isBookmarksLoading && _hasMoreBookmarks) {
        _loadBookmarks(loadMore: true);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final user = AuthService.currentUser;
    if (user != null) {
      final data = await UserService.getUserFromFirestore(user.uid);
      setState(() {
        userProfile = data;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAllTabData() async {
    // 모든 탭의 데이터를 병렬로 로드
    await Future.wait([
      _loadUserPosts(),
      _loadUserComments(),
      _loadLikedPosts(),
      _loadBookmarks(),
    ]);
  }

  Future<void> _loadUserPosts({bool loadMore = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isPostsLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_posts')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (loadMore && _lastPostDoc != null) {
        query = query.startAfterDocument(_lastPostDoc!);
      }
      final querySnapshot = await query.get();
      if (loadMore) {
        _userPosts.addAll(querySnapshot.docs);
      } else {
        _userPosts = querySnapshot.docs;
      }
      if (querySnapshot.docs.isNotEmpty) {
        _lastPostDoc = querySnapshot.docs.last;
      }
      _hasMorePosts = querySnapshot.docs.length == _pageSize;
      setState(() {
        _isPostsLoading = false;
      });
    } catch (e) {
      print('사용자 게시글 로드 오류: $e');
      setState(() {
        _isPostsLoading = false;
      });
    }
  }

  Future<void> _loadUserComments({bool loadMore = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isCommentsLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_comments')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (loadMore && _lastCommentDoc != null) {
        query = query.startAfterDocument(_lastCommentDoc!);
      }
      final querySnapshot = await query.get();
      if (loadMore) {
        _userComments.addAll(querySnapshot.docs);
      } else {
        _userComments = querySnapshot.docs;
      }
      if (querySnapshot.docs.isNotEmpty) {
        _lastCommentDoc = querySnapshot.docs.last;
      }
      _hasMoreComments = querySnapshot.docs.length == _pageSize;
      setState(() {
        _isCommentsLoading = false;
      });
    } catch (e) {
      print('사용자 댓글 로드 오류: $e');
      setState(() {
        _isCommentsLoading = false;
      });
    }
  }

  Future<void> _loadLikedPosts({bool loadMore = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isLikedPostsLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('liked_posts')
          .orderBy('likedAt', descending: true)
          .limit(_pageSize);
      if (loadMore && _lastLikedDoc != null) {
        query = query.startAfterDocument(_lastLikedDoc!);
      }
      final querySnapshot = await query.get();
      if (loadMore) {
        _likedPosts.addAll(querySnapshot.docs);
      } else {
        _likedPosts = querySnapshot.docs;
      }
      if (querySnapshot.docs.isNotEmpty) {
        _lastLikedDoc = querySnapshot.docs.last;
      }
      _hasMoreLikedPosts = querySnapshot.docs.length == _pageSize;
      setState(() {
        _isLikedPostsLoading = false;
      });
    } catch (e) {
      print('좋아요한 게시글 로드 오류: $e');
      setState(() {
        _isLikedPostsLoading = false;
      });
    }
  }

  Future<void> _loadBookmarks({bool loadMore = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isBookmarksLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .orderBy('bookmarkedAt', descending: true)
          .limit(_pageSize);
      if (loadMore && _lastBookmarkDoc != null) {
        query = query.startAfterDocument(_lastBookmarkDoc!);
      }
      final querySnapshot = await query.get();
      if (loadMore) {
        _bookmarkedPosts.addAll(querySnapshot.docs);
      } else {
        _bookmarkedPosts = querySnapshot.docs;
      }
      if (querySnapshot.docs.isNotEmpty) {
        _lastBookmarkDoc = querySnapshot.docs.last;
      }
      _hasMoreBookmarks = querySnapshot.docs.length == _pageSize;
      setState(() {
        _isBookmarksLoading = false;
      });
    } catch (e) {
      print('북마크한 게시글 로드 오류: $e');
      setState(() {
        _isBookmarksLoading = false;
      });
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // 변경 가능 여부 확인
      final canChange = await UserService.canChangePhotoURL(user.uid);
      bool needsPurchaseDialog = false;
      if (!canChange) {
        // 변경권 구매 다이얼로그 표시
        final shouldPurchase = await _showChangePurchaseDialog('photoURL');
        if (!shouldPurchase) return;
        needsPurchaseDialog = true; // 구매 다이얼로그를 거쳤음을 표시
      }

      // 땅콩 소모 확인 다이얼로그 (이미지 선택 전)
      final userData = await UserService.getUserFromFirestore(user.uid);
      if (userData != null) {
        final changeCount = userData['photoURLChangeCount'] ?? 0;
        final peanutCount = userData['peanutCount'] ?? 0;
        
        // 변경 횟수가 1 이상이고 땅콩이 충분하거나, 구매 다이얼로그를 거친 경우
        if ((changeCount >= 1 && peanutCount >= 50) || needsPurchaseDialog) {
          final shouldProceed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  '프로필 이미지 변경',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 초기 1회 무료인지 확인
                    Text(
                      changeCount == 0 ? '1회 무료로 변경할 수 있습니다.' : '땅콩 50개가 소모될 예정입니다.',
                      style: TextStyle(
                        color: changeCount == 0 ? Colors.green : Colors.black,
                        fontSize: 16,
                        fontWeight: changeCount == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (changeCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '현재 보유 땅콩: ${peanutCount}개',
                        style: TextStyle(
                          color: peanutCount >= 50 ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      '선정적인 이미지로 변경 시 제재의 대상이 될 수 있습니다.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '변경하시겠습니까?',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '변경',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );

          if (shouldProceed != true) return;
        }
      }

      setState(() {
        _isUpdatingProfileImage = true;
      });

      // 1. 이미지 선택
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      // 2. 이미지 압축
      final originalFile = File(image.path);
      
      // 이미지 정보 출력 (디버깅용)
      await ImageCompressor.printImageInfo(originalFile);
      
      // 이미지 압축
      final compressedFile = await ImageCompressor.compressImage(originalFile);
      
      // 압축된 이미지 정보 출력 (디버깅용)
      await ImageCompressor.printImageInfo(compressedFile);

      // 3. Firebase Storage에 업로드
      final File imageFile = compressedFile;
      final String fileName = '${user.uid}.png';
      
      // iOS에서는 올바른 bucket 사용
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }
      
      final Reference storageRef = storage
          .ref()
          .child('users')
          .child(fileName);

      // 기존 파일이 있다면 덮어쓰기 (같은 경로이므로 자동으로 대체됨)
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 3. UserService를 통한 변경 처리 (땅콩 차감 포함)
      await UserService.changePhotoURL(user.uid, downloadUrl);

      // 4. Firebase Auth 프로필 업데이트
      await user.updatePhotoURL(downloadUrl);

      // 5. 기존 게시글과 댓글의 프로필 이미지 업데이트
      await _updateExistingPostsAndComments(user.uid, downloadUrl);

      // 6. 로컬 상태 업데이트
      await _loadUserProfile(); // 전체 프로필 다시 로드하여 변경된 데이터 반영

      setState(() {
        _isUpdatingProfileImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 이미지가 업데이트되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('프로필 이미지 업데이트 오류: $e');
      setState(() {
        _isUpdatingProfileImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로필 이미지 업데이트 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateExistingPostsAndComments(String uid, String newPhotoURL) async {
    try {
      // 1. 사용자의 모든 게시글 업데이트
      final myPostsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_posts')
          .get();

      for (final myPostDoc in myPostsSnapshot.docs) {
        final myPostData = myPostDoc.data();
        final postPath = myPostData['postPath'] as String?;
        
        if (postPath != null) {
          final pathParts = postPath.split('/');
          if (pathParts.length >= 4) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            
            try {
              // 실제 게시글 문서 업데이트
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(dateString)
                  .collection('posts')
                  .doc(postId)
                  .update({
                'author.photoURL': newPhotoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // 개별 게시글 업데이트 실패는 무시하고 계속 진행
            }
          }
        }
      }

      // 2. 사용자의 모든 댓글 업데이트
      final myCommentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_comments')
          .get();

      for (final myCommentDoc in myCommentsSnapshot.docs) {
        final myCommentData = myCommentDoc.data();
        final commentPath = myCommentData['commentPath'] as String?;
        
        if (commentPath != null) {
          final pathParts = commentPath.split('/');
          if (pathParts.length >= 6) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            final commentId = pathParts[5];
            
            try {
              // 실제 댓글 문서 업데이트
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(dateString)
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .update({
                'profileImageUrl': newPhotoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // 개별 댓글 업데이트 실패는 무시하고 계속 진행
            }
          }
        }
      }

    } catch (e) {
      // 에러가 발생해도 프로필 이미지 업데이트 자체는 성공했으므로 
      // 사용자에게는 성공 메시지를 보여주고 백그라운드에서 조용히 처리
    }
  }

  Future<void> _editDisplayName() async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 변경 가능 여부 확인
    final canChange = await UserService.canChangeDisplayName(user.uid);
    if (!canChange) {
      // 변경권 구매 다이얼로그 표시
      final shouldPurchase = await _showChangePurchaseDialog('displayName');
      if (!shouldPurchase) return;
    }

    final TextEditingController controller = TextEditingController();
    final currentDisplayName = userProfile?['displayName'] ?? '';
    controller.text = currentDisplayName;
    String? errorText;
    bool isValid = false;

    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void validate(String value) {
              // 띄어쓰기, 특수문자 체크
              final hasWhitespace = value.contains(RegExp(r'\s'));
              final hasSpecial = value.contains(RegExp(r'[^a-zA-Z0-9가-힣_]'));
              if (value.isEmpty) {
                errorText = null;
                isValid = false;
              } else if (hasWhitespace) {
                errorText = '닉네임에 띄어쓰기를 포함할 수 없습니다.';
                isValid = false;
              } else if (hasSpecial) {
                errorText = '닉네임에 특수문자를 포함할 수 없습니다.';
                isValid = false;
              } else {
                errorText = null;
                isValid = true;
              }
              setState(() {});
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                '닉네임 변경',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: '새 닉네임을 입력하세요',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    maxLength: 10,
                    autofocus: true,
                    onChanged: validate,
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // 초기 1회 무료인지 확인
                  FutureBuilder<Map<String, dynamic>?>(
                    future: UserService.getUserFromFirestore(user.uid),
                    builder: (context, snapshot) {
                      final userData = snapshot.data;
                      final displayNameChangeCount = userData?['displayNameChangeCount'] ?? 0;
                      final peanutCount = userData?['peanutCount'] ?? 0;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayNameChangeCount == 0 ? '1회 무료로 변경할 수 있습니다.' : '땅콩 30개가 소모될 예정입니다.',
                            style: TextStyle(
                              color: displayNameChangeCount == 0 ? Colors.green : Colors.black,
                              fontSize: 16,
                              fontWeight: displayNameChangeCount == 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (displayNameChangeCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '현재 보유 땅콩: ${peanutCount}개',
                              style: TextStyle(
                                color: peanutCount >= 30 ? Colors.green : Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '선정적인 닉네임은 사용할 수 없습니다. 선정적인 닉네임 사용시 추후 제재가 될 수 있습니다',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '변경하시겠습니까?',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: isValid && controller.text.trim() != currentDisplayName
                      ? () => Navigator.pop(context, controller.text.trim())
                      : null,
                  child: const Text(
                    '변경',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((newDisplayName) async {
      if (newDisplayName != null) {
        await _updateDisplayName(newDisplayName);
      }
    });
  }

  Future<void> _updateDisplayName(String newDisplayName) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      setState(() {
        _isUpdatingDisplayName = true;
      });

      // 1. UserService를 통한 변경 처리 (땅콩 차감 포함)
      await UserService.changeDisplayName(user.uid, newDisplayName);

      // 2. Firebase Auth 프로필 업데이트
      await user.updateDisplayName(newDisplayName);

      // 3. 기존 게시글과 댓글의 displayName 업데이트
      await _updateExistingPostsAndCommentsDisplayName(user.uid, newDisplayName);

      // 4. 로컬 상태 업데이트
      await _loadUserProfile(); // 전체 프로필 다시 로드하여 변경된 데이터 반영

      setState(() {
        _isUpdatingDisplayName = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임이 업데이트되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() {
        _isUpdatingDisplayName = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('닉네임 업데이트 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateExistingPostsAndCommentsDisplayName(String uid, String newDisplayName) async {
    try {
      // 1. 사용자의 모든 게시글 업데이트
      final myPostsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_posts')
          .get();

      for (final myPostDoc in myPostsSnapshot.docs) {
        final myPostData = myPostDoc.data();
        final postPath = myPostData['postPath'] as String?;
        
        if (postPath != null) {
          final pathParts = postPath.split('/');
          if (pathParts.length >= 4) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            
            try {
              // 실제 게시글 문서 업데이트
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(dateString)
                  .collection('posts')
                  .doc(postId)
                  .update({
                'author.displayName': newDisplayName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // 개별 게시글 업데이트 실패는 무시하고 계속 진행
            }
          }
        }
      }

      // 2. 사용자의 모든 댓글 업데이트
      final myCommentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_comments')
          .get();

      for (final myCommentDoc in myCommentsSnapshot.docs) {
        final myCommentData = myCommentDoc.data();
        final commentPath = myCommentData['commentPath'] as String?;
        
        if (commentPath != null) {
          final pathParts = commentPath.split('/');
          if (pathParts.length >= 6) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            final commentId = pathParts[5];
            
            try {
              // 실제 댓글 문서 업데이트
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(dateString)
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .update({
                'displayName': newDisplayName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // 개별 댓글 업데이트 실패는 무시하고 계속 진행
            }
          }
        }
      }

    } catch (e) {
      // 에러가 발생해도 닉네임 업데이트 자체는 성공했으므로 
      // 사용자에게는 성공 메시지를 보여주고 백그라운드에서 조용히 처리
    }
  }

  // 변경권 구매 다이얼로그
  Future<bool> _showChangePurchaseDialog(String type) async {
    final prices = UserService.getChangePrices();
    final price = prices[type] ?? 0;
    final typeName = type == 'photoURL' ? '프로필 이미지' : '닉네임';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            '$typeName 변경권 구매',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$typeName을 변경하려면 $price땅콩이 필요합니다.',
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                '현재 보유 땅콩: ${userProfile?['peanutCount'] ?? 0}개',
                style: TextStyle(
                  color: (userProfile?['peanutCount'] ?? 0) >= price 
                      ? Colors.green 
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if ((userProfile?['peanutCount'] ?? 0) < price)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '땅콩이 부족합니다!',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: (userProfile?['peanutCount'] ?? 0) >= price 
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(
                '구매',
                style: TextStyle(
                  color: (userProfile?['peanutCount'] ?? 0) >= price 
                      ? Colors.blue 
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  void _loadMyPageBannerAd() {
    _myPageBannerAd = BannerAd(
      adUnitId: AdHelper.myPageBannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isMyPageBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  // 차단된 멤버 리스트 다이얼로그
  void _showBlockedUsersDialog() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final blockedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('blocked')
        .get();
    List<QueryDocumentSnapshot> blockedList = blockedSnapshot.docs;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('차단된 멤버', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              content: blockedList.isEmpty
                  ? const Text('차단된 멤버가 없습니다.', style: TextStyle(color: Colors.black))
                  : SizedBox(
                      width: 320,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: blockedList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final doc = blockedList[idx];
                          final displayName = doc['displayName'] ?? '사용자';
                          final photoURL = doc['photoURL'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                              backgroundColor: Colors.grey[300],
                              child: photoURL.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            title: Text(displayName, style: const TextStyle(color: Colors.black)),
                            trailing: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('blocked')
                                    .doc(doc.id)
                                    .delete();
                                setState(() {
                                  blockedList.removeAt(idx);
                                });
                              },
                              child: const Text('차단해제'),
                            ),
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 광고 없애기 상태 확인
  Future<void> _checkAdRemovalStatus() async {
    final isActive = await AdRemovalUtils.isAdRemovalActive();
    final expiryTime = await AdRemovalUtils.getAdRemovalExpiryTime();
    setState(() {
      _isAdRemovalActive = isActive;
      _adRemovalExpiryTime = expiryTime?.toIso8601String();
    });

    // 활성화 상태면 배너 광고를 즉시 제거
    if (isActive) {
      if (_myPageBannerAd != null) {
        _myPageBannerAd!.dispose();
        _myPageBannerAd = null;
        if (mounted) {
          setState(() {
            _isMyPageBannerAdLoaded = false;
          });
        }
      }
    } else {
      // 비활성 상태이고 아직 로드되지 않았다면 로드
      if (_myPageBannerAd == null && !_isMyPageBannerAdLoaded) {
        _loadMyPageBannerAd();
      }
    }
  }

  // 전면광고 로드
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerDanAdUnitId, // 대한항공 전면광고 ID 사용
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              _givePeanuts(10);
              ad.dispose();
              setState(() {
                _interstitialAd = null;
              });
              _loadInterstitialAd(); // 다음 광고 프리로드
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              setState(() {
                _interstitialAd = null;
              });
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  // 보상형광고 로드
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedDanAdUnitId, // 대한항공 보상형광고 ID 사용
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              setState(() {
                _rewardedAd = null;
              });
              _loadRewardedAd(); // 다음 광고 프리로드
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              setState(() {
                _rewardedAd = null;
              });
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  // 땅콩 지급
  Future<void> _givePeanuts(int amount) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final userData = await UserService.getUserFromFirestore(currentUser.uid);
      final currentPeanuts = userData?['peanutCount'] ?? 0;
      final newPeanuts = currentPeanuts + amount;

      await UserService.updatePeanutCount(currentUser.uid, newPeanuts);
      
      // SharedPreferences도 업데이트 (기존 로직과 일관성 유지)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('counter', newPeanuts);

      setState(() {
        if (userProfile != null) {
          userProfile!['peanutCount'] = newPeanuts;
        }
      });

      Fluttertoast.showToast(
        msg: "땅콩 $amount개를 얻었습니다!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "오류가 발생했습니다. 다시 시도해주세요.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // 광고 관리 다이얼로그 표시
  void _showAdManagementDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const SizedBox(width: 8),
              const Text('광고 관리'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 광고 없애기 옵션
              Card(
                color: Colors.white70,
                child: ListTile(
                  leading: Icon(Icons.visibility_off, color: Colors.brown.shade600),
                  title: const Text('광고 없애기'),
                  subtitle: const Text('땅콩 30개 → 24시간 광고 제거'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _applyAdRemoval();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('적용'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 전면광고 +10 옵션
              Card(
                color: Colors.white70,
                child: ListTile(
                  leading: Icon(Icons.fullscreen, color: Colors.green.shade600),
                  title: const Text('전면광고 보기'),
                  subtitle: const Text('광고 시청 → 땅콩 +10개'),
                  trailing: ElevatedButton(
                    onPressed: _interstitialAd != null ? () {
                      Navigator.of(context).pop();
                      _interstitialAd?.show();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('+10'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 보상형광고 +30 옵션
              Card(
                color: Colors.white70,
                child: ListTile(
                  leading: Icon(Icons.card_giftcard, color: Colors.orange.shade600),
                  title: const Text('보상형광고 보기'),
                  subtitle: const Text('광고 시청 → 땅콩 +30개'),
                  trailing: ElevatedButton(
                    onPressed: _rewardedAd != null ? () {
                      Navigator.of(context).pop();
                      _rewardedAd?.show(onUserEarnedReward: (_, reward) {
                        _givePeanuts(30);
                      });
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('+30'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '닫기',
                style: TextStyle(
                  color: Colors.brown.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 광고 없애기 적용
  Future<void> _applyAdRemoval() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      Fluttertoast.showToast(
        msg: "로그인이 필요합니다!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      final userData = await UserService.getUserFromFirestore(currentUser.uid);
      final currentPeanuts = userData?['peanutCount'] ?? 0;

      if (currentPeanuts < 30) {
        Fluttertoast.showToast(
          msg: "땅콩이 부족합니다!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // 땅콩 차감
      await UserService.updatePeanutCount(currentUser.uid, currentPeanuts - 30);
      
      // 광고 없애기 활성화
      await AdRemovalUtils.activateAdRemoval();

      // UI 업데이트
      await _checkAdRemovalStatus();
      setState(() {
        if (userProfile != null) {
          userProfile!['peanutCount'] = currentPeanuts - 30;
        }
      });

      // 이미 로드된 배너 광고가 있으면 즉시 제거
      if (_myPageBannerAd != null) {
        _myPageBannerAd!.dispose();
        _myPageBannerAd = null;
        setState(() {
          _isMyPageBannerAdLoaded = false;
        });
      }

      Fluttertoast.showToast(
        msg: "광고없애기가 적용되었습니다!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "오류가 발생했습니다. 다시 시도해주세요.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // 광고 관리 섹션 빌드
  Widget _buildAdManagementSection() {
    if (_isAdRemovalActive) {
      // 광고 없애기 활성 상태
      DateTime? expiryTime;
      String timeText = '';
      
      if (_adRemovalExpiryTime != null) {
        try {
          expiryTime = DateTime.parse(_adRemovalExpiryTime!);
          timeText = '${expiryTime.year}년 ${expiryTime.month}월 ${expiryTime.day}일 ${expiryTime.hour.toString().padLeft(2, '0')}:${expiryTime.minute.toString().padLeft(2, '0')}까지';
        } catch (e) {
          timeText = '만료 시간 확인 중...';
        }
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🚫 광고 없애기 활성 중',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              timeText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            if (expiryTime != null) ...[
              const SizedBox(height: 4),
              FutureBuilder<String?>(
                future: AdRemovalUtils.getRemainingTimeString(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Text(
                      '(${snapshot.data})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ],
        ),
      );
    } else {
      // 광고 없애기 비활성 상태 - 프로모션 카드
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showAdManagementDialog,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '광고 관리',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 땅콩 30개로 24시간 광고 없애기\n• 광고 시청으로 땅콩 획득 (+10, +30)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF74512D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // 땅콩 히스토리 버튼
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PeanutHistoryScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'asset/img/peanuts.png',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${userProfile?['peanutCount'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _tabController == null
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // 프로필 영역
                      _buildProfileHeader(),
                      const SizedBox(height: 8),
                      // 레벨 영역
                      _buildLevelSection(),
                      const SizedBox(height: 8),
                      // 스카이 이펙트 영역
                      _buildSkyEffectSection(),
                      const SizedBox(height: 8),
                      // 광고 관리 영역
                      _buildAdManagementSection(),
                      const SizedBox(height: 8),
                      // 광고 영역: 스카이 이펙트와 탭바 사이
                      _buildMyPageBannerAd(),
                      const SizedBox(height: 8),
                      // 탭바
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController!,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey[600],
                          indicatorColor: const Color(0xFF74512D),
                          indicatorWeight: 2,
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('게시글'),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_userPosts.length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('댓글'),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_userComments.length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('좋아요'),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_likedPosts.length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('북마크'),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_bookmarkedPosts.length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController!,
                physics: const NeverScrollableScrollPhysics(), // 스와이프 비활성화
                children: [
                  _buildPostsList(),
                  _buildCommentsList(),
                  _buildLikedPostsList(),
                  _buildBookmarksList(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    if (userProfile == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 프로필 이미지
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: userProfile!['photoURL'] != null &&
                        userProfile!['photoURL'].toString().isNotEmpty
                    ? NetworkImage(userProfile!['photoURL'])
                    : null,
                child: userProfile!['photoURL'] == null ||
                        userProfile!['photoURL'].toString().isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUpdatingProfileImage ? null : _updateProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isUpdatingProfileImage
                          ? Colors.grey[300]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isUpdatingProfileImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 닉네임 + 편집 버튼
          Stack(
            children: [
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  userProfile!['displayName'] ?? '사용자',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userProfile!['displayName'] ?? '사용자',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.transparent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: _isUpdatingDisplayName ? null : _editDisplayName,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _isUpdatingDisplayName
                              ? Colors.grey[300]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _isUpdatingDisplayName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 이펙트
          if (userProfile!['title'] != null &&
              userProfile!['title'].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userProfile!['title'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // 좋아요/땅콩 수
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite,
                color: Colors.pink[300],
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '좋아요 ${userProfile!['likesReceived'] ?? 0}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Image.asset(
                'asset/img/peanuts.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 4),
              Text(
                                  '${userProfile!['peanutCount'] ?? 0}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600]!,
                    fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 팔로워/팔로잉 수
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FollowerListScreen()),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        '${userProfile!['followerCount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '팔로워',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FollowingListScreen()),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        '${userProfile!['followingCount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '팔로잉',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSection() {
    if (userProfile == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LevelDetailScreen(userProfile: userProfile!),
          ),
        );
        
        // 레벨이 업데이트되었으면 프로필 정보 새로고침
        if (result == true) {
          _loadUserProfile();
        }
      },
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '레벨',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Text(
                  userProfile!['displayGrade'] ?? '이코노미 Lv.1',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkyEffectSection() {
    if (userProfile == null) {
      return const SizedBox.shrink();
    }
    final currentEffect = userProfile!["currentSkyEffect"] as String?;
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkyEffectScreen(userProfile: userProfile!),
          ),
        );
        // 이펙트가 변경되었든 안 되었든 항상 최신 프로필을 새로고침하여 미리보기 동기화
        await _loadUserProfile();
        setState(() {});
      },
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '스카이 이펙트',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: userProfile!['photoURL'] != null &&
                                  userProfile!['photoURL'].toString().isNotEmpty
                              ? NetworkImage(userProfile!['photoURL'])
                              : null,
                          child: userProfile!['photoURL'] == null ||
                                  userProfile!['photoURL'].toString().isEmpty
                              ? const Icon(Icons.person, size: 16, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 2),
                        // FutureBuilder로 Lottie 미리보기와 effectName
                        _buildEffectPreviewLottieAndName(currentEffect, userProfile!['displayName'] ?? '사용자'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // effectName을 우측에 표시
                    _buildEffectNameText(currentEffect),
                    if (currentEffect != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF74512D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '착용 중',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF74512D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectPreviewLottieAndName(String? effectId, String displayName) {
    return FutureBuilder<DocumentSnapshot>(
      future: _fetchEffectDoc(effectId),
      builder: (context, snapshot) {
        if (effectId == null) {
          return Row(
            children: [
              const SizedBox(width: 32, height: 20),
              const SizedBox(width: 8),
              Text(displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              const SizedBox(width: 32, height: 20),
              const SizedBox(width: 8),
              Text(displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          print('Lottie effectId $effectId: 문서 없음');
          return Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 20),
              const SizedBox(width: 8),
              Text(displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lottieUrl = data['lottieUrl'] as String?;
        final effectName = data['name'] as String?;
        print('Lottie effectId $effectId: $lottieUrl, name: $effectName');
        return Row(
          children: [
            if (lottieUrl != null && lottieUrl.isNotEmpty)
              SizedBox(
                width: 32,
                height: 20,
                child: Lottie.network(
                  lottieUrl,
                  width: 32,
                  height: 20,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              )
            else
              const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 20),
            const SizedBox(width: 2),
            Text(displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        );
      },
    );
  }

  Widget _buildEffectNameText(String? effectId) { 
    return FutureBuilder<DocumentSnapshot>(
      future: _fetchEffectDoc(effectId),
      builder: (context, snapshot) {
        if (effectId == null) {
          return const Text('미착용', style: TextStyle(fontSize: 14, color: Colors.grey));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('...', style: TextStyle(fontSize: 14, color: Colors.grey));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('커스텀 이펙트', style: TextStyle(fontSize: 14, color: Colors.grey));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final effectName = data['name'] as String?;
        return Text(
          effectName ?? '커스텀 이펙트',
          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
        );
      },
    );
  }

  Future<DocumentSnapshot> _fetchEffectDoc(String? effectId) async {
    if (effectId == null || effectId.isEmpty) return Future.value(null);
    try {
      final doc = await FirebaseFirestore.instance.collection('effects').doc(effectId).get();
      return doc;
    } catch (e) {
      print('Firestore fetch error: $e');
      return Future.value(null);
    }
  }

  Widget _buildPostsList() {
    if (_isPostsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_userPosts.isEmpty) {
      return const Center(
        child: Text('작성한 게시글이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      primary: true,
      padding: const EdgeInsets.all(12),
      itemCount: _userPosts.length + 1,
      itemBuilder: (context, index) {
        if (index == _userPosts.length) {
          return const SizedBox(height: 32);
        }
        final myPost = _userPosts[index].data() as Map<String, dynamic>;
        final createdAt = (myPost['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final boardId = myPost['boardId'] ?? 'free';
        final boardName = _getBoardName(boardId);
        final title = myPost['title'] ?? '제목 없음';
        
        return GestureDetector(
          onTap: () async {
            final postPath = myPost['postPath'] as String?;
            if (postPath != null) {
              final pathParts = postPath.split('/');
              if (pathParts.length >= 4) {
                final dateString = pathParts[1];
                final postId = pathParts[3];
                
                // 게시글 상태 확인
                try {
                  final postDoc = await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(dateString)
                      .collection('posts')
                      .doc(postId)
                      .get();
                  
                  if (postDoc.exists) {
                    final postData = postDoc.data() as Map<String, dynamic>;
                    
                    // 신고 수가 5건 이상이면 자동으로 숨김처리
                    final reportsCount = postData['reportsCount'] ?? 0;
                    if (reportsCount >= 5 && postData['isHidden'] != true) {
                      await postDoc.reference.update({
                        'isHidden': true,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      postData['isHidden'] = true;
                    }
                    
                    // 숨김처리된 게시글인 경우 접근 차단
                    if (postData['isHidden'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('해당 게시글은 숨김처리되었습니다.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }
                } catch (e) {
                  print('게시글 상태 확인 오류: $e');
                }
                
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(
                    postId: postId,
                    boardId: boardId,
                    boardName: boardName,
                    dateString: dateString,
                  ),
                ));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 게시판명
                  Text(
                    boardName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown[300],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 제목
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // 작성일
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('yyyy.MM.dd').format(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 게시글의 boardId와 boardName을 가져오는 함수
  Future<Map<String, String>> _getPostBoardInfo(String dateString, String postId) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(dateString)
          .collection('posts')
          .doc(postId)
          .get();
      
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final boardId = postData['boardId'] ?? 'free';
        final boardName = _getBoardName(boardId);
        return {'boardId': boardId, 'boardName': boardName};
      }
    } catch (e) {
      print('게시글 boardId 조회 오류: $e');
    }
    
    // 기본값 반환
    return {'boardId': 'free', 'boardName': '자유게시판'};
  }

  Widget _buildMentionText(String content) {
    final mentionRegex = RegExp(r'@([\w가-힣]+)');
    final matches = mentionRegex.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    List<TextSpan> spans = [];
    int last = 0;
    for (final match in matches) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: content.substring(last, match.start),
          style: const TextStyle(color: Colors.black),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      ));
      last = match.end;
    }
    if (last < content.length) {
      spans.add(TextSpan(
        text: content.substring(last),
        style: const TextStyle(color: Colors.black),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCommentsList() {
    if (_isCommentsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74512D)),
      );
    }

    if (_userComments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('작성한 댓글이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      primary: true,
      padding: const EdgeInsets.all(12),
      itemCount: _userComments.length + 1,
      itemBuilder: (context, index) {
        if (index == _userComments.length) {
          return const SizedBox(height: 32);
        }
        final myComment = _userComments[index].data() as Map<String, dynamic>;
        final createdAt = (myComment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final content = _removeHtmlTags(myComment['contentHtml'] ?? '댓글 내용 없음');
        
        return GestureDetector(
          onTap: () async {
            // commentPath와 postPath에서 정보 추출해서 게시글 상세로 이동
            final postPath = myComment['postPath'] as String?;
            final commentPath = myComment['commentPath'] as String?;
            
            if (postPath != null && commentPath != null) {
              final postPathParts = postPath.split('/');
              final commentPathParts = commentPath.split('/');
              
              if (postPathParts.length >= 4 && commentPathParts.length >= 6) {
                final dateString = postPathParts[1];
                final postId = postPathParts[3];
                final commentId = commentPathParts[5];
                
                // 게시글의 boardId와 boardName 조회
                final boardInfo = await _getPostBoardInfo(dateString, postId);
                
                // 게시글 상세 화면으로 이동하면서 댓글 위치로 스크롤
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(
                    postId: postId,
                    boardId: boardInfo['boardId']!,
                    boardName: boardInfo['boardName']!,
                    dateString: dateString,
                    scrollToCommentId: commentId, // 댓글 위치로 스크롤
                  ),
                ));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 댓글 내용 (멘션 파란색)
                  _buildMentionText(content),
                  const SizedBox(height: 10),
                  // 작성일
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('yyyy.MM.dd').format(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikedPostsList() {
    if (_isLikedPostsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74512D)),
      );
    }

    if (_likedPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('좋아요한 게시글이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      primary: true,
      padding: const EdgeInsets.all(12),
      itemCount: _likedPosts.length + 1,
      itemBuilder: (context, index) {
        if (index == _likedPosts.length) {
          return const SizedBox(height: 32);
        }
        final likedPost = _likedPosts[index].data() as Map<String, dynamic>;
        final likedAt = (likedPost['likedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final title = likedPost['title'] ?? '제목 없음';
        
        return GestureDetector(
          onTap: () async {
            // postPath에서 dateString과 postId 추출해서 게시글 상세로 이동
            final postPath = likedPost['postPath'] as String?;
            if (postPath != null) {
              final pathParts = postPath.split('/');
              if (pathParts.length >= 4) {
                final dateString = pathParts[1];
                final postId = pathParts[3];
                // 게시글의 boardId와 boardName 조회
                final boardInfo = await _getPostBoardInfo(dateString, postId);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(
                    postId: postId,
                    boardId: boardInfo['boardId']!,
                    boardName: boardInfo['boardName']!,
                    dateString: dateString,
                  ),
                ));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // 좋아요한 날짜
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('yyyy.MM.dd').format(likedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _removeHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  // boardId로 게시판 이름 가져오기
  String _getBoardName(String boardId) {
    final boardNameMap = {
      'free': '자유게시판',
      'question': '마일리지',
      'deal': '적립/카드 혜택',
      'seat_share': '좌석 공유',
      'review': '항공 리뷰',
      'error_report': '오류 신고',
      'suggestion': '건의사항',
      'notice': '운영 공지사항',
    };
    return boardNameMap[boardId] ?? '알 수 없음';
  }

  Widget _buildBookmarksList() {
    if (_isBookmarksLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74512D)),
      );
    }

    if (_bookmarkedPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('북마크한 게시글이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _bookmarksScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _bookmarkedPosts.length + 1,
      itemBuilder: (context, index) {
        if (index == _bookmarkedPosts.length) {
          return const SizedBox(height: 32);
        }
        final bookmark = _bookmarkedPosts[index].data() as Map<String, dynamic>;
        final bookmarkedAt = (bookmark['bookmarkedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final title = bookmark['title'] ?? '제목 없음';
        
        return GestureDetector(
          onTap: () async {
            // postPath에서 dateString과 postId 추출해서 게시글 상세로 이동
            final postPath = bookmark['postPath'] as String?;
            if (postPath != null) {
              final pathParts = postPath.split('/');
              if (pathParts.length >= 4) {
                final dateString = pathParts[1];
                final postId = pathParts[3];
                // 게시글의 boardId와 boardName 조회
                final boardInfo = await _getPostBoardInfo(dateString, postId);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(
                    postId: postId,
                    boardId: boardInfo['boardId']!,
                    boardName: boardInfo['boardName']!,
                    dateString: dateString,
                  ),
                ));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // 북마크한 날짜
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('yyyy.MM.dd').format(bookmarkedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyPageBannerAd() {
    if (_isAdRemovalActive) {
      return const SizedBox.shrink();
    }
    if (_isMyPageBannerAdLoaded && _myPageBannerAd != null) {
      return Container(
        width: _myPageBannerAd!.size.width.toDouble(),
        height: _myPageBannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _myPageBannerAd!),
      );
    } else {
      return const SizedBox(height: 50);
    }
  }

  // 광고 초기화: 상태 확인 후 필요 시 배너 로드/제거
  void _initAdState() async {
    await _checkAdRemovalStatus();
    if (!_isAdRemovalActive) {
      _loadMyPageBannerAd();
    } else {
      _myPageBannerAd?.dispose();
      _myPageBannerAd = null;
      if (mounted) {
        setState(() {
          _isMyPageBannerAdLoaded = false;
        });
      }
    }
  }
}