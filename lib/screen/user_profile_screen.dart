import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userUid;
  const UserProfileScreen({Key? key, required this.userUid}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userProfile;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('프로필', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
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
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: (userProfile!['photoURL'] as String?)?.isNotEmpty == true
                              ? NetworkImage(userProfile!['photoURL'])
                              : null,
                          child: (userProfile!['photoURL'] as String?)?.isEmpty == true
                              ? const Icon(Icons.person, color: Colors.grey, size: 48)
                              : null,
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
                              child: Column(
                                children: [
                                  Text('$followerCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                  const SizedBox(height: 2),
                                  const Text('팔로워', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.grey[200]),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('$followingCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                  const SizedBox(height: 2),
                                  const Text('팔로잉', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
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