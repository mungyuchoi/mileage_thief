import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/ad_removal_utils.dart';
import '../services/user_service.dart';

class AdRemovalButton extends StatelessWidget {
  final VoidCallback onAdRemovalActivated;
  
  const AdRemovalButton({
    Key? key,
    required this.onAdRemovalActivated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.brown.shade600,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.brown.shade600,
              width: 2,
            ),
            color: Colors.white, // 흰색 배경으로 변경
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showAdRemovalDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: Colors.brown.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '24시간 광고 없애기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.brown.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.brown.shade400),
                      ),
                      child: Text(
                        '땅콩 30개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.brown.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAdRemovalDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime expiryTime = now.add(Duration(hours: 24));
    String formattedTime = '${expiryTime.year}년 ${expiryTime.month}월 ${expiryTime.day}일 ${expiryTime.hour.toString().padLeft(2, '0')}:${expiryTime.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.visibility_off,
                color: Colors.brown.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '광고 없애기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '땅콩이 30개 차감됩니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.hide_source, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '광고 배너가 삭제됩니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$formattedTime까지\n광고 없애기가 적용됩니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await _handleAdRemovalConfirm(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAdRemovalConfirm(BuildContext context) async {
    try {
      // 현재 사용자의 땅콩 개수 확인
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pop();
        Fluttertoast.showToast(
          msg: "로그인이 필요합니다!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final userData = await UserService.getUserFromFirestore(currentUser.uid);
      final currentPeanuts = userData?['peanutCount'] ?? 0;

      if (currentPeanuts < 30) {
        Navigator.of(context).pop();
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

      Navigator.of(context).pop();
      
      Fluttertoast.showToast(
        msg: "광고없애기가 적용되었습니다!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // 부모 위젯에 광고 없애기 활성화 알림
      onAdRemovalActivated();

    } catch (e) {
      Navigator.of(context).pop();
      Fluttertoast.showToast(
        msg: "오류가 발생했습니다. 다시 시도해주세요.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
}
