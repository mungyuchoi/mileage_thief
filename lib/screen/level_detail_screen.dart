import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'package:lottie/lottie.dart';

class LevelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const LevelDetailScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _showUpgradeAnimation = false;
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;

  // 현재 활동 통계
  int currentPosts = 0;
  int currentComments = 0;
  int currentLikes = 0;
  int currentPoints = 0;
  int currentFollowers = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadUserStats();
    
    // 프로그레스 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 300), () {
      _progressAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 게시글 수 조회
      final postsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_posts')
          .get();
      currentPosts = postsQuery.docs.length;

      // 댓글 수 조회
      final commentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_comments')
          .get();
      currentComments = commentsQuery.docs.length;

      // 좋아요 수 조회
      final likedQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('liked_posts')
          .get();
      currentLikes = likedQuery.docs.length;

      // 사용자 프로필에서 추가 정보
      currentPoints = widget.userProfile['peanutCount'] ?? 0;
      currentFollowers = widget.userProfile['followerCount'] ?? 0;

      setState(() => _isLoading = false);
    } catch (e) {
      print('사용자 통계 로딩 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  // 레벨 정책 정의
  Map<String, Map<String, Map<String, int>>> get levelRequirements => {
    '이코노미': {
      'Lv.1': {'posts': 0, 'comments': 0, 'likes': 0, 'points': 0, 'followers': 0},
      'Lv.2': {'posts': 2, 'comments': 5, 'likes': 10, 'points': 0, 'followers': 0},
      'Lv.3': {'posts': 5, 'comments': 15, 'likes': 20, 'points': 0, 'followers': 0},
      'Lv.4': {'posts': 10, 'comments': 30, 'likes': 50, 'points': 0, 'followers': 0},
      'Lv.5': {'posts': 20, 'comments': 50, 'likes': 100, 'points': 0, 'followers': 0},
    },
    '비즈니스': {
      'Lv.1': {'posts': 30, 'comments': 70, 'likes': 150, 'points': 0, 'followers': 0},
      'Lv.2': {'posts': 40, 'comments': 100, 'likes': 250, 'points': 0, 'followers': 0},
      'Lv.3': {'posts': 50, 'comments': 150, 'likes': 400, 'points': 0, 'followers': 0},
      'Lv.4': {'posts': 70, 'comments': 200, 'likes': 600, 'points': 0, 'followers': 0},
      'Lv.5': {'posts': 100, 'comments': 300, 'likes': 1000, 'points': 0, 'followers': 0},
    },
    '퍼스트': {
      'Lv.1': {'posts': 150, 'comments': 400, 'likes': 1500, 'points': 500, 'followers': 30},
      'Lv.2': {'posts': 150, 'comments': 400, 'likes': 1500, 'points': 500, 'followers': 30}, // 운영자 승인 필요
    },
  };

  // 현재 레벨 정보 파싱
  Map<String, dynamic> get currentLevelInfo {
    final displayGrade = widget.userProfile['displayGrade'] ?? '이코노미 Lv.1';
    final parts = displayGrade.split(' ');
    final grade = parts[0];
    final level = parts.length > 1 ? parts[1] : 'Lv.1';
    return {'grade': grade, 'level': level};
  }

  // 다음 레벨 정보 가져오기
  Map<String, dynamic>? get nextLevelInfo {
    final current = currentLevelInfo;
    final currentGrade = current['grade'];
    final currentLevel = current['level'];
    
    if (currentGrade == '퍼스트' && currentLevel == 'Lv.2') {
      return null; // 최고 레벨
    }

    // 현재 등급 내에서 다음 레벨 확인
    final gradeRequirements = levelRequirements[currentGrade];
    if (gradeRequirements != null) {
      final currentLevelNum = int.tryParse(currentLevel.replaceAll('Lv.', '')) ?? 1;
      final nextLevelNum = currentLevelNum + 1;
      final nextLevelKey = 'Lv.$nextLevelNum';
      
      if (gradeRequirements.containsKey(nextLevelKey)) {
        return {
          'grade': currentGrade,
          'level': nextLevelKey,
          'requirements': gradeRequirements[nextLevelKey]!,
        };
      }
    }

    // 현재 등급에서 다음 레벨이 없으면 다음 등급의 첫 레벨
    if (currentGrade == '이코노미') {
      return {
        'grade': '비즈니스',
        'level': 'Lv.1',
        'requirements': levelRequirements['비즈니스']!['Lv.1']!,
      };
    } else if (currentGrade == '비즈니스') {
      return {
        'grade': '퍼스트',
        'level': 'Lv.1',
        'requirements': levelRequirements['퍼스트']!['Lv.1']!,
      };
    }

    return null;
  }

  // 업그레이드 가능 여부 확인
  bool get canUpgrade {
    final next = nextLevelInfo;
    if (next == null) return false;

    final requirements = next['requirements'] as Map<String, int>;
    return currentPosts >= requirements['posts']! &&
           currentComments >= requirements['comments']! &&
           currentLikes >= requirements['likes']! &&
           currentPoints >= requirements['points']! &&
           currentFollowers >= requirements['followers']!;
  }

  // 등급별 색상
  Color _getGradeColor(String grade) {
    switch (grade) {
      case '이코노미':
        return Colors.grey[600]!;
      case '비즈니스':
        return Colors.blue[600]!;
      case '퍼스트':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // 업그레이드 버튼 클릭
  Future<void> _upgradeLevel() async {
    if (!canUpgrade) return;

    final next = nextLevelInfo;
    if (next == null) return;

    // 퍼스트 Lv.2는 운영자 승인 필요
    if (next['grade'] == '퍼스트' && next['level'] == 'Lv.2') {
      _showAdminApprovalDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newDisplayGrade = '${next['grade']} ${next['level']}';
      
      // 레벨 업그레이드
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'grade': next['grade'],
        'gradeLevel': int.tryParse(next['level'].replaceAll('Lv.', '')) ?? 1,
        'displayGrade': newDisplayGrade,
        'gradeUpdatedAt': FieldValue.serverTimestamp(),
      });

      // 축하 다이얼로그 표시
      _showUpgradeDialog(newDisplayGrade);

    } catch (e) {
      print('레벨 업그레이드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업그레이드 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUpgradeDialog(String newGrade) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF74512D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 40,
                  color: Color(0xFF74512D),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🎉 레벨 업!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF74512D),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                newGrade,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '축하합니다!\n새로운 레벨에 도달했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true); // 업데이트되었음을 알림
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '퍼스트 Lv.2 승급 신청',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '퍼스트 Lv.2는 운영자 승인이 필요합니다.\n신고 누적이 0이고 커뮤니티 활동이 건전해야 합니다.\n\n신청서를 제출하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitUpgradeRequest();
            },
            child: const Text('신청하기', style: TextStyle(color: Color(0xFF74512D))),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUpgradeRequest() async {
    // 운영자 승급 신청 로직 (추후 구현)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('승급 신청이 완료되었습니다. 운영자 검토 후 연락드리겠습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '레벨',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF74512D)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCurrentLevelCard(),
          const SizedBox(height: 20),
          _buildProgressSection(),
          const SizedBox(height: 20),
          if (canUpgrade) _buildUpgradeButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelCard() {
    final current = currentLevelInfo;
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getGradeColor(current['grade']).withOpacity(0.1),
            _getGradeColor(current['grade']).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getGradeColor(current['grade']).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _getGradeColor(current['grade']).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // 레벨 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getGradeColor(current['grade']),
                    _getGradeColor(current['grade']).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: _getGradeColor(current['grade']).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.diamond,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${current['grade']} ${current['level']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '현재 레벨',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
                      const SizedBox(height: 20),
          // 전체 진행도 프로그레스바
          _buildOverallProgress(current['grade'], current['level']),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress(String grade, String level) {
    final next = nextLevelInfo;
    if (next == null) {
      // 최고 레벨인 경우
      return Column(
        children: [
          Icon(Icons.emoji_events, size: 32, color: Colors.amber[600]),
          const SizedBox(height: 12),
          const Text(
            '최고 레벨 달성!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    final requirements = next['requirements'] as Map<String, int>;
    
    // 전체 필요량과 현재 진행량 계산
    int totalRequired = 0;
    int totalCurrent = 0;
    
    if (requirements['posts']! > 0) {
      totalRequired += requirements['posts']!;
      totalCurrent += currentPosts;
    }
    if (requirements['comments']! > 0) {
      totalRequired += requirements['comments']!;
      totalCurrent += currentComments;
    }
    if (requirements['likes']! > 0) {
      totalRequired += requirements['likes']!;
      totalCurrent += currentLikes;
    }
    if (requirements['points']! > 0) {
      totalRequired += requirements['points']!;
      totalCurrent += currentPoints;
    }
    if (requirements['followers']! > 0) {
      totalRequired += requirements['followers']!;
      totalCurrent += currentFollowers;
    }

    // 진행률 계산 (최대 100%)
    final progress = totalCurrent >= totalRequired ? 1.0 : totalCurrent / totalRequired;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getGradeColor(grade).withOpacity(0.8),
            _getGradeColor(grade).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getGradeColor(grade).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '전체 진행도',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 삼성멤버스 스타일 프로그레스바
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: _getGradeColor(grade),
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimationController,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress * _progressAnimationController.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
                    minHeight: 12,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalCurrent / $totalRequired 활동 완료',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (totalCurrent < totalRequired)
                Text(
                  '${totalRequired - totalCurrent}개 더 필요',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final next = nextLevelInfo;
    if (next == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
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
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.amber[600]),
            const SizedBox(height: 16),
            const Text(
              '최고 레벨 달성!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '축하합니다! 최고 레벨에 도달했습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final requirements = next['requirements'] as Map<String, int>;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getGradeColor(next['grade']).withOpacity(0.1),
                  _getGradeColor(next['grade']).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getGradeColor(next['grade']),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emoji_events, 
                    color: Colors.white, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 레벨까지',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getGradeColor(next['grade']),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${next['grade']} ${next['level']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 미션 목록
          if (requirements['posts']! > 0)
            _buildMissionItem('게시글 작성', currentPosts, requirements['posts']!, Icons.edit),
          if (requirements['comments']! > 0)
            _buildMissionItem('댓글 작성', currentComments, requirements['comments']!, Icons.comment),
          if (requirements['likes']! > 0)
            _buildMissionItem('좋아요하기', currentLikes, requirements['likes']!, Icons.favorite),
          if (requirements['points']! > 0)
            _buildMissionItem('땅콩 보유', currentPoints, requirements['points']!, Icons.monetization_on),
          if (requirements['followers']! > 0)
            _buildMissionItem('팔로워 확보', currentFollowers, requirements['followers']!, Icons.people),
        ],
      ),
    );
  }

  Widget _buildMissionItem(String title, int current, int target, IconData icon) {
    final progress = current >= target ? 1.0 : current / target;
    final isCompleted = current >= target;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCompleted 
            ? const Color(0xFF74512D).withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
              ? const Color(0xFF74512D).withOpacity(0.3)
              : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted 
                ? const Color(0xFF74512D).withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF74512D),
                            const Color(0xFF74512D).withOpacity(0.8),
                          ],
                        )
                      : null,
                  color: isCompleted ? null : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isCompleted
                      ? [
                          BoxShadow(
                            color: const Color(0xFF74512D).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  size: 24,
                  color: isCompleted ? Colors.white : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? const Color(0xFF74512D) : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$current',
                          style: TextStyle(
                            fontSize: 16,
                            color: isCompleted ? const Color(0xFF74512D) : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' / $target',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF74512D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 프로그레스 바
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimationController,
              builder: (context, child) {
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: LinearProgressIndicator(
                    value: progress * _progressAnimationController.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted 
                          ? const Color(0xFF74512D) 
                          : const Color(0xFF74512D).withOpacity(0.7),
                    ),
                    minHeight: 8,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 퍼센트 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% 완료',
                style: TextStyle(
                  fontSize: 13,
                  color: isCompleted ? const Color(0xFF74512D) : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isCompleted)
                Text(
                  '${target - current}개 더',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF74512D),
            Color(0xFF8B6332),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF74512D).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _upgradeLevel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.rocket_launch, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '레벨 업그레이드',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '🚀',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
} 