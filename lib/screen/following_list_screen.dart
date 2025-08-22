import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mileage_thief/screen/user_profile_screen.dart';

import 'my_page_screen.dart';

class FollowingListScreen extends StatefulWidget {
  final String? userUid; // null이면 본인, 있으면 해당 유저
  final String? userName; // 상단 타이틀용
  const FollowingListScreen({Key? key, this.userUid, this.userName}) : super(key: key);

  @override
  State<FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  List<Map<String, dynamic>> following = [];
  Set<String> myFollowingUids = {}; // 내가 팔로우하는 유저들
  bool isLoading = true;
  bool isMyProfile = true; // 본인 프로필인지 여부

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    isMyProfile = widget.userUid == null || widget.userUid == currentUser?.uid;
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // 조회할 대상 유저 (본인이거나 다른 유저)
    final targetUid = widget.userUid ?? user.uid;
    
    setState(() { isLoading = true; });
    try {
      // 1. 대상 유저의 following uid 리스트
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('following')
          .get();
      final followingUids = followingSnap.docs.map((doc) => doc.id).toList();

      // 2. 내가 팔로우하고 있는 uid set (팔로우 버튼 상태 표시용)
      final myFollowingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();
      myFollowingUids = myFollowingSnap.docs.map((doc) => doc.id).toSet();

      // 3. 실제 팔로잉 수와 users 문서의 followingCount 동기화
      await _syncFollowingCount(targetUid, followingUids.length);

      // 4. 각 팔로잉의 프로필 정보
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

  /// 실제 팔로잉 수와 users 문서의 followingCount를 동기화
  Future<void> _syncFollowingCount(String targetUid, int actualCount) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final currentCount = userData['followingCount'] ?? 0;
        
        // 카운트가 다르면 실제 값으로 업데이트
        if (currentCount != actualCount) {
          print('팔로잉 카운트 동기화: $currentCount -> $actualCount (uid: $targetUid)');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(targetUid)
              .update({
            'followingCount': actualCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('팔로잉 카운트 동기화 오류: $e');
      // 동기화 실패해도 메인 기능에는 영향 없음
    }
  }

  Future<void> _unfollow(String targetUid, String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final shouldUnfollow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Text(
          '$displayName 님 팔로우를 취소할까요?',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('팔로우 취소', style: TextStyle(color: Colors.black)),
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
        myFollowingUids.remove(targetUid);
      });
    }
  }

  Future<void> _toggleFollow(String targetUid, bool isFollowing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    
    if (isFollowing) {
      // 언팔로우
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid));
      
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(user.uid));
      
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid), {
        'followingCount': FieldValue.increment(-1)
      });
      
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid), {
        'followerCount': FieldValue.increment(-1)
      });
      
      setState(() { myFollowingUids.remove(targetUid); });
    } else {
      // 팔로우
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(user.uid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid), {
        'followingCount': FieldValue.increment(1)
      });
      
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid), {
        'followerCount': FieldValue.increment(1)
      });
      
      setState(() { myFollowingUids.add(targetUid); });
    }
    
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = isMyProfile ? '팔로잉' : '${widget.userName ?? "사용자"}님의 팔로잉';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('$displayTitle (${following.length})', style: const TextStyle(color: Colors.black)),
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
                      Text(
                        isMyProfile ? '아직 팔로잉한 사용자가 없습니다' : '아직 팔로잉한 사용자가 없습니다',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: following.length,
                  itemBuilder: (context, index) {
                    final user = following[index];
                    final userUid = user['uid'];
                    final isFollowing = myFollowingUids.contains(userUid);
                    final isMyself = FirebaseAuth.instance.currentUser?.uid == userUid;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                  if (userUid == currentUid) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MyPageScreen()),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => UserProfileScreen(userUid: userUid)),
                                    );
                                  }
                                },
                                behavior: HitTestBehavior.translucent,
                                child: Row(
                                  children: [
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
                                    Column(
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
                                  ],
                                ),
                              ),
                            ),
                            // 팔로우/언팔로우 버튼 (항상 오른쪽 끝)
                            if (isMyProfile && !isMyself)
                              GestureDetector(
                                onTap: () => _unfollow(userUid, user['displayName']),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
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
                              )
                            else if (!isMyProfile && !isMyself)
                              GestureDetector(
                                onTap: () => _toggleFollow(userUid, isFollowing),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isFollowing ? Colors.grey[200] : const Color(0xFF74512D),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    isFollowing ? '팔로잉' : '팔로우',
                                    style: TextStyle(
                                      color: isFollowing ? Colors.black : Colors.white,
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