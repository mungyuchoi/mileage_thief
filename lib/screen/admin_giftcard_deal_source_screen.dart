import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/giftcard_deal_model.dart';
import '../services/giftcard_deal_service.dart';
import 'giftcard_deals_screen.dart';

class AdminGiftcardDealSourceScreen extends StatelessWidget {
  const AdminGiftcardDealSourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('상품권 특가 URL 관리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _GiftcardDealSourceEditScreen(),
          ),
        ),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('URL 추가'),
      ),
      body: StreamBuilder<List<GiftcardDealSourceRequest>>(
        stream: GiftcardDealService.watchSourceRequests(),
        builder: (context, requestSnapshot) {
          final requests =
              requestSnapshot.data ?? const <GiftcardDealSourceRequest>[];
          return StreamBuilder<List<GiftcardDealSource>>(
            stream: GiftcardDealService.watchSources(),
            builder: (context, sourceSnapshot) {
              final sources =
                  sourceSnapshot.data ?? const <GiftcardDealSource>[];
              final loadingRequests =
                  requestSnapshot.connectionState == ConnectionState.waiting &&
                      requests.isEmpty;
              final loadingSources =
                  sourceSnapshot.connectionState == ConnectionState.waiting &&
                      sources.isEmpty;
              if (loadingRequests && loadingSources) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _GiftcardSourceRequestSection(
                    requests: requests,
                    isLoading: loadingRequests,
                  ),
                  const SizedBox(height: 16),
                  const _AdminSectionTitle(title: '등록된 URL'),
                  const SizedBox(height: 10),
                  if (sources.isEmpty)
                    const _AdminGiftcardSourceEmpty()
                  else
                    for (final source in sources) ...[
                      _GiftcardDealSourceCard(source: source),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GiftcardSourceRequestSection extends StatelessWidget {
  const _GiftcardSourceRequestSection({
    required this.requests,
    required this.isLoading,
  });

  final List<GiftcardDealSourceRequest> requests;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _AdminSectionTitle(title: 'URL 요청 항목')),
            if (requests.isNotEmpty)
              _SourceBadge(
                icon: Icons.pending_actions_rounded,
                text: '${requests.length}건',
                color: const Color(0xFF74512D),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '대기 중인 URL 요청이 없습니다.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          )
        else
          for (final request in requests) ...[
            _GiftcardSourceRequestCard(request: request),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _GiftcardSourceRequestCard extends StatefulWidget {
  const _GiftcardSourceRequestCard({required this.request});

  final GiftcardDealSourceRequest request;

  @override
  State<_GiftcardSourceRequestCard> createState() =>
      _GiftcardSourceRequestCardState();
}

class _GiftcardSourceRequestCardState
    extends State<_GiftcardSourceRequestCard> {
  bool _working = false;

  GiftcardDealSourceRequest get request => widget.request;

  Future<void> _approve() async {
    if (!request.canApprove) {
      Fluttertoast.showToast(msg: '구매처, 상품권, 권종 확인 후 수정 후 수락해주세요.');
      return;
    }
    setState(() => _working = true);
    try {
      await GiftcardDealService.approveSourceRequest(
        requestId: request.id,
        url: request.url,
        merchantName: request.merchantName,
        brandName: request.brandName,
        denominationKRW: request.amountKRW,
        faceValueKRW: request.amountKRW,
        displayName: request.title,
        memo: '사용자 URL 요청',
      );
      Fluttertoast.showToast(msg: 'URL 요청을 수락했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '수락 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editAndApprove() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GiftcardDealSourceEditScreen(request: request),
      ),
    );
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL 요청을 반려할까요?'),
        content: const Text('반려하면 요청 목록에서 사라지고 기존 URL 목록에는 영향이 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('반려'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await GiftcardDealService.rejectSourceRequest(
        request.id,
        note: '관리자 반려',
      );
      Fluttertoast.showToast(msg: 'URL 요청을 반려했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '반려 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) {
      Fluttertoast.showToast(msg: 'URL이 올바르지 않습니다.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final amountText =
        request.amountKRW > 0 ? _formatWon(request.amountKRW) : '권종 모름';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          request.merchantName.isEmpty
                              ? '구매처 모름'
                              : request.merchantName,
                          request.brandName.isEmpty
                              ? '상품권 모름'
                              : request.brandName,
                          amountText,
                        ].join(' · '),
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  onPressed: _working ? null : _openUrl,
                  icon: const Icon(Icons.open_in_new_rounded),
                  tooltip: 'URL 열기',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF374151), height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              '요청자 ${request.requesterUid.isEmpty ? '-' : request.requesterUid} · ${_formatTimestamp(request.createdAt)}',
              style: const TextStyle(
                color: Color(0xFF8A91A1),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _working ? null : _approve,
                    child: Text(_working ? '처리 중' : '수락'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _working ? null : _editAndApprove,
                    child: const Text('수정 후 수락'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _working ? null : _reject,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '반려',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftcardDealSourceCard extends StatelessWidget {
  const _GiftcardDealSourceCard({required this.source});

  final GiftcardDealSource source;

  @override
  Widget build(BuildContext context) {
    final statusColor = source.lastCrawlStatus == 'success'
        ? const Color(0xFF027A48)
        : source.lastCrawlStatus == 'error'
            ? const Color(0xFFB42318)
            : const Color(0xFF667085);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${source.merchantName} · ${source.brandName} · ${_formatWon(source.faceValueKRW)}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: source.enabled,
                  onChanged: (value) async {
                    try {
                      await GiftcardDealService.saveSource(
                        existingId: source.id,
                        url: source.url,
                        merchantName: source.merchantName,
                        brandName: source.brandName,
                        denominationKRW: source.denominationKRW,
                        faceValueKRW: source.faceValueKRW,
                        displayName: source.displayName,
                        enabled: value,
                        memo: source.memo,
                      );
                    } catch (e) {
                      Fluttertoast.showToast(msg: '상태 변경 실패: $e');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SourceBadge(
                  icon: Icons.campaign_outlined,
                  text: source.enabled ? '활성' : '비활성',
                  color: source.enabled
                      ? const Color(0xFF027A48)
                      : const Color(0xFF667085),
                ),
                _SourceBadge(
                  icon: Icons.sync_rounded,
                  text: source.lastCrawlStatus.isEmpty
                      ? '수집 전'
                      : source.lastCrawlStatus,
                  color: statusColor,
                ),
                _SourceBadge(
                  icon: Icons.local_offer_outlined,
                  text: source.lastDiscountRate > 0
                      ? '${source.lastDiscountRate.toStringAsFixed(2)}%'
                      : '-',
                  color: const Color(0xFFB42318),
                ),
                _SourceBadge(
                  icon: Icons.payments_outlined,
                  text: _formatWon(source.lastPriceKRW),
                  color: const Color(0xFF111827),
                ),
              ],
            ),
            if (source.lastCrawlError.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                source.lastCrawlError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: GiftcardDealPriceChart(
                dealId: source.id,
                currentPriceKRW: source.lastPriceKRW,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _GiftcardDealSourceEditScreen(source: source),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () async {
                    final uri = Uri.tryParse(source.url);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  tooltip: 'URL 열기',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftcardDealSourceEditScreen extends StatefulWidget {
  const _GiftcardDealSourceEditScreen({
    this.source,
    this.request,
  });

  final GiftcardDealSource? source;
  final GiftcardDealSourceRequest? request;

  @override
  State<_GiftcardDealSourceEditScreen> createState() =>
      _GiftcardDealSourceEditScreenState();
}

class _GiftcardDealSourceEditScreenState
    extends State<_GiftcardDealSourceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _merchantController;
  late final TextEditingController _brandController;
  late final TextEditingController _denominationController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _memoController;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    final request = widget.request;
    _urlController = TextEditingController(
      text: source?.url ?? request?.url ?? '',
    );
    _merchantController = TextEditingController(
      text: source?.merchantName ?? request?.merchantName ?? '',
    );
    _brandController = TextEditingController(
      text: source?.brandName ?? request?.brandName ?? '',
    );
    final amount = source?.faceValueKRW ?? request?.amountKRW ?? 0;
    _denominationController = TextEditingController(
      text: amount <= 0 ? '' : amount.toString(),
    );
    _displayNameController = TextEditingController(
      text: source?.displayName ?? request?.title ?? '',
    );
    _memoController = TextEditingController(
      text: source?.memo ?? (request == null ? '' : '사용자 URL 요청'),
    );
    _enabled = source?.enabled ?? true;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _merchantController.dispose();
    _brandController.dispose();
    _denominationController.dispose();
    _displayNameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = int.parse(
        _denominationController.text.replaceAll(',', '').trim(),
      );
      final request = widget.request;
      final dealId = request == null
          ? await GiftcardDealService.saveSource(
              existingId: widget.source?.id,
              url: _urlController.text,
              merchantName: _merchantController.text,
              brandName: _brandController.text,
              denominationKRW: amount,
              faceValueKRW: amount,
              displayName: _displayNameController.text,
              enabled: _enabled,
              memo: _memoController.text,
            )
          : await GiftcardDealService.approveSourceRequest(
              requestId: request.id,
              url: _urlController.text,
              merchantName: _merchantController.text,
              brandName: _brandController.text,
              denominationKRW: amount,
              faceValueKRW: amount,
              displayName: _displayNameController.text,
              memo: _memoController.text,
              reviewNote: '수정 후 수락',
            );
      Fluttertoast.showToast(
        msg: request == null ? '상품권 특가 URL을 저장했습니다.' : 'URL 요청을 수락했습니다.',
      );
      if (mounted) Navigator.of(context).pop(dealId);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.source != null;
    final isRequest = widget.request != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: Text(
          isRequest ? '요청 수정 후 수락' : (isEdit ? '특가 URL 수정' : '특가 URL 추가'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _AdminFormSection(
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'URL을 입력해주세요.';
                    if (Uri.tryParse(text)?.host.isEmpty != false) {
                      return '올바른 URL을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: '상점',
                          hintText: '옥션, SSG, 삼카몰',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: '브랜드',
                          hintText: '신세계, 롯데, 현대',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.card_giftcard_rounded),
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _denominationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '액면가/권종',
                    hintText: '100000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(
                      (value ?? '').replaceAll(',', '').trim(),
                    );
                    if (amount == null || amount <= 0) return '액면가를 입력해주세요.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: '표시명',
                    hintText: '신세계상품권 10만원권',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _enabled,
                  onChanged: isRequest
                      ? null
                      : (value) => setState(() => _enabled = value),
                  title: const Text('매일 수집 대상에 포함'),
                  subtitle: isRequest
                      ? const Text('요청 수락 시 자동으로 활성 URL로 등록됩니다.')
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving ? '저장 중' : (isRequest ? '수정 후 수락' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return '필수 입력입니다.';
    return null;
  }
}

class _AdminFormSection extends StatelessWidget {
  const _AdminFormSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _AdminGiftcardSourceEmpty extends StatelessWidget {
  const _AdminGiftcardSourceEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          '아직 등록된 상품권 특가 URL이 없습니다.\n우측 하단에서 추적할 URL을 추가하세요.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

String _formatWon(int value) {
  if (value <= 0) return '-';
  return '${NumberFormat('#,###').format(value)}원';
}

String _formatTimestamp(Timestamp? value) {
  if (value == null) return '-';
  return DateFormat('M.d HH:mm').format(value.toDate());
}
