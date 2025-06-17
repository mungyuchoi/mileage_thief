import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  const CommunityPostCreateScreen({Key? key, this.initialBoardId, this.initialBoardName}) : super(key: key);

  @override
  State<CommunityPostCreateScreen> createState() => _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  String? selectedBoardId;
  String? selectedBoardName;
  final TextEditingController _titleController = TextEditingController();
  final quill.QuillController _quillController = quill.QuillController.basic();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  bool _showToolbar = false;

  @override
  void initState() {
    super.initState();
    selectedBoardId = widget.initialBoardId;
    selectedBoardName = widget.initialBoardName;
    _editorFocusNode.addListener(() {
      setState(() {
        _showToolbar = _editorFocusNode.hasFocus;
      });
    });
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
        title: const Text('커뮤니티 게시글 작성', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              final title = _titleController.text;
              final content = _quillController.document.toDelta().toJson();
              // Firestore 저장 등 처리
            },
            child: const Text('등록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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
              const Text('게시판 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  // 게시판 선택 화면으로 이동
                  final result = await Navigator.pushNamed(context, '/community_board_select');
                  if (result is Map<String, String>) {
                    setState(() {
                      selectedBoardId = result['boardId'];
                      selectedBoardName = result['boardName'];
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedBoardName ?? '게시판을 선택하세요', style: TextStyle(color: selectedBoardName == null ? Colors.grey : Colors.black, fontSize: 15)),
                      const Icon(Icons.edit, color: Colors.black38, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              // RichTextEditor 영역 시작
              Container(
                height: 500,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: quill.QuillEditor(
                  controller: _quillController,
                  focusNode: _editorFocusNode,
                  scrollController: _editorScrollController,
                  config: quill.QuillEditorConfig(
                    placeholder: '내용을 입력하세요...',
                    padding: const EdgeInsets.all(2),
                    expands: false,
                    embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // RichTextEditor 영역 끝
              const Text(
                '항공권 발권 후기, 마일리지 꿀팁, 좌석 정보, 취소표 알림 후기 등 자유롭게 공유해주세요.\n  예시)\n  - 대한항공 ICN→JFK 퍼스트 클래스 발권 후기 (8만 마일 + 유류할증료)\n  - 아시아나 마일리지 적립 카드 비교\n  - 6월 인기 구간 취소표 알림 받고 발권 성공했어요!\n  - 오류 있던 구간 알려드립니다 (예: BKK 노선 좌석 미출력)\n\n  ※ 자세히 작성할수록 다른 유저에게 더 도움이 됩니다!',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomSheet: _showToolbar && MediaQuery.of(context).viewInsets.bottom > 0
          ? Material(
              elevation: 2,
              color: Colors.transparent,
              child: quill.QuillSimpleToolbar(
                controller: _quillController,
                config: quill.QuillSimpleToolbarConfig(
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: true,
                  showFontSize: true,
                  buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                    fontFamily: quill.QuillToolbarFontFamilyButtonOptions(
                      items: const {
                        'Sans Serif': 'sans-serif',
                        'Serif': 'serif',
                        'Monospace': 'monospace',
                        'Ibarra Real Nova': 'ibarra-real-nova',
                        'SquarePeg': 'square-peg',
                        'Nunito': 'nunito',
                        'Pacifico': 'pacifico',
                        'Roboto Mono': 'roboto-mono',
                        'Clear': 'Clear', // 또는 context.loc.clear 사용 가능
                      },
                      defaultDisplayText: '글꼴',
                    ),
                    fontSize: quill.QuillToolbarFontSizeButtonOptions(
                      items: const {
                        '10': '10',
                        '12': '12',
                        '14': '14',
                        '16': '16',
                        '18': '18',
                        '20': '20',
                        '24': '24',
                      },
                      defaultDisplayText: '크기',
                      // 필요시 initialValue, style 등도 추가 가능
                    ),
                  ),
                  showQuote: true,
                  showAlignmentButtons: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: false,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showLink: false,
                  showClearFormat: false,
                  showDirection: false,
                  showIndent: false,
                  showUndo: false,
                  showRedo: false,
                  showHeaderStyle: false,
                  showSearchButton: false,
                  showDividers: false,
                  showFontFamily: true,
                  showSmallButton: false,
                  showJustifyAlignment: true,
                  showClipboardPaste: true,
                  multiRowsDisplay: false,
                  embedButtons: FlutterQuillEmbeds.toolbarButtons(
                    imageButtonOptions: const QuillToolbarImageButtonOptions(), // 이미지 버튼만
                    videoButtonOptions: null,    // 동영상 버튼 제거
                    cameraButtonOptions: null,   // 카메라 버튼 제거
                  ),
                ),
              ),
            )
          : null,
    );
  }
} 