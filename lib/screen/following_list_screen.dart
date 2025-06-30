import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingListScreen extends StatefulWidget {
  const FollowingListScreen({Key? key}) : super(key: key);

  @override
  State<FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  List<Map<String, dynamic>> following = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { isLoading = true; });
    try {
      // 1. following uid 리스트
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();
      final followingUids = followingSnap.docs.map((doc) => doc.id).toList();

      // 2. 각 팔로잉의 프로필 정보
      List<Map<String, dynamic>> followingList = [];
      for (final uid in followingUids) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          followingList.add({
            'uid': uid,
            'photoURL': data['photoURL'] ?? '',
            'displayName': data['displayName'] ?? '알 수 없음',
            'displayGrade': data['displayGrade'] ?? '',
          });
        }
      }
      setState(() {
        following = followingList;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  Future<void> _unfollow(String targetUid, String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final shouldUnfollow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('$displayName 님 팔로우를 취소할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('팔로우 취소'),
          ),
        ],
      ),
    );
    if (shouldUnfollow == true) {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. 내 following 서브컬렉션에서 제거
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid));
      
      // 2. 상대방 followers 서브컬렉션에서 제거
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(user.uid));
      
      // 3. 내 followingCount 감소
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid), {
        'followingCount': FieldValue.increment(-1)
      });
      
      // 4. 상대방 followerCount 감소
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid), {
        'followerCount': FieldValue.increment(-1)
      });
      
      await batch.commit();
      
      setState(() {
        following.removeWhere((f) => f['uid'] == targetUid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('팔로잉 (${following.length})', style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (following.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 18),
                      const Text(
                        '아직 팔로잉한 사용자가 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: following.length,
                  itemBuilder: (context, index) {
                    final user = following[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // 프로필 이미지
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: (user['photoURL'] as String).isNotEmpty
                                  ? NetworkImage(user['photoURL'])
                                  : null,
                              child: (user['photoURL'] as String).isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey, size: 28)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            // 닉네임/레벨
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['displayName'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user['displayGrade'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // 팔로잉 버튼
                            GestureDetector(
                              onTap: () => _unfollow(user['uid'], user['displayName']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Text(
                                  '팔로잉',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
    );
  }
} 