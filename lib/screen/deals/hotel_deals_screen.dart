import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/hotel_region_model.dart';
import '../../services/hotel_deals_service.dart';
import '../../services/hotel_debug.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';
import 'hotel_detail_screen.dart';
import 'widgets/hotel_deal_card_tile.dart';

class HotelDealsScreen extends StatefulWidget {
  const HotelDealsScreen({super.key});

  @override
  State<HotelDealsScreen> createState() => _HotelDealsScreenState();
}

class _HotelDealsScreenState extends State<HotelDealsScreen> {
  String? _selectedRegionKey;

  static const _windowSections = <({String key, String title, String subtitle})>[
    (key: 'TODAY', title: '오늘 체크인', subtitle: '지금 바로 떠나는 1박'),
    (key: 'TOMORROW', title: '내일 체크인', subtitle: '내일 바로 떠나는 1박'),
    (key: 'THIS_WEEKEND', title: '이번 주말', subtitle: '이번 주 토-일'),
    (key: 'NEXT_WEEKEND', title: '다음 주말', subtitle: '다음 주 토-일'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        title: const Text(
          '특가 호텔',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: StreamBuilder<List<HotelRegionModel>>(
          stream: HotelDealsService.getRegionsStream(),
          builder: (context, regionSnap) {
            if (regionSnap.hasError) {
              hotelLog('HotelDealsScreen regions ERROR: ${regionSnap.error}');
            } else {
              hotelLog(
                'HotelDealsScreen regions state=${regionSnap.connectionState} hasData=${regionSnap.hasData} count=${regionSnap.data?.length ?? 0}',
              );
            }

            if (regionSnap.hasError) {
              return _ErrorState(
                title: '지역 목록을 불러오지 못했습니다.',
                message:
                    '${regionSnap.error}\n\n- Firestore 규칙에서 hotel_regions 읽기 권한이 있는지 확인\n- 컬렉션 이름이 hotel_regions 맞는지 확인\n- isActive/sortOrder 필드 존재 여부 확인',
              );
            }

            final regions = regionSnap.data ?? const <HotelRegionModel>[];
            if (_selectedRegionKey == null && regions.isNotEmpty) {
              // 첫 활성 지역 자동 선택
              _selectedRegionKey = regions.first.regionKey;
            }

            return Column(
              children: [
                _buildRegionChips(regions),
                Expanded(
                  child: StreamBuilder<Set<String>>(
                    stream: HotelDealsService.getSavedHotelIdsStream(),
                    builder: (context, savedSnap) {
                      final savedIds = savedSnap.data ?? <String>{};
                      final regionKey = _selectedRegionKey;
                      if (regionKey == null) {
                        // regions가 비어있으면 "로딩"이 아니라 "데이터 없음"일 수 있어 안내
                        return _EmptyState(
                          title: '지역 데이터가 없습니다.',
                          message:
                              'Firestore에 `hotel_regions` 컬렉션이 없거나 문서가 0개일 수 있어요.\n\n'
                              '예시:\n- docId: KR_SEOUL\n- fields: { regionKey, name, countryCode, isLocal, sortOrder, isActive }',
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 18),
                        children: [
                          const SizedBox(height: 8),
                          for (final section in _windowSections) ...[
                            _HotelDealSection(
                              title: section.title,
                              subtitle: section.subtitle,
                              regionKey: regionKey,
                              windowKey: section.key,
                              savedHotelIds: savedIds,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegionChips(List<HotelRegionModel> regions) {
    if (regions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorConstants.milecatchBrown,
              ),
            ),
            SizedBox(width: 10),
            Text('지역 목록을 불러오는 중... (또는 데이터 없음)'),
          ],
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: regions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = regions[i];
          final selected = r.regionKey == _selectedRegionKey;
          return ChoiceChip(
            selected: selected,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CountryFlag(countryCode: r.countryCode),
                const SizedBox(width: 6),
                Text(
                  r.name,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            selectedColor: ColorConstants.milecatchBrown,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? ColorConstants.milecatchBrown : Colors.black12),
            onSelected: (_) => setState(() => _selectedRegionKey = r.regionKey),
          );
        },
      ),
    );
  }
}

class _HotelDealSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String regionKey;
  final String windowKey;
  final Set<String> savedHotelIds;

  const _HotelDealSection({
    required this.title,
    required this.subtitle,
    required this.regionKey,
    required this.windowKey,
    required this.savedHotelIds,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Fluttertoast.showToast(msg: '더보기는 준비중입니다.');
                },
                child: const Text(
                  '더보기',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 252,
          child: StreamBuilder(
            stream: HotelDealsService.getDealCardsStream(
              regionKey: regionKey,
              windowKey: windowKey,
              limit: 12,
            ),
            builder: (context, snap) {
              if (snap.hasError) {
                hotelLog('DealSection ERROR: regionKey=$regionKey windowKey=$windowKey err=${snap.error}');
                return _ErrorInline(
                  message:
                      '딜 로딩 실패: ${snap.error}\n\n(인덱스/권한 문제일 수 있어요)',
                );
              }
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: ColorConstants.milecatchBrown,
                  ),
                );
              }
              final deals = snap.data ?? const [];
              if (deals.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: const Center(
                      child: Text(
                        '조건에 맞는 호텔 특가가 없습니다.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                );
              }

              final user = FirebaseAuth.instance.currentUser;

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: deals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final deal = deals[i];
                  final isSaved = savedHotelIds.contains(deal.hotelId);
                  return HotelDealCardTile(
                    deal: deal,
                    isSaved: isSaved,
                    onToggleSaved: user == null
                        ? null
                        : () => HotelDealsService.toggleSavedHotel(
                              hotelId: deal.hotelId,
                              name: deal.name,
                              imageUrl: deal.imageUrl,
                            ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HotelDetailScreen(initialDeal: deal),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountryFlag extends StatelessWidget {
  final String countryCode;
  const _CountryFlag({required this.countryCode});

  @override
  Widget build(BuildContext context) {
    final asset = _countryToFlagAsset(countryCode);
    if (asset == null) return const SizedBox(width: 18, height: 18);
    return Image.asset(asset, width: 18, height: 18, fit: BoxFit.contain);
  }

  String? _countryToFlagAsset(String cc) {
    final c = cc.toLowerCase();
    const supported = {
      'kr',
      'jp',
      'cn',
      'us',
      'ca',
      'mx',
      'gb',
      'fr',
      'de',
      'es',
      'pt',
      'gr',
      'au',
      'nz',
      'ae',
      'th',
      'sg',
      'vn',
      'ph',
      'id',
      'in',
      'my',
    };
    if (!supported.contains(c)) return null;
    return 'asset/img/flag_$c.png';
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.black54, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorInline extends StatelessWidget {
  final String message;
  const _ErrorInline({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}


