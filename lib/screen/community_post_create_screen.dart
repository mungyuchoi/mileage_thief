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
  final Callbacks _editorCallbacks = Callbacks();
  bool _showToolbar = false;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();
  String _editorText = '';

  @override
  void initState() {
    super.initState();
    selectedBoardId = widget.initialBoardId;
    selectedBoardName = widget.initialBoardName;
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('게시판 선택',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    onTap: () {
                      _editorFocusNode.unfocus();
                    },
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
                    height: 300,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Stack(
                      children: [
                        Focus(
                          focusNode: _editorFocusNode,
                          onFocusChange: (hasFocus) async {
                            if (hasFocus) {
                              String html = await _htmlController.getText();
                              if (html.trim() == '<p><br></p>' || html.trim() == '<p></p>') {
                                _htmlController.setText('');
                              }
                              _titleFocusNode.unfocus();
                            }
                            setState(() {
                              _showToolbar = hasFocus;
                            });
                          },
                          child: HtmlEditor(
                            controller: _htmlController,
                            htmlEditorOptions: HtmlEditorOptions(
                              hint: '', // 기본 hint 제거
                              autoAdjustHeight: false,
                            ),
                            htmlToolbarOptions: HtmlToolbarOptions(
                              toolbarPosition: ToolbarPosition.custom,
                              toolbarType: ToolbarType.nativeGrid,
                              defaultToolbarButtons: [], // 커스텀 툴바 사용
                              customToolbarButtons: [],
                            ),
                            otherOptions: OtherOptions(
                              height: 500,
                              customOptions: '''
                                <style>
                                  p { margin-top: 0 !important; margin-bottom: 0 !important; padding-top: 0 !important; padding-bottom: 0 !important; }
                                  body { margin: 0 !important; padding: 0 !important; }
                                </style>
                              ''',
                            ),
                            callbacks: Callbacks(
                              onChangeContent: (String? changed) {
                                setState(() {
                                  _editorText = changed ?? '';
                                });
                              },
                              // ... 기존 콜백 필요시 추가 ...
                            ),
                          ),
                        ),
                        // 커스텀 힌트 텍스트
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Builder(
                              builder: (context) {
                                final isEmpty = _editorText.trim().isEmpty || _editorText.trim() == '<p></p>';
                                if (!_showToolbar && isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        '내용을 입력하세요...',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                                      ),
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ],
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
          if (MediaQuery.of(context).viewInsets.bottom > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 2,
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 이미지 삽입
                        IconButton(
                          icon: const Icon(Icons.image),
                          tooltip: '이미지',
                          onPressed: () {
                            _htmlController.execCommand('insertImage');
                          },
                        ),
                        SizedBox(width: 6),
                        // 굵게
                        IconButton(
                          icon: const Icon(Icons.format_bold),
                          tooltip: '굵게',
                          onPressed: () {
                            _htmlController.execCommand('bold');
                          },
                        ),
                        // 이탤릭
                        IconButton(
                          icon: const Icon(Icons.format_italic),
                          tooltip: '이탤릭',
                          onPressed: () {
                            _htmlController.execCommand('italic');
                          },
                        ),
                        // 밑줄
                        IconButton(
                          icon: const Icon(Icons.format_underline),
                          tooltip: '밑줄',
                          onPressed: () {
                            _htmlController.execCommand('underline');
                          },
                        ),
                        SizedBox(width: 6),
                        // 정렬
                        Builder(
                          builder: (context) {
                            return IconButton(
                              icon: const Icon(Icons.format_align_left),
                              tooltip: '정렬',
                              onPressed: () async {
                                final RenderBox button = context.findRenderObject() as RenderBox;
                                final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                final Offset position = button.localToGlobal(Offset.zero, ancestor: overlay);
                                final selected = await showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromLTRB(
                                    position.dx,
                                    position.dy - 120, // 메뉴 높이(5*48)만큼 빼서 툴바 바로 위에 정확히 붙도록 조정
                                    position.dx + button.size.width,
                                    position.dy,
                                  ),
                                  items: [
                                    PopupMenuItem(
                                      value: 'Left',
                                      child: Container(
                                        color: Colors.white,
                                        child: Text('왼쪽 정렬'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Center',
                                      child: Container(
                                        color: Colors.white,
                                        child: Text('가운데 정렬'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Right',
                                      child: Container(
                                        color: Colors.white,
                                        child: Text('오른쪽 정렬'),
                                      ),
                                    ),
                                  ],
                                );
                                if (selected != null) {
                                  _htmlController.execCommand('justify' + selected);
                                }
                              },
                            );
                          },
                        ),
                        SizedBox(width: 6),
                        // 폰트 크기
                        Builder(
                          builder: (context) {
                            return IconButton(
                              icon: const Icon(Icons.format_size),
                              tooltip: '폰트 크기',
                              onPressed: () async {
                                final RenderBox button = context.findRenderObject() as RenderBox;
                                final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                final Offset position = button.localToGlobal(Offset.zero, ancestor: overlay);
                                final selected = await showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromLTRB(
                                    position.dx,
                                    position.dy - 240, // 메뉴 높이(5*48)만큼 빼서 툴바 바로 위에 정확히 붙도록 조정
                                    position.dx + button.size.width,
                                    position.dy,
                                  ),
                                  items: [
                                    PopupMenuItem(
                                      value: '1',
                                      child: Container(
                                        width: 80,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Text('10pt'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: '2',
                                      child: Container(
                                        width: 80,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Text('12pt'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: '3',
                                      child: Container(
                                        width: 80,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Text('14pt'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: '4',
                                      child: Container(
                                        width: 80,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Text('18pt'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: '5',
                                      child: Container(
                                        width: 80,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Text('24pt'),
                                      ),
                                    ),
                                  ],
                                );
                                if (selected != null) {
                                  _htmlController.execCommand('fontSize', argument: selected);
                                }
                              },
                            );
                          },
                        ),
                        SizedBox(width: 6),
                        // 전체 지우기
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: '전체 지우기',
                          onPressed: () {
                            _htmlController.setText('');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
