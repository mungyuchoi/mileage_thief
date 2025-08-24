import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/peanut_history_service.dart';

class CommunityPostCreateScreenV3 extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  
  // 편집 모드 관련 파라미터
  final bool isEditMode;
  final String? postId;
  final String? dateString;
  final String? editTitle;
  final String? editContentHtml;

  const CommunityPostCreateScreenV3({
    Key? key, 
    this.initialBoardId, 
    this.initialBoardName,
    this.isEditMode = false,
    this.postId,
    this.dateString,
    this.editTitle,
    this.editContentHtml,
  }) : super(key: key);

  @override
  State<CommunityPostCreateScreenV3> createState() =>
      _CommunityPostCreateScreenV3State();
}

class _CommunityPostCreateScreenV3State extends State<CommunityPostCreateScreenV3> {
  String? selectedBoardId;
  String? selectedBoardName;
  bool _isLoading = false;
  
  // 컨트롤러들
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  
  // 상태 관리
  bool _showToolbar = false;
  bool _hasUnsavedChanges = false;
  List<XFile> _selectedImages = [];
  
  // 이미지 피커
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    
    // 초기 데이터 설정
    if (widget.isEditMode) {
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
      
      if (widget.editTitle?.isNotEmpty == true) {
        _titleController.text = widget.editTitle!;
      }
      
      if (widget.editContentHtml?.isNotEmpty == true) {
        _contentController.text = widget.editContentHtml!;
      }
    } else {
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
    }
    
    // 포커스 리스너 설정
    _contentFocusNode.addListener(() {
      setState(() {
        _showToolbar = _contentFocusNode.hasFocus;
      });
    });
    
    // 텍스트 변경 리스너 설정
    _titleController.addListener(() {
      _updateUnsavedChanges();
    });
    
    _contentController.addListener(() {
      _updateUnsavedChanges();
    });
  }
  
  void _updateUnsavedChanges() {
    final hasChanges = _titleController.text.isNotEmpty || 
                      _contentController.text.isNotEmpty ||
                      _selectedImages.isNotEmpty;
    
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  // 뒤로가기 처리
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true; // 변경사항이 없으면 바로 나가기
    }
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '작성중인 글을 취소하시겠습니까?',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          '작성취소 선택시, 작성된 글은 저장되지 않습니다.',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('temp_save'),
            child: const Text(
              '임시저장',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text(
              '작성취소',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    // 다이얼로그 결과 처리
    if (result == 'cancel') {
      return false; // 취소 - 나가지 않음
    } else if (result == 'discard') {
      // 작성취소 - 바로 나가기
      return true;
    } else if (result == 'temp_save') {
      // 임시저장 - 임시 저장 후 나가기
      await _saveDraft();
      return true;
    }
    
    return false;
  }
  
  // 임시저장
  Future<void> _saveDraft() async {
    // TODO: 임시저장 로직 구현
    Fluttertoast.showToast(
      msg: "임시저장되었습니다",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
    );
  }

  // 이미지 선택
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          if (_selectedImages.length > 20) {
            _selectedImages = _selectedImages.take(20).toList();
          }
        });
        _updateUnsavedChanges();
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }
  
  // 이미지 제거
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _updateUnsavedChanges();
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isEditMode ? '게시글을 수정하고 있습니다...' : '게시글을 등록하고 있습니다...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    
    // 유효성 검사
    if (_titleController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: "제목을 입력해주세요",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
      return;
    }
    
    if (_contentController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: "내용을 입력해주세요",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
      return;
    }
    
    if (selectedBoardId == null || selectedBoardName == null) {
      Fluttertoast.showToast(
        msg: "게시판을 선택해주세요",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    _showLoadingDialog();
    
    try {
      // 1. 로그인 확인
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _hideLoadingDialog();
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "로그인이 필요합니다",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
        return;
      }

      // 2. 사용자 정보 가져오기
      final userProfile = await UserService.getUserFromFirestore(currentUser.uid);
      if (userProfile == null) {
        _hideLoadingDialog();
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "사용자 정보를 가져올 수 없습니다",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
        return;
      }

      // 3. UUID와 날짜 생성
      String postId;
      String dateString;
      
      if (widget.isEditMode) {
        postId = widget.postId!;
        dateString = widget.dateString!;
      } else {
        const uuid = Uuid();
        postId = uuid.v4();
        final now = DateTime.now();
        dateString = DateFormat('yyyyMMdd').format(now);
      }

      // 4. Firestore에 저장할 데이터 준비
      Map<String, dynamic> postData;
      
      if (widget.isEditMode) {
        postData = {
          'boardId': selectedBoardId,
          'title': _titleController.text.trim(),
          'contentHtml': _contentController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        postData = {
          'postId': postId,
          'boardId': selectedBoardId,
          'title': _titleController.text.trim(),
          'contentHtml': _contentController.text.trim(),
          'author': {
            'uid': currentUser.uid,
            'displayName': userProfile['displayName'] ?? '익명',
            'photoURL': userProfile['photoURL'] ?? '',
            'displayGrade': (userProfile['roles'] != null && (userProfile['roles'] as List).contains('admin'))
                ? '★★★'
                : (userProfile['displayGrade'] ?? '이코노미 Lv.1'),
            'currentSkyEffect': userProfile['currentSkyEffect'] ?? '',
          },
          'viewsCount': 0,
          'likesCount': 0,
          'commentCount': 0,
          'reportsCount': 0,
          'isDeleted': false,
          'isHidden': false,
          'hiddenByReport': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      // 5. Firestore에 저장
      if (widget.isEditMode) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(dateString)
            .collection('posts')
            .doc(postId)
            .update(postData);
            
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('my_posts')
            .doc(postId)
            .update({
              'title': _titleController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        final batch = FirebaseFirestore.instance.batch();
        
        final postRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(dateString)
            .collection('posts')
            .doc(postId);
        batch.set(postRef, postData);
        
        final myPostRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('my_posts')
            .doc(postId);
        batch.set(myPostRef, {
          'postPath': 'posts/$dateString/posts/$postId',
          'title': _titleController.text.trim(),
          'boardId': selectedBoardId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid);
        batch.update(userRef, {
          'postsCount': FieldValue.increment(1),
        });
        
        await batch.commit();
      }

      _hideLoadingDialog();
      setState(() {
        _isLoading = false;
      });

      // 6. 성공 메시지
      Fluttertoast.showToast(
        msg: widget.isEditMode 
            ? "게시글이 성공적으로 수정되었습니다"
            : "게시글이 성공적으로 등록되었습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );

      // 새 글 작성 시 땅콩 10개 추가
      if (!widget.isEditMode) {
        try {
          final userData = await UserService.getUserFromFirestore(currentUser.uid);
          final currentPeanut = userData?['peanutCount'] ?? 0;
          final newPeanut = currentPeanut + 10;
          await UserService.updatePeanutCount(currentUser.uid, newPeanut);
          
          await PeanutHistoryService.addHistory(
            userId: currentUser.uid,
            type: 'post_create',
            amount: 10,
            additionalData: {
              'postId': postId,
              'dateString': dateString,
              'boardId': selectedBoardId!,
              'postTitle': _titleController.text.trim(),
            },
          );
          
          Fluttertoast.showToast(
            msg: "땅콩 10개가 추가되었습니다.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey[800],
            textColor: Colors.white,
          );
        } catch (e) {
          print('땅콩 추가 오류: $e');
        }
      }

      // 7. 화면 닫기
      Navigator.pop(context, widget.isEditMode ? true : false);

    } catch (e) {
      print('게시글 등록 오류: $e');
      
      _hideLoadingDialog();
      setState(() {
        _isLoading = false;
      });
      
      Fluttertoast.showToast(
        msg: "게시글 등록 중 오류가 발생했습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              // 취소 버튼
              TextButton(
                onPressed: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  '취소',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // 가운데 카테고리명
              Expanded(
                child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                          context, '/community_board_select');
                      if (result is Map<String, dynamic>) {
                        setState(() {
                          selectedBoardId = result['boardId'];
                          selectedBoardName = result['boardName'];
                        });
                        _updateUnsavedChanges();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedBoardName ?? '카테고리 선택',
                            style: TextStyle(
                              color: selectedBoardName == null ? Colors.grey : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: selectedBoardName == null ? Colors.grey : Colors.black,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
              ),
              
              // 등록 버튼
              TextButton(
                onPressed: _isLoading ? null : () async {
                  await _handleSubmit();
                },
                child: Text(
                  _isLoading ? '등록 중...' : '등록',
                  style: TextStyle(
                    color: _isLoading ? Colors.grey : const Color(0xFF74512D),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // 구분선
            Container(
              height: 1,
              color: Colors.grey[300],
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 입력
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      decoration: const InputDecoration(
                        hintText: '제목',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 18,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        _contentFocusNode.requestFocus();
                      },
                    ),
                    
                    // 구분선
                    Container(
                      height: 1,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    
                    // 내용 입력
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 200,
                      ),
                      child: TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        decoration: const InputDecoration(
                          hintText: '오늘 어떤 여행을 떠나셨나요?\n경험을 공유해주세요!',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 선택된 이미지들 표시
                    if (_selectedImages.isNotEmpty)
                      Container(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_selectedImages[index].path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  
                                  // 순서 번호
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // 삭제 버튼
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 100), // 키보드 툴바 공간 확보
                  ],
                ),
              ),
            ),
          ],
        ),
        
        // 키보드 위 툴바 (내용 입력 포커스시에만 표시)
        bottomNavigationBar: _showToolbar
            ? Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    // 사진 첨부 버튼
                    IconButton(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.camera_alt_outlined),
                      tooltip: '사진 첨부',
                    ),
                    
                    // 볼드 버튼
                    IconButton(
                      onPressed: () {
                        // TODO: 볼드 기능 구현
                      },
                      icon: const Icon(Icons.format_bold),
                      tooltip: '굵게',
                    ),
                    
                    // 이탤릭 버튼
                    IconButton(
                      onPressed: () {
                        // TODO: 이탤릭 기능 구현
                      },
                      icon: const Icon(Icons.format_italic),
                      tooltip: '기울임',
                    ),
                    
                    // 리스트 버튼
                    IconButton(
                      onPressed: () {
                        // TODO: 리스트 기능 구현
                      },
                      icon: const Icon(Icons.format_list_bulleted),
                      tooltip: '목록',
                    ),
                    
                    const Spacer(),
                    
                    // 저장 버튼
                    TextButton(
                      onPressed: () {
                        _saveDraft();
                      },
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
