import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'community_detail_screen.dart';
import 'follower_list_screen.dart';
import 'following_list_screen.dart';
import 'package:lottie/lottie.dart';

class UserProfileScreen extends StatefulWidget {
  final String userUid;
  const UserProfileScreen({Key? key, required this.userUid}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? currentUserProfile; // 현재 로그인한 사용자의 프로필 추가
  int followerCount = 0;
  int followingCount = 0;
  bool isFollowing = false;
  bool isLoading = true;
  TabController? _tabController;
  List<DocumentSnapshot> _userPosts = [];
  List<DocumentSnapshot> _userComments = [];
  bool _isPostsLoading = false;
  bool _isCommentsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
    _loadCurrentUserProfile(); // 현재 로그인한 사용자 프로필 로드 추가
    _loadUserPosts();
    _loadUserComments();
    _checkFollowing();
  }

  Future<void> _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userUid).get();
    if (doc.exists) {
      setState(() {
        userProfile = doc.data();
        followerCount = userProfile?['followerCount'] ?? 0;
        followingCount = userProfile?['followingCount'] ?? 0;
        isLoading = false;
      });
    } else {
      setState(() { isLoading = false; });
    }
  }

  // 현재 로그인한 사용자의 프로필 로드
  Future<void> _loadCurrentUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        setState(() {
          currentUserProfile = doc.data();
        });
      }
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() { _isPostsLoading = true; });
    final postsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('my_posts')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    setState(() {
      _userPosts = postsSnap.docs;
      _isPostsLoading = false;
    });
  }

  Future<void> _loadUserComments() async {
    setState(() { _isCommentsLoading = true; });
    final commentsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('my_comments')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    setState(() {
      _userComments = commentsSnap.docs;
      _isCommentsLoading = false;
    });
  }

  Future<void> _checkFollowing() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(widget.userUid)
        .get();
    setState(() {
      isFollowing = doc.exists;
    });
  }

  // 관리자용 땅콩 주기 다이얼로그
  void _showGivePeanutsDialog() {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '땅콩 주기',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${userProfile!['displayName'] ?? '사용자'}님에게 땅콩을 주시겠습니까?',
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Image.asset(
                    'asset/img/peanuts.png',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '땅콩 개수 입력',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ],
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
              onPressed: () async {
                final amount = int.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  Fluttertoast.showToast(
                    msg: '올바른 숫자를 입력해주세요.',
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                await _givePeanuts(amount);
              },
              child: const Text(
                '주기',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // 땅콩 주기 실행
  Future<void> _givePeanuts(int amount) async {
    try {
      // 현재 사용자의 땅콩 개수 가져오기
      final currentPeanutCount = userProfile!['peanutCount'] ?? 0;
      final newPeanutCount = currentPeanutCount + amount;
      
      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .update({
        'peanutCount': newPeanutCount,
      });
      
      // 로컬 상태 업데이트
      setState(() {
        userProfile!['peanutCount'] = newPeanutCount;
      });
      
      // 성공 메시지
      Fluttertoast.showToast(
        msg: '${userProfile!['displayName'] ?? '사용자'}님에게 땅콩 $amount개를 주었습니다.',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
    } catch (e) {
      print('땅콩 주기 오류: $e');
      Fluttertoast.showToast(
        msg: '땅콩 주기 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    
    if (isFollowing) {
      // 언팔로우
      // 1. 내 following 서브컬렉션에서 제거
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userUid));
      
      // 2. 상대방 followers 서브컬렉션에서 제거
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('followers')
          .doc(currentUser.uid));
      
      // 3. 내 followingCount 감소
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid), {
        'followingCount': FieldValue.increment(-1)
      });
      
      // 4. 상대방 followerCount 감소
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid), {
        'followerCount': FieldValue.increment(-1)
      });
      
      setState(() {
        isFollowing = false;
        followerCount = (followerCount - 1).clamp(0, 999999);
      });
    } else {
      // 팔로우
      // 1. 내 following 서브컬렉션에 추가
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userUid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      // 2. 상대방 followers 서브컬렉션에 추가
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('followers')
          .doc(currentUser.uid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      // 3. 내 followingCount 증가
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid), {
        'followingCount': FieldValue.increment(1)
      });
      
      // 4. 상대방 followerCount 증가
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid), {
        'followerCount': FieldValue.increment(1)
      });
      
      setState(() {
        isFollowing = true;
        followerCount = followerCount + 1;
      });
    }
    
    await batch.commit();
  }

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
    return {'boardId': 'free', 'boardName': '자유게시판'};
  }

  String _getBoardName(String boardId) {
    // boardId에 따른 boardName 반환 (예시)
    switch (boardId) {
      case 'free':
        return '자유게시판';
      case 'qna':
        return '질문답변';
      case 'review':
        return '후기게시판';
      default:
        return '자유게시판';
    }
  }

  // 1. _buildSkyEffectPreview 함수 추가 (community_detail_screen.dart에서 복사)
  Widget _buildSkyEffectPreview(String? effectId) {
    if (effectId == null || effectId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('effects').doc(effectId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 28);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lottieUrl = data['lottieUrl'] as String?;
        if (lottieUrl != null && lottieUrl.isNotEmpty) {
          return SizedBox(
            width: 36,
            height: 36,
            child: Lottie.network(
              lottieUrl,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              repeat: true,
              animate: true,
            ),
          );
        } else {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 28);
        }
      },
    );
  }

  // 멤버 차단 다이얼로그 및 Firestore 저장
  void _showBlockDialog(BuildContext context) {
    final displayName = userProfile?['displayName'] ?? '사용자';
    final photoURL = userProfile?['photoURL'] ?? '';
    final targetUid = widget.userUid;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '$displayName님을 차단할까요?',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('blocked')
                    .doc(targetUid)
                    .set({
                  'displayName': displayName,
                  'photoURL': photoURL,
                  'blockedAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 프로필 화면 닫기
            },
            child: const Text('차단', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 차단 인원 체크 후 다이얼로그 또는 Toast
  void _onBlockMember(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    print("user.uid:${user.uid}");
    final blockedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('blocked')
        .get();
    if (blockedSnapshot.docs.length >= 10) {
      Fluttertoast.showToast(
        msg: "멤버 차단은 10명을 초과할 수 없습니다.",
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }
    _showBlockDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // 본인 프로필이 아니고, 로그인 유저가 admin인지 체크
    bool isAdmin = false;
    if (currentUser != null && currentUserProfile != null && currentUser.uid != widget.userUid) {
      // 현재 로그인한 사용자의 roles 확인
      final roles = currentUserProfile!['roles'] ?? [];
      isAdmin = roles.contains('admin');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('프로필', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // 관리자인 경우에만 땅콩 주기 버튼 표시
          if (isAdmin)
            IconButton(
              onPressed: _showGivePeanutsDialog,
              icon: Image.asset(
                'asset/img/peanuts.png',
                width: 24,
                height: 24,
              ),
              tooltip: '땅콩 주기',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _onBlockMember(context);
              }
            },
            itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'block',
                  child: Text('멤버 차단'),
                ),
            ],
          ),
        ],
      ),
      body: isLoading || userProfile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 프로필 카드
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 2. 프로필 카드 내 CircleAvatar + skyEffect Row로 감싸기
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(child: SizedBox()), // 1번(왼쪽) 빈 공간
                            Expanded(
                              child: Center(
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (userProfile!['photoURL'] as String?)?.isNotEmpty == true
                                      ? NetworkImage(userProfile!['photoURL'])
                                      : null,
                                  child: (userProfile!['photoURL'] as String?)?.isEmpty == true
                                      ? const Icon(Icons.person, color: Colors.grey, size: 48)
                                      : null,
                                ),
                              ),
                            ),
                            Expanded(
                              child: (userProfile?['currentSkyEffect'] ?? '').toString().isNotEmpty
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildSkyEffectPreview(userProfile?['currentSkyEffect']),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          userProfile!['displayName'] ?? '알 수 없음',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if ((userProfile!['title'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              userProfile!['title'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          userProfile!['displayGrade'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 팔로워/팔로잉
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FollowerListScreen(
                                        userUid: widget.userUid,
                                        userName: userProfile!['displayName'],
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Text('$followerCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                    const SizedBox(height: 2),
                                    const Text('팔로워', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.grey[200]),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FollowingListScreen(
                                        userUid: widget.userUid,
                                        userName: userProfile!['displayName'],
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Text('$followingCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                    const SizedBox(height: 2),
                                    const Text('팔로잉', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // 팔로우/팔로잉 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isFollowing ? Colors.grey[200] : const Color(0xFF74512D),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  isFollowing ? '팔로잉' : '팔로우',
                                  style: TextStyle(
                                    color: isFollowing ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 관리자용 ban/unban 버튼
                        if (isAdmin) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: userProfile!['isBanned'] == true ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: Text(
                                    userProfile!['isBanned'] == true ? '이용금지 해제' : '이용금지 처리',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  content: Text(
                                    userProfile!['isBanned'] == true
                                        ? '이 사용자의 이용금지를 해제하시겠습니까?'
                                        : '이 사용자를 정말 이용금지 처리하시겠습니까?',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('아니오', style: TextStyle(color: Colors.black)), 
                                      onPressed: () => Navigator.pop(context, false)
                                    ),
                                    TextButton(
                                      child: const Text('예', style: TextStyle(color: Colors.black)), 
                                      onPressed: () => Navigator.pop(context, true)
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userUid)
                                      .update({'isBanned': !(userProfile!['isBanned'] == true)});
                                  setState(() {
                                    userProfile!['isBanned'] = !(userProfile!['isBanned'] == true);
                                  });
                                  Fluttertoast.showToast(
                                    msg: userProfile!['isBanned'] == true
                                        ? '해당 사용자는 이용금지 처리되었습니다.'
                                        : '이용금지가 해제되었습니다.',
                                    backgroundColor: Colors.black87,
                                    textColor: Colors.white,
                                  );
                                } catch (e) {
                                  print('이용금지 처리 오류: $e');
                                  Fluttertoast.showToast(
                                    msg: '처리 중 오류가 발생했습니다.',
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                  );
                                }
                              }
                            },
                            child: Text(
                              userProfile!['isBanned'] == true ? '이용금지 해제' : '이용금지 처리',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 탭바
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController!,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: const Color(0xFF74512D),
                      indicatorWeight: 2,
                      tabs: const [
                        Tab(child: Text('게시글', style: TextStyle(fontSize: 15))),
                        Tab(child: Text('댓글', style: TextStyle(fontSize: 15))),
                      ],
                    ),
                  ),
                  Container(
                    height: 400,
                    color: Colors.grey[50],
                    child: TabBarView(
                      controller: _tabController!,
                      children: [
                        _buildPostsList(),
                        _buildCommentsList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
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
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final myPost = _userPosts[index].data() as Map<String, dynamic>;
        final createdAt = (myPost['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final title = myPost['title'] ?? '제목 없음';
        final postPath = myPost['postPath'] as String?;
        return GestureDetector(
          onTap: () async {
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
                
                final boardInfo = await _getPostBoardInfo(dateString, postId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityDetailScreen(
                      postId: postId,
                      boardId: boardInfo['boardId']!,
                      boardName: boardInfo['boardName']!,
                      dateString: dateString,
                    ),
                  ),
                );
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}',
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

  Widget _buildCommentsList() {
    if (_isCommentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_userComments.isEmpty) {
      return const Center(
        child: Text('작성한 댓글이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      primary: true,
      padding: const EdgeInsets.all(12),
      itemCount: _userComments.length,
      itemBuilder: (context, index) {
        final myComment = _userComments[index].data() as Map<String, dynamic>;
        final createdAt = (myComment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final content = _removeHtmlTags(myComment['contentHtml'] ?? '댓글 내용 없음');
        final postPath = myComment['postPath'] as String?;
        final commentPath = myComment['commentPath'] as String?;
        return GestureDetector(
          onTap: () async {
            if (postPath != null && commentPath != null) {
              final postPathParts = postPath.split('/');
              final commentPathParts = commentPath.split('/');
              if (postPathParts.length >= 4 && commentPathParts.length >= 6) {
                final dateString = postPathParts[1];
                final postId = postPathParts[3];
                final commentId = commentPathParts[5];
                final boardInfo = await _getPostBoardInfo(dateString, postId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityDetailScreen(
                      postId: postId,
                      boardId: boardInfo['boardId']!,
                      boardName: boardInfo['boardName']!,
                      dateString: dateString,
                      scrollToCommentId: commentId,
                    ),
                  ),
                );
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
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}',
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
} 