import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReportManageScreen extends StatelessWidget {
  const AdminReportManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final kinds = <_ReportKind>[
      _ReportKind(
        key: 'post',
        tabLabel: '게시글',
        title: '게시글 신고',
        emptyText: '접수된 게시글 신고가 없습니다.',
        collection: firestore.collection('reports').doc('posts').collection(
              'posts',
            ),
      ),
      _ReportKind(
        key: 'comment',
        tabLabel: '댓글',
        title: '댓글 신고',
        emptyText: '접수된 댓글 신고가 없습니다.',
        collection: firestore.collection('reports').doc('comments').collection(
              'comments',
            ),
      ),
      _ReportKind(
        key: 'chat_message',
        tabLabel: '채팅',
        title: '채팅 신고',
        emptyText: '접수된 채팅 신고가 없습니다.',
        collection:
            firestore.collection('reports').doc('chat_messages').collection(
                  'messages',
                ),
      ),
    ];

    return DefaultTabController(
      length: kinds.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F1F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF0F1F5),
          foregroundColor: const Color(0xFF1A1D27),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            '신고 관리',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Color(0xFF8A91A1),
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: '게시글'),
              Tab(text: '댓글'),
              Tab(text: '채팅'),
            ],
          ),
        ),
        body: TabBarView(
          children: kinds
              .map((kind) => _AdminReportList(kind: kind))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AdminReportList extends StatelessWidget {
  const _AdminReportList({required this.kind});

  final _ReportKind kind;

  @override
  Widget build(BuildContext context) {
    final stream = kind.collection
        .orderBy('reportedAt', descending: true)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '신고 내역을 불러오지 못했습니다.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF727A89),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs
            .map((doc) => _ReportEntry.fromDoc(doc, kind))
            .toList(growable: false);
        if (reports.isEmpty) {
          return Center(
            child: Text(
              kind.emptyText,
              style: const TextStyle(
                color: Color(0xFF7A8190),
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: reports.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _AdminReportCard(entry: reports[index]);
          },
        );
      },
    );
  }
}

class _AdminReportCard extends StatefulWidget {
  const _AdminReportCard({required this.entry});

  final _ReportEntry entry;

  @override
  State<_AdminReportCard> createState() => _AdminReportCardState();
}

class _AdminReportCardState extends State<_AdminReportCard> {
  bool _isProcessing = false;

  _ReportEntry get entry => widget.entry;

  Future<void> _setStatus(String status) async {
    final update = _statusUpdate(status);
    await _runAction(
      successMessage: _statusSuccessMessage(status),
      action: () => _updateReportDocuments(update),
    );
  }

  Future<void> _hideTarget() async {
    if (entry.detailPath.isEmpty) {
      _showMessage('대상 경로가 없어 숨김 처리할 수 없습니다.');
      return;
    }

    await _runAction(
      successMessage: '신고 대상이 숨김 처리되었습니다.',
      action: () async {
        final firestore = FirebaseFirestore.instance;
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
        final now = FieldValue.serverTimestamp();

        await firestore.doc(entry.detailPath).set({
          'isHidden': true,
          'hiddenByReport': true,
          'hiddenReportId': entry.id,
          'hiddenAt': now,
          'hiddenBy': adminUid,
          'updatedAt': now,
        }, SetOptions(merge: true));

        await _updateReportDocuments({
          'status': 'resolved',
          'action': 'hidden',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': adminUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Future<void> _updateReportDocuments(Map<String, Object?> update) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(entry.reference, update, SetOptions(merge: true));

    if (entry.detailPath.isNotEmpty && entry.reporterUid.isNotEmpty) {
      final detailReportRef = FirebaseFirestore.instance
          .doc(entry.detailPath)
          .collection('reports')
          .doc(entry.reporterUid);
      batch.set(detailReportRef, update, SetOptions(merge: true));
    }
    if (entry.userReportPath.isNotEmpty) {
      batch.set(
        FirebaseFirestore.instance.doc(entry.userReportPath),
        update,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Map<String, Object?> _statusUpdate(String status) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final now = FieldValue.serverTimestamp();
    final update = <String, Object?>{
      'status': status,
      'updatedAt': now,
    };

    switch (status) {
      case 'reviewed':
        update['reviewedAt'] = now;
        update['reviewedBy'] = adminUid;
        break;
      case 'resolved':
        update['resolvedAt'] = now;
        update['resolvedBy'] = adminUid;
        break;
      case 'rejected':
        update['rejectedAt'] = now;
        update['rejectedBy'] = adminUid;
        break;
    }
    return update;
  }

  Future<void> _runAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
      if (!mounted) return;
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage('처리 중 오류가 발생했습니다: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _statusSuccessMessage(String status) {
    switch (status) {
      case 'reviewed':
        return '검토 완료로 표시했습니다.';
      case 'resolved':
        return '처리 완료로 표시했습니다.';
      case 'rejected':
        return '기각 처리했습니다.';
      default:
        return '상태를 변경했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasonLabel = _reasonLabel(entry.reason);
    final reportedAtText = entry.reportedAt == null
        ? '접수 시간 확인 중'
        : DateFormat('yyyy.MM.dd HH:mm').format(entry.reportedAt!);
    final hasDetail = entry.detail.trim().isNotEmpty;
    final hasTargetAuthor = entry.targetAuthor.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.kind.title,
                  style: const TextStyle(
                    color: Color(0xFF1F2533),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.targetSummary.isNotEmpty ? entry.targetSummary : '(내용 없음)',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF262C3A),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoPill(text: reasonLabel),
              if (entry.imageCount > 0)
                _InfoPill(text: '이미지 ${entry.imageCount}장'),
              if (hasTargetAuthor) _InfoPill(text: '대상: ${entry.targetAuthor}'),
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: 10),
            Text(
              entry.detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF697181),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '신고자: ${entry.reporterName} · $reportedAtText',
            style: const TextStyle(
              color: Color(0xFF8A91A1),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (entry.detailPath.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.detailPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFA0A6B3),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReportActionButton(
                label: '검토 완료',
                icon: Icons.rate_review_outlined,
                onPressed: _isProcessing ? null : () => _setStatus('reviewed'),
              ),
              _ReportActionButton(
                label: '숨김 처리',
                icon: Icons.visibility_off_outlined,
                isDestructive: true,
                onPressed: _isProcessing ? null : _hideTarget,
              ),
              _ReportActionButton(
                label: '처리 완료',
                icon: Icons.check_circle_outline,
                onPressed: _isProcessing ? null : () => _setStatus('resolved'),
              ),
              _ReportActionButton(
                label: '기각',
                icon: Icons.block_outlined,
                onPressed: _isProcessing ? null : () => _setStatus('rejected'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportActionButton extends StatelessWidget {
  const _ReportActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isDestructive ? const Color(0xFFE24C4C) : const Color(0xFF1F2533);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: 0.26)),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF596172),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReportKind {
  const _ReportKind({
    required this.key,
    required this.tabLabel,
    required this.title,
    required this.emptyText,
    required this.collection,
  });

  final String key;
  final String tabLabel;
  final String title;
  final String emptyText;
  final CollectionReference<Map<String, dynamic>> collection;
}

class _ReportEntry {
  const _ReportEntry({
    required this.id,
    required this.reference,
    required this.kind,
    required this.reason,
    required this.detail,
    required this.status,
    required this.reporterUid,
    required this.reporterName,
    required this.reportedAt,
    required this.targetSummary,
    required this.targetAuthor,
    required this.detailPath,
    required this.userReportPath,
    required this.imageCount,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final _ReportKind kind;
  final String reason;
  final String detail;
  final String status;
  final String reporterUid;
  final String reporterName;
  final DateTime? reportedAt;
  final String targetSummary;
  final String targetAuthor;
  final String detailPath;
  final String userReportPath;
  final int imageCount;

  factory _ReportEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    _ReportKind kind,
  ) {
    final data = doc.data();
    return _ReportEntry(
      id: doc.id,
      reference: doc.reference,
      kind: kind,
      reason: (data['reason'] ?? '').toString(),
      detail: (data['detail'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      reporterUid: (data['reporterUid'] ?? '').toString(),
      reporterName: _firstNonEmpty([
        data['reporterName'],
        data['reporterUid'],
        '익명',
      ]),
      reportedAt: _dateFromTimestamp(data['reportedAt']),
      targetSummary: _targetSummary(data, kind.key),
      targetAuthor: _targetAuthor(data, kind.key),
      detailPath: (data['detailPath'] ?? '').toString(),
      userReportPath: (data['userReportPath'] ?? '').toString(),
      imageCount: _stringList(data['imageUrls']).length,
    );
  }
}

String _targetSummary(Map<String, dynamic> data, String kind) {
  switch (kind) {
    case 'post':
      return _firstNonEmpty([data['postTitle'], data['title'], data['postId']]);
    case 'comment':
      return _stripHtml(
        _firstNonEmpty([
          data['commentContent'],
          data['contentHtml'],
          data['content'],
          data['commentId'],
        ]),
      );
    case 'chat_message':
      final messageText = (data['messageText'] ?? '').toString().trim();
      if (messageText.isNotEmpty) return messageText;
      final imageCount = _stringList(data['imageUrls']).length;
      return imageCount > 0 ? '사진 $imageCount장' : '';
    default:
      return _firstNonEmpty([data['targetId'], data['detailPath']]);
  }
}

String _targetAuthor(Map<String, dynamic> data, String kind) {
  switch (kind) {
    case 'post':
      return _authorName(data['postAuthor']);
    case 'comment':
      return _authorName(data['commentAuthor']);
    case 'chat_message':
      return _authorName(data['messageAuthor']);
    default:
      return '';
  }
}

String _authorName(Object? author) {
  if (author is Map) {
    return _firstNonEmpty([author['displayName'], author['uid']]);
  }
  return (author ?? '').toString().trim();
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}

DateTime? _dateFromTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

String _stripHtml(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
      .trim();
}

String _reasonLabel(String reason) {
  switch (reason) {
    case 'abuse':
      return '욕설/비방';
    case 'copyright':
      return '저작권';
    case 'advertisement':
      return '광고';
    case 'spam':
      return '도배/광고';
    case 'sexual':
      return '음란/선정성';
    case 'hate':
      return '혐오/차별';
    case 'other':
    case 'etc':
      return '기타';
    default:
      return reason.isEmpty ? '사유 없음' : reason;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'reviewed':
      return '검토 완료';
    case 'resolved':
      return '처리 완료';
    case 'rejected':
      return '기각';
    case 'pending':
    default:
      return '접수';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'reviewed':
      return const Color(0xFF3A6FD8);
    case 'resolved':
      return const Color(0xFF2F8F63);
    case 'rejected':
      return const Color(0xFF6C7484);
    case 'pending':
    default:
      return const Color(0xFFE38A1B);
  }
}
