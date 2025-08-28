import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/peanut_history_service.dart';
import '../community_editor/community_editor.dart';

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
  bool _isLoading = false;
  // 임시 저장 키
  static const String _tempTitleKey = 'temp_post_title_v3';
  static const String _tempContentKey = 'temp_post_content_v3';
  static const String _tempBoardIdKey = 'temp_board_id_v3';
  static const String _tempBoardNameKey = 'temp_board_name_v3';
  
  // 커뮤니티 에디터 컨트롤러
  late CommunityEditorController _editorController;
  
  @override
  void initState() {
    super.initState();
    
    // 커뮤니티 에디터 컨트롤러 초기화
    _editorController = CommunityEditorController();
    
    // 초기 데이터 설정
    _editorController.initializeWithData(
      boardId: widget.initialBoardId,
      boardName: widget.initialBoardName,
      isEditMode: widget.isEditMode,
      postId: widget.postId,
      dateString: widget.dateString,
      editTitle: widget.editTitle,
      editContentHtml: widget.editContentHtml,
    );

    // 즉시 업로드 사용 안 함: 식별자 사전 부여 제거
    
    // 상태 변경 리스너 설정
    _editorController.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          // 상태 변경 반영
        });
      }
    };
    
    // 컨트롤러 변경 리스너도 추가
    _editorController.addListener(() {
      if (mounted) {
        setState(() {
          // 컨트롤러 상태 변경 반영
        });
      }
    });

    // 진입 시 임시 저장 데이터가 있으면 팝업 노출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDraftAndPrompt();
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  // 뒤로가기 처리
  Future<bool> _onWillPop() async {
    if (!_editorController.hasUnsavedChanges) return true;
    final action = await _showExitDraftSheet();
    switch (action) {
      case 'save':
        await _saveDraft();
        return true;
      case 'discard':
        await _clearDraft();
        return true;
      case 'cancel':
      default:
        return false;
    }
  }
  
  // 임시저장 (텍스트/게시판만 저장)
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = _editorController.titleController.text.trim();
      // 본문은 저장하지 않음
      final boardId = _editorController.postData.boardId;
      final boardName = _editorController.postData.boardName;

      if (title.isNotEmpty) {
        await prefs.setString(_tempTitleKey, title);
        if (boardId != null && boardName != null) {
          await prefs.setString(_tempBoardIdKey, boardId);
          await prefs.setString(_tempBoardNameKey, boardName);
        }
      }

      Fluttertoast.showToast(
        msg: "임시저장되었습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "임시저장에 실패했습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // 임시저장 함수 (툴바에서 사용)
  Future<void> _handleSaveDraft() async {
    await _saveDraft();
  }

  // 임시저장 데이터 삭제
  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tempTitleKey);
    await prefs.remove(_tempContentKey);
    await prefs.remove(_tempBoardIdKey);
    await prefs.remove(_tempBoardNameKey);
  }

  // 진입 시 임시저장 확인 팝업
  Future<void> _checkDraftAndPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString(_tempTitleKey) ?? '';
      final content = ''; // 본문 임시저장 사용 안 함
      final boardId = prefs.getString(_tempBoardIdKey);
      final boardName = prefs.getString(_tempBoardNameKey);
      final has = title.isNotEmpty || (boardId != null && boardName != null);
      if (!has) return;
      final choice = await _showRestoreDraftSheet();
      if (choice == 'restore') {
        await _loadDraftFromPrefs();
      } else if (choice == 'new') {
        await _clearDraft();
      }
    } catch (_) {}
  }

  Future<void> _loadDraftFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_tempTitleKey) ?? '';
    final boardId = prefs.getString(_tempBoardIdKey);
    final boardName = prefs.getString(_tempBoardNameKey);

    if (title.isNotEmpty) {
      _editorController.titleController.text = title;
    }
    if (boardId != null && boardName != null) {
      _editorController.updateBoard(boardId, boardName);
    }

    Fluttertoast.showToast(
      msg: "임시 저장된 내용을 불러왔습니다",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
    );
  }

  // 하단 시트: 나갈 때 저장 여부
  Future<String?> _showExitDraftSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 게시글을 임시 저장할까요?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      child: const Text('취소', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'discard'),
                      child: const Text('저장 안 함', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'save'),
                      child: const Text('저장', style: TextStyle(color: Color(0xFF74512D), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // 하단 시트: 임시저장 불러오기
  Future<String?> _showRestoreDraftSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '임시 저장한 내용 불러오기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  '임시 저장된 내용을 불러오거나 내용을 새로 작성하세요.',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'new'),
                      child: const Text('새로 만들기', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ),
                    Container(width: 1, height: 20, color: Colors.grey[300]),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'restore'),
                      child: const Text('불러오기', style: TextStyle(color: Color(0xFF74512D), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
    if (_editorController.postData.title.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: "제목을 입력해주세요",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
      return;
    }
    
    if (_editorController.postData.contentHtml.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: "내용을 입력해주세요",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
      );
      return;
    }
    
    if (_editorController.postData.boardId == null || _editorController.postData.boardName == null) {
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
        // 편집 중 미리 부여한 식별자가 있으면 재사용
        if (_editorController.postData.postId != null && _editorController.postData.dateString != null) {
          postId = _editorController.postData.postId!;
          dateString = _editorController.postData.dateString!;
        } else {
          const uuid = Uuid();
          postId = uuid.v4();
          final now = DateTime.now();
          dateString = DateFormat('yyyyMMdd').format(now);
          _editorController.setIdentifiers(postId: postId, dateString: dateString);
        }
      }

      // 4. Firestore에 저장할 데이터 준비
      Map<String, dynamic> postData;
      
      if (widget.isEditMode) {
        // 수정 모드에서는 HTML 처리
        final processedHtml = await _editorController.getProcessedHtml();
        
        postData = {
          'boardId': _editorController.postData.boardId,
          'title': _editorController.postData.title.trim(),
          'contentHtml': processedHtml.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        // 새 게시글 모드에서는 HTML 처리
        final processedHtml = await _editorController.getProcessedHtml();
        
        postData = {
          'postId': postId,
          'boardId': _editorController.postData.boardId,
          'title': _editorController.postData.title.trim(),
          'contentHtml': processedHtml.trim(),
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
              'title': _editorController.postData.title.trim(),
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
          'title': _editorController.postData.title.trim(),
          'boardId': _editorController.postData.boardId,
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
              'boardId': _editorController.postData.boardId!,
              'postTitle': _editorController.postData.title.trim(),
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
        resizeToAvoidBottomInset: true, // 키보드가 올라올 때 화면 크기 조정
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
                        _editorController.updateBoard(
                          result['boardId'],
                          result['boardName'],
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _editorController.postData.boardName ?? '카테고리 선택',
                            style: TextStyle(
                              color: _editorController.postData.boardName == null ? Colors.grey : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: _editorController.postData.boardName == null ? Colors.grey : Colors.black,
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
        body: Stack(
          children: [
            Column(
              children: [
                // 구분선
                Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
                
                // 에디터 영역
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CommunityContentEditor(
                      controller: _editorController,
                    ),
                  ),
                ),
              ],
            ),
            
            // 키보드 위 툴바 (내용 입력 포커스시에만 표시)
            AnimatedBuilder(
              animation: _editorController,
              builder: (context, child) {
                if (!_editorController.showToolbar) {
                  return const SizedBox.shrink();
                }
                
                return Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 0,
                  right: 0,
                  child: CommunityToolbar(
                    controller: _editorController,
                    onSaveDraft: _handleSaveDraft,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
