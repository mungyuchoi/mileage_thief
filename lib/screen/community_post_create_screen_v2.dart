import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../milecatch_rich_editor/src/widgets/rich_text_editor.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/peanut_history_service.dart';

// Milecatch Rich Editor 라이브러리 import
import '../milecatch_rich_editor/milecatch_rich_editor.dart';

class CommunityPostCreateScreenV2 extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  
  // 편집 모드 관련 파라미터
  final bool isEditMode;
  final String? postId;
  final String? dateString;
  final String? editTitle;
  final String? editContentHtml;

  const CommunityPostCreateScreenV2({
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
  State<CommunityPostCreateScreenV2> createState() =>
      _CommunityPostCreateScreenV2State();
}

class _CommunityPostCreateScreenV2State extends State<CommunityPostCreateScreenV2> {
  String? selectedBoardId;
  String? selectedBoardName;
  bool _isLoading = false;
  
  // Milecatch Rich Editor 컨트롤러들
  late PostingController _postingController;
  
  @override
  void initState() {
    super.initState();
    
    // PostingController 초기화
    _postingController = PostingController();
    
    if (widget.isEditMode) {
      // 편집 모드일 때 기존 데이터로 초기화
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
      
      if (widget.editTitle?.isNotEmpty == true) {
        _postingController.updateTitle(widget.editTitle!);
      }
      
      if (widget.editContentHtml?.isNotEmpty == true) {
        _postingController.updateContent(widget.editContentHtml!);
      }
    } else {
      // 새 게시글 작성 모드
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
    }
  }

  @override
  void dispose() {
    _postingController.dispose();
    super.dispose();
  }

  // 뒤로가기 처리
  Future<bool> _onWillPop() async {
    if (!_postingController.hasUnsavedChanges) {
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
          '작성 중인 내용이 있습니다',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          '이 게시글을 임시 저장할까요?',
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
            onPressed: () => Navigator.of(context).pop('no_save'),
            child: const Text(
              '저장 안함',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.black,
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
    } else if (result == 'no_save') {
      // 저장 안함 - 바로 나가기
      return true;
    } else if (result == 'save') {
      // 저장 - 임시 저장 후 나가기
      await _postingController.saveDraft();
      return true;
    }
    
    return false;
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

      // 2. 유효성 검사
      final validation = _postingController.validatePost();
      if (validation.isNotEmpty) {
        _hideLoadingDialog();
        setState(() {
          _isLoading = false;
        });
        
        final firstError = validation.values.first;
        Fluttertoast.showToast(
          msg: firstError ?? "입력 내용을 확인해주세요",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
        return;
      }

      // 3. 게시판 선택 확인
      if (selectedBoardId == null || selectedBoardName == null) {
        _hideLoadingDialog();
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "게시판을 선택해주세요",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey[800],
          textColor: Colors.white,
        );
        return;
      }

      // 4. 사용자 정보 가져오기
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

      // 5. UUID와 날짜 생성
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

      // 6. Firestore에 저장할 데이터 준비
      Map<String, dynamic> postData;
      
      if (widget.isEditMode) {
        postData = {
          'boardId': selectedBoardId,
          'title': _postingController.title,
          'contentHtml': _postingController.content,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        postData = {
          'postId': postId,
          'boardId': selectedBoardId,
          'title': _postingController.title,
          'contentHtml': _postingController.content,
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

      // 7. Firestore에 저장
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
              'title': _postingController.title,
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
          'title': _postingController.title,
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

      // 8. 성공 메시지
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
              'postTitle': _postingController.title,
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

      // 9. 화면 닫기
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
        backgroundColor: const Color(0xFFF1F1F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            widget.isEditMode 
                ? '게시글 수정 (Milecatch Editor)' 
                : _postingController.hasUnsavedChanges 
                    ? '커뮤니티 게시글 작성 (Milecatch Editor) *' 
                    : '커뮤니티 게시글 작성 (Milecatch Editor)',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () async {
                await _handleSubmit();
              },
              child: Text(
                _isLoading ? '등록 중...' : '등록',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                
                // 게시판 선택
                const Text('게시판 선택',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                        context, '/community_board_select');
                    if (result is Map<String, dynamic>) {
                      setState(() {
                        selectedBoardId = result['boardId'];
                        selectedBoardName = result['boardName'];
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedBoardName ?? '게시판을 선택하세요',
                            style: TextStyle(
                                color: selectedBoardName == null
                                    ? Colors.grey
                                    : Colors.black,
                                fontSize: 15)),
                        const Icon(Icons.edit,
                            color: Colors.black38, size: 20),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 제목 입력
                TextField(
                  controller: _postingController.titleController,
                  decoration: const InputDecoration(
                    hintText: '제목',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                
                const Divider(height: 32, color: Color(0xFFE0E0E0)),
                
                // Milecatch Rich Text Editor
                Container(
                  height: 400,
                  child: RichTextEditor(
                    initialContent: widget.editContentHtml,
                    placeholder: '내용을 입력하세요...',
                    isEditMode: widget.isEditMode,
                    onTextChanged: (text) {
                      // 텍스트 변경 시 콜백
                    },
                    onDataChanged: (data) {
                      // 데이터 변경 시 콜백
                    },
                    onFocusChanged: () {
                      // 포커스 변경 시 콜백
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 첨부파일 추가 버튼
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _postingController.attachmentController.pickImageFromGallery();
                    },
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      '사진 추가 (${_postingController.attachments.length}/20)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF74512D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 상태 정보 표시 (디버깅용)
                if (_postingController.hasUnsavedChanges)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '변경사항이 있습니다',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

