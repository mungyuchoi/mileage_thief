import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/deal_notification_service.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../utils/deal_image_utils.dart';
import 'deal_notification_register_screen.dart';

class DealNotificationScreen extends StatefulWidget {
  const DealNotificationScreen({super.key});

  @override
  State<DealNotificationScreen> createState() => _DealNotificationScreenState();
}

class _DealNotificationScreenState extends State<DealNotificationScreen> {
  int _userPeanutCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPeanutCount();
  }

  Future<void> _loadUserPeanutCount() async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      try {
        final userData = await UserService.getUserFromFirestoreWithLimit(currentUser.uid);
        setState(() {
          _userPeanutCount = userData?['peanutCount'] ?? 0;
        });
      } catch (e) {
        print('땅콩 개수 로드 오류: $e');
      }
    }
  }

  Future<void> _handleFabPressed() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      Fluttertoast.showToast(
        msg: "로그인이 필요합니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DealNotificationRegisterScreen(),
      ),
    ).then((_) {
      _loadUserPeanutCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('특가 알림'),
          backgroundColor: ColorConstants.milecatchBrown,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                '로그인이 필요합니다',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('특가 알림'),
        backgroundColor: ColorConstants.milecatchBrown,
        foregroundColor: Colors.white,
      ),
      body: _buildNotificationsList(currentUser.uid),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleFabPressed,
        backgroundColor: ColorConstants.milecatchBrown,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNotificationsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: DealNotificationService.getDealSubscriptionsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: ColorConstants.milecatchBrown,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  '등록된 특가 알림이 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '+ 버튼을 눌러 알림을 등록하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSubscriptionCard(data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> data, String docId) {
    final region = data['region'] ?? '기타';
    final airports = List<String>.from(data['airports'] ?? []);
    final maxPrice = data['maxPrice'] ?? 0;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    final originAirport = data['originAirport'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isExpiringSoon = expiresAt != null &&
        expiresAt.isAfter(DateTime.now()) &&
        expiresAt.difference(DateTime.now()).inDays <= 3;

    final dateFormatter = DateFormat('yyyy.MM.dd');

    // 대표 국가 코드 찾기 (첫 번째 공항의 국가)
    String? mainCountryCode;
    if (airports.isNotEmpty) {
      // 간단한 매핑 (실제로는 DealNotificationService에서 가져와야 함)
      mainCountryCode = _getCountryCodeByAirport(airports.first);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                // 국기 아이콘
                if (mainCountryCode != null)
                  DealImageUtils.getCountryFlag(
                    mainCountryCode,
                    width: 24,
                    height: 24,
                  ),
                if (mainCountryCode != null) const SizedBox(width: 8),
                // 지역명
                Expanded(
                  child: Text(
                    region,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 만료 상태
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Text(
                      '만료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      '곧 만료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 도시 목록
            Text(
              airports.isEmpty
                  ? '도착지 미선택'
                  : airports.length == 1
                      ? airports.first
                      : '${airports.take(3).join(', ')}${airports.length > 3 ? ' 등 ${airports.length}개' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            // 가격 조건
            Row(
              children: [
                const Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${NumberFormat('#,###').format(maxPrice)}원 이하',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (originAirport != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.flight_takeoff,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '출발지: $originAirport',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // 만료일
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '만료일: ${expiresAt != null ? dateFormatter.format(expiresAt) : '미정'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpiringSoon ? Colors.orange : Colors.grey[600],
                    fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isExpired)
                  TextButton(
                    onPressed: () => _showExtendDialog(docId, expiresAt),
                    child: const Text('연장'),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showDeleteDialog(docId, region, maxPrice),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _getCountryCodeByAirport(String airportCode) {
    // 간단한 매핑 (실제로는 더 정확한 데이터가 필요)
    final mapping = {
      'LHR': 'GB', 'CDG': 'FR', 'FCO': 'IT', 'BCN': 'ES', 'MAD': 'ES',
      'ZRH': 'CH', 'CPH': 'DK', 'FRA': 'DE', 'HEL': 'FI', 'IST': 'TR',
      'ATH': 'GR', 'LIS': 'PT', 'MXP': 'IT',
      'NRT': 'JP', 'HND': 'JP', 'KIX': 'JP', 'FUK': 'JP', 'OKA': 'JP',
      'BKK': 'TH', 'DMK': 'TH', 'SIN': 'SG', 'HKG': 'HK', 'TPE': 'TW',
      'SYD': 'AU', 'BNE': 'AU', 'JFK': 'US', 'LAX': 'US', 'HNL': 'US',
    };
    return mapping[airportCode];
  }

  void _showExtendDialog(String subscriptionId, DateTime? currentExpiresAt) {
    int selectedDays = 7;
    int extensionPeanuts = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          extensionPeanuts = DealNotificationService.calculatePeanuts(
            airportCount: 1, // 연장은 기간만 계산
            days: selectedDays,
            hasOriginAirport: false,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '알림 기간 연장',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentExpiresAt != null) ...[
                  Text(
                    '현재 만료일: ${DateFormat('yyyy.MM.dd').format(currentExpiresAt)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  '연장 기간 선택:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildExtendPeriodButton(
                        context,
                        setDialogState,
                        7,
                        '7일',
                        selectedDays,
                        (days) => selectedDays = days,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExtendPeriodButton(
                        context,
                        setDialogState,
                        14,
                        '14일',
                        selectedDays,
                        (days) => selectedDays = days,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExtendPeriodButton(
                        context,
                        setDialogState,
                        30,
                        '30일',
                        selectedDays,
                        (days) => selectedDays = days,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '소모 땅콩:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        '$extensionPeanuts개',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: extensionPeanuts > _userPeanutCount
                              ? Colors.red
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (extensionPeanuts > _userPeanutCount) ...[
                  const SizedBox(height: 8),
                  Text(
                    '땅콩이 부족합니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: extensionPeanuts > _userPeanutCount
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _extendSubscription(subscriptionId, selectedDays, extensionPeanuts);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConstants.milecatchBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  '연장하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExtendPeriodButton(
    BuildContext context,
    StateSetter setDialogState,
    int days,
    String label,
    int selectedDays,
    Function(int) onSelect,
  ) {
    final isSelected = selectedDays == days;
    return InkWell(
      onTap: () {
        onSelect(days);
        setDialogState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorConstants.milecatchBrown
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? ColorConstants.milecatchBrown
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String subscriptionId, String region, int maxPrice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '알림 삭제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이 알림을 삭제하시겠습니까?',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,###').format(maxPrice)}원 이하',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSubscription(subscriptionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              '삭제',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _extendSubscription(String subscriptionId, int days, int peanuts) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: ColorConstants.milecatchBrown,
          ),
        ),
      );

      await DealNotificationService.extendDealSubscription(
        uid: currentUser.uid,
        subscriptionId: subscriptionId,
        days: days,
        peanutUsed: peanuts,
      );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('알림이 ${days}일 연장되었습니다! (땅콩 $peanuts개 소모)'),
          backgroundColor: ColorConstants.milecatchBrown,
        ),
      );

      _loadUserPeanutCount();
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연장 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSubscription(String subscriptionId) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: ColorConstants.milecatchBrown,
          ),
        ),
      );

      await DealNotificationService.deleteDealSubscription(
        currentUser.uid,
        subscriptionId,
      );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림이 삭제되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

