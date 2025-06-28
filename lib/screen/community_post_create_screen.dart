import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';

class CommunityPostCreateScreen extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  
  // 편집 모드 관련 파라미터
  final bool isEditMode;
  final String? postId;
  final String? dateString;
  final String? editTitle;
  final String? editContentHtml;

  const CommunityPostCreateScreen({
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
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  String? selectedBoardId;
  String? selectedBoardName;
  final TextEditingController _titleController = TextEditingController();
  final HtmlEditorController _htmlController = HtmlEditorController();
  final ImagePicker _picker = ImagePicker();
  List<String> tempImagePaths = []; // 임시 이미지 경로들
  static const int maxImageCount = 10; // 최대 이미지 개수
  bool _isLoading = false; // 로딩 상태 관리

  @override
  void initState() {
    super.initState();
    
    if (widget.isEditMode) {
      // 편집 모드일 때 기존 데이터로 초기화
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
      _titleController.text = widget.editTitle ?? '';
      // HTML 에디터 내용은 onInit 콜백에서 설정
    } else {
      // 새 게시글 작성 모드
      selectedBoardId = widget.initialBoardId;
      selectedBoardName = widget.initialBoardName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addImageToEditor() async {
    try {
      // 최대 개수 확인
      if (tempImagePaths.length >= maxImageCount) {
        Fluttertoast.showToast(
          msg: "최대 $maxImageCount개까지만 사진을 추가할 수 있습니다",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          tempImagePaths.add(image.path);
        });
        
        print('이미지 선택됨: ${image.path}');
        print('총 이미지 개수: ${tempImagePaths.length}/$maxImageCount');
        
        // HTML 에디터에 직접 이미지 태그 삽입
        final String imageHtml = '<img src="file://${image.path}" style="max-width: 100%; border-radius: 8px;" /><br/>';
        _htmlController.insertHtml(imageHtml);
        
        Fluttertoast.showToast(
          msg: "이미지가 추가되었습니다 (${tempImagePaths.length}/$maxImageCount)",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Color(0xFF74512D),
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      Fluttertoast.showToast(
        msg: "이미지 선택 중 오류가 발생했습니다",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }



  Future<String> _uploadImageAndGetUrl(String imagePath, String postId, String dateString) async {
    try {
      final String fileName = '${postId}_${const Uuid().v4()}.${imagePath.split('.').last}';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(dateString)
          .child('posts')
          .child(postId)
          .child('images')
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(File(imagePath));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      throw e;
    }
  }

  Future<String> _processImagesInHtml(String htmlContent, String postId, String dateString) async {
    String processedHtml = htmlContent;
    
    print('HTML 처리 시작, 원본 크기: ${htmlContent.length} 바이트');
    
    // file:// 형태의 로컬 이미지 경로 처리
    final RegExp fileImgRegex = RegExp(r'<img[^>]*src="file://([^"]*)"[^>]*>', caseSensitive: false);
    final matches = fileImgRegex.allMatches(processedHtml);
    
    print('발견된 로컬 이미지 개수: ${matches.length}');
    
    for (final match in matches) {
      final String fullMatch = match.group(0)!; // 전체 img 태그
      final String imagePath = match.group(1)!; // 파일 경로 (file:// 제외)
      
      try {
        print('로컬 이미지 업로드 시작: $imagePath');
        
        // Firebase Storage에 업로드
        final String downloadUrl = await _uploadImageAndGetUrl(imagePath, postId, dateString);
        print('로컬 이미지 업로드 완료: $downloadUrl');
        
        // HTML에서 로컬 경로를 다운로드 URL로 교체
        final String newImgTag = '<img src="$downloadUrl" style="max-width: 100%; border-radius: 8px;" />';
        processedHtml = processedHtml.replaceAll(fullMatch, newImgTag);
        
        print('이미지 교체 완료: $downloadUrl');
        
      } catch (e) {
        print('로컬 이미지 업로드 실패: $imagePath, 오류: $e');
        // 업로드 실패한 이미지는 제거
        processedHtml = processedHtml.replaceAll(fullMatch, '');
      }
    }
    
    print('HTML 처리 완료, 최종 크기: ${processedHtml.length} 바이트');
    return processedHtml;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
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
                CircularProgressIndicator(
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
    if (_isLoading) return; // 이미 로딩 중이면 중복 실행 방지
    
    setState(() {
      _isLoading = true;
    });
    
    _showLoadingDialog(); // 로딩 다이얼로그 표시
    
    try {
      // 1. 로그인 확인
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _hideLoadingDialog(); // 로딩 다이얼로그 닫기
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "로그인이 필요합니다",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // 2. 게시판 선택 확인
      if (selectedBoardId == null || selectedBoardName == null) {
        _hideLoadingDialog(); // 로딩 다이얼로그 닫기
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "게시판을 선택해주세요",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // 3. 제목 확인
      final title = _titleController.text.trim();
      if (title.isEmpty) {
        _hideLoadingDialog(); // 로딩 다이얼로그 닫기
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "제목을 입력해주세요",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // 4. 내용 확인
      final contentHtml = await _htmlController.getText();
      print('=== HTML 에디터에서 가져온 원본 HTML ===');
      print('HTML 길이: ${contentHtml.length}');
      print('HTML 내용 미리보기 (첫 1000자): ${contentHtml.length > 1000 ? contentHtml.substring(0, 1000) : contentHtml}');
      
      if (contentHtml.trim().isEmpty || contentHtml.trim() == '<p></p>') {
        _hideLoadingDialog(); // 로딩 다이얼로그 닫기
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "내용을 입력해주세요",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }
      
      // HTML에 base64 이미지가 포함되어 있는지 확인
      final base64Count = RegExp(r'data:image/[^;]+;base64,').allMatches(contentHtml).length;
      print('발견된 base64 이미지 개수: $base64Count');

      // 5. 사용자 정보 가져오기
      final userProfile = await UserService.getUserFromFirestore(currentUser.uid);
      if (userProfile == null) {
        _hideLoadingDialog(); // 로딩 다이얼로그 닫기
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "사용자 정보를 가져올 수 없습니다",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // 6. UUID와 날짜 생성 (편집 모드가 아닐 때만)
      String postId;
      String dateString;
      
      if (widget.isEditMode) {
        // 편집 모드일 때는 기존 ID 사용
        postId = widget.postId!;
        dateString = widget.dateString!;
      } else {
        // 새 게시글일 때만 새 ID 생성
        const uuid = Uuid();
        postId = uuid.v4();
        final now = DateTime.now();
        dateString = DateFormat('yyyyMMdd').format(now);
      }

      // 7. HTML 내의 이미지들을 업로드하고 URL로 교체
      print('=== 이미지 처리 시작 ===');
      print('원본 contentHtml 크기: ${contentHtml.length} 바이트');
      print('원본 contentHtml (첫 500자): ${contentHtml.length > 500 ? contentHtml.substring(0, 500) : contentHtml}');
      
      final processedContentHtml = await _processImagesInHtml(contentHtml, postId, dateString);
      
      print('처리된 contentHtml 크기: ${processedContentHtml.length} 바이트');
      print('처리된 contentHtml (첫 500자): ${processedContentHtml.length > 500 ? processedContentHtml.substring(0, 500) : processedContentHtml}');

      // 8. Firestore에 저장할 데이터 준비
      Map<String, dynamic> postData;
      
      if (widget.isEditMode) {
        // 편집 모드일 때는 업데이트할 필드만 포함
        postData = {
          'boardId': selectedBoardId,
          'title': title,
          'contentHtml': processedContentHtml,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        // 새 게시글일 때는 모든 필드 포함
        postData = {
          'postId': postId,
          'boardId': selectedBoardId,
          'title': title,
          'contentHtml': processedContentHtml,
          'author': {
            'uid': currentUser.uid,
            'displayName': userProfile['displayName'] ?? '익명',
            'photoURL': userProfile['photoURL'] ?? '',
            'displayGrade': userProfile['displayGrade'] ?? '이코노미 Lv.1',
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

      // 데이터 크기 확인
      print('=== Firestore 데이터 크기 확인 ===');
      print('postId: ${postData['postId']?.toString().length ?? 0} 바이트');
      print('boardId: ${postData['boardId']?.toString().length ?? 0} 바이트');
      print('title: ${postData['title']?.toString().length ?? 0} 바이트');
      print('contentHtml: ${postData['contentHtml']?.toString().length ?? 0} 바이트');
      
      // contentHtml이 여전히 클 경우 추가 처리
      if (processedContentHtml.length > 900000) { // 900KB 이상일 경우
        print('⚠️ contentHtml이 여전히 너무 큽니다: ${processedContentHtml.length} 바이트');
        
        // 최대 800KB로 자르기 (안전 마진)
        final truncatedHtml = processedContentHtml.length > 800000 
            ? processedContentHtml.substring(0, 800000) + '...[내용이 잘렸습니다]'
            : processedContentHtml;
        
        postData['contentHtml'] = truncatedHtml;
        print('contentHtml 크기 조정: ${truncatedHtml.length} 바이트');
      }

      // 9. Firestore에 저장
      if (widget.isEditMode) {
        // 편집 모드일 때는 업데이트
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(dateString)
            .collection('posts')
            .doc(postId)
            .update(postData);
            
        // 사용자의 my_posts 서브컬렉션도 업데이트
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('my_posts')
            .doc(postId)
            .update({
              'title': title,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // 새 게시글일 때는 생성
        final batch = FirebaseFirestore.instance.batch();
        
        // 게시글 생성
        final postRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(dateString)
            .collection('posts')
            .doc(postId);
        batch.set(postRef, postData);
        
        // 사용자의 my_posts 서브컬렉션에도 추가
        final myPostRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('my_posts')
            .doc(postId);
        batch.set(myPostRef, {
          'postPath': 'posts/$dateString/posts/$postId',
          'title': title,
          'boardId': selectedBoardId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // 사용자의 postsCount 증가
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid);
        batch.update(userRef, {
          'postsCount': FieldValue.increment(1),
        });
        
        // 배치 실행
        await batch.commit();
      }

      // 10. 로딩 다이얼로그 닫기
      _hideLoadingDialog();
      setState(() {
        _isLoading = false;
      });

      // 11. 성공 메시지
      Fluttertoast.showToast(
        msg: widget.isEditMode 
            ? "게시글이 성공적으로 수정되었습니다"
            : "게시글이 성공적으로 등록되었습니다",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black38,
        textColor: Colors.white,
      );

      // 12. 화면 닫기 (편집 완료 신호와 함께)
      Navigator.pop(context, widget.isEditMode ? true : false);

    } catch (e) {
      print('게시글 등록 오류: $e');
      
      // 오류 발생 시에도 로딩 다이얼로그 닫기
      _hideLoadingDialog();
      setState(() {
        _isLoading = false;
      });
      
      Fluttertoast.showToast(
        msg: "게시글 등록 중 오류가 발생했습니다",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditMode ? '게시글 수정' : '커뮤니티 게시글 작성',
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
                  // 게시판 선택 화면으로 이동
                  final result = await Navigator.pushNamed(
                      context, '/community_board_select');
                  print('게시판 선택 결과: $result');
                  if (result is Map<String, dynamic>) {
                    setState(() {
                      selectedBoardId = result['boardId'];
                      selectedBoardName = result['boardName'];
                    });
                    print('선택된 게시판: ID=$selectedBoardId, Name=$selectedBoardName');
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
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '제목',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 18),
              ),
              const Divider(height: 32, color: Color(0xFFE0E0E0)),
              // HTML Editor
              HtmlEditor(
                controller: _htmlController,
                htmlEditorOptions: HtmlEditorOptions(
                  hint: '내용을 입력하세요...',
                  shouldEnsureVisible: true,
                  darkMode: false,
                ),
                htmlToolbarOptions: HtmlToolbarOptions(
                  toolbarPosition: ToolbarPosition.aboveEditor,
                  toolbarType: ToolbarType.nativeScrollable,
                  defaultToolbarButtons: [
                    InsertButtons(
                      video: false, 
                      audio: false, 
                      table: false, 
                      hr: false, 
                      otherFile: false,
                      picture: false, // 이미지 버튼 비활성화 - 별도 버튼 사용
                    ),
                    FontButtons(clearAll: false),
                    ColorButtons(),
                    StyleButtons(),
                    ParagraphButtons(textDirection: false, lineHeight: false, caseConverter: false),
                  ],
                ),
                otherOptions: OtherOptions(height: 400),
                callbacks: Callbacks(
                  onChangeContent: (String? changed) {
                    // 내용 변경 시 콜백
                  },
                  onInit: () async {
                    // 초기화 완료 시 콜백
                    print('HTML 에디터 초기화 완료');
                    
                    // 편집 모드일 때 기존 내용 설정
                    if (widget.isEditMode && widget.editContentHtml != null && widget.editContentHtml!.isNotEmpty) {
                      print('편집 모드 - 기존 내용 설정: ${widget.editContentHtml!.length > 100 ? widget.editContentHtml!.substring(0, 100) + "..." : widget.editContentHtml!}');
                      
                      // 약간의 지연 후 내용 설정 (에디터가 완전히 준비될 때까지)
                      await Future.delayed(const Duration(milliseconds: 500));
                      _htmlController.setText(widget.editContentHtml!);
                      
                      print('기존 내용 설정 완료');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 이미지 추가 버튼
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: tempImagePaths.length >= maxImageCount ? null : _addImageToEditor,
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                    color: tempImagePaths.length >= maxImageCount 
                        ? Colors.grey[600] 
                        : Colors.white,
                  ),
                  label: Text(
                    tempImagePaths.length >= maxImageCount 
                        ? '최대 개수 도달 (${tempImagePaths.length}/$maxImageCount)'
                        : '사진 추가 (${tempImagePaths.length}/$maxImageCount)',
                    style: TextStyle(
                      color: tempImagePaths.length >= maxImageCount 
                          ? Colors.grey[600] 
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tempImagePaths.length >= maxImageCount 
                        ? Colors.grey[200] 
                        : const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: tempImagePaths.length >= maxImageCount ? 0 : 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
