import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import 'package:lottie/lottie.dart';

class SkyEffectScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const SkyEffectScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<SkyEffectScreen> createState() => _SkyEffectScreenState();
}

class _SkyEffectScreenState extends State<SkyEffectScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _allEffects = [];
  List<String> _ownedEffects = [];
  String? _currentEffect;
  String? _previewEffectId; // 미리보기용 effectId
  String? _originalEffectId;

  @override
  void initState() {
    super.initState();
    _loadEffects();
    _previewEffectId = null;
    _originalEffectId = widget.userProfile['currentSkyEffect'];
  }

  Future<void> _loadEffects() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 데이터 로드
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _ownedEffects = List<String>.from(userData['ownedEffects'] ?? []);
        _currentEffect = userData['currentSkyEffect'];
      }

      // Firestore에서 이펙트 데이터 로드
      _allEffects = await _loadEffectsFromFirestore();
      
    } catch (e) {
      print('이펙트 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Firestore에서 이펙트 데이터 가져오기
  Future<List<Map<String, dynamic>>> _loadEffectsFromFirestore() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('effects')
          .orderBy('grade')
          .orderBy('level')
          .orderBy('id')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // previewColor는 등급과 레벨에 따라 동적으로 생성
        data['previewColor'] = _getPreviewColor(data['grade'], data['level']);
        return data;
      }).toList();
    } catch (e) {
      print('이펙트 로딩 오류: $e');
      return [];
    }
  }

  // 등급과 레벨에 따른 미리보기 색상 생성
  Color _getPreviewColor(String grade, int level) {
    switch (grade) {
      case '이코노미':
        switch (level) {
          case 1: return Colors.yellow[300]!;
          case 2: return Colors.orange[300]!;
          default: return Colors.grey[300]!;
        }
      case '비즈니스':
        switch (level) {
          case 1: return Colors.blue[400]!;
          case 2: return Colors.indigo[400]!;
          default: return Colors.blue[300]!;
        }
      case '퍼스트':
        switch (level) {
          case 1: return Colors.red[400]!;
          case 2: return Colors.purple[400]!;
          default: return Colors.red[300]!;
        }
      default:
        return Colors.grey[300]!;
    }
  }

  // 사용자의 현재 레벨 정보 파싱
  Map<String, dynamic> get currentLevelInfo {
    final displayGrade = widget.userProfile['displayGrade'] ?? '이코노미 Lv.1';
    final parts = displayGrade.split(' ');
    final grade = parts[0];
    final level = int.tryParse(parts.length > 1 ? parts[1].replaceAll('Lv.', '') : '1') ?? 1;
    return {'grade': grade, 'level': level};
  }

  // 이펙트 구매 가능 여부 확인
  bool _canPurchaseEffect(Map<String, dynamic> effect) {
    final currentLevel = currentLevelInfo;
    final currentGrade = currentLevel['grade'];
    final currentLv = currentLevel['level'] as int;
    
    final effectGrade = effect['grade'];
    final effectLevel = effect['level'] as int;

    // 등급 순서 확인
    final gradeOrder = {'이코노미': 1, '비즈니스': 2, '퍼스트': 3};
    final currentGradeNum = gradeOrder[currentGrade] ?? 1;
    final effectGradeNum = gradeOrder[effectGrade] ?? 1;

    if (currentGradeNum > effectGradeNum) return true;
    if (currentGradeNum == effectGradeNum && currentLv >= effectLevel) return true;
    
    return false;
  }

  // 이펙트 구매
  Future<void> _purchaseEffect(Map<String, dynamic> effect) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final price = effect['price'] as int;
    final currentPeanutCount = widget.userProfile['peanutCount'] ?? 0;

    if (currentPeanutCount < price) {
      _showInsufficientPointsDialog(price, currentPeanutCount);
      return;
    }

    final confirmed = await _showPurchaseConfirmDialog(effect);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) return;
        
        final userData = userDoc.data()!;
        final currentPeanutCount = userData['peanutCount'] ?? 0;
        final ownedEffects = List<String>.from(userData['ownedEffects'] ?? []);
        
        if (currentPeanutCount < price) {
          throw Exception('땅콩이 부족합니다');
        }
        
        ownedEffects.add(effect['id']);
        
        transaction.update(userRef, {
          'peanutCount': currentPeanutCount - price,
          'ownedEffects': ownedEffects,
        });
      });

      // 로컬 상태 업데이트
      setState(() {
        _ownedEffects.add(effect['id']);
        widget.userProfile['peanutCount'] = (widget.userProfile['peanutCount'] ?? 0) - price;
      });

      _showPurchaseSuccessDialog(effect);
      
    } catch (e) {
      print('구매 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구매 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 이펙트 착용/해제
  Future<void> _equipEffect(String effectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 현재 착용 중인 이펙트와 같으면 착용 해제
      final newEffectId = (_currentEffect == effectId) ? null : effectId;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'currentSkyEffect': newEffectId});

      setState(() {
        _currentEffect = newEffectId;
        _previewEffectId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newEffectId == null ? '이펙트가 해제되었습니다!' : '이펙트가 적용되었습니다!'),
        ),
      );
      
    } catch (e) {
      print('착용/해제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이펙트 변경 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showPurchaseConfirmDialog(Map<String, dynamic> effect) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('이펙트 구매', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${effect['name']} 이펙트를 구매하시겠습니까?'),
            const SizedBox(height: 8),
            Text(
              '가격: ${effect['price']}땅콩',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF74512D)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF74512D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('구매'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showInsufficientPointsDialog(int requiredPoints, int currentPoints) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('땅콩 부족', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('땅콩이 부족합니다.'),
            const SizedBox(height: 8),
            Text('필요: ${requiredPoints}땅콩'),
            Text('보유: ${currentPoints}땅콩'),
            Text('부족: ${requiredPoints - currentPoints}땅콩', 
                 style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFF74512D))),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSuccessDialog(Map<String, dynamic> effect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🎉 구매 완료!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('${effect['name']} 이펙트를 구매했습니다!\n이제 착용할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFF74512D))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('스카이 이펙트', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _isLoading ? 
          const Center(child: CircularProgressIndicator(color: Color(0xFF74512D))) :
          _buildContent(),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final skyEffect = userDoc.data()?['currentSkyEffect'];
    // 변경된 경우에만 업데이트
    if (skyEffect == _originalEffectId) return true;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF74512D))),
    );

    // 1. 내가 쓴 게시글 일괄 업데이트
    final posts = await FirebaseFirestore.instance
        .collectionGroup('posts')
        .where('author.uid', isEqualTo: user.uid)
        .get();
    for (final doc in posts.docs) {
      await doc.reference.update({'author.currentSkyEffect': skyEffect});
    }

    // 2. 내가 쓴 댓글 일괄 업데이트
    final comments = await FirebaseFirestore.instance
        .collectionGroup('comments')
        .where('uid', isEqualTo: user.uid)
        .get();
    for (final doc in comments.docs) {
      await doc.reference.update({'currentSkyEffect': skyEffect});
    }

    // 로딩 다이얼로그 닫기
    Navigator.of(context).pop();
    return true;
  }

  Widget _buildContent() {
    // 레벨별로 이펙트 그룹화
    final groupedEffects = <String, List<Map<String, dynamic>>>{};
    
    for (final effect in _allEffects) {
      final key = '${effect['grade']} Lv.${effect['level']}';
      groupedEffects.putIfAbsent(key, () => []);
      groupedEffects[key]!.add(effect);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // 미리보기 영역
          _buildCurrentEffectPreview(),
          // 내가 소유한 이펙트 horizontal 리스트
          if (_ownedEffects.isNotEmpty) _buildOwnedEffectsBar(),
          const SizedBox(height: 16),
          
          // 레벨별 이펙트 목록
          ...groupedEffects.entries.map((entry) => _buildLevelSection(entry.key, entry.value)),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCurrentEffectPreview() {
    // 미리보기용 effectId 우선, 없으면 현재 착용 이펙트
    final effectId = _previewEffectId ?? _currentEffect;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            '미리보기',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 프로필 이미지
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.userProfile['photoURL'] != null &&
                          widget.userProfile['photoURL'].toString().isNotEmpty
                      ? NetworkImage(widget.userProfile['photoURL'])
                      : null,
                  child: widget.userProfile['photoURL'] == null ||
                          widget.userProfile['photoURL'].toString().isEmpty
                      ? const Icon(Icons.person, size: 32, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 8),
                // Lottie 이펙트
                _buildPreviewLottie(effectId),
                const SizedBox(width: 8),
                // 닉네임(텍스트)
                Flexible(
                  child: Text(
                    widget.userProfile['displayName'] ?? '사용자',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLottie(String? effectId) {
    if (effectId == null) {
      return const SizedBox(width: 60, height: 40);
    }
    final effect = _allEffects.firstWhere(
      (e) => e['id'] == effectId,
      orElse: () => {},
    );
    if (effect.isEmpty || effect['lottieUrl'] == null) {
      return const SizedBox(width: 60, height: 40);
    }
    return SizedBox(
      width: 60,
      height: 40,
      child: Lottie.network(
        effect['lottieUrl'],
        width: 60,
        height: 40,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
        // backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildOwnedEffectsBar() {
    final owned = _allEffects.where((e) => _ownedEffects.contains(e['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            '내가 보유한 스카이 이펙트',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
        ),
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: owned.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final effect = owned[idx];
              final isEquipped = _currentEffect == effect['id'];
              return GestureDetector(
                onTap: () async {
                  await _equipEffect(effect['id']);
                  if (mounted) Navigator.pop(context, true);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isEquipped ? Border.all(color: const Color(0xFF74512D), width: 2) : null,
                      ),
                      child: effect['lottieUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Lottie.network(
                                effect['lottieUrl'],
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                repeat: true,
                                animate: true,
                                // backgroundColor: Colors.transparent,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, color: Color(0xFF74512D)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          effect['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isEquipped) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Color(0xFF74512D).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '착용중',
                              style: TextStyle(fontSize: 8, color: Color(0xFF74512D), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLevelSection(String levelTitle, List<Map<String, dynamic>> effects) {
    final canAccess = _canAccessLevel(levelTitle);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레벨 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: canAccess ? const Color(0xFF74512D).withOpacity(0.1) : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canAccess ? Icons.lock_open : Icons.lock,
                  color: canAccess ? const Color(0xFF74512D) : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  levelTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canAccess ? const Color(0xFF74512D) : Colors.grey,
                  ),
                ),
                if (!canAccess) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '잠금',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 이펙트 그리드
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: effects.length,
              itemBuilder: (context, index) => _buildEffectCard(effects[index], canAccess),
            ),
          ),
        ],
      ),
    );
  }

  bool _canAccessLevel(String levelTitle) {
    final currentLevel = currentLevelInfo;
    final currentGrade = currentLevel['grade'];
    final currentLv = currentLevel['level'] as int;
    
    // 레벨 타이틀에서 등급과 레벨 추출
    final parts = levelTitle.split(' Lv.');
    if (parts.length != 2) return false;
    
    final grade = parts[0];
    final level = int.tryParse(parts[1]) ?? 1;
    
    // 등급 순서 확인
    final gradeOrder = {'이코노미': 1, '비즈니스': 2, '퍼스트': 3};
    final currentGradeNum = gradeOrder[currentGrade] ?? 1;
    final targetGradeNum = gradeOrder[grade] ?? 1;

    if (currentGradeNum > targetGradeNum) return true;
    if (currentGradeNum == targetGradeNum && currentLv >= level) return true;
    
    return false;
  }

  Widget _buildEffectCard(Map<String, dynamic> effect, bool canAccess) {
    final isOwned = _ownedEffects.contains(effect['id']);
    final isEquipped = _currentEffect == effect['id'];
    final effectColor = effect['previewColor'] as Color?;
    return Container(
      decoration: BoxDecoration(
        color: isEquipped ? const Color(0xFF74512D).withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEquipped 
              ? const Color(0xFF74512D) 
              : canAccess 
                  ? Colors.grey[300]! 
                  : Colors.grey[200]!,
          width: isEquipped ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lottie 미리보기 (크기 확대)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(top: 8, bottom: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: canAccess && effect['lottieUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Lottie.network(
                      effect['lottieUrl'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      repeat: true,
                      animate: true,
                      // backgroundColor: Colors.transparent,
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: canAccess 
                          ? (effectColor ?? const Color(0xFF74512D))
                          : Colors.grey[400],
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          // 이펙트 이름
          Text(
            effect['name'],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: canAccess ? Colors.black87 : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 가격
          Text(
            '${effect['price']}땅콩',
            style: TextStyle(
              fontSize: 9,
              color: canAccess ? const Color(0xFF74512D) : Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          // 버튼 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF74512D),
                    side: const BorderSide(color: Color(0xFF74512D)),
                    minimumSize: const Size(0, 22),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _previewEffectId = effect['id'];
                    });
                  },
                  child: const Text('미리보기', style: TextStyle(fontSize: 9)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAccess && !isOwned ? const Color(0xFF74512D) : Colors.grey[300],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 22),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: canAccess && !isOwned
                      ? () => _purchaseEffect(effect)
                      : null,
                  child: const Text('구매하기', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _onEffectTap(Map<String, dynamic> effect, bool isOwned, bool isEquipped) {
    if (isEquipped) {
      // 착용 중인 이펙트를 다시 탭하면 해제
      _equipEffect(effect['id']);
    } else if (isOwned) {
      // 보유 중이지만 미착용 -> 착용
      _equipEffect(effect['id']);
    } else {
      // 미보유 -> 구매
      _purchaseEffect(effect);
    }
  }
} 