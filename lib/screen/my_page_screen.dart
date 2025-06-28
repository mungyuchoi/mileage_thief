import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
  bool _isUpdatingProfile = false;
  
  final ImagePicker _imagePicker = ImagePicker();

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
      // 사용자의 my_posts 서브컬렉션에서 직접 가져오기
      final myPostsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_posts')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _userPosts = myPostsQuery.docs;
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
      // 사용자의 my_comments 서브컬렉션에서 직접 가져오기
      final myCommentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_comments')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _userComments = myCommentsQuery.docs;
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

  Future<void> _updateProfileImage() async {
    try {
      // 1. 이미지 선택
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      final user = AuthService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      setState(() {
        _isUpdatingProfile = true;
      });

      // 2. Firebase Storage에 업로드
      final File imageFile = File(image.path);
      final String fileName = '${user.uid}.png';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(fileName);

      // 기존 파일이 있다면 덮어쓰기 (같은 경로이므로 자동으로 대체됨)
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 3. Firestore 사용자 정보 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoURL': downloadUrl,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Firebase Auth 프로필 업데이트
      await user.updatePhotoURL(downloadUrl);

      // 5. 기존 게시글과 댓글의 프로필 이미지 업데이트
      await _updateExistingPostsAndComments(user.uid, downloadUrl);

      // 6. 로컬 상태 업데이트
      setState(() {
        if (userProfile != null) {
          userProfile!['photoURL'] = downloadUrl;
        }
        _isUpdatingProfile = false;
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
        _isUpdatingProfile = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 이미지 업데이트 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateExistingPostsAndComments(String uid, String newPhotoURL) async {
    try {
      print('🔄 기존 게시글과 댓글의 프로필 이미지 업데이트 시작...');
      print('📸 새 프로필 이미지 URL: $newPhotoURL');
      
      // 1. 사용자의 모든 게시글 업데이트
      final myPostsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('my_posts')
          .get();

      print('📝 업데이트할 게시글 수: ${myPostsSnapshot.docs.length}');

      for (final myPostDoc in myPostsSnapshot.docs) {
        final myPostData = myPostDoc.data();
        final postPath = myPostData['postPath'] as String?;
        print('📄 게시글 경로: $postPath');
        
        if (postPath != null) {
          final pathParts = postPath.split('/');
          if (pathParts.length >= 4) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            
            print('🎯 게시글 업데이트: posts/$dateString/posts/$postId');
            
            try {
              // 실제 게시글 문서 업데이트 (개별로 처리)
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(dateString)
                  .collection('posts')
                  .doc(postId)
                  .update({
                'author.photoURL': newPhotoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              print('✅ 게시글 업데이트 성공: $postId');
            } catch (e) {
              print('❌ 게시글 업데이트 실패: $postId, 오류: $e');
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

      print('💬 업데이트할 댓글 수: ${myCommentsSnapshot.docs.length}');

      for (final myCommentDoc in myCommentsSnapshot.docs) {
        final myCommentData = myCommentDoc.data();
        final commentPath = myCommentData['commentPath'] as String?;
        print('💭 댓글 경로: $commentPath');
        
        if (commentPath != null) {
          final pathParts = commentPath.split('/');
          if (pathParts.length >= 6) {
            final dateString = pathParts[1];
            final postId = pathParts[3];
            final commentId = pathParts[5];
            
            print('🎯 댓글 업데이트: posts/$dateString/posts/$postId/comments/$commentId');
            
            try {
              // 실제 댓글 문서 업데이트 (개별로 처리)
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
              print('✅ 댓글 업데이트 성공: $commentId');
            } catch (e) {
              print('❌ 댓글 업데이트 실패: $commentId, 오류: $e');
            }
          }
        }
      }

      print('🎉 프로필 이미지 업데이트 완료!');

    } catch (e) {
      print('💥 기존 게시글/댓글 프로필 이미지 업데이트 오류: $e');
      // 에러가 발생해도 프로필 이미지 업데이트 자체는 성공했으므로 
      // 사용자에게는 성공 메시지를 보여주고 백그라운드에서 로그만 남김
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
                                     onTap: _isUpdatingProfile ? null : _updateProfileImage,
                                     child: Container(
                                       padding: const EdgeInsets.all(4),
                                       decoration: BoxDecoration(
                                         color: _isUpdatingProfile 
                                             ? Colors.grey[300] 
                                             : Colors.grey[100],
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: _isUpdatingProfile
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
        final myPost = _userPosts[index].data() as Map<String, dynamic>;
        final createdAt = (myPost['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              myPost['title'] ?? '제목 없음',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '작성한 게시글',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM.dd').format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Icon(
              Icons.article_outlined,
              size: 20,
              color: Colors.blue[300],
            ),
            onTap: () {
              // postPath에서 dateString과 postId 추출해서 게시글 상세로 이동
              final postPath = myPost['postPath'] as String?;
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
        final myComment = _userComments[index].data() as Map<String, dynamic>;
        final createdAt = (myComment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              _removeHtmlTags(myComment['contentHtml'] ?? '댓글 내용 없음'),
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '작성한 댓글',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM.dd').format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Icon(
              Icons.comment_outlined,
              size: 20,
              color: Colors.blue[300],
            ),
            onTap: () {
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
                  
                  // 게시글 상세 화면으로 이동하면서 댓글 위치로 스크롤 (추후 구현)
                  // Navigator.push(context, MaterialPageRoute(...));
                }
              }
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