import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';

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
              final title = _titleController.text;
              final content = await _htmlController.getText();
              print('Title: $title');
              print('Content: $content');
              // Firestore 저장 등 처리
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
                  if (result is Map<String, String>) {
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
