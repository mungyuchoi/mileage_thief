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

class ContestPostCreateScreen extends StatefulWidget {
  final String contestId;
  final String contestTitle;

  const ContestPostCreateScreen({
    Key? key,
    required this.contestId,
    required this.contestTitle,
  }) : super(key: key);

  @override
  State<ContestPostCreateScreen> createState() => _ContestPostCreateScreenState();
}

class _ContestPostCreateScreenState extends State<ContestPostCreateScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImageFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isPosting = false;

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
          _uploadedImageUrl = null; // 새 이미지 선택 시 기존 URL 초기화
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

  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) return;

    setState(() {
      _isUploading = true;
    });

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
      
      // 임시 경로에 업로드 (게시 시 최종 경로로 이동)
      final Reference tempRef = storage
          .ref()
          .child('contests')
          .child(widget.contestId)
          .child('temp')
          .child(fileName);

      // 파일 업로드
      final UploadTask uploadTask = tempRef.putFile(compressedFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploading = false;
      });

      Fluttertoast.showToast(
        msg: '이미지 업로드 완료',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      Fluttertoast.showToast(
        msg: '이미지 업로드 실패: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _showImagePreview() {
    if (_uploadedImageUrl == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleImageViewer(imageUrl: _uploadedImageUrl!),
      ),
    );
  }

  Future<void> _submitPost() async {
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
    if (description.isEmpty && _uploadedImageUrl == null) {
      Fluttertoast.showToast(
        msg: '설명 또는 이미지를 입력해주세요.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // 이미지가 선택되었지만 업로드되지 않은 경우 업로드
      String? imageUrl = _uploadedImageUrl;
      if (_selectedImageFile != null && imageUrl == null) {
        await _uploadImage();
        imageUrl = _uploadedImageUrl;
      }

      // 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final displayName = userData['displayName'] ?? '익명';
      final photoURL = userData['photoURL'] ?? '';

      // submissionId 생성
      final submissionId = const Uuid().v4();
      final now = FieldValue.serverTimestamp();
      final dateString = DateFormat('yyyyMMdd').format(DateTime.now());

      // 이미지가 임시 경로에 있다면 최종 경로로 이동
      if (imageUrl != null && imageUrl.contains('/temp/')) {
        try {
          // Firebase Storage 설정
          FirebaseStorage storage;
          if (Platform.isIOS) {
            storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
          } else {
            storage = FirebaseStorage.instance;
          }

          // 임시 경로에서 파일명 추출
          final tempRef = storage.refFromURL(imageUrl);
          final fileName = tempRef.name;
          
          // 최종 경로로 복사
          final finalRef = storage
              .ref()
              .child('contests')
              .child(widget.contestId)
              .child('submissions')
              .child(submissionId)
              .child('images')
              .child(fileName);

          // 임시 파일의 바이트 다운로드 후 최종 경로에 업로드
          final bytes = await tempRef.getData();
          if (bytes != null) {
            await finalRef.putData(bytes);
            imageUrl = await finalRef.getDownloadURL();
            
            // 임시 파일 삭제
            try {
              await tempRef.delete();
            } catch (e) {
              print('임시 파일 삭제 실패 (무시 가능): $e');
            }
          }
        } catch (e) {
          print('이미지 경로 이동 실패: $e');
          // 실패해도 기존 URL 사용
        }
      }

      // contentHtml 생성 (이미지가 있으면 포함)
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

      // contentHtml에서 제목과 동일한 첫 부분 제거 (중복 방지)
      String finalContentHtml = contentHtml;
      if (description.isNotEmpty && title == description) {
        // 제목과 설명이 동일한 경우, contentHtml에서 첫 번째 <p> 태그의 내용 제거
        final titlePattern = RegExp(r'^<p[^>]*>([^<]*)</p>', caseSensitive: false);
        final match = titlePattern.firstMatch(contentHtml);
        if (match != null && match.group(1)?.trim() == title.trim()) {
          // 첫 번째 <p> 태그 제거
          finalContentHtml = contentHtml.replaceFirst(match.group(0) ?? '', '').trim();
        }
      }

      // Firestore에 데이터 추가
      final batch = FirebaseFirestore.instance.batch();

      // 1. contests/{contestId}/submissions/{submissionId} 생성
      final submissionRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(submissionId);

      batch.set(submissionRef, {
        'submissionId': submissionId,
        'uid': user.uid,
        'displayName': displayName,
        'photoURL': photoURL,
        'title': title,
        'contentHtml': finalContentHtml,
        'likeCount': 0,
        'viewCount': 0,
        'commentCount': 0,
        'createdAt': now,
        'submittedAt': now,
        'dateString': dateString,
        'postId': submissionId, // 참고용
      });

      // 2. users/{uid}/contests/{contestId} 생성
      final userContestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contests')
          .doc(widget.contestId);

      batch.set(userContestRef, {
        'contestId': widget.contestId,
        'contestTitle': widget.contestTitle,
        'submissionId': submissionId,
        'submissionTitle': title,
        'status': 'submitted',
        'participatedAt': now,
        'updatedAt': now,
      });

      // 3. contests/{contestId}의 participantCount 증가
      final contestRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId);

      batch.update(contestRef, {
        'participantCount': FieldValue.increment(1),
        'updatedAt': now,
      });

      // 배치 실행
      await batch.commit();

      Fluttertoast.showToast(
        msg: '게시글이 등록되었습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // 성공 시 이전 화면으로 돌아가기
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isPosting = false;
      });
      Fluttertoast.showToast(
        msg: '게시글 등록 실패: $e',
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
          '콘테스트',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _submitPost,
            child: Text(
              '게시',
              style: TextStyle(
                color: _isPosting ? Colors.grey : const Color(0xFF74512D),
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
                onTap: _uploadedImageUrl != null ? _showImagePreview : null,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _isUploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                          ),
                        )
                      : _uploadedImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _uploadedImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error, size: 48, color: Colors.grey),
                                  );
                                },
                              ),
                            )
                          : _selectedImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImageFile!,
                                    fit: BoxFit.cover,
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
              // 이미지 업로드 버튼
              if (_uploadedImageUrl == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _selectedImageFile == null ? _pickImage : _uploadImage,
                    icon: Icon(
                      _selectedImageFile == null ? Icons.add_photo_alternate : Icons.upload,
                      color: const Color(0xFF74512D),
                    ),
                    label: Text(
                      _selectedImageFile == null ? '이미지 선택' : '이미지 업로드',
                      style: const TextStyle(color: Color(0xFF74512D)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF74512D)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_uploadedImageUrl != null) ...[
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
        padding: const EdgeInsets.all(16),
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
            onPressed: _isPosting ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF74512D),
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '게시',
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
