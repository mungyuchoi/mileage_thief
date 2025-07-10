import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mileage_thief/screen/user_profile_screen.dart';

import 'my_page_screen.dart'; // Added import for UserProfileScreen

class FollowerListScreen extends StatefulWidget {
  final String? userUid; // null이면 본인, 있으면 해당 유저
  final String? userName; // 상단 타이틀용
  const FollowerListScreen({Key? key, this.userUid, this.userName}) : super(key: key);

  @override
  State<FollowerListScreen> createState() => _FollowerListScreenState();
}

class _FollowerListScreenState extends State<FollowerListScreen> {
  List<Map<String, dynamic>> followers = [];
  Set<String> followingUids = {};
  bool isLoading = true;
  bool isMyProfile = true; // 본인 프로필인지 여부

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    isMyProfile = widget.userUid == null || widget.userUid == currentUser?.uid;
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // 조회할 대상 유저 (본인이거나 다른 유저)
    final targetUid = widget.userUid ?? user.uid;
    
    setState(() { isLoading = true; });
    try {
      // 1. 대상 유저의 followers uid 리스트
      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .get();
      final followerUids = followersSnap.docs.map((doc) => doc.id).toList();

      // 2. 내가 팔로우하고 있는 uid set (팔로우 버튼 상태 표시용)
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();
      followingUids = followingSnap.docs.map((doc) => doc.id).toSet();

      // 3. 각 팔로워의 프로필 정보
      List<Map<String, dynamic>> followerList = [];
      for (final uid in followerUids) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          followerList.add({
            'uid': uid,
            'photoURL': data['photoURL'] ?? '',
            'displayName': data['displayName'] ?? '알 수 없음',
            'displayGrade': data['displayGrade'] ?? '',
          });
        }
      }
      setState(() {
        followers = followerList;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  Future<void> _toggleFollow(String targetUid, bool isFollowing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    
    if (isFollowing) {
      // 언팔로우
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
      
      setState(() { followingUids.remove(targetUid); });
    } else {
      // 팔로우
      // 1. 내 following 서브컬렉션에 추가
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      // 2. 상대방 followers 서브컬렉션에 추가
      batch.set(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(user.uid), {
        'followedAt': FieldValue.serverTimestamp()
      });
      
      // 3. 내 followingCount 증가
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid), {
        'followingCount': FieldValue.increment(1)
      });
      
      // 4. 상대방 followerCount 증가
      batch.update(FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid), {
        'followerCount': FieldValue.increment(1)
      });
      
      setState(() { followingUids.add(targetUid); });
    }
    
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = isMyProfile ? '팔로워' : '${widget.userName ?? "사용자"}님의 팔로워';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('$displayTitle (${followers.length})', style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (followers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 18),
                      Text(
                        isMyProfile ? '아직 팔로워가 없습니다' : '아직 팔로워가 없습니다',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    final followerUid = follower['uid'];
                    final isFollowing = followingUids.contains(followerUid);
                    final isMyself = FirebaseAuth.instance.currentUser?.uid == followerUid;
                    
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
                                  if (followerUid == currentUid) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MyPageScreen()),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => UserProfileScreen(userUid: followerUid)),
                                    );
                                  }
                                },
                                behavior: HitTestBehavior.translucent,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: (follower['photoURL'] as String).isNotEmpty
                                          ? NetworkImage(follower['photoURL'])
                                          : null,
                                      child: (follower['photoURL'] as String).isEmpty
                                          ? const Icon(Icons.person, color: Colors.grey, size: 28)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          follower['displayName'],
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
                                          follower['displayGrade'],
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
                            if (!isMyself)
                              GestureDetector(
                                onTap: () => _toggleFollow(followerUid, isFollowing),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8), // 버튼과 프로필 사이 여백
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