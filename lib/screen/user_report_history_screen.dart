import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserReportHistoryScreen extends StatefulWidget {
  const UserReportHistoryScreen({super.key});

  @override
  State<UserReportHistoryScreen> createState() =>
      _UserReportHistoryScreenState();
}

class _UserReportHistoryScreenState extends State<UserReportHistoryScreen> {
  late Future<List<_UserReportEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadReports();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadReports();
    });
    await _future;
  }

  Future<List<_UserReportEntry>> _loadReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <_UserReportEntry>[];

    final userScopedEntries = await _loadUserScopedReports(user.uid);
    var globalEntries = const <_UserReportEntry>[];
    try {
      globalEntries = await _loadGlobalReports(user.uid);
    } catch (_) {
      // 사용자별 미러가 있으면 글로벌 reports 읽기 권한이 없어도 내역 화면은 동작합니다.
    }

    final byKey = <String, _UserReportEntry>{};
    for (final entry in [...userScopedEntries, ...globalEntries]) {
      byKey[entry.dedupeKey] = entry;
    }
    final entries = byKey.values.toList();
    entries.sort((a, b) {
      final left = a.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return entries;
  }

  Future<List<_UserReportEntry>> _loadUserScopedReports(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('reports')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final kind = _normalizeKind((data['type'] ?? '').toString());
      return _UserReportEntry.fromDoc(doc, _kindLabel(kind), kind);
    }).toList(growable: false);
  }

  Future<List<_UserReportEntry>> _loadGlobalReports(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      _loadKind(
        label: '게시글',
        kind: 'post',
        collection: firestore.collection('reports').doc('posts').collection(
              'posts',
            ),
        reporterUid: uid,
      ),
      _loadKind(
        label: '댓글',
        kind: 'comment',
        collection: firestore.collection('reports').doc('comments').collection(
              'comments',
            ),
        reporterUid: uid,
      ),
      _loadKind(
        label: '채팅',
        kind: 'chat_message',
        collection:
            firestore.collection('reports').doc('chat_messages').collection(
                  'messages',
                ),
        reporterUid: uid,
      ),
    ]);

    return results.expand((items) => items).toList(growable: false);
  }

  Future<List<_UserReportEntry>> _loadKind({
    required String label,
    required String kind,
    required CollectionReference<Map<String, dynamic>> collection,
    required String reporterUid,
  }) async {
    final snapshot =
        await collection.where('reporterUid', isEqualTo: reporterUid).get();
    return snapshot.docs
        .map((doc) => _UserReportEntry.fromDoc(doc, label, kind))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1A1D27),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      '신고 내역',
                      style: TextStyle(
                        color: Color(0xFF1A1D27),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '새로고침',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_UserReportEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ReportHistoryMessage(
                      title: '신고 내역을 불러오지 못했습니다.',
                      subtitle: '${snapshot.error}',
                      icon: Icons.error_outline_rounded,
                    );
                  }

                  final entries = snapshot.data ?? const <_UserReportEntry>[];
                  if (FirebaseAuth.instance.currentUser == null) {
                    return const _ReportHistoryMessage(
                      title: '로그인 후 신고 내역을 확인할 수 있어요.',
                      subtitle: '로그인하면 내가 접수한 신고 처리 상태가 표시됩니다.',
                      icon: Icons.lock_outline_rounded,
                    );
                  }
                  if (entries.isEmpty) {
                    return const _ReportHistoryMessage(
                      title: '접수한 신고 내역이 없습니다.',
                      subtitle: '신고를 접수하면 이곳에서 처리 상태를 확인할 수 있어요.',
                      icon: Icons.report_gmailerrorred_outlined,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: entries.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _UserReportCard(entry: entries[index]);
                      },
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
}

class _UserReportCard extends StatelessWidget {
  const _UserReportCard({required this.entry});

  final _UserReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateText = entry.reportedAt == null
        ? '접수 시간 확인 중'
        : DateFormat('yyyy.MM.dd HH:mm').format(entry.reportedAt!);
    final hasDetail = entry.detail.trim().isNotEmpty;

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
              _TypeChip(label: entry.label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A91A1),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.targetSummary.isNotEmpty ? entry.targetSummary : '(내용 없음)',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2533),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '사유: ${_reasonLabel(entry.reason)}',
            style: const TextStyle(
              color: Color(0xFF596172),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasDetail) ...[
            const SizedBox(height: 6),
            Text(
              entry.detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF697181),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportHistoryMessage extends StatelessWidget {
  const _ReportHistoryMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Icon(icon, color: const Color(0xFFB2B8C4), size: 46),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF424A59),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8A91A1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF596172),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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

class _UserReportEntry {
  const _UserReportEntry({
    required this.id,
    required this.label,
    required this.kind,
    required this.reportPath,
    required this.reason,
    required this.detail,
    required this.status,
    required this.reportedAt,
    required this.targetSummary,
  });

  final String id;
  final String label;
  final String kind;
  final String reportPath;
  final String reason;
  final String detail;
  final String status;
  final DateTime? reportedAt;
  final String targetSummary;

  String get dedupeKey => reportPath.isNotEmpty ? reportPath : '$kind:$id';

  factory _UserReportEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String label,
    String kind,
  ) {
    final data = doc.data();
    return _UserReportEntry(
      id: doc.id,
      label: label,
      kind: kind,
      reportPath: (data['reportPath'] ?? '').toString(),
      reason: (data['reason'] ?? '').toString(),
      detail: (data['detail'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      reportedAt: _dateFromTimestamp(data['reportedAt']),
      targetSummary: _targetSummary(data, kind),
    );
  }
}

String _normalizeKind(String kind) {
  switch (kind) {
    case 'post':
    case 'comment':
    case 'chat_message':
      return kind;
    default:
      return kind.trim().isEmpty ? 'report' : kind.trim();
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'post':
      return '게시글';
    case 'comment':
      return '댓글';
    case 'chat_message':
      return '채팅';
    default:
      return '신고';
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
