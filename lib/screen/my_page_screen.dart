import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  TabController? _tabController;
  
  // 탭별 데이터
  List<DocumentSnapshot> _userPosts = [];
  List<DocumentSnapshot> _userComments = [];
  List<DocumentSnapshot> _likedPosts = [];
  
  // 로딩 상태
  bool _isPostsLoading = false;
  bool _isCommentsLoading = false;
  bool _isLikedPostsLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _loadUserProfile();
    _loadUserPosts();
  }

  void _initializeTabController() {
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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

  Future<void> _loadUserPosts() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isPostsLoading = true;
    });

    try {
      // 사용자가 작성한 게시글 가져오기
      final postsQuery = await FirebaseFirestore.instance
          .collectionGroup('posts')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _userPosts = postsQuery.docs;
        _isPostsLoading = false;
      });
    } catch (e) {
      print('사용자 게시글 로드 오류: $e');
      setState(() {
        _isPostsLoading = false;
      });
    }
  }

  Future<void> _loadUserComments() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isCommentsLoading = true;
    });

    try {
      // 사용자가 작성한 댓글 가져오기
      final commentsQuery = await FirebaseFirestore.instance
          .collectionGroup('comments')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _userComments = commentsQuery.docs;
        _isCommentsLoading = false;
      });
    } catch (e) {
      print('사용자 댓글 로드 오류: $e');
      setState(() {
        _isCommentsLoading = false;
      });
    }
  }

  Future<void> _loadLikedPosts() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isLikedPostsLoading = true;
    });

    try {
      // 사용자의 liked_posts 서브컬렉션에서 직접 가져오기
      final likedPostsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('liked_posts')
          .orderBy('likedAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _likedPosts = likedPostsQuery.docs;
        _isLikedPostsLoading = false;
      });
    } catch (e) {
      print('좋아요한 게시글 로드 오류: $e');
      setState(() {
        _isLikedPostsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '마이페이지',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF74512D),
              ),
            )
          : userProfile == null
              ? const Center(
                  child: Text(
                    '사용자 정보를 불러올 수 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 상단 프로필 영역
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
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
                                     onTap: () {
                                       // 닉네임 편집 기능 추후 구현
                                     },
                                     child: Container(
                                       padding: const EdgeInsets.all(4),
                                       decoration: BoxDecoration(
                                         color: Colors.grey[100],
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: const Icon(
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
                             Stack(
                               children: [
                                 // displayName (전체 폭을 차지하면서 중앙 정렬)
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
                                 // 편집 버튼 (displayName 바로 옆에 붙임)
                                 Positioned.fill(
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       Text(
                                         userProfile!['displayName'] ?? '사용자',
                                         style: const TextStyle(
                                           fontSize: 24,
                                           fontWeight: FontWeight.bold,
                                           color: Colors.transparent, // 투명하게 해서 위치만 잡음
                                         ),
                                         textAlign: TextAlign.center,
                                       ),
                                       const SizedBox(width: 40),
                                       GestureDetector(
                                         onTap: () {
                                           // 닉네임 편집 기능 추후 구현
                                         },
                                         child: Container(
                                           padding: const EdgeInsets.all(4),
                                           decoration: BoxDecoration(
                                             color: Colors.grey[100],
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: const Icon(
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
                            
                            // 이펙트 (있을 경우에만 표시)
                            if (userProfile!['title'] != null && 
                                userProfile!['title'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
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
                            
                                                         // 좋아요 받은 수
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
                               ],
                             ),
                            const SizedBox(height: 24),
                            
                            // 팔로워/팔로잉 수
                            Row(
                              children: [
                                Expanded(
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
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[300],
                                ),
                                Expanded(
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
                              ],
                            ),
                            
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 레벨 영역
                      Container(
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
                      
                      const SizedBox(height: 8),
                      
                      // 탭바와 탭뷰
                      if (_tabController != null) ...[
                        Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController!,
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey[600],
                            indicatorColor: const Color(0xFF74512D),
                            indicatorWeight: 2,
                            onTap: (index) {
                              if (index == 1 && _userComments.isEmpty && !_isCommentsLoading) {
                                _loadUserComments();
                              } else if (index == 2 && _likedPosts.isEmpty && !_isLikedPostsLoading) {
                                _loadLikedPosts();
                              }
                            },
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
                                        '${userProfile?['postCount'] ?? _userPosts.length}',
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
                                        '${userProfile?['commentCount'] ?? _userComments.length}',
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
                            ],
                          ),
                        ),
                        
                        // 탭뷰
                        Container(
                          height: 400, // 고정 높이
                          color: Colors.grey[50],
                          child: TabBarView(
                            controller: _tabController!,
                            children: [
                              _buildPostsList(),
                              _buildCommentsList(),
                              _buildLikedPostsList(),
                            ],
                          ),
                        ),
                      ] else
                        // TabController가 초기화되지 않은 경우 로딩 표시
                        Container(
                          height: 450,
                          color: Colors.grey[50],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF74512D),
                            ),
                          ),
                        ),
                      
                    ],
                  ),
                ),
    );
  }

  Widget _buildPostsList() {
    if (_isPostsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74512D)),
      );
    }

    if (_userPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('작성한 게시글이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index].data() as Map<String, dynamic>;
        final createdAt = (post['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              post['title'] ?? '제목 없음',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _removeHtmlTags(post['contentHtml'] ?? ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM.dd').format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, size: 14, color: Colors.pink[300]),
                    const SizedBox(width: 2),
                    Text('${post['likesCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Icon(Icons.comment, size: 14, color: Colors.blue[300]),
                    const SizedBox(width: 2),
                    Text('${post['commentsCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            onTap: () {
              // 게시글 상세로 이동
            },
          ),
        );
      },
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
            Icon(Icons.comment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('작성한 댓글이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userComments.length,
      itemBuilder: (context, index) {
        final comment = _userComments[index].data() as Map<String, dynamic>;
        final createdAt = (comment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              _removeHtmlTags(comment['contentHtml'] ?? '댓글 내용 없음'),
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              DateFormat('MM.dd').format(createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 14, color: Colors.pink[300]),
                const SizedBox(width: 2),
                Text('${comment['likesCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            onTap: () {
              // 댓글이 있는 게시글로 이동
            },
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
      padding: const EdgeInsets.all(8),
      itemCount: _likedPosts.length,
      itemBuilder: (context, index) {
        final likedPost = _likedPosts[index].data() as Map<String, dynamic>;
        final likedAt = (likedPost['likedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              likedPost['title'] ?? '제목 없음',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '좋아요한 게시글',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM.dd').format(likedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Icon(
              Icons.favorite,
              size: 20,
              color: Colors.pink[300],
            ),
            onTap: () {
              // postPath에서 dateString과 postId 추출해서 게시글 상세로 이동
              final postPath = likedPost['postPath'] as String?;
              if (postPath != null) {
                final pathParts = postPath.split('/');
                if (pathParts.length >= 4) {
                  final dateString = pathParts[1];
                  final postId = pathParts[3];
                  
                  // 게시글 상세 화면으로 이동 (추후 구현)
                  // Navigator.push(context, MaterialPageRoute(...));
                }
              }
            },
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