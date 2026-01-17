import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import '../widgets/image_viewer.dart';
import '../utils/image_compressor.dart';

class ContestPostEditScreen extends StatefulWidget {
  final String contestId;
  final String submissionId;
  final Map<String, dynamic> initialSubmission;

  const ContestPostEditScreen({
    Key? key,
    required this.contestId,
    required this.submissionId,
    required this.initialSubmission,
  }) : super(key: key);

  @override
  State<ContestPostEditScreen> createState() => _ContestPostEditScreenState();
}

class _ContestPostEditScreenState extends State<ContestPostEditScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImageFile;
  String? _existingImageUrl;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    // 기존 데이터 로드
    final contentHtml = widget.initialSubmission['contentHtml'] as String? ?? '';
    
    // HTML에서 텍스트 추출
    final textContent = contentHtml
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    
    _descriptionController.text = textContent;
    
    // 기존 이미지 URL 추출
    final RegExp imgTagRegex = RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false);
    final match = imgTagRegex.firstMatch(contentHtml);
    if (match != null) {
      _existingImageUrl = match.group(2);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _existingImageUrl = null; // 새 이미지 선택 시 기존 이미지 URL 초기화
        });
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '이미지 선택 중 오류가 발생했습니다: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _existingImageUrl = null;
    });
  }

  void _showImagePreview() {
    if (_selectedImageFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
            ),
            body: Center(
              child: Image.file(
                _selectedImageFile!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    } else if (_existingImageUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
            ),
            body: Center(
              child: Image.network(
                _existingImageUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }
  }

  // 게시 시 이미지를 Storage에 업로드하고 다운로드 URL 반환
  Future<String?> _uploadImageToStorage() async {
    if (_selectedImageFile == null) return _existingImageUrl;

    try {
      // 이미지 압축
      final compressedFile = await ImageCompressor.compressImage(_selectedImageFile!);
      if (compressedFile == null) {
        throw Exception('이미지 압축 실패');
      }

      // Firebase Storage 설정
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }

      // 파일명 생성
      final String ext = compressedFile.path.split('.').last;
      final String fileName = '${const Uuid().v4()}.$ext';
      
      // 최종 경로에 업로드
      final Reference ref = storage
          .ref()
          .child('contests')
          .child(widget.contestId)
          .child('submissions')
          .child(widget.submissionId)
          .child('images')
          .child(fileName);

      // 파일 업로드
      final UploadTask uploadTask = ref.putFile(compressedFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 실패: $e');
      throw Exception('이미지 업로드에 실패했습니다: $e');
    }
  }

  Future<void> _updatePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: '로그인이 필요합니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty && _selectedImageFile == null && _existingImageUrl == null) {
      Fluttertoast.showToast(
        msg: '설명 또는 이미지를 입력해주세요.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final displayName = userData['displayName'] ?? '익명';
      final photoURL = userData['photoURL'] ?? '';

      // 이미지 업로드
      String? imageUrl;
      if (_selectedImageFile != null || _existingImageUrl != null) {
        imageUrl = await _uploadImageToStorage();
      }

      // contentHtml 생성
      String contentHtml = description;
      if (imageUrl != null) {
        contentHtml = '<p>$description</p><img src="$imageUrl" />';
      } else if (description.isNotEmpty) {
        contentHtml = '<p>$description</p>';
      }

      // 제목 생성 (설명의 첫 30자 또는 "콘테스트 참여")
      final title = description.isNotEmpty 
          ? (description.length > 30 ? '${description.substring(0, 30)}...' : description)
          : '콘테스트 참여';

      // Firestore 업데이트
      final batch = FirebaseFirestore.instance.batch();

      // 1. contests/{contestId}/submissions/{submissionId} 업데이트
      final submissionRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId);

      batch.update(submissionRef, {
        'title': title,
        'contentHtml': contentHtml,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. users/{uid}/contests/{contestId} 업데이트
      final userContestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contests')
          .doc(widget.contestId);

      batch.update(userContestRef, {
        'submissionTitle': title,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 배치 실행
      await batch.commit();

      Fluttertoast.showToast(
        msg: '게시글이 수정되었습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // 성공 시 이전 화면으로 돌아가기
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      Fluttertoast.showToast(
        msg: '게시글 수정 실패: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '콘테스트 수정',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _updatePost,
            child: Text(
              '수정',
              style: TextStyle(
                color: _isUpdating ? Colors.grey : const Color(0xFF74512D),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지 업로드/미리보기 영역
              GestureDetector(
                onTap: (_selectedImageFile != null || _existingImageUrl != null) ? _showImagePreview : null,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _existingImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _existingImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '이미지를 불러올 수 없습니다',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '이미지 업로드',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 16),
              // 이미지 선택/변경/삭제 버튼
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(
                        (_selectedImageFile != null || _existingImageUrl != null) ? Icons.edit : Icons.add_photo_alternate,
                        color: const Color(0xFF74512D),
                      ),
                      label: Text(
                        (_selectedImageFile != null || _existingImageUrl != null) ? '이미지 변경' : '이미지 선택',
                        style: const TextStyle(color: Color(0xFF74512D)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF74512D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_selectedImageFile != null || _existingImageUrl != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        '삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
              if (_selectedImageFile != null || _existingImageUrl != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showImagePreview,
                  icon: const Icon(Icons.preview, color: Color(0xFF74512D)),
                  label: const Text(
                    '미리 보기',
                    style: TextStyle(color: Color(0xFF74512D)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // 설명 입력 필드
              const Text(
                '설명 추가',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: '설명 추가...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 100), // 하단 버튼을 위한 여백
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updatePost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF74512D),
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '수정',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
