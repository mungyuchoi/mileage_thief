import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminHotelRequestManageScreen extends StatelessWidget {
  const AdminHotelRequestManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('reports')
        .doc('hotels')
        .collection('hotels')
        .orderBy('reportedAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F1F5),
        foregroundColor: const Color(0xFF1A1D27),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '호텔 관리',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '호텔 요청을 불러오지 못했습니다.\n${snapshot.error}',
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

          final requests = snapshot.data!.docs
              .map(_HotelRequestEntry.fromDoc)
              .toList(growable: false);
          if (requests.isEmpty) {
            return const Center(
              child: Text(
                '접수된 호텔 요청이 없습니다.',
                style: TextStyle(
                  color: Color(0xFF7A8190),
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: requests.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _HotelRequestCard(entry: requests[index]);
            },
          );
        },
      ),
    );
  }
}

class _HotelRequestCard extends StatefulWidget {
  const _HotelRequestCard({required this.entry});

  final _HotelRequestEntry entry;

  @override
  State<_HotelRequestCard> createState() => _HotelRequestCardState();
}

class _HotelRequestCardState extends State<_HotelRequestCard> {
  bool _isProcessing = false;

  _HotelRequestEntry get entry => widget.entry;

  Future<void> _setStatus(String status) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
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

      final batch = FirebaseFirestore.instance.batch();
      batch.set(entry.reference, update, SetOptions(merge: true));
      if (entry.userReportPath.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance.doc(entry.userReportPath),
          update,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusSuccessMessage(status))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류가 발생했습니다: $error')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openUrl() async {
    final raw = entry.url.trim();
    if (raw.isEmpty) return;
    final url = raw.startsWith(RegExp(r'https?://')) ? raw : 'https://$raw';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final requestedAtText = entry.requestedAt == null
        ? '접수 시간 확인 중'
        : DateFormat('yyyy.MM.dd HH:mm').format(entry.requestedAt!);

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
                  entry.hotelName.isEmpty ? '(호텔명 없음)' : entry.hotelName,
                  style: const TextStyle(
                    color: Color(0xFF1F2533),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _HotelStatusChip(status: entry.status),
            ],
          ),
          if (entry.url.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _openUrl,
              child: Text(
                entry.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2F6FDB),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '요청자: ${entry.requesterName} · $requestedAtText',
            style: const TextStyle(
              color: Color(0xFF8A91A1),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HotelRequestActionButton(
                label: '검토 완료',
                icon: Icons.rate_review_outlined,
                onPressed: _isProcessing ? null : () => _setStatus('reviewed'),
              ),
              _HotelRequestActionButton(
                label: '처리 완료',
                icon: Icons.check_circle_outline,
                onPressed: _isProcessing ? null : () => _setStatus('resolved'),
              ),
              _HotelRequestActionButton(
                label: '기각',
                icon: Icons.block_outlined,
                isDestructive: true,
                onPressed: _isProcessing ? null : () => _setStatus('rejected'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HotelRequestActionButton extends StatelessWidget {
  const _HotelRequestActionButton({
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

class _HotelStatusChip extends StatelessWidget {
  const _HotelStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'reviewed' => const Color(0xFF2F6FDB),
      'resolved' => const Color(0xFF1B9A5A),
      'rejected' => const Color(0xFFE24C4C),
      _ => const Color(0xFFB7791F),
    };
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

class _HotelRequestEntry {
  const _HotelRequestEntry({
    required this.reference,
    required this.hotelName,
    required this.url,
    required this.status,
    required this.requesterName,
    required this.requestedAt,
    required this.userReportPath,
  });

  final DocumentReference<Map<String, dynamic>> reference;
  final String hotelName;
  final String url;
  final String status;
  final String requesterName;
  final DateTime? requestedAt;
  final String userReportPath;

  factory _HotelRequestEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _HotelRequestEntry(
      reference: doc.reference,
      hotelName: (data['hotelName'] ?? data['targetSummary'] ?? '').toString(),
      url: (data['url'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      requesterName: _firstNonEmpty([
        data['reporterName'],
        data['requesterName'],
        data['reporterUid'],
        '익명',
      ]),
      requestedAt: _dateFromTimestamp(data['reportedAt'] ?? data['createdAt']),
      userReportPath: (data['userReportPath'] ?? '').toString(),
    );
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
    default:
      return '대기';
  }
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

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

DateTime? _dateFromTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
