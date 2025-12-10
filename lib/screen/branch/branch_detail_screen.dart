import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// 상품권 지점 리뷰 상세/작성 화면
/// 구조는 community_detail_screen.dart의 댓글 구조를 최대한 재사용하되,
///  - 컬렉션: branches/{branchId}/comments
///  - 사용자 로그: users/{uid}/branch_comments
/// 로 분리해서 관리한다.
class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchDetailScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _branch;

  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _isAddingComment = false;

  bool _isLoading = true;
  bool _isLoadingComments = true;
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];

  String _commentSortOrder = '등록순';

  @override
  void initState() {
    super.initState();
    _loadBranch();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadBranch() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .get();
      if (doc.exists) {
        setState(() {
          _branch = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoadingComments = true;
      });

      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .orderBy('createdAt', descending: _commentSortOrder == '최신순')
          .get();

      final list = snap.docs
          .map<Map<String, dynamic>>(
            (d) => <String, dynamic>{'commentId': d.id, ...d.data()},
          )
          .toList();

      setState(() {
        _comments = list;
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('브랜치 댓글 로드 오류: $e');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _submitComment() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    final content = _commentController.text.trim();
    if (content.isEmpty && _selectedImage == null) {
      Fluttertoast.showToast(msg: '내용을 입력하거나 이미지를 첨부해주세요.');
      return;
    }

    try {
      setState(() {
        _isAddingComment = true;
      });

      final commentRef = FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc();

      final now = DateTime.now();
      final Map<String, dynamic> data = <String, dynamic>{
        'authorId': _currentUser!.uid,
        'authorDisplayName': _currentUser!.displayName ?? '사용자',
        'authorPhotoURL': _currentUser!.photoURL,
        'contentHtml': '<p>$content</p>',
        'contentType': 'html',
        'attachments': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isHidden': false,
        'reportsCount': 0,
        'likesCount': 0,
        'plainText': content,
        'branchId': widget.branchId,
      };

      // (이미지 업로드는 후속으로 확장 가능; 여기서는 구조만 맞춰둔다)

      await commentRef.set(data);

      // 사용자 branch_comments 서브컬렉션에 기록
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('branch_comments')
          .doc(commentRef.id)
          .set(<String, dynamic>{
        'commentPath':
            'branches/${widget.branchId}/comments/${commentRef.id}',
        'branchId': widget.branchId,
        'branchName': widget.branchName,
        'contentHtml': data['contentHtml'],
        'contentType': data['contentType'],
        'attachments': data['attachments'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _removeSelectedImage();

      await _loadComments();

      setState(() {
        _isAddingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰가 등록되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('브랜치 댓글 등록 오류: $e');
      setState(() {
        _isAddingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리뷰 등록 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBranchHeader() {
    final Map<String, dynamic>? b = _branch;
    if (b == null) {
      return const SizedBox.shrink();
    }
    final String? address = b['address'] as String?;
    final String? phone = b['phone'] as String?;
    final Map<String, dynamic>? openingHours =
        b['openingHours'] is Map ? Map<String, dynamic>.from(b['openingHours']) : null;
    final String? notice = b['notice'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Icon(Icons.storefront_outlined,
                  size: 20, color: Color(0xFF74512D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.branchName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(phone,
                    style: const TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
          if (openingHours != null && openingHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '영업시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            for (final entry in openingHours.entries)
              Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
          ],
          if (notice != null && notice.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '안내',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              notice,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final String displayName =
        (comment['authorDisplayName'] as String?) ?? '익명';
    final String content =
        (comment['plainText'] as String?) ?? '내용 없음';
    final Timestamp? createdAtTs = comment['createdAt'] as Timestamp?;
    final DateTime createdAt =
        createdAtTs?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0x1174512D),
                child: Icon(Icons.person, size: 16, color: Color(0xFF74512D)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                DateFormat('yyyy.MM.dd').format(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (_isLoadingComments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '아직 등록된 리뷰가 없습니다.\n첫 리뷰를 남겨주세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _removeSelectedImage,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined,
                      color: Color(0xFF74512D)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: '지점 이용 후기를 남겨주세요.',
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _isAddingComment ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isAddingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '리뷰 등록',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: Text(widget.branchName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBranchHeader(),
                      const SizedBox(height: 16),
                      const Text(
                        '리뷰',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCommentsSection(),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildCommentInput(),
                ),
              ],
            ),
    );
  }
}


