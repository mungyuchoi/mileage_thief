import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/user_service.dart';

/// 상품권 지점 리뷰 상세/작성 화면
/// 구조는 community_detail_screen.dart의 댓글 구조를 최대한 재사용하되,
///  - 컬렉션: branches/{branchId}/comments
///  - 사용자 로그: users/{uid}/branch_comments
/// 로 분리해서 관리한다.
class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchDetailScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _branch;

  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _isAddingComment = false;

  bool _isLoading = true;
  bool _isLoadingComments = true;
  bool _isLoadingEvents = true;
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  bool _isEventManager = false;

  String _commentSortOrder = '등록순';

  @override
  void initState() {
    super.initState();
    _loadBranch();
    _loadComments();
    _loadUserRole();
    _loadEvents();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadBranch() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .get();
      if (doc.exists) {
        setState(() {
          _branch = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoadingComments = true;
      });

      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .orderBy('createdAt', descending: _commentSortOrder == '최신순')
          .get();

      final list = snap.docs
          .map<Map<String, dynamic>>(
            (d) => <String, dynamic>{'commentId': d.id, ...d.data()},
          )
          .toList();

      setState(() {
        _comments = list;
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('브랜치 댓글 로드 오류: $e');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// 현재 사용자 role 로드 (admin, branch 여부 확인)
  Future<void> _loadUserRole() async {
    if (_currentUser == null) {
      setState(() {
        _isEventManager = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? userData =
          await UserService.getUserFromFirestore(_currentUser!.uid);
      final List<dynamic> rawRoles =
          (userData?['roles'] as List<dynamic>?) ?? const <dynamic>['user'];

      // roles 예시:
      // - ['user']
      // - ['user', 'admin']          → 전체 지점 관리 가능
      // - ['user', 'branch']         → 전체 지점 이벤트 관리 가능
      // - ['user', 'jungang']        → jungang 지점만 이벤트 관리 가능 (branchId 직접 사용)
      final List<String> roles = rawRoles.map((e) => e.toString()).toList();

      final bool isAdmin = roles.contains('admin');
      final bool isGlobalBranchManager = roles.contains('branch');
      // branchId 자체가 roles 안에 있으면 해당 지점의 오너로 취급
      final bool isBranchOwnerById = roles.contains(widget.branchId);

      final bool isManager =
          isAdmin || isGlobalBranchManager || isBranchOwnerById;

      setState(() {
        _isEventManager = isManager;
      });
    } catch (e) {
      debugPrint('사용자 권한 로드 오류: $e');
      setState(() {
        _isEventManager = false;
      });
    }
  }

  /// 지점별 진행 중인 이벤트 로드
  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoadingEvents = true;
      });

      final QuerySnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('branches')
              .doc(widget.branchId)
              .collection('events')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

      final List<Map<String, dynamic>> list = snap.docs
          .map<Map<String, dynamic>>(
            (d) => <String, dynamic>{'eventId': d.id, ...d.data()},
          )
          .toList();

      setState(() {
        _events = list;
        _isLoadingEvents = false;
      });
    } catch (e) {
      debugPrint('브랜치 이벤트 로드 오류: $e');
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  /// 브랜치 댓글용 이미지 업로드
  /// Storage 경로: branches/{branchId}/comments/{commentId}/images/{fileName}.jpg
  Future<String?> _uploadImage(File imageFile, String commentId) async {
    try {
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(
            bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }

      if (!await imageFile.exists()) {
        return null;
      }

      final fileName =
          '${commentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath =
          'branches/${widget.branchId}/comments/$commentId/images/$fileName';

      final storageRef = storage.ref().child(storagePath);
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      debugPrint('브랜치 댓글 이미지 업로드 오류: $e');
      return null;
    }
  }

  /// 이벤트 생성 다이얼로그
  Future<void> _showCreateEventDialog() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (!_isEventManager) {
      Fluttertoast.showToast(msg: '이벤트를 생성할 수 있는 권한이 없습니다.');
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController peanutController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '이벤트 추가',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트명',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '예) 중앙상품권 5월 이벤트',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트 비밀번호',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '참여 시 입력할 비밀번호',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: peanutController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '땅콩 개수 (최대 100개)',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '1~100 사이 숫자를 입력하세요.',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '추가',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final String name = nameController.text.trim();
    final String password = passwordController.text.trim();
    final String peanutText = peanutController.text.trim();

    if (name.isEmpty || password.isEmpty || peanutText.isEmpty) {
      Fluttertoast.showToast(msg: '이벤트명, 비밀번호, 땅콩 개수를 모두 입력해주세요.');
      return;
    }

    final int? peanutCount = int.tryParse(peanutText);
    if (peanutCount == null || peanutCount <= 0 || peanutCount > 100) {
      Fluttertoast.showToast(msg: '땅콩 개수는 1~100 사이의 숫자만 가능합니다.');
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> eventRef =
          FirebaseFirestore.instance
              .collection('branches')
              .doc(widget.branchId)
              .collection('events')
              .doc();

      await eventRef.set(<String, dynamic>{
        'name': name,
        'password': password,
        'peanutCount': peanutCount,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'branchId': widget.branchId,
      });

      await _loadEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이벤트가 추가되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('이벤트 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이벤트 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 이벤트 참여 다이얼로그
  Future<void> _showJoinEventDialog() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (_events.isEmpty) {
      Fluttertoast.showToast(msg: '현재 진행 중인 이벤트가 없습니다.');
      return;
    }

    final TextEditingController passwordController = TextEditingController();
    String selectedEventId = _events.first['eventId'] as String;
    Map<String, dynamic> selectedEvent = _events.first;
    bool isProcessing = false;
    bool hasJoined = false;

    Future<void> checkAndJoin(
      BuildContext dialogContext,
      void Function(void Function()) setStateDialog,
    ) async {
      if (isProcessing || hasJoined) return;

      final String inputPassword = passwordController.text.trim();
      if (inputPassword.isEmpty) {
        Fluttertoast.showToast(msg: '비밀번호를 입력해주세요.');
        return;
      }

      setStateDialog(() {
        isProcessing = true;
      });

      try {
        final String? savedPassword =
            selectedEvent['password'] as String?;
        if (savedPassword == null || savedPassword.isEmpty) {
          Fluttertoast.showToast(msg: '이벤트 정보가 올바르지 않습니다.');
          setStateDialog(() {
            isProcessing = false;
          });
          return;
        }

        // 비밀번호 검증
        if (inputPassword != savedPassword) {
          Fluttertoast.showToast(msg: '비밀번호가 잘못 입력되었습니다.');
          setStateDialog(() {
            isProcessing = false;
          });
          return;
        }

        final int peanutCount =
            (selectedEvent['peanutCount'] as int?) ?? 0;
        if (peanutCount <= 0) {
          Fluttertoast.showToast(msg: '유효하지 않은 땅콩 개수입니다.');
          setStateDialog(() {
            isProcessing = false;
          });
          return;
        }

        // 이미 참여했는지 확인
        final DocumentReference<Map<String, dynamic>> userEventRef =
            FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .collection('events')
                .doc(selectedEventId);

        final DocumentSnapshot<Map<String, dynamic>> userEventDoc =
            await userEventRef.get();

        if (userEventDoc.exists) {
          Fluttertoast.showToast(msg: '이미 참여한 이벤트입니다.');
          setStateDialog(() {
            hasJoined = true;
            isProcessing = false;
          });
          return;
        }

        // 현재 땅콩 개수 조회 후 업데이트
        final Map<String, dynamic>? userData =
            await UserService.getUserFromFirestore(_currentUser!.uid);
        final int currentPeanuts =
            (userData?['peanutCount'] as int?) ?? 0;
        final int newPeanuts = currentPeanuts + peanutCount;

        await UserService.updatePeanutCount(
          _currentUser!.uid,
          newPeanuts,
        );

        // 유저 이벤트 참여 기록 저장
        await userEventRef.set(<String, dynamic>{
          'branchId': widget.branchId,
          'eventId': selectedEventId,
          'eventName': selectedEvent['name'] ?? '',
          'joined': true,
          'peanutCount': peanutCount,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        setStateDialog(() {
          hasJoined = true;
          isProcessing = false;
        });

        Navigator.of(dialogContext).pop();

        Fluttertoast.showToast(
          msg: '이벤트 참여를 통해 땅콩 $peanutCount개를 받았습니다.',
        );
      } catch (e) {
        debugPrint('이벤트 참여 오류: $e');
        Fluttertoast.showToast(
          msg: '이벤트 참여 중 오류가 발생했습니다.',
        );
        setStateDialog(() {
          isProcessing = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '이벤트 참여',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이벤트 선택',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedEventId,
                      isExpanded: true,
                      items: _events.map((Map<String, dynamic> e) {
                        return DropdownMenuItem<String>(
                          value: e['eventId'] as String,
                          child: Text(
                            (e['name'] as String?) ?? '이벤트',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        final Map<String, dynamic>? selected =
                            _events.firstWhere(
                          (Map<String, dynamic> e) =>
                              e['eventId'] == value,
                          orElse: () => <String, dynamic>{},
                        );
                        if (selected == null || selected.isEmpty) {
                          return;
                        }
                        setStateDialog(() {
                          selectedEventId = value;
                          selectedEvent = selected;
                          hasJoined = false;
                          passwordController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!hasJoined) ...[
                      const Text(
                        '비밀번호 입력',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        enabled: !isProcessing,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: '이벤트 비밀번호를 입력하세요.',
                          hintStyle: TextStyle(color: Colors.black38),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        '이미 참여한 이벤트입니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                if (!hasJoined)
                  TextButton(
                    onPressed: isProcessing
                        ? null
                        : () => checkAndJoin(dialogContext, setStateDialog),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            '참여하기',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitComment() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    final content = _commentController.text.trim();
    if (content.isEmpty && _selectedImage == null) {
      Fluttertoast.showToast(msg: '내용을 입력하거나 이미지를 첨부해주세요.');
      return;
    }

    try {
      setState(() {
        _isAddingComment = true;
      });

      final commentRef = FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc();
      String contentHtml = content;
      final List<Map<String, dynamic>> attachments = <Map<String, dynamic>>[];

      // 이미지가 있으면 업로드
      if (_selectedImage != null) {
        final String? imageUrl =
            await _uploadImage(_selectedImage!, commentRef.id);
        if (imageUrl != null) {
          contentHtml +=
              '<br><img src="$imageUrl" alt="첨부이미지" style="max-width: 100%; border-radius: 8px;" />';
          attachments.add(<String, dynamic>{
            'type': 'image',
            'url': imageUrl,
            'filename':
                'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          });
        }
      }

      // 최신 사용자 정보 가져오기 (프로필 이미지/닉네임)
      final Map<String, dynamic>? userData =
          await UserService.getUserFromFirestore(_currentUser!.uid);
      final String displayName =
          (userData?['displayName'] as String?) ??
              _currentUser!.displayName ??
              '사용자';
      final String profileImageUrl =
          (userData?['photoURL'] as String?) ??
              (_currentUser!.photoURL ?? '');

      final Map<String, dynamic> data = <String, dynamic>{
        'authorId': _currentUser!.uid,
        'authorDisplayName': displayName,
        'authorPhotoURL': profileImageUrl,
        'profileImageUrl': profileImageUrl,
        'contentHtml':
            contentHtml.isEmpty ? '<p>이미지</p>' : '<p>$contentHtml</p>',
        'contentType': 'html',
        'attachments': attachments,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isHidden': false,
        'reportsCount': 0,
        'likesCount': 0,
        'plainText': content,
        'branchId': widget.branchId,
      };

      // (이미지 업로드는 후속으로 확장 가능; 여기서는 구조만 맞춰둔다)

      await commentRef.set(data);

      // 사용자 branch_comments 서브컬렉션에 기록
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('branch_comments')
          .doc(commentRef.id)
          .set(<String, dynamic>{
        'commentPath':
            'branches/${widget.branchId}/comments/${commentRef.id}',
        'branchId': widget.branchId,
        'branchName': widget.branchName,
        'contentHtml': data['contentHtml'],
        'contentType': data['contentType'],
        'attachments': attachments,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _removeSelectedImage();

      await _loadComments();

      setState(() {
        _isAddingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰가 등록되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('브랜치 댓글 등록 오류: $e');
      setState(() {
        _isAddingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리뷰 등록 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBranchHeader() {
    final Map<String, dynamic>? b = _branch;
    if (b == null) {
      return const SizedBox.shrink();
    }
    final String? address = b['address'] as String?;
    final String? phone = b['phone'] as String?;
    final Map<String, dynamic>? openingHours =
        b['openingHours'] is Map ? Map<String, dynamic>.from(b['openingHours']) : null;
    final String? notice = b['notice'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 20, color: Color(0xFF74512D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.branchName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(phone,
                    style: const TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
          if (openingHours != null && openingHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '영업시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            for (final entry in openingHours.entries)
              Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
          ],
          if (notice != null && notice.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '안내',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              notice,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final String displayName =
        (comment['authorDisplayName'] as String?) ?? '익명';
    final String content =
        (comment['plainText'] as String?) ?? '내용 없음';
    final Timestamp? createdAtTs = comment['createdAt'] as Timestamp?;
    final DateTime createdAt =
        createdAtTs?.toDate() ?? DateTime.now();

    final List<dynamic> rawAttachments =
        (comment['attachments'] as List<dynamic>?) ?? const [];
    final List<Map<String, dynamic>> imageAttachments = rawAttachments
        .whereType<Map<String, dynamic>>()
        .where((a) => (a['type'] == 'image') && (a['url'] != null))
        .toList();

    final bool isMyComment =
        _currentUser != null && comment['authorId'] == _currentUser!.uid;

    final String? photoUrl =
        (comment['authorPhotoURL'] ??
                comment['profileImageUrl']) as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0x1174512D),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF74512D),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                DateFormat('yyyy.MM.dd').format(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                ),
              ),
              if (isMyComment) _buildCommentMoreOptions(comment),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          if (imageAttachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageAttachments.first['url'] as String,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentMoreOptions(Map<String, dynamic> comment) {
    if (_currentUser == null ||
        comment['authorId'] != _currentUser!.uid) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[500]),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (String value) {
        switch (value) {
          case 'edit':
            _editComment(comment);
            break;
          case 'delete':
            _deleteComment(comment);
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
              SizedBox(width: 12),
              Text('수정하기'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('삭제하기', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final String? commentId = comment['commentId'] as String?;
    if (commentId == null) return;

    final TextEditingController controller = TextEditingController(
      text: (comment['plainText'] as String?) ?? '',
    );

    final String? newText = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '리뷰 수정',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            minLines: 1,
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              hintText: '리뷰 내용을 수정하세요.',
              hintStyle: TextStyle(color: Colors.black38),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (newText == null || newText.isEmpty) return;

    try {
      final String html = '<p>$newText</p>';

      // branches/{branchId}/comments
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc(commentId)
          .update(<String, dynamic>{
        'plainText': newText,
        'contentHtml': html,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // users/{uid}/branch_comments
      if (_currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('branch_comments')
            .doc(commentId)
            .update(<String, dynamic>{
          'contentHtml': html,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _loadComments();
    } catch (e) {
      debugPrint('브랜치 댓글 수정 오류: $e');
      Fluttertoast.showToast(
        msg: '리뷰 수정 중 오류가 발생했습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final String? commentId = comment['commentId'] as String?;
    if (commentId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '리뷰 삭제',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '해당 리뷰를 삭제하시겠습니까?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      // 1) 댓글 문서를 먼저 읽어서 첨부 이미지 목록 확보
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc(commentId)
          .get();

      final List<dynamic> attachments =
          (doc.data()?['attachments'] as List<dynamic>?) ?? const [];

      // 2) Firestore에서 댓글 / 사용자 로그 삭제
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (_currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('branch_comments')
            .doc(commentId)
            .delete();
      }

      // 3) Storage 이미지 삭제 (type == image 인 첨부만)
      for (final dynamic raw in attachments) {
        if (raw is! Map<String, dynamic>) continue;
        if (raw['type'] != 'image') continue;
        final String? url = raw['url'] as String?;
        if (url == null || url.isEmpty) continue;
        try {
          final Reference ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint('브랜치 댓글 이미지 삭제 오류: $e');
        }
      }

      await _loadComments();

      Fluttertoast.showToast(
        msg: '리뷰가 삭제되었습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      debugPrint('브랜치 댓글 삭제 오류: $e');
      Fluttertoast.showToast(
        msg: '리뷰 삭제 중 오류가 발생했습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Widget _buildCommentsSection() {
    if (_isLoadingComments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '아직 등록된 리뷰가 없습니다.\n첫 리뷰를 남겨주세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _removeSelectedImage,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined,
                      color: Color(0xFF74512D)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: '지점 이용 후기를 남겨주세요.',
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _isAddingComment ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isAddingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '리뷰 등록',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: Text(widget.branchName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_isEventManager)
            IconButton(
              icon: const Icon(Icons.event_available_outlined),
              tooltip: '이벤트 추가',
              onPressed: _showCreateEventDialog,
            ),
          if (!_isLoadingEvents && _events.isNotEmpty)
            TextButton(
              onPressed: _showJoinEventDialog,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF74512D),
              ),
              child: const Text(
                '이벤트 참여',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBranchHeader(),
                      const SizedBox(height: 16),
                      const Text(
                        '리뷰',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCommentsSection(),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildCommentInput(),
                ),
              ],
            ),
    );
  }
}


