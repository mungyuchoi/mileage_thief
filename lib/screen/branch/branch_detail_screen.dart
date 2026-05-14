import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../const/colors.dart';
import '../../services/user_service.dart';
import '../../widgets/segment_tab_bar.dart';
import '../community_detail_screen.dart';
import 'branch_event_manage_screen.dart';

/// 상품권 지점 통합 상세 화면.
///
/// 지점 기본 정보, 취급 상품권, 시세 차트, 리뷰, 관련 커뮤니티 글을
/// 하나의 탭 기반 상세 화면에서 보여준다.
class BranchDetailScreen extends StatefulWidget {
  final String branchId;

  /// 최초 진입 시 표시할 지점 이름. 생략하면 Firestore의 branches/{branchId}.name을 사용한다.
  final String? branchName;

  const BranchDetailScreen({
    super.key,
    required this.branchId,
    this.branchName,
  });

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = <String>[
    '홈',
    '취급 상품권',
    '시세·차트',
    '리뷰',
    '정보',
  ];

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final NumberFormat _won = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy.MM.dd');
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _commentController = TextEditingController();

  late final TabController _tabController;

  int _selectedTabIndex = 0;
  Map<String, dynamic>? _branch;
  List<_BranchRateRow> _rates = <_BranchRateRow>[];
  List<_DailyRateSnapshot> _dailyRates = <_DailyRateSnapshot>[];
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  List<_RelatedPost> _relatedPosts = <_RelatedPost>[];
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  bool _isLoadingBranch = true;
  bool _isLoadingRates = true;
  bool _isLoadingComments = true;
  bool _isLoadingRelatedPosts = true;
  bool _isLoadingEvents = true;
  bool _isEventManager = false;
  bool _isAddingComment = false;
  File? _selectedImage;

  String get _effectiveBranchName {
    final data = _branch;
    final fromBranch = data == null
        ? null
        : (data['name'] as String? ?? data['title'] as String?);
    return fromBranch ?? widget.branchName ?? widget.branchId;
  }

  bool get _isOfficialBranch {
    final data = _branch;
    if (data == null) return false;
    return data['verified'] == true || data['isOfficialPartner'] == true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadBranch();
    _loadRates();
    _loadComments();
    _loadUserRole();
    _loadEvents();
    _loadRelatedPosts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_selectedTabIndex == _tabController.index) return;
    setState(() {
      _selectedTabIndex = _tabController.index;
    });
  }

  Future<void> _loadBranch() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .get();
      if (!mounted) return;
      setState(() {
        _branch = doc.data();
        _isLoadingBranch = false;
      });
    } catch (e) {
      debugPrint('지점 정보 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingBranch = false;
      });
    }
  }

  Future<void> _loadRates() async {
    try {
      final branchRef = FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 59));
      final startKey = DateFormat('yyyyMMdd').format(start);
      final endKey = DateFormat('yyyyMMdd').format(now);

      final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
        branchRef.collection('giftcardRates_current').get(),
        branchRef
            .collection('rates_daily')
            .orderBy(FieldPath.documentId)
            .startAt([startKey]).endAt([endKey]).get(),
        FirebaseFirestore.instance.collection('giftcards').get(),
      ]);

      final ratesSnap = results[0];
      final dailySnap = results[1];
      final giftcardsSnap = results[2];

      final giftcards = <String, Map<String, dynamic>>{
        for (final doc in giftcardsSnap.docs) doc.id: doc.data(),
      };

      final rates = ratesSnap.docs.map((doc) {
        final data = doc.data();
        final giftcardId = (data['giftcardId'] as String?) ?? doc.id;
        return _BranchRateRow(
          giftcardId: giftcardId,
          giftcardName:
              (giftcards[giftcardId]?['name'] as String?) ?? giftcardId,
          data: data,
        );
      }).toList()
        ..sort((a, b) {
          final aOrder =
              (giftcards[a.giftcardId]?['sortOrder'] as num?)?.toInt() ?? 999;
          final bOrder =
              (giftcards[b.giftcardId]?['sortOrder'] as num?)?.toInt() ?? 999;
          final order = aOrder.compareTo(bOrder);
          return order != 0 ? order : a.giftcardName.compareTo(b.giftcardName);
        });

      final dailyRates = dailySnap.docs
          .map((doc) => _DailyRateSnapshot.fromFirestore(doc))
          .whereType<_DailyRateSnapshot>()
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;
      setState(() {
        _rates = rates;
        _dailyRates = dailyRates;
        _isLoadingRates = false;
      });
    } catch (e) {
      debugPrint('지점 시세 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingRates = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      final comments = snap.docs
          .map<Map<String, dynamic>>(
            (doc) => <String, dynamic>{'commentId': doc.id, ...doc.data()},
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('지점 리뷰 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _loadRelatedPosts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('posts')
          .where('entityRefs.branchId', isEqualTo: widget.branchId)
          .where('isDeleted', isEqualTo: false)
          .where('isHidden', isEqualTo: false)
          .limit(8)
          .get();

      final posts = snap.docs
          .map(_RelatedPost.fromFirestore)
          .whereType<_RelatedPost>()
          .toList()
        ..sort((a, b) {
          final created = b.createdAt.compareTo(a.createdAt);
          if (created != 0) return created;
          return b.commentCount.compareTo(a.commentCount);
        });

      if (!mounted) return;
      setState(() {
        _relatedPosts = posts;
        _isLoadingRelatedPosts = false;
      });
    } catch (e) {
      debugPrint('관련 게시글 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingRelatedPosts = false;
      });
    }
  }

  Future<void> _loadUserRole() async {
    if (_currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isEventManager = false;
      });
      return;
    }

    try {
      final userData =
          await UserService.getUserFromFirestore(_currentUser!.uid);
      final rawRoles =
          (userData?['roles'] as List<dynamic>?) ?? const <dynamic>['user'];
      final roles = rawRoles.map((e) => e.toString()).toList();
      final isAdmin = roles.contains('admin');
      final isGlobalBranchManager = roles.contains('branch');
      final isBranchOwnerById = roles.contains(widget.branchId);

      if (!mounted) return;
      setState(() {
        _isEventManager = isAdmin || isGlobalBranchManager || isBranchOwnerById;
      });
    } catch (e) {
      debugPrint('지점 이벤트 권한 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isEventManager = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('events')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final events = snap.docs
          .map<Map<String, dynamic>>(
            (doc) => <String, dynamic>{'eventId': doc.id, ...doc.data()},
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      debugPrint('지점 이벤트 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  String _formatWon(num? value) {
    if (value == null) return '-';
    return '${_won.format(value)}원';
  }

  String _formatRate(double? value) {
    if (value == null) return '-';
    final text = value.toStringAsFixed(2);
    if (text.endsWith('00')) return text.substring(0, text.length - 3);
    if (text.endsWith('0')) return text.substring(0, text.length - 1);
    return text;
  }

  double? _feeRateFromPrice(num? price, {num faceValue = 100000}) {
    if (price == null || faceValue == 0) return null;
    return ((faceValue.toDouble() - price.toDouble()) / faceValue.toDouble()) *
        100;
  }

  String _timestampText(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('yyyy.MM.dd HH:mm').format(value.toDate());
    }
    return '';
  }

  Future<void> _launchPhone(String? phone) async {
    final value = phone?.trim();
    if (value == null || value.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: value));
  }

  Future<void> _launchExternalUrl(String? rawUrl) async {
    var value = rawUrl?.trim();
    if (value == null || value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMap() async {
    final data = _branch;
    if (data == null) return;
    final lat = (data['latitude'] as num?)?.toDouble() ??
        (data['lat'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble() ??
        (data['lng'] as num?)?.toDouble();
    final address = (data['address'] as String?)?.trim();

    Uri? uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    } else if (address != null && address.isNotEmpty) {
      uri = Uri.https('maps.google.com', '/', {'q': address});
    }
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
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

  Future<String?> _uploadImage(File imageFile, String commentId) async {
    try {
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(
          bucket: 'mileagethief.firebasestorage.app',
        );
      } else {
        storage = FirebaseStorage.instance;
      }

      if (!await imageFile.exists()) return null;

      final fileName =
          '${commentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath =
          'branches/${widget.branchId}/comments/$commentId/images/$fileName';
      final ref = storage.ref().child(storagePath);
      final snapshot = await ref.putFile(imageFile);
      return snapshot.state == TaskState.success
          ? snapshot.ref.getDownloadURL()
          : null;
    } catch (e) {
      debugPrint('지점 리뷰 이미지 업로드 오류: $e');
      return null;
    }
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
    if (_isAddingComment) return;

    setState(() {
      _isAddingComment = true;
    });

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc();

      String contentHtml = content;
      final attachments = <Map<String, dynamic>>[];

      if (_selectedImage != null) {
        final imageUrl = await _uploadImage(_selectedImage!, commentRef.id);
        if (imageUrl != null) {
          contentHtml +=
              '<br><img src="$imageUrl" alt="첨부이미지" style="max-width: 100%; border-radius: 8px;" />';
          attachments.add(<String, dynamic>{
            'type': 'image',
            'url': imageUrl,
            'filename': 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          });
        }
      }

      final userData =
          await UserService.getUserFromFirestore(_currentUser!.uid);
      final displayName = (userData?['displayName'] as String?) ??
          _currentUser!.displayName ??
          '사용자';
      final profileImageUrl =
          (userData?['photoURL'] as String?) ?? (_currentUser!.photoURL ?? '');

      final data = <String, dynamic>{
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

      await commentRef.set(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('branch_comments')
          .doc(commentRef.id)
          .set(<String, dynamic>{
        'commentPath': 'branches/${widget.branchId}/comments/${commentRef.id}',
        'branchId': widget.branchId,
        'branchName': _effectiveBranchName,
        'contentHtml': data['contentHtml'],
        'contentType': data['contentType'],
        'attachments': attachments,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      if (_selectedImage != null) {
        setState(() {
          _selectedImage = null;
        });
      }
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰가 등록되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('지점 리뷰 등록 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리뷰 등록 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingComment = false;
        });
      }
    }
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final commentId = comment['commentId'] as String?;
    if (commentId == null) return;

    final controller = TextEditingController(
      text: (comment['plainText'] as String?) ?? '',
    );

    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('리뷰 수정', style: McTextStyles.sectionTitle),
          content: TextField(
            controller: controller,
            maxLines: 5,
            minLines: 1,
            decoration: const InputDecoration(hintText: '리뷰 내용을 수정하세요.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (newText == null || newText.isEmpty) return;

    try {
      final html = '<p>$newText</p>';
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
      debugPrint('지점 리뷰 수정 오류: $e');
      Fluttertoast.showToast(msg: '리뷰 수정 중 오류가 발생했습니다.');
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentId = comment['commentId'] as String?;
    if (commentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('리뷰 삭제', style: McTextStyles.sectionTitle),
          content: const Text('해당 리뷰를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('comments')
          .doc(commentId)
          .get();
      final attachments =
          (doc.data()?['attachments'] as List<dynamic>?) ?? const [];

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

      for (final raw in attachments) {
        if (raw is! Map<String, dynamic>) continue;
        if (raw['type'] != 'image') continue;
        final url = raw['url'] as String?;
        if (url == null || url.isEmpty) continue;
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint('지점 리뷰 이미지 삭제 오류: $e');
        }
      }

      await _loadComments();
      Fluttertoast.showToast(msg: '리뷰가 삭제되었습니다.');
    } catch (e) {
      debugPrint('지점 리뷰 삭제 오류: $e');
      Fluttertoast.showToast(msg: '리뷰 삭제 중 오류가 발생했습니다.');
    }
  }

  Future<void> _showJoinEventDialog() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (_events.isEmpty) {
      Fluttertoast.showToast(msg: '현재 진행 중인 이벤트가 없습니다.');
      return;
    }

    final passwordController = TextEditingController();
    String selectedEventId = _events.first['eventId'] as String;
    Map<String, dynamic> selectedEvent = _events.first;
    bool isProcessing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> join() async {
              if (isProcessing) return;
              final inputPassword = passwordController.text.trim();
              if (inputPassword.isEmpty) {
                Fluttertoast.showToast(msg: '비밀번호를 입력해주세요.');
                return;
              }
              setStateDialog(() {
                isProcessing = true;
              });
              try {
                final savedPassword = selectedEvent['password'] as String?;
                if (savedPassword == null || savedPassword.isEmpty) {
                  Fluttertoast.showToast(msg: '이벤트 정보가 올바르지 않습니다.');
                  return;
                }
                if (inputPassword != savedPassword) {
                  Fluttertoast.showToast(msg: '비밀번호가 잘못 입력되었습니다.');
                  return;
                }

                final userEventRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('events')
                    .doc(selectedEventId);
                final userEventDoc = await userEventRef.get();
                if (userEventDoc.exists) {
                  Fluttertoast.showToast(msg: '이미 참여한 이벤트입니다.');
                  return;
                }

                final peanutCount =
                    (selectedEvent['peanutCount'] as num?)?.toInt() ?? 0;
                if (peanutCount <= 0) {
                  Fluttertoast.showToast(msg: '유효하지 않은 땅콩 개수입니다.');
                  return;
                }

                final userData =
                    await UserService.getUserFromFirestore(_currentUser!.uid);
                final currentPeanuts =
                    (userData?['peanutCount'] as num?)?.toInt() ?? 0;
                await UserService.updatePeanutCount(
                  _currentUser!.uid,
                  currentPeanuts + peanutCount,
                );

                await userEventRef.set(<String, dynamic>{
                  'branchId': widget.branchId,
                  'eventId': selectedEventId,
                  'eventName': selectedEvent['name'] ?? '',
                  'joined': true,
                  'peanutCount': peanutCount,
                  'joinedAt': FieldValue.serverTimestamp(),
                });

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                Fluttertoast.showToast(
                  msg: '이벤트 참여를 통해 땅콩 $peanutCount개를 받았습니다.',
                );
              } catch (e) {
                debugPrint('이벤트 참여 오류: $e');
                Fluttertoast.showToast(msg: '이벤트 참여 중 오류가 발생했습니다.');
              } finally {
                if (dialogContext.mounted) {
                  setStateDialog(() {
                    isProcessing = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('이벤트 참여', style: McTextStyles.sectionTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이벤트 선택', style: McTextStyles.bodyStrong),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedEventId,
                      isExpanded: true,
                      items: _events.map((event) {
                        return DropdownMenuItem<String>(
                          value: event['eventId'] as String,
                          child: Text(
                            (event['name'] as String?) ?? '이벤트',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final selected = _events.firstWhere(
                          (event) => event['eventId'] == value,
                          orElse: () => <String, dynamic>{},
                        );
                        if (selected.isEmpty) return;
                        setStateDialog(() {
                          selectedEventId = value;
                          selectedEvent = selected;
                          passwordController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      enabled: !isProcessing,
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        hintText: '이벤트 비밀번호를 입력하세요.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('닫기'),
                ),
                TextButton(
                  onPressed: isProcessing ? null : join,
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('참여하기'),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();
  }

  void _openReviewTab() {
    _tabController.animateTo(3);
  }

  void _openRelatedPost(_RelatedPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          postId: post.postId,
          dateString: post.dateString,
          boardId: post.boardId,
          boardName: _boardNameFor(post.boardId, post.boardName),
        ),
      ),
    );
  }

  String _boardNameFor(String boardId, String? providedName) {
    final trimmed = providedName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    const names = {
      'all': '전체글',
      'free': '자유게시판',
      'deal': '적립/카드 혜택',
      'milecatch_guide': '마일캐치 사용법',
      'hot_deal': '핫딜',
      'question': '마일리지',
      'seats': '오늘의 좌석',
      'news': '오늘의 뉴스',
      'suggestion': '건의사항',
      'notice': '운영 공지사항',
    };
    return names[boardId] ?? boardId;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: Text(
          _effectiveBranchName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
        shadowColor: McColors.line,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_isEventManager)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BranchEventManageScreen(
                      branchId: widget.branchId,
                      branchName: _effectiveBranchName,
                    ),
                  ),
                );
              },
              child: const Text('이벤트 관리'),
            ),
          if (!_isLoadingEvents && _events.isNotEmpty)
            TextButton(
              onPressed: _showJoinEventDialog,
              child: const Text('이벤트 참여'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoadingBranch
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: McColors.accent,
              backgroundColor: Colors.white,
              onRefresh: () async {
                await Future.wait([
                  _loadBranch(),
                  _loadRates(),
                  _loadComments(),
                  _loadEvents(),
                  _loadRelatedPosts(),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 12),
                  ScrollableUnderlineTabBar(
                    controller: _tabController,
                    labels: _tabs,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    separatorWidth: 18,
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 1:
        return _buildGiftcardsTab();
      case 2:
        return _buildRatesTab();
      case 3:
        return _buildReviewsTab();
      case 4:
        return _buildInfoTab();
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHeroCard() {
    final data = _branch ?? const <String, dynamic>{};
    final address = data['address'] as String?;
    final phone = data['phone'] as String?;
    final url = data['url'] as String?;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: McColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: McColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _effectiveBranchName,
                            style: McTextStyles.appBarTitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isOfficialBranch) _buildOfficialBadge(),
                      ],
                    ),
                    if (address != null && address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: McTextStyles.meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRepresentativeRates(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChipButton(
                icon: Icons.rate_review_outlined,
                label: '리뷰',
                onTap: _openReviewTab,
              ),
              _ActionChipButton(
                icon: Icons.place_outlined,
                label: '길찾기',
                onTap: _launchMap,
              ),
              _ActionChipButton(
                icon: Icons.phone_outlined,
                label: '전화',
                onTap: phone == null || phone.trim().isEmpty
                    ? null
                    : () => _launchPhone(phone),
              ),
              _ActionChipButton(
                icon: Icons.language,
                label: 'URL',
                onTap: url == null || url.trim().isEmpty
                    ? null
                    : () => _launchExternalUrl(url),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: McColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '인증',
        style: McTextStyles.micro.copyWith(
          color: McColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRepresentativeRates() {
    if (_isLoadingRates) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (_rates.isEmpty) {
      return const Text('등록된 시세가 없습니다.', style: McTextStyles.meta);
    }

    final sorted = _rates.toList()
      ..sort((a, b) {
        final av = (a.data['sellPrice_general'] as num?) ?? 0;
        final bv = (b.data['sellPrice_general'] as num?) ?? 0;
        return bv.compareTo(av);
      });

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in sorted.take(3))
          _SummaryPill(
            icon: Icons.card_giftcard_outlined,
            label:
                '${row.giftcardName} ${_formatWon(row.data['sellPrice_general'] as num?)}',
          ),
        _SummaryPill(
          icon: Icons.chat_bubble_outline,
          label: '리뷰 ${_comments.length}',
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    final notice = (_branch?['notice'] as String?)?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeRateCard(),
        if (notice != null && notice.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: '안내사항',
            child: Text(notice, style: McTextStyles.body),
          ),
        ],
        const SizedBox(height: 12),
        _buildRecentReviewsPreview(),
        const SizedBox(height: 12),
        _buildRelatedPostsSection(),
      ],
    );
  }

  Widget _buildHomeRateCard() {
    if (_isLoadingRates) return _buildLoadingCard('대표 시세를 불러오는 중입니다.');
    if (_rates.isEmpty) {
      return const _SectionCard(
        title: '대표 시세',
        child: Text('아직 등록된 시세가 없습니다.', style: McTextStyles.body),
      );
    }

    final rows = _rates.take(4).toList();
    return _SectionCard(
      title: '대표 시세',
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _buildCompactRateRow(rows[i]),
            if (i != rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactRateRow(_BranchRateRow row) {
    final sellPrice = row.data['sellPrice_general'] as num?;
    final buyPrice = row.data['buyPrice_general'] as num?;
    final sellRate = _feeRateFromPrice(sellPrice);
    final buyRate = _feeRateFromPrice(buyPrice);

    return Row(
      children: [
        Expanded(
          child: Text(
            row.giftcardName,
            style: McTextStyles.bodyStrong,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '팔 때 ${_formatWon(sellPrice)}',
              style: McTextStyles.meta.copyWith(color: McColors.ink),
            ),
            Text(
              '살 때 ${_formatWon(buyPrice)}',
              style: McTextStyles.micro,
            ),
            Text(
              '수수료 ${_formatRate(sellRate)}% / ${_formatRate(buyRate)}%',
              style: McTextStyles.micro,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentReviewsPreview() {
    if (_isLoadingComments) return _buildLoadingCard('최근 리뷰를 불러오는 중입니다.');
    if (_comments.isEmpty) {
      return _SectionCard(
        title: '최근 리뷰',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('아직 등록된 리뷰가 없습니다.', style: McTextStyles.body),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openReviewTab,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('첫 리뷰 남기기'),
            ),
          ],
        ),
      );
    }

    final shown = _comments.take(2).toList();
    return _SectionCard(
      title: '최근 리뷰',
      trailing: TextButton(
        onPressed: _openReviewTab,
        child: const Text('전체 보기'),
      ),
      child: Column(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            _buildCommentItem(shown[i], compact: true),
            if (i != shown.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedPostsSection() {
    if (_isLoadingRelatedPosts) {
      return _buildLoadingCard('관련 커뮤니티 글을 불러오는 중입니다.');
    }
    if (_relatedPosts.isEmpty) {
      return const _SectionCard(
        title: '관련 커뮤니티 글',
        child: Text(
          '아직 이 지점과 연결된 커뮤니티 글이 없습니다.',
          style: McTextStyles.body,
        ),
      );
    }

    return _SectionCard(
      title: '관련 커뮤니티 글',
      child: Column(
        children: [
          for (int i = 0; i < _relatedPosts.length; i++) ...[
            _buildRelatedPostItem(_relatedPosts[i]),
            if (i != _relatedPosts.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedPostItem(_RelatedPost post) {
    return InkWell(
      onTap: () => _openRelatedPost(post),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: McColors.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 18,
                color: McColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_boardNameFor(post.boardId, post.boardName)} · 댓글 ${post.commentCount}',
                    style: McTextStyles.micro,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: McColors.mutedLight),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftcardsTab() {
    if (_isLoadingRates) return _buildLoadingCard('취급 상품권을 불러오는 중입니다.');
    if (_rates.isEmpty) {
      return const _SectionCard(
        child: Text('이 지점에 등록된 취급 상품권이 없습니다.', style: McTextStyles.body),
      );
    }

    return Column(
      children: [
        for (final row in _rates) ...[
          _buildRateDetailCard(row),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRateDetailCard(_BranchRateRow row) {
    final sellPrice = row.data['sellPrice_general'] as num?;
    final buyPrice = row.data['buyPrice_general'] as num?;
    final sellRate = _feeRateFromPrice(sellPrice);
    final buyRate = _feeRateFromPrice(buyPrice);
    final updatedAt = _timestampText(row.data['updatedAt']);
    final isActive = row.data['isActive'] != false;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.giftcardName, style: McTextStyles.cardTitle),
              ),
              _MiniPill(label: isActive ? '취급중' : '중지'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateMetric(
                  label: '팔 때',
                  price: _formatWon(sellPrice),
                  rate: '수수료 ${_formatRate(sellRate)}%',
                  icon: Icons.south_west,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RateMetric(
                  label: '살 때',
                  price: _formatWon(buyPrice),
                  rate: '수수료 ${_formatRate(buyRate)}%',
                  icon: Icons.north_east,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ],
          ),
          if (updatedAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('업데이트 $updatedAt', style: McTextStyles.micro),
          ],
        ],
      ),
    );
  }

  Widget _buildRatesTab() {
    if (_isLoadingRates) return _buildLoadingCard('시세 차트를 불러오는 중입니다.');
    if (_rates.isEmpty) {
      return const _SectionCard(
        child: Text('차트로 표시할 시세가 없습니다.', style: McTextStyles.body),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDailyChartCard(),
        const SizedBox(height: 12),
        _SectionCard(
          title: '현재 시세',
          child: Column(
            children: [
              for (int i = 0; i < _rates.length; i++) ...[
                _buildCompactRateRow(_rates[i]),
                if (i != _rates.length - 1) const Divider(height: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChartCard() {
    final chartRows = _rates.take(5).toList();
    final chartData = _ChartSeries.fromDailyRates(
      snapshots: _dailyRates,
      rows: chartRows,
    );

    return _SectionCard(
      title: '최근 2달 시세 추이',
      child: chartData.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('최근 차트 데이터가 없습니다.', style: McTextStyles.body),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < chartData.series.length; i++)
                      _LegendDot(
                        color: _seriesColor(i),
                        label: chartData.series[i].giftcardName,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minY: chartData.minY,
                      maxY: chartData.maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: McColors.line,
                          strokeWidth: 0.7,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: math.max(
                              1,
                              (chartData.maxX / 3).floorToDouble(),
                            ),
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 ||
                                  index >= chartData.labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                chartData.labels[index],
                                style: McTextStyles.micro,
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _won.format(value.round()),
                                style: McTextStyles.micro,
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        for (int i = 0; i < chartData.series.length; i++)
                          LineChartBarData(
                            spots: chartData.series[i].spots,
                            isCurved: true,
                            barWidth: 2.2,
                            dotData: const FlDotData(show: false),
                            color: _seriesColor(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _seriesColor(int index) {
    const colors = <Color>[
      Color(0xFF1E88E5),
      Color(0xFFD81B60),
      Color(0xFF43A047),
      Color(0xFFF4511E),
      Color(0xFF8E24AA),
    ];
    return colors[index % colors.length];
  }

  Widget _buildReviewsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentInputCard(),
        const SizedBox(height: 12),
        _SectionCard(
          title: '리뷰 ${_comments.length}',
          child: _buildCommentsSection(),
        ),
      ],
    );
  }

  Widget _buildCommentInputCard() {
    return _SectionCard(
      title: '리뷰 쓰기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImage != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selectedImage!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _removeSelectedImage,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _commentController,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '지점 이용 후기를 남겨주세요.',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('이미지'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isAddingComment ? null : _submitComment,
                icon: _isAddingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 18),
                label: Text(_isAddingComment ? '등록 중' : '등록'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: McColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (_isLoadingComments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('아직 등록된 리뷰가 없습니다.', style: McTextStyles.body),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < _comments.length; i++) ...[
          _buildCommentItem(_comments[i]),
          if (i != _comments.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCommentItem(
    Map<String, dynamic> comment, {
    bool compact = false,
  }) {
    final displayName = (comment['authorDisplayName'] as String?) ?? '익명';
    final content = (comment['plainText'] as String?) ?? '';
    final createdAtTs = comment['createdAt'] as Timestamp?;
    final createdAt = createdAtTs?.toDate() ?? DateTime.now();
    final photoUrl =
        (comment['authorPhotoURL'] ?? comment['profileImageUrl']) as String?;
    final rawAttachments =
        (comment['attachments'] as List<dynamic>?) ?? const [];
    final imageAttachments = rawAttachments
        .whereType<Map<String, dynamic>>()
        .where((item) => item['type'] == 'image' && item['url'] != null)
        .toList();
    final isMyComment =
        _currentUser != null && comment['authorId'] == _currentUser!.uid;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: compact ? McColors.field : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: McColors.accentSoft,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 16, color: McColors.accent)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(displayName, style: McTextStyles.bodyStrong),
              ),
              Text(_dateFormat.format(createdAt), style: McTextStyles.micro),
              if (isMyComment && !compact) _buildCommentMoreOptions(comment),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.isEmpty ? '이미지 리뷰' : content,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: McTextStyles.body,
          ),
          if (imageAttachments.isNotEmpty && !compact) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageAttachments.first['url'] as String,
                height: 170,
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: McColors.muted),
      color: Colors.white,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _editComment(comment);
            break;
          case 'delete':
            _deleteComment(comment);
            break;
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 10),
              Text('수정하기'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 10),
              Text('삭제하기', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    final data = _branch ?? const <String, dynamic>{};
    final address = data['address'] as String?;
    final phone = data['phone'] as String?;
    final url = data['url'] as String?;
    final notice = data['notice'] as String?;
    final openingHours = data['openingHours'] is Map
        ? Map<String, dynamic>.from(data['openingHours'] as Map)
        : null;

    return _SectionCard(
      title: '지점 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: '지점명',
            value: _effectiveBranchName,
          ),
          if (address != null && address.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.place_outlined,
              label: '주소',
              value: address,
              onTap: _launchMap,
            ),
          if (phone != null && phone.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: '연락처',
              value: phone,
              onTap: () => _launchPhone(phone),
            ),
          if (openingHours != null && openingHours.isNotEmpty)
            _InfoRow(
              icon: Icons.access_time_outlined,
              label: '영업시간',
              value: openingHours.entries
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n'),
            ),
          if (url != null && url.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.language,
              label: 'URL',
              value: url,
              onTap: () => _launchExternalUrl(url),
            ),
          if (notice != null && notice.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.info_outline,
              label: '안내사항',
              value: notice,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String text) {
    return _SectionCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: McTextStyles.body)),
        ],
      ),
    );
  }
}

class _BranchRateRow {
  final String giftcardId;
  final String giftcardName;
  final Map<String, dynamic> data;

  const _BranchRateRow({
    required this.giftcardId,
    required this.giftcardName,
    required this.data,
  });
}

class _DailyRateSnapshot {
  final DateTime date;
  final Map<String, dynamic> rates;

  const _DailyRateSnapshot({
    required this.date,
    required this.rates,
  });

  static _DailyRateSnapshot? fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    DateTime? date;
    final data = doc.data();
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      final d = rawDate.toDate();
      date = DateTime(d.year, d.month, d.day);
    } else if (RegExp(r'^\d{8}$').hasMatch(doc.id)) {
      final year = int.tryParse(doc.id.substring(0, 4));
      final month = int.tryParse(doc.id.substring(4, 6));
      final day = int.tryParse(doc.id.substring(6, 8));
      if (year != null && month != null && day != null) {
        date = DateTime(year, month, day);
      }
    }
    if (date == null) return null;

    final rawRates = data['giftcardRates'] ?? data['cards'];
    if (rawRates is! Map) return _DailyRateSnapshot(date: date, rates: {});
    return _DailyRateSnapshot(
      date: date,
      rates: Map<String, dynamic>.from(rawRates),
    );
  }
}

class _RelatedPost {
  final String postId;
  final String dateString;
  final String title;
  final String boardId;
  final String? boardName;
  final int commentCount;
  final DateTime createdAt;

  const _RelatedPost({
    required this.postId,
    required this.dateString,
    required this.title,
    required this.boardId,
    required this.boardName,
    required this.commentCount,
    required this.createdAt,
  });

  static _RelatedPost? fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dateDoc = doc.reference.parent.parent;
    final dateString = dateDoc?.id;
    if (dateString == null || dateString.isEmpty) return null;
    final data = doc.data();
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    return _RelatedPost(
      postId: (data['postId'] as String?) ?? doc.id,
      dateString: dateString,
      title: (data['title'] as String?) ?? '제목 없음',
      boardId: (data['boardId'] as String?) ?? 'free',
      boardName: data['boardName'] as String?,
      commentCount: (data['commentCount'] as num?)?.toInt() ??
          (data['commentsCount'] as num?)?.toInt() ??
          0,
      createdAt: createdAt,
    );
  }
}

class _ChartSeries {
  final List<_ChartLine> series;
  final List<String> labels;
  final double minY;
  final double maxY;
  final double maxX;

  const _ChartSeries({
    required this.series,
    required this.labels,
    required this.minY,
    required this.maxY,
    required this.maxX,
  });

  bool get isEmpty => series.isEmpty || labels.length < 2;

  static _ChartSeries fromDailyRates({
    required List<_DailyRateSnapshot> snapshots,
    required List<_BranchRateRow> rows,
  }) {
    if (snapshots.isEmpty || rows.isEmpty) {
      return const _ChartSeries(
        series: [],
        labels: [],
        minY: 0,
        maxY: 0,
        maxX: 0,
      );
    }

    final formatter = DateFormat('M/d');
    final labels =
        snapshots.map((snapshot) => formatter.format(snapshot.date)).toList();
    final lines = <_ChartLine>[];
    double minY = double.infinity;
    double maxY = 0;

    for (final row in rows) {
      final spots = <FlSpot>[];
      for (int i = 0; i < snapshots.length; i++) {
        final raw = snapshots[i].rates[row.giftcardId];
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final price = (map['sellPrice_general'] ??
            map['sellPrice'] ??
            map['sellPriceGeneral']) as num?;
        if (price == null || price <= 0) continue;
        final y = price.toDouble();
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        spots.add(FlSpot(i.toDouble(), y));
      }
      if (spots.length >= 2) {
        lines.add(_ChartLine(giftcardName: row.giftcardName, spots: spots));
      }
    }

    if (lines.isEmpty) {
      return _ChartSeries(
        series: const [],
        labels: labels,
        minY: 0,
        maxY: 0,
        maxX: math.max(0, labels.length - 1).toDouble(),
      );
    }

    final padding = math.max(100, ((maxY - minY) * 0.12).round()).toDouble();
    return _ChartSeries(
      series: lines,
      labels: labels,
      minY: math.max(0, minY - padding),
      maxY: maxY + padding,
      maxX: math.max(0, labels.length - 1).toDouble(),
    );
  }
}

class _ChartLine {
  final String giftcardName;
  final List<FlSpot> spots;

  const _ChartLine({
    required this.giftcardName,
    required this.spots,
  });
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: McTextStyles.sectionTitle)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? McColors.field : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: McColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? McColors.accent : McColors.mutedLight,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: McTextStyles.micro.copyWith(
                color: enabled ? McColors.inkSoft : McColors.mutedLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: McColors.inkSoft),
          const SizedBox(width: 6),
          Text(
            label,
            style: McTextStyles.micro.copyWith(
              color: McColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: McColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: McTextStyles.micro.copyWith(
          color: McColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RateMetric extends StatelessWidget {
  final String label;
  final String price;
  final String rate;
  final IconData icon;
  final Color color;

  const _RateMetric({
    required this.label,
    required this.price,
    required this.rate,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(label, style: McTextStyles.meta),
            ],
          ),
          const SizedBox(height: 6),
          Text(price, style: McTextStyles.bodyStrong),
          const SizedBox(height: 2),
          Text(rate, style: McTextStyles.micro),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: McTextStyles.micro),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: McColors.muted),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(label, style: McTextStyles.bodyStrong),
            ),
            Expanded(
              child: Text(
                value,
                style: McTextStyles.body.copyWith(
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
