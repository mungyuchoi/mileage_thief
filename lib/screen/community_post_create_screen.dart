import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;

  const CommunityPostCreateScreen(
      {Key? key, this.initialBoardId, this.initialBoardName})
      : super(key: key);

  @override
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  String? selectedBoardId;
  String? selectedBoardName;
  final TextEditingController _titleController = TextEditingController();
  final HtmlEditorController _htmlController = HtmlEditorController();

  @override
  void initState() {
    super.initState();
    selectedBoardId = widget.initialBoardId;
    selectedBoardName = widget.initialBoardName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    try {
      // 1. 로그인 확인
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
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
      if (contentHtml.trim().isEmpty || contentHtml.trim() == '<p></p>') {
        Fluttertoast.showToast(
          msg: "내용을 입력해주세요",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // 5. 사용자 정보 가져오기
      final userProfile = await UserService.getUserFromFirestore(currentUser.uid);
      if (userProfile == null) {
        Fluttertoast.showToast(
          msg: "사용자 정보를 가져올 수 없습니다",
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // 6. UUID와 날짜 생성
      const uuid = Uuid();
      final postId = uuid.v4();
      final now = DateTime.now();
      final dateString = DateFormat('yyyyMMdd').format(now);

      // 7. Firestore에 저장할 데이터 준비
      final postData = {
        'postId': postId,
        'boardId': selectedBoardId,
        'title': title,
        'contentHtml': contentHtml,
        'author': {
          'uid': currentUser.uid,
          'displayName': userProfile['displayName'] ?? '익명',
          'profileImageUrl': userProfile['photoURL'] ?? '',
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

      // 8. Firestore에 저장
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(dateString)
          .collection('posts')
          .doc(postId)
          .set(postData);

      // 9. 성공 메시지
      Fluttertoast.showToast(
        msg: "게시글이 성공적으로 등록되었습니다",
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // 10. 화면 닫기
      Navigator.pop(context);

    } catch (e) {
      print('게시글 등록 오류: $e');
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
        title: const Text('커뮤니티 게시글 작성',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () async {
              await _handleSubmit();
            },
            child: const Text('등록',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
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
                    // FontSettingButtons(),
                    InsertButtons(video: false, audio: false, table: false, hr: false, otherFile: false),
                    FontButtons(clearAll: false,),
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
                  onInit: () {
                    // 초기화 완료 시 콜백
                  },
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
