import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowerListScreen extends StatefulWidget {
  const FollowerListScreen({Key? key}) : super(key: key);

  @override
  State<FollowerListScreen> createState() => _FollowerListScreenState();
}

class _FollowerListScreenState extends State<FollowerListScreen> {
  List<Map<String, dynamic>> followers = [];
  Set<String> followingUids = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { isLoading = true; });
    try {
      // 1. followers uid 리스트
      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('followers')
          .get();
      final followerUids = followersSnap.docs.map((doc) => doc.id).toList();

      // 2. following uid set
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
    if (isFollowing) {
      // 언팔로우
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid)
          .delete();
      setState(() { followingUids.remove(targetUid); });
    } else {
      // 팔로우
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUid)
          .set({'followedAt': FieldValue.serverTimestamp()});
      setState(() { followingUids.add(targetUid); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('팔로워 (${followers.length})', style: const TextStyle(color: Colors.black)),
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
                      const Text(
                        '아직 팔로워가 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    final isFollowing = followingUids.contains(follower['uid']);
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
                              backgroundImage: (follower['photoURL'] as String).isNotEmpty
                                  ? NetworkImage(follower['photoURL'])
                                  : null,
                              child: (follower['photoURL'] as String).isEmpty
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
                            ),
                            // 팔로우/팔로잉 버튼
                            GestureDetector(
                              onTap: () => _toggleFollow(follower['uid'], isFollowing),
                              child: Container(
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