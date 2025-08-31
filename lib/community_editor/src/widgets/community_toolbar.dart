import 'package:flutter/material.dart';
import '../controllers/community_editor_controller.dart';

/// 커뮤니티 에디터용 툴바 위젯입니다.
/// 내용 필드에 포커스가 있을 때 키보드 위에 표시됩니다.
class CommunityToolbar extends StatefulWidget {
  final CommunityEditorController controller;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onImagePick;

  const CommunityToolbar({
    Key? key,
    required this.controller,
    this.onSaveDraft,
    this.onImagePick,
  }) : super(key: key);

  @override
  State<CommunityToolbar> createState() => _CommunityToolbarState();
}

class _CommunityToolbarState extends State<CommunityToolbar> {
  // 확장된 툴바 상태
  bool _showExtendedToolbar = false;
  
  // 포맷 상태 (토글용)
  Map<String, bool> _formatState = {
    'bold': false,
    'italic': false,
    'underline': false,
    'insertUnorderedList': false,
  };
  
  // 선택된 색상과 폰트 크기 상태 (기본값 설정)
  Color? _selectedColor = Colors.black; // 기본 검은색
  int? _selectedFontSize = 16; // 기본 16px
  String? _selectedAlignment;
  
  // 색상 팔레트
  final List<Color> _colorPalette = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    const Color(0xFF74512D), // 브랜드 색상
  ];
  
  // 폰트 크기 옵션
  final List<int> _fontSizes = [8, 10, 12, 14, 16, 18, 20, 24, 36];
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        // 컨트롤러에서 포맷 상태 업데이트
        final formatState = widget.controller.state.formatState;
        if (formatState != null) {
          _formatState = Map<String, bool>.from(formatState);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 확장된 툴바 (색상, 폰트 크기, 정렬 등)
        if (_showExtendedToolbar) _buildExtendedToolbar(),
        
        // 기본 툴바
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진 첨부 버튼 (맨 왼쪽)
              IconButton(
                onPressed: widget.onImagePick ?? widget.controller.pickImages,
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: '사진 첨부',
                color: Colors.grey[700],
              ),
              // 동영상 첨부 버튼 (카메라 버튼 우측)
              IconButton(
                onPressed: widget.controller.pickVideo,
                icon: const Icon(Icons.videocam_outlined),
                tooltip: '동영상 첨부 (mp4)',
                color: Colors.grey[700],
              ),
              
              // 볼드 버튼
              _buildToggleButton(
                icon: Icons.format_bold,
                tooltip: '굵게',
                isActive: _formatState['bold'] ?? false,
                onPressed: () => widget.controller.applyTextFormat('bold'),
              ),
              
              // 이탤릭 버튼
              _buildToggleButton(
                icon: Icons.format_italic,
                tooltip: '기울임',
                isActive: _formatState['italic'] ?? false,
                onPressed: () => widget.controller.applyTextFormat('italic'),
              ),
              
              // 언더라인 버튼 (이탤릭 우측)
              _buildToggleButton(
                icon: Icons.format_underlined,
                tooltip: '밑줄',
                isActive: _formatState['underline'] ?? false,
                onPressed: () => widget.controller.applyTextFormat('underline'),
              ),
              
              // 리스트 버튼
              _buildToggleButton(
                icon: Icons.format_list_bulleted,
                tooltip: '목록',
                isActive: _formatState['insertUnorderedList'] ?? false,
                onPressed: () => widget.controller.insertList(ordered: false),
              ),
              
              // 더보기 버튼
              IconButton(
                onPressed: () {
                  setState(() {
                    _showExtendedToolbar = !_showExtendedToolbar;
                  });
                },
                icon: Icon(_showExtendedToolbar ? Icons.expand_more : Icons.expand_less),
                tooltip: '더보기',
                color: Colors.grey[700],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 확장된 툴바를 빌드합니다.
  Widget _buildExtendedToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100], // 기본 툴바와 동일한 색상
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // 색상 팔레트
          Row(
            children: [
              const Text('색상: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _colorPalette.map((color) => 
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                          widget.controller.applyTextColor(color);
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: _selectedColor == color 
                                ? const Color(0xFF74512D) 
                                : Colors.grey[300]!,
                              width: _selectedColor == color ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _selectedColor == color ? [
                              BoxShadow(
                                color: const Color(0xFF74512D).withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 2,
                              )
                            ] : null,
                          ),
                          child: _selectedColor == color 
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 폰트 크기와 정렬
          Row(
            children: [
              // 폰트 크기
              const Text('크기: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fontSizes.length,
                    itemBuilder: (context, index) {
                      final fontSize = _fontSizes[index];
                      final isSelected = _selectedFontSize == fontSize;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFontSize = fontSize;
                          });
                          widget.controller.applyFontSize(fontSize);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected 
                                ? const Color(0xFF74512D) 
                                : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            color: isSelected 
                              ? const Color(0xFF74512D).withOpacity(0.1) 
                              : Colors.white,
                          ),
                          child: Text(
                            '$fontSize',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected 
                                ? const Color(0xFF74512D) 
                                : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 정렬 버튼들
          Row(
            children: [
              const Text('정렬: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    _buildAlignmentButton(Icons.format_align_left, '왼쪽 정렬', 'left'),
                    _buildAlignmentButton(Icons.format_align_center, '가운데 정렬', 'center'),
                    _buildAlignmentButton(Icons.format_align_right, '오른쪽 정렬', 'right'),
                    _buildAlignmentButton(Icons.format_align_justify, '양쪽 정렬', 'justify'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 토글 버튼을 빌드합니다.
  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF74512D).withOpacity(0.15) : Colors.transparent,
        shape: BoxShape.circle, // 동그라미 모양
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        color: isActive ? const Color(0xFF74512D) : Colors.grey[700],
        splashRadius: 20, // 터치 효과 반경 조정
      ),
    );
  }
  
  /// 정렬 버튼을 빌드합니다.
  Widget _buildAlignmentButton(IconData icon, String tooltip, String alignment) {
    final isSelected = _selectedAlignment == alignment;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF74512D).withOpacity(0.15) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {
          setState(() {
            _selectedAlignment = alignment;
          });
          widget.controller.applyTextAlignment(alignment);
        },
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        color: isSelected ? const Color(0xFF74512D) : Colors.grey[700],
        splashRadius: 20,
      ),
    );
  }
  
  /// 폰트 크기 선택 다이얼로그를 표시합니다.
  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '폰트 크기 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2,
                ),
                itemCount: _fontSizes.length,
                itemBuilder: (context, index) {
                  final fontSize = _fontSizes[index];
                  return GestureDetector(
                    onTap: () {
                      widget.controller.applyFontSize(fontSize);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          '$fontSize',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 색상 선택 다이얼로그를 표시합니다.
  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '텍스트 색상 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 기본 색상들
            const Text('기본 색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorPalette.map((color) => 
                GestureDetector(
                  onTap: () {
                    widget.controller.applyTextColor(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // 추가 색상들
            const Text('추가 색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Colors.pink,
                Colors.cyan,
                Colors.lime,
                Colors.amber,
                Colors.deepOrange,
                Colors.teal,
                Colors.brown,
                Colors.grey,
              ].map((color) => 
                GestureDetector(
                  onTap: () {
                    widget.controller.applyTextColor(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 정렬 선택 다이얼로그를 표시합니다.
  void _showAlignmentPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '텍스트 정렬',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _alignmentButton(Icons.format_align_left, '왼쪽 정렬', 'left'),
                _alignmentButton(Icons.format_align_center, '가운데 정렬', 'center'),
                _alignmentButton(Icons.format_align_right, '오른쪽 정렬', 'right'),
                _alignmentButton(Icons.format_align_justify, '양쪽 정렬', 'justify'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _alignmentButton(IconData icon, String label, String alignment) {
    return GestureDetector(
      onTap: () {
        widget.controller.applyTextAlignment(alignment);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Icon(icon, size: 24, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }


}
