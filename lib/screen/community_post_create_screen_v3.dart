import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/peanut_history_service.dart';
import '../community_editor/community_editor.dart';
// any_link_preview는 상세 화면에서 사용. 작성 화면은 직접 메타데이터 파싱 사용
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CommunityPostCreateScreenV3 extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  // deal 게시판 초기 타입: 'buy' | 'sell'
  final String? initialDealType;

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
    this.initialDealType,
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
  static const String _tempHasContentKey = 'temp_post_has_content_v3';

  // 커뮤니티 에디터 컨트롤러
  late CommunityEditorController _editorController;
  // deal 게시판 전용 타입 선택: 'buy' | 'sell' (기본값: 'buy')
  String? _dealType;
  // 판매 정보 입력용 상태 (선택 사항)
  String? _selectedBranchId;
  String? _selectedBranchName;
  double? _selectedLat;
  double? _selectedLng;
  List<Map<String, dynamic>> _branches = [];
  bool _branchesLoading = false;
  // 판매 항목 입력 리스트
  List<Map<String, dynamic>> _tradeItems = [];
  // 상품권 목록 로딩 상태
  List<Map<String, dynamic>> _giftcards = [];
  bool _giftcardsLoading = false;

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

    // 링크 감지 시 메타데이터 조회 후 에디터에 카드 업데이트
    _editorController.onLinkDetected = (link) async {
      try {
        final normalized = link.startsWith('http') ? link : 'https://$link';
        final meta = await _fetchLinkPreviewMeta(normalized);
        // WebView에 미리보기 카드 주입
        final jsonMeta = jsonEncode(meta);
        await _editorController.executeJS(
          'try{ window.communityEditorAPI && window.communityEditorAPI.updateLinkPreview(${jsonEncode(normalized)}, ${jsonMeta}); }catch(e){}',
        );
      } catch (_) {
        // 실패해도 조용히 무시 (에디터 플레이스홀더 유지)
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
    // 초기 진입 시 deal 게시판이면 기본 타입을 설정
    if (_isDealBoard(widget.initialBoardId, widget.initialBoardName)) {
      _dealType = (widget.initialDealType == 'sell' || widget.initialDealType == 'buy')
          ? widget.initialDealType
          : 'buy';
      if (_dealType == 'sell') {
        _ensureBranchesLoaded();
        _ensureGiftcardsLoaded();
        if (_tradeItems.isEmpty) {
          _tradeItems = [
            {
              'giftcardId': '',
              'giftcardName': '',
              'side': 'sell',
              'rate': '',
              'price': '',
              'unitKRW': 100000,
            }
          ];
        }
      }
    }
  }

  bool _isDealBoard(String? boardId, String? boardName) {
    if ((boardId ?? '').toLowerCase() == 'deal') return true;
    final name = (boardName ?? '');
    return name.contains('적립') || name.contains('카드');
  }

  Future<void> _ensureBranchesLoaded() async {
    if (_branchesLoading || _branches.isNotEmpty) return;
    setState(() { _branchesLoading = true; });
    try {
      final snap = await FirebaseFirestore.instance.collection('branches').get();
      final List<Map<String, dynamic>> list = [];
      for (final d in snap.docs) {
        final data = d.data();
        list.add({
          'id': d.id,
          'name': (data['name'] as String?) ?? d.id,
          'latitude': (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null,
          'longitude': (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null,
        });
      }
      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      setState(() { _branches = list; });
    } catch (_) {
    } finally {
      if (mounted) setState(() { _branchesLoading = false; });
    }
  }

  Future<void> _ensureGiftcardsLoaded() async {
    if (_giftcardsLoading || _giftcards.isNotEmpty) return;
    setState(() { _giftcardsLoading = true; });
    try {
      final snap = await FirebaseFirestore.instance.collection('giftcards').get();
      final List<Map<String, dynamic>> list = [];
      for (final d in snap.docs) {
        final data = d.data();
        list.add({
          'id': d.id,
          'name': (data['name'] as String?) ?? d.id,
        });
      }
      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      setState(() { _giftcards = list; });
    } catch (_) {
    } finally {
      if (mounted) setState(() { _giftcardsLoading = false; });
    }
  }

  Future<void> _openBranchSelectSheet() async {
    await _ensureBranchesLoaded();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('지점 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _branchesLoading
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : ListView.separated(
                            itemCount: _branches.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final b = _branches[i];
                              return ListTile(
                                title: Text(b['name'] as String, style: const TextStyle(color: Colors.black)),
                                subtitle: Text(b['id'] as String, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                onTap: () {
                                  setState(() {
                                    _selectedBranchId = b['id'] as String?;
                                    _selectedBranchName = b['name'] as String?;
                                    _selectedLat = b['latitude'] as double?;
                                    _selectedLng = b['longitude'] as double?;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedBranchId = null;
                        _selectedBranchName = null;
                        _selectedLat = null;
                        _selectedLng = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('선택 해제', style: TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _openGiftcardSelectSheetForItem(int index) async {
    await _ensureGiftcardsLoaded();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('상품권', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                Expanded(
                  child: _giftcardsLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : ListView.separated(
                          itemCount: _giftcards.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final g = _giftcards[i];
                            return ListTile(
                              title: Text(g['name'] as String, style: const TextStyle(color: Colors.black)),
                              subtitle: Text(g['id'] as String, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              onTap: () {
                                setState(() {
                                  if (index >= 0 && index < _tradeItems.length) {
                                    _tradeItems[index]['giftcardId'] = g['id'];
                                    _tradeItems[index]['giftcardName'] = g['name'];
                                  }
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (index >= 0 && index < _tradeItems.length) {
                        _tradeItems[index]['giftcardId'] = '';
                        _tradeItems[index]['giftcardName'] = '';
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('선택 해제', style: TextStyle(color: Colors.black87)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapPicker() async {
    LatLng? picked;
    String pickedAddress = '';
    final double initLat = (_selectedLat ?? 37.5665);
    final double initLng = (_selectedLng ?? 126.9780);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('지도에서 위치 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        pickedAddress.isEmpty ? '지도를 탭하여 위치를 선택하세요' : pickedAddress,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: LatLng(initLat, initLng), zoom: 14),
                      myLocationEnabled: false,
                      onTap: (latLng) async {
                        setModalState(() { picked = latLng; });
                        final addr = await _reverseGeocode(latLng.latitude, latLng.longitude);
                        setModalState(() { pickedAddress = addr; });
                      },
                      markers: picked == null
                          ? {}
                          : { Marker(markerId: const MarkerId('picked'), position: picked!) },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소', style: TextStyle(color: Colors.black87)),
                      ),
                      TextButton(
                        onPressed: () {
                          if (picked != null) {
                            setState(() {
                              _selectedLat = picked!.latitude;
                              _selectedLng = picked!.longitude;
                            });
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('선택', style: TextStyle(color: Color(0xFF74512D), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ko');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'MileageThief/1.0 (reverse-geocode)');
      final resp = await req.close();
      if (resp.statusCode != 200) return '';
      final body = await resp.transform(const Utf8Decoder()).join();
      final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
      return (json['display_name'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  void _addTradeItem() {
    setState(() {
      _tradeItems.add({
        'giftcardId': '',
        'side': 'sell',
        'rate': '',
        'price': '',
        'unitKRW': 100000,
      });
    });
  }

  void _removeTradeItem(int index) {
    setState(() {
      if (index >= 0 && index < _tradeItems.length) {
        _tradeItems.removeAt(index);
      }
    });
  }

  // 간단한 메타데이터 수집기 (HTML 파싱 기반)
  Future<Map<String, String>> _fetchLinkPreviewMeta(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Mobile; LinkPreview)');
      final response = await request.close();
      if (response.statusCode != 200) return {};
      final contents = await response.transform(const Utf8Decoder()).join();
      String pickMeta(String pattern) {
        final reg = RegExp(pattern, caseSensitive: false);
        final m = reg.firstMatch(contents);
        return m != null ? (m.group(1) ?? '').trim() : '';
      }
      final title = pickMeta(r'<meta[^>]*property=["\"]og:title["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>')
          .isNotEmpty ? pickMeta(r'<meta[^>]*property=["\"]og:title["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>')
          : pickMeta(r'<title[^>]*>([^<]+)</title>');
      final desc = pickMeta(r'<meta[^>]*property=["\"]og:description["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>')
          .isNotEmpty ? pickMeta(r'<meta[^>]*property=["\"]og:description["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>')
          : pickMeta(r'<meta[^>]*name=["\"]description["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>');
      String image = pickMeta(r'<meta[^>]*property=["\"]og:image["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>');
      final site = pickMeta(r'<meta[^>]*property=["\"]og:site_name["\"][^>]*content=["\"]([^"\"]+)["\"][^>]*>');
      // 상대 경로 이미지 보정
      if (image.isNotEmpty && !image.startsWith('http')) {
        try { image = Uri.parse(url).resolve(image).toString(); } catch (_) {}
      }
      return {
        'title': title,
        'desc': desc,
        'image': image,
        'siteName': site,
      };
    } catch (_) {
      return {};
    }
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

  // 임시저장 (텍스트/게시판만 저장, 본문은 저장하지 않음. 존재 여부만 기록)
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = _editorController.titleController.text.trim();
      // 본문 저장 + 내용 존재 여부 기록
      final html = await _editorController.getHTML();
      final hasBody = html.replaceAll(RegExp(r'\s+'), '').isNotEmpty;
      final boardId = _editorController.postData.boardId;
      final boardName = _editorController.postData.boardName;

      if (title.isNotEmpty) {
        await prefs.setString(_tempTitleKey, title);
        if (boardId != null && boardName != null) {
          await prefs.setString(_tempBoardIdKey, boardId);
          await prefs.setString(_tempBoardNameKey, boardName);
        }
      }
      if (hasBody) {
        await prefs.setString(_tempContentKey, html);
      } else {
        await prefs.remove(_tempContentKey);
      }
      // 본문이 있으면 플래그 기록 (제목이 비어있어도 팝업이 뜨도록)
      await prefs.setBool(_tempHasContentKey, hasBody);

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
    await prefs.remove(_tempHasContentKey);
  }

  // 진입 시 임시저장 확인 팝업
  Future<void> _checkDraftAndPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString(_tempTitleKey) ?? '';
      final hasBody = prefs.getBool(_tempHasContentKey) ?? false;
      final boardId = prefs.getString(_tempBoardIdKey);
      final boardName = prefs.getString(_tempBoardNameKey);
      final has = title.isNotEmpty || hasBody || (boardId != null && boardName != null);
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
    final content = prefs.getString(_tempContentKey) ?? '';
    final boardId = prefs.getString(_tempBoardIdKey);
    final boardName = prefs.getString(_tempBoardNameKey);

    if (title.isNotEmpty) {
      _editorController.titleController.text = title;
    }
    if (content.isNotEmpty) {
      await _editorController.setHTML(content);
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

    // 판매 정보일 때 필수 입력 검증: 항목 1개 이상, giftcardId와 rate/price 중 최소 하나 이상 입력
    if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName) && (_dealType ?? 'buy') == 'sell') {
      if (_tradeItems.isEmpty) {
        Fluttertoast.showToast(msg: "상품권 항목을 1개 이상 입력해주세요");
        return;
      }
      bool invalid = false;
      for (final it in _tradeItems) {
        final gid = (it['giftcardId'] ?? '').toString().trim();
        final rate = (it['rate'] ?? '').toString().trim();
        final price = (it['price'] ?? '').toString().trim();
        if (gid.isEmpty || (rate.isEmpty && price.isEmpty)) { invalid = true; break; }
      }
      if (invalid) {
        Fluttertoast.showToast(msg: "각 항목에 상품권, 퍼센트/가격 중 최소 하나를 입력해주세요");
        return;
      }
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
      // 저장 직전, 에디터 내 오토링크/프리뷰 반영을 강제 동기화
      await _editorController.executeJS('try{ window.communityEditorAPI && window.communityEditorAPI.forceSync && window.communityEditorAPI.forceSync(); }catch(e){}');
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
      // 제목 가공: deal 게시판이라면 타입 라벨 프리픽스 부착 (중복 방지)
      String finalTitle = _editorController.postData.title.trim();
      if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName)) {
        const String buyHeader = '[구매 정보]';
        const String sellHeader = '[판매 정보]';
        if (!finalTitle.startsWith(buyHeader) && !finalTitle.startsWith(sellHeader)) {
          final prefix = (_dealType ?? 'buy') == 'sell' ? '$sellHeader ' : '$buyHeader ';
          finalTitle = prefix + finalTitle;
        }
      }

      if (widget.isEditMode) {
        // 수정 모드에서는 HTML 처리
        final processedHtml = await _editorController.getProcessedHtml();

        postData = {
          'boardId': _editorController.postData.boardId,
          'title': finalTitle,
          'contentHtml': processedHtml.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName)) {
          postData['dealType'] = (_dealType ?? 'buy');
        }
      } else {
        // 새 게시글 모드에서는 HTML 처리
        // postNumber 할당: meta/postNumber 문서의 number 필드를 트랜잭션으로 +1
        final int allocatedPostNumber = await FirebaseFirestore.instance.runTransaction((transaction) async {
          final DocumentReference metaRef = FirebaseFirestore.instance.collection('meta').doc('postNumber');
          final DocumentSnapshot snap = await transaction.get(metaRef);
          final int current = (snap.exists ? ((snap.data() as Map<String, dynamic>?)?['number'] ?? 0) : 0) as int;
          final int next = current + 1;
          transaction.set(metaRef, { 'number': next }, SetOptions(merge: true));
          return next;
        });
        final String postNumberStr = allocatedPostNumber.toString();

        final processedHtml = await _editorController.getProcessedHtml();

        postData = {
          'postId': postId,
          'postNumber': postNumberStr,
          'boardId': _editorController.postData.boardId,
          'title': finalTitle,
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
        if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName)) {
          postData['dealType'] = (_dealType ?? 'buy');
        }
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
          'title': finalTitle,
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
          'title': finalTitle,
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
              'postTitle': finalTitle,
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
      // 판매 정보라면 서브컬렉션 giftcard 문서 작성 (선택된 값 기반)
      try {
        if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName) && (_dealType ?? 'buy') == 'sell') {
          final entryId = FirebaseFirestore.instance.collection('tmp').doc().id;
          final items = _tradeItems.map((it) {
            return {
              'giftcardId': (it['giftcardId'] ?? '').toString().trim(),
              'side': (it['side'] ?? 'sell').toString(),
              'rate': double.tryParse((it['rate'] ?? '').toString()) ?? 0,
              'price': int.tryParse((it['price'] ?? '').toString()) ?? 0,
              'unitKRW': (it['unitKRW'] is int) ? it['unitKRW'] : 100000,
              if (_selectedLat != null) 'latitude': _selectedLat,
              if (_selectedLng != null) 'longitude': _selectedLng,
            };
          }).toList();

          await FirebaseFirestore.instance
              .collection('posts')
              .doc(dateString)
              .collection('posts')
              .doc(postId)
              .collection('giftcard')
              .doc(entryId)
              .set({
            if (_selectedBranchId != null) 'branchId': _selectedBranchId,
            'trade': 'sell',
            'items': items,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('giftcard 서브컬렉션 저장 오류: $e');
      }

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
                      setState(() {
                        if (_isDealBoard(result['boardId'] as String?, result['boardName'] as String?)) {
                          _dealType ??= 'buy';
                        } else {
                          _dealType = null;
                        }
                      });
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

                // deal 게시판 전용: 타입 선택 토글 (구매 정보 / 판매 정보)
                if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Align(
                      alignment: Alignment.center,
                      child: ToggleButtons(
                        borderRadius: const BorderRadius.all(Radius.circular(24)),
                        selectedBorderColor: const Color(0xFF74512D),
                        fillColor: const Color(0x1A74512D),
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 84),
                        isSelected: [
                          (_dealType ?? 'buy') == 'buy',
                          (_dealType ?? 'buy') == 'sell',
                        ],
                        onPressed: (index) {
                          setState(() {
                            _dealType = index == 0 ? 'buy' : 'sell';
                            if (_dealType == 'sell') {
                              _ensureBranchesLoaded();
                              _ensureGiftcardsLoaded();
                              if (_tradeItems.isEmpty) {
                                _tradeItems = [
                                  {
                                    'giftcardId': '',
                                    'giftcardName': '',
                                    'side': 'sell',
                                    'rate': '',
                                    'price': '',
                                    'unitKRW': 100000,
                                  }
                                ];
                              }
                            }
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text('구매 정보', style: TextStyle(color: Colors.black)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text('판매 정보', style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // deal 게시판 전용: 안내 문구
                if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        (_dealType ?? 'buy') == 'buy'
                            ? '상품권 구매 링크 혹은 정보를 공유하는 타입입니다.'
                            : '특정 상품권 매장에서 얼마에 팔았는지 혹은 판매 정보입니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                // 판매 정보일 때만: 매장 라벨
                if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName) && (_dealType ?? 'buy') == 'sell')
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('매장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    ),
                  ),

                // deal = 판매 정보일 때만: 지점 선택 + 좌표 선택 진입
                if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName) && (_dealType ?? 'buy') == 'sell')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openBranchSelectSheet,
                            icon: const Icon(Icons.store_mall_directory_outlined, size: 18, color: Colors.black87),
                            label: Text(
                              _selectedBranchName == null ? '지점 선택(선택 사항)' : _selectedBranchName!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 판매 정보일 때만: 상품권 항목 입력 (필수 최소 1개)
                if (_isDealBoard(_editorController.postData.boardId, _editorController.postData.boardName) && (_dealType ?? 'buy') == 'sell')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('상품권', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 8),
                        ...List.generate(_tradeItems.length, (i) {
                          final item = _tradeItems[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                // giftcard 선택 버튼 (목록에서 선택)
                                Expanded(
                                  flex: 32,
                                  child: OutlinedButton(
                                    onPressed: () => _openGiftcardSelectSheetForItem(i),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      side: const BorderSide(color: Colors.black26),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        (item['giftcardName'] as String?)?.isNotEmpty == true
                                            ? '${item['giftcardName']} (${item['giftcardId']})'
                                            : '상품권 선택',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // rate
                                Expanded(
                                  flex: 22,
                                  child: TextField(
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    controller: TextEditingController(text: item['rate']?.toString() ?? '')
                                      ..selection = TextSelection.collapsed(offset: (item['rate']?.toString() ?? '').length),
                                    onChanged: (v) => item['rate'] = v,
                                    cursorColor: const Color(0xFF74512D),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: '퍼센트',
                                      hintStyle: TextStyle(fontSize: 12, color: Colors.black45),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFF74512D), width: 2),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.black26),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // price
                                Expanded(
                                  flex: 28,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    controller: TextEditingController(text: item['price']?.toString() ?? '')
                                      ..selection = TextSelection.collapsed(offset: (item['price']?.toString() ?? '').length),
                                    onChanged: (v) => item['price'] = v,
                                    cursorColor: const Color(0xFF74512D),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: '가격(원)',
                                      hintStyle: TextStyle(fontSize: 12, color: Colors.black45),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFF74512D), width: 2),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.black26),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // unit (라운드/화이트 스타일 드롭다운)
                                DropdownButtonHideUnderline(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.black26),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: DropdownButton<int>(
                                      value: (item['unitKRW'] as int?) ?? 100000,
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                                      style: const TextStyle(color: Colors.black87),
                                      isDense: true,
                                      items: const [
                                        DropdownMenuItem(value: 50000, child: Text('5만', style: TextStyle(color: Colors.black))),
                                        DropdownMenuItem(value: 100000, child: Text('10만', style: TextStyle(color: Colors.black))),
                                        DropdownMenuItem(value: 500000, child: Text('50만', style: TextStyle(color: Colors.black))),
                                      ],
                                      onChanged: (v) => setState(() { item['unitKRW'] = v ?? 100000; }),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _removeTradeItem(i),
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.black54, size: 20),
                                ),
                              ],
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _addTradeItem,
                            icon: const Icon(Icons.add, size: 18, color: Colors.black87),
                            label: const Text('항목 추가', style: TextStyle(color: Colors.black87)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
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
