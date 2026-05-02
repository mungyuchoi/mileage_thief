import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'community_detail_screen.dart';
import 'user_profile_screen.dart';

const Color _adminBackground = Color(0xFFF0F1F5);
const Color _adminText = Color(0xFF1F2533);
const Color _adminMuted = Color(0xFF7A8190);
const Color _adminAccent = Color(0xFF74512D);

class AdminUserManageScreen extends StatelessWidget {
  const AdminUserManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('lastLoginAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: _adminAppBar(context, '사용자 관리'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminError(
                message: '사용자 목록을 불러오지 못했습니다.\n${snapshot.error}');
          }
          if (!snapshot.hasData) return const _AdminLoading();

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const _AdminEmpty(message: '사용자 데이터가 없습니다.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _AdminUserCard(doc: docs[index]);
            },
          );
        },
      ),
    );
  }
}

class AdminPostManageScreen extends StatelessWidget {
  const AdminPostManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collectionGroup('posts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: _adminAppBar(context, '게시글 관리'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminError(message: '게시글을 불러오지 못했습니다.\n${snapshot.error}');
          }
          if (!snapshot.hasData) return const _AdminLoading();

          final posts = snapshot.data!.docs
              .where((doc) => _string(doc.data()['postId']).isNotEmpty)
              .map(_PostAdminEntry.fromDoc)
              .toList(growable: false);
          if (posts.isEmpty) {
            return const _AdminEmpty(message: '게시글이 없습니다.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: posts.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _AdminPostCard(post: posts[index]);
            },
          );
        },
      ),
    );
  }
}

class AdminStatsDashboardScreen extends StatelessWidget {
  const AdminStatsDashboardScreen({super.key});

  Future<Map<String, int>> _loadCounts() async {
    final firestore = FirebaseFirestore.instance;

    final postSnapshotFuture = firestore.collectionGroup('posts').get();
    final resolved = await Future.wait<AggregateQuerySnapshot>([
      firestore.collection('users').count().get(),
      firestore
          .collection('users')
          .where('isBanned', isEqualTo: true)
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('posts')
          .collection('posts')
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('comments')
          .collection('comments')
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('chat_messages')
          .collection('messages')
          .count()
          .get(),
      firestore.collection('contests').count().get(),
      firestore
          .collection('cards')
          .doc('catalog')
          .collection('cardProducts')
          .count()
          .get(),
    ]);
    final postSnapshot = await postSnapshotFuture;
    final postDocs = postSnapshot.docs.where(_isCommunityPostDoc).toList();
    var visiblePosts = 0;
    var hiddenPosts = 0;
    var deletedPosts = 0;
    var notices = 0;
    for (final doc in postDocs) {
      final data = doc.data();
      final isDeleted = data['isDeleted'] == true;
      final isHidden = data['isHidden'] == true;
      if (isDeleted) deletedPosts++;
      if (isHidden) hiddenPosts++;
      if (!isDeleted) visiblePosts++;
      if (_string(data['boardId']) == 'notice') notices++;
    }

    return <String, int>{
      'users': resolved[0].count ?? 0,
      'bannedUsers': resolved[1].count ?? 0,
      'posts': postDocs.length,
      'visiblePosts': visiblePosts,
      'hiddenPosts': hiddenPosts,
      'deletedPosts': deletedPosts,
      'postReports': resolved[2].count ?? 0,
      'commentReports': resolved[3].count ?? 0,
      'chatReports': resolved[4].count ?? 0,
      'contests': resolved[5].count ?? 0,
      'cards': resolved[6].count ?? 0,
      'notices': notices,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: _adminAppBar(context, '통계 대시보드'),
      body: FutureBuilder<Map<String, int>>(
        future: _loadCounts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminError(message: '통계를 불러오지 못했습니다.\n${snapshot.error}');
          }
          if (!snapshot.hasData) return const _AdminLoading();

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _StatSection(
                title: '커뮤니티',
                children: [
                  _StatCard(
                    title: '전체 게시글',
                    value: data['posts'] ?? 0,
                    icon: Icons.feed_outlined,
                  ),
                  _StatCard(
                    title: '노출 게시글',
                    value: data['visiblePosts'] ?? 0,
                    icon: Icons.visibility_outlined,
                  ),
                  _StatCard(
                    title: '숨김 게시글',
                    value: data['hiddenPosts'] ?? 0,
                    icon: Icons.visibility_off_outlined,
                  ),
                  _StatCard(
                    title: '삭제 처리',
                    value: data['deletedPosts'] ?? 0,
                    icon: Icons.delete_outline,
                  ),
                  _StatCard(
                    title: '운영 공지',
                    value: data['notices'] ?? 0,
                    icon: Icons.campaign_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatSection(
                title: '회원',
                children: [
                  _StatCard(
                    title: '전체 사용자',
                    value: data['users'] ?? 0,
                    icon: Icons.groups_outlined,
                  ),
                  _StatCard(
                    title: '이용금지',
                    value: data['bannedUsers'] ?? 0,
                    icon: Icons.block_outlined,
                    color: const Color(0xFFE24C4C),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatSection(
                title: '운영',
                children: [
                  _StatCard(
                    title: '게시글 신고',
                    value: data['postReports'] ?? 0,
                    icon: Icons.report_outlined,
                    color: const Color(0xFFE38A1B),
                  ),
                  _StatCard(
                    title: '댓글 신고',
                    value: data['commentReports'] ?? 0,
                    icon: Icons.mode_comment_outlined,
                    color: const Color(0xFFE38A1B),
                  ),
                  _StatCard(
                    title: '채팅 신고',
                    value: data['chatReports'] ?? 0,
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFFE38A1B),
                  ),
                  _StatCard(
                    title: '콘테스트',
                    value: data['contests'] ?? 0,
                    icon: Icons.emoji_events_outlined,
                  ),
                  _StatCard(
                    title: '카드 DB',
                    value: data['cards'] ?? 0,
                    icon: Icons.credit_card_outlined,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminPeriodStatsScreen extends StatefulWidget {
  const AdminPeriodStatsScreen({super.key});

  @override
  State<AdminPeriodStatsScreen> createState() => _AdminPeriodStatsScreenState();
}

class _AdminPeriodStatsScreenState extends State<AdminPeriodStatsScreen> {
  int _days = 7;
  late Future<_PeriodStats> _future = _loadPeriodStats();

  void _setDays(int days) {
    if (_days == days) return;
    setState(() {
      _days = days;
      _future = _loadPeriodStats();
    });
  }

  Future<_PeriodStats> _loadPeriodStats() async {
    final firestore = FirebaseFirestore.instance;
    final from = DateTime.now().subtract(Duration(days: _days));
    final fromTs = Timestamp.fromDate(from);
    final postSnapshotFuture = firestore.collectionGroup('posts').get();

    final countFuture = Future.wait<AggregateQuerySnapshot>([
      firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: fromTs)
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('posts')
          .collection('posts')
          .where('reportedAt', isGreaterThanOrEqualTo: fromTs)
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('comments')
          .collection('comments')
          .where('reportedAt', isGreaterThanOrEqualTo: fromTs)
          .count()
          .get(),
      firestore
          .collection('reports')
          .doc('chat_messages')
          .collection('messages')
          .where('reportedAt', isGreaterThanOrEqualTo: fromTs)
          .count()
          .get(),
    ]);

    final counts = await countFuture;
    final postSnapshot = await postSnapshotFuture;
    var periodPostCount = 0;
    final boardMap = <String, _BoardStat>{};
    for (final doc in postSnapshot.docs.where(_isCommunityPostDoc)) {
      final data = doc.data();
      final createdAt = _date(data['createdAt']);
      if (createdAt == null || createdAt.isBefore(from)) continue;
      periodPostCount++;
      if (data['isDeleted'] == true) continue;
      final boardId = _string(data['boardId']);
      if (boardId.isEmpty) continue;
      final current = boardMap[boardId] ??
          _BoardStat(
            boardId: boardId,
            boardName: _boardName(data),
            postCount: 0,
            likesCount: 0,
            viewsCount: 0,
          );
      boardMap[boardId] = current.copyWith(
        postCount: current.postCount + 1,
        likesCount: current.likesCount + _int(data['likesCount']),
        viewsCount: current.viewsCount + _viewCount(data),
      );
    }

    final boards = boardMap.values.toList()
      ..sort((a, b) {
        final countCompare = b.postCount.compareTo(a.postCount);
        if (countCompare != 0) return countCompare;
        return b.score.compareTo(a.score);
      });

    return _PeriodStats(
      posts: periodPostCount,
      users: counts[0].count ?? 0,
      postReports: counts[1].count ?? 0,
      commentReports: counts[2].count ?? 0,
      chatReports: counts[3].count ?? 0,
      boards: boards.take(5).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: _adminAppBar(context, '기간별 통계'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _PeriodSelector(days: _days, onSelected: _setDays),
          const SizedBox(height: 12),
          FutureBuilder<_PeriodStats>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _AdminError(
                    message: '기간 통계를 불러오지 못했습니다.\n${snapshot.error}');
              }
              if (!snapshot.hasData) return const _AdminLoading(inList: true);

              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatSection(
                    title: '최근 $_days일',
                    children: [
                      _StatCard(
                        title: '신규 게시글',
                        value: data.posts,
                        icon: Icons.feed_outlined,
                      ),
                      _StatCard(
                        title: '신규 가입자',
                        value: data.users,
                        icon: Icons.person_add_alt_1_outlined,
                      ),
                      _StatCard(
                        title: '게시글 신고',
                        value: data.postReports,
                        icon: Icons.report_outlined,
                        color: const Color(0xFFE38A1B),
                      ),
                      _StatCard(
                        title: '댓글 신고',
                        value: data.commentReports,
                        icon: Icons.mode_comment_outlined,
                        color: const Color(0xFFE38A1B),
                      ),
                      _StatCard(
                        title: '채팅 신고',
                        value: data.chatReports,
                        icon: Icons.chat_bubble_outline,
                        color: const Color(0xFFE38A1B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BoardStatsSection(boards: data.boards),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminPopularContentScreen extends StatelessWidget {
  const AdminPopularContentScreen({super.key});

  Future<List<_PostAdminEntry>> _loadPosts() async {
    final snapshot =
        await FirebaseFirestore.instance.collectionGroup('posts').get();
    final posts = snapshot.docs
        .where(_isCommunityPostDoc)
        .where((doc) {
          final data = doc.data();
          return data['isDeleted'] != true && data['isHidden'] != true;
        })
        .map(_PostAdminEntry.fromDoc)
        .toList(growable: false);
    return posts.toList()
      ..sort((a, b) {
        final scoreCompare = b.popularityScore.compareTo(a.popularityScore);
        if (scoreCompare != 0) return scoreCompare;
        return b.likesCount.compareTo(a.likesCount);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: _adminAppBar(context, '인기 콘텐츠'),
      body: FutureBuilder<List<_PostAdminEntry>>(
        future: _loadPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminError(
                message: '인기 콘텐츠를 불러오지 못했습니다.\n${snapshot.error}');
          }
          if (!snapshot.hasData) return const _AdminLoading();

          final posts = snapshot.data!.take(50).toList(growable: false);
          if (posts.isEmpty) {
            return const _AdminEmpty(message: '인기 콘텐츠가 없습니다.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: posts.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _PopularPostCard(rank: index + 1, post: posts[index]);
            },
          );
        },
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final uid = doc.id;
    final displayName = _firstNonEmpty([data['displayName'], uid]);
    final email = _string(data['email']);
    final photoUrl = _string(data['photoURL']);
    final isBanned = data['isBanned'] == true;
    final grade =
        _firstNonEmpty([data['displayGrade'], data['grade'], '등급 없음']);
    final lastLoginAt = _date(data['lastLoginAt']);

    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE9E1D8),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        displayName.characters.first,
                        style: const TextStyle(
                          color: _adminAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _adminText,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isBanned)
                          const _StatusPill(
                            label: '이용금지',
                            color: Color(0xFFE24C4C),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.isNotEmpty ? email : uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _adminMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoPill(text: grade),
              _InfoPill(text: '땅콩 ${_int(data['peanutCount'])}'),
              _InfoPill(text: '글 ${_int(data['postsCount'])}'),
              _InfoPill(text: '댓글 ${_int(data['commentCount'])}'),
              _InfoPill(text: '최근 ${_formatDate(lastLoginAt)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserProfileScreen(userUid: uid),
                    ),
                  ),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('프로필'),
                  style: _outlineButtonStyle(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _setUserBan(context, uid, !isBanned),
                  icon: Icon(
                    isBanned ? Icons.lock_open_outlined : Icons.block_outlined,
                    size: 18,
                  ),
                  label: Text(isBanned ? '해제' : '이용금지'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isBanned
                        ? const Color(0xFF2F8F63)
                        : const Color(0xFFE24C4C),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setUserBan(
    BuildContext context,
    String uid,
    bool shouldBan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(shouldBan ? '이용금지 처리' : '이용금지 해제'),
        content: Text(
          shouldBan ? '이 사용자를 이용금지 처리할까요?' : '이 사용자의 이용금지를 해제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final update = <String, dynamic>{
      'isBanned': shouldBan,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (shouldBan) {
      update['bannedAt'] = FieldValue.serverTimestamp();
      update['bannedBy'] = adminUid;
    } else {
      update['banReleasedAt'] = FieldValue.serverTimestamp();
      update['banReleasedBy'] = adminUid;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(update, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shouldBan ? '이용금지 처리했습니다.' : '이용금지를 해제했습니다.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류가 발생했습니다: $error')),
      );
    }
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({required this.post});

  final _PostAdminEntry post;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _adminText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.28,
                  ),
                ),
              ),
              if (post.isDeleted)
                const _StatusPill(label: '삭제', color: Color(0xFFE24C4C))
              else if (post.isHidden)
                const _StatusPill(label: '숨김', color: Color(0xFFE38A1B)),
            ],
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF596172),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoPill(text: post.boardName),
              _InfoPill(text: post.authorName),
              _InfoPill(text: _formatDate(post.createdAt)),
              _InfoPill(text: '좋아요 ${post.likesCount}'),
              _InfoPill(text: '댓글 ${post.commentCount}'),
              _InfoPill(text: '조회 ${post.viewsCount}'),
              if (post.reportsCount > 0)
                _InfoPill(text: '신고 ${post.reportsCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallActionButton(
                label: '보기',
                icon: Icons.open_in_new_outlined,
                onPressed: () => _openPost(context, post),
              ),
              _SmallActionButton(
                label: post.isHidden ? '숨김해제' : '숨김',
                icon: post.isHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                onPressed: () => _setPostHidden(context, post, !post.isHidden),
              ),
              _SmallActionButton(
                label: post.isDeleted ? '복구' : '삭제',
                icon: post.isDeleted
                    ? Icons.restore_outlined
                    : Icons.delete_outline,
                isDestructive: !post.isDeleted,
                onPressed: () =>
                    _setPostDeleted(context, post, !post.isDeleted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PopularPostCard extends StatelessWidget {
  const _PopularPostCard({required this.rank, required this.post});

  final int rank;
  final _PostAdminEntry post;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: InkWell(
        onTap: () => _openPost(context, post),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE9E1D8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: _adminAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _adminText,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666F7F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoPill(text: post.boardName),
                      _InfoPill(text: '좋아요 ${post.likesCount}'),
                      _InfoPill(text: '댓글 ${post.commentCount}'),
                      _InfoPill(text: '조회 ${post.viewsCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.days, required this.onSelected});

  final int days;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [7, 30, 90].map((value) {
        final selected = value == days;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value == 90 ? 0 : 8),
            child: FilledButton(
              onPressed: () => onSelected(value),
              style: FilledButton.styleFrom(
                backgroundColor:
                    selected ? _adminAccent : const Color(0xFFD8DEE8),
                foregroundColor:
                    selected ? Colors.white : const Color(0xFF596070),
                minimumSize: const Size.fromHeight(42),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text('$value일'),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _BoardStatsSection extends StatelessWidget {
  const _BoardStatsSection({required this.boards});

  final List<_BoardStat> boards;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '활동 많은 게시판',
            style: TextStyle(
              color: _adminText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (boards.isEmpty)
            const Text(
              '기간 내 게시판 활동이 없습니다.',
              style: TextStyle(
                color: _adminMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...boards.map((board) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        board.boardName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _adminText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '글 ${board.postCount} · 좋아요 ${board.likesCount} · 조회 ${board.viewsCount}',
                      style: const TextStyle(
                        color: _adminMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  const _StatSection({required this.title, required this.children});

  final String title;
  final List<_StatCard> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: _adminText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 560;
            final width =
                isWide ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children
                  .map((child) => SizedBox(width: width, child: child))
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = _adminAccent,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _adminText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isDestructive ? const Color(0xFFE24C4C) : const Color(0xFF1F2533);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: 0.24)),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF596172),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _AdminLoading extends StatelessWidget {
  const _AdminLoading({this.inList = false});

  final bool inList;

  @override
  Widget build(BuildContext context) {
    const loader = Center(
      child: CircularProgressIndicator(color: _adminAccent),
    );
    if (inList) {
      return const Padding(
        padding: EdgeInsets.only(top: 22),
        child: loader,
      );
    }
    return loader;
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _adminMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _adminMuted,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _PostAdminEntry {
  const _PostAdminEntry({
    required this.id,
    required this.dateString,
    required this.reference,
    required this.title,
    required this.body,
    required this.boardId,
    required this.boardName,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.likesCount,
    required this.commentCount,
    required this.viewsCount,
    required this.reportsCount,
    required this.isHidden,
    required this.isDeleted,
  });

  final String id;
  final String dateString;
  final DocumentReference<Map<String, dynamic>> reference;
  final String title;
  final String body;
  final String boardId;
  final String boardName;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final int likesCount;
  final int commentCount;
  final int viewsCount;
  final int reportsCount;
  final bool isHidden;
  final bool isDeleted;

  int get popularityScore => likesCount * 3 + commentCount * 2 + viewsCount;

  factory _PostAdminEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final contentText = _stripHtml(
      _firstNonEmpty(
          [data['contentText'], data['contentHtml'], data['content']]),
    );
    final author = data['author'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : {};
    final boardId = _string(data['boardId']);

    return _PostAdminEntry(
      id: _firstNonEmpty([data['postId'], doc.id]),
      dateString: doc.reference.parent.parent?.id ?? '',
      reference: doc.reference,
      title: _firstNonEmpty([data['title'], contentText, '(제목 없음)']),
      body: contentText,
      boardId: boardId,
      boardName: _boardName(data),
      authorUid: _string(authorMap['uid']),
      authorName:
          _firstNonEmpty([authorMap['displayName'], authorMap['uid'], '익명']),
      createdAt: _date(data['createdAt']),
      likesCount: _int(data['likesCount']),
      commentCount: _int(data['commentCount']),
      viewsCount: _viewCount(data),
      reportsCount: _int(data['reportsCount']),
      isHidden: data['isHidden'] == true,
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class _PeriodStats {
  const _PeriodStats({
    required this.posts,
    required this.users,
    required this.postReports,
    required this.commentReports,
    required this.chatReports,
    required this.boards,
  });

  final int posts;
  final int users;
  final int postReports;
  final int commentReports;
  final int chatReports;
  final List<_BoardStat> boards;
}

class _BoardStat {
  const _BoardStat({
    required this.boardId,
    required this.boardName,
    required this.postCount,
    required this.likesCount,
    required this.viewsCount,
  });

  final String boardId;
  final String boardName;
  final int postCount;
  final int likesCount;
  final int viewsCount;

  int get score => postCount * 10 + likesCount * 3 + viewsCount;

  _BoardStat copyWith({
    int? postCount,
    int? likesCount,
    int? viewsCount,
  }) {
    return _BoardStat(
      boardId: boardId,
      boardName: boardName,
      postCount: postCount ?? this.postCount,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
    );
  }
}

PreferredSizeWidget _adminAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: _adminBackground,
    foregroundColor: _adminText,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}

ButtonStyle _outlineButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _adminText,
    side: BorderSide(color: _adminText.withValues(alpha: 0.18)),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
  );
}

void _openPost(BuildContext context, _PostAdminEntry post) {
  if (post.dateString.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('게시글 날짜 경로를 찾을 수 없습니다.')),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommunityDetailScreen(
        postId: post.id,
        boardId: post.boardId,
        boardName: post.boardName,
        dateString: post.dateString,
      ),
    ),
  );
}

Future<void> _setPostHidden(
  BuildContext context,
  _PostAdminEntry post,
  bool shouldHide,
) async {
  await _updatePostFlag(
    context: context,
    post: post,
    field: 'isHidden',
    value: shouldHide,
    successMessage: shouldHide ? '게시글을 숨김 처리했습니다.' : '게시글 숨김을 해제했습니다.',
    extra: shouldHide
        ? {
            'hiddenAt': FieldValue.serverTimestamp(),
            'hiddenBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
          }
        : {
            'unhiddenAt': FieldValue.serverTimestamp(),
            'unhiddenBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
          },
  );
}

Future<void> _setPostDeleted(
  BuildContext context,
  _PostAdminEntry post,
  bool shouldDelete,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(shouldDelete ? '게시글 삭제 처리' : '게시글 복구'),
      content: Text(shouldDelete ? '이 게시글을 삭제 상태로 바꿀까요?' : '이 게시글을 복구할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  await _updatePostFlag(
    context: context,
    post: post,
    field: 'isDeleted',
    value: shouldDelete,
    successMessage: shouldDelete ? '게시글을 삭제 처리했습니다.' : '게시글을 복구했습니다.',
    extra: shouldDelete
        ? {
            'adminDeletedAt': FieldValue.serverTimestamp(),
            'adminDeletedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
          }
        : {
            'restoredAt': FieldValue.serverTimestamp(),
            'restoredBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
          },
  );
}

Future<void> _updatePostFlag({
  required BuildContext context,
  required _PostAdminEntry post,
  required String field,
  required bool value,
  required String successMessage,
  required Map<String, dynamic> extra,
}) async {
  try {
    await post.reference.set({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
      ...extra,
    }, SetOptions(merge: true));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('처리 중 오류가 발생했습니다: $error')),
    );
  }
}

bool _isCommunityPostDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  return _string(doc.data()['postId']).isNotEmpty;
}

String _boardName(Map<String, dynamic> data) {
  final boardName = _string(data['boardName']);
  if (boardName.isNotEmpty) return boardName;
  final boardId = _string(data['boardId']);
  return _boardNameById[boardId] ?? (boardId.isEmpty ? '커뮤니티' : boardId);
}

const Map<String, String> _boardNameById = {
  'question': '마일리지',
  'deal': '적립/카드 혜택',
  'seat_share': '좌석 공유',
  'review': '항공 리뷰',
  'free': '자유게시판',
  'seats': '오늘의 좌석',
  'news': '오늘의 뉴스',
  'error_report': '오류 신고',
  'suggestion': '건의사항',
  'notice': '운영 공지사항',
};

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = _string(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _string(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

int _viewCount(Map<String, dynamic> data) {
  if (data.containsKey('viewsCount')) return _int(data['viewsCount']);
  return _int(data['viewCount']);
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatDate(DateTime? value) {
  if (value == null) return '날짜 없음';
  return DateFormat('yyyy.MM.dd HH:mm').format(value);
}

String _stripHtml(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
