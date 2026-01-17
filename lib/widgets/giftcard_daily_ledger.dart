import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum GiftcardLedgerEntryType { buy, sell }

@immutable
class GiftcardLedgerEntry {
  final GiftcardLedgerEntryType type;
  final String id;
  final String giftcardId;
  final String giftcardName;
  final DateTime dateTime;
  final int qty;
  final int unitPrice;
  final int amount;
  final int profit; // sell only (0 for buy)
  final double? discount; // % (nullable)
  final String? branchName; // sell only
  final String? cardName; // buy only
  final String? payType; // '신용' | '체크' | etc
  final String? whereToBuyName; // buy only
  final String? memo; // buy only
  final bool deletable; // buy: open only, sell: always true in current UX
  final bool? trade; // buy only: 교환 완료 여부 (null이면 false로 간주)
  final Map<String, dynamic> raw;

  const GiftcardLedgerEntry({
    required this.type,
    required this.id,
    required this.giftcardId,
    required this.giftcardName,
    required this.dateTime,
    required this.qty,
    required this.unitPrice,
    required this.amount,
    required this.profit,
    required this.discount,
    required this.branchName,
    required this.cardName,
    required this.payType,
    required this.whereToBuyName,
    required this.memo,
    required this.deletable,
    this.trade,
    required this.raw,
  });
}

@immutable
class GiftcardLedgerDayGroup {
  final DateTime day; // y-m-d normalized
  final List<GiftcardLedgerEntry> entries;
  final int sumBuyAmount;
  final int sumSellAmount;
  final int sumProfit;

  const GiftcardLedgerDayGroup({
    required this.day,
    required this.entries,
    required this.sumBuyAmount,
    required this.sumSellAmount,
    required this.sumProfit,
  });
}

class GiftcardDailyLedgerMapper {
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _toDateTime(dynamic ts) {
    // Timestamp comes from cloud_firestore, but we keep mapper decoupled.
    // Timestamp has toDate(); fallback to epoch on unexpected type.
    try {
      final dynamic maybe = ts;
      final dynamic d = maybe?.toDate?.call();
      if (d is DateTime) return d;
    } catch (_) {}
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<GiftcardLedgerDayGroup> buildDayGroups({
    required List<Map<String, dynamic>> lots,
    required List<Map<String, dynamic>> sales,
    required Map<String, String> giftcardNames,
    required Map<String, Map<String, dynamic>> lotById,
    required Map<String, String> branchNames,
    required Map<String, String> whereToBuyNames,
    required Map<String, Map<String, dynamic>> cards, // cardId -> {name, credit, check}
    required Set<String> filterGiftcardIds, // empty => all
  }) {
    final List<GiftcardLedgerEntry> entries = [];

    for (final lot in lots) {
      final String id = (lot['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final String giftcardId = (lot['giftcardId'] as String?) ?? '';
      if (giftcardId.isEmpty) continue;
      if (filterGiftcardIds.isNotEmpty && !filterGiftcardIds.contains(giftcardId)) {
        continue;
      }
      final DateTime dt = _toDateTime(lot['buyDate']);
      final int qty = _asInt(lot['qty']);
      final int unit = _asInt(lot['buyUnit']);
      final double? discount = (lot['discount'] as num?)?.toDouble();
      final String cardId = (lot['cardId'] as String?) ?? '';
      final String? cardName = (cards[cardId]?['name'] as String?) ?? (cardId.isEmpty ? null : cardId);
      final String? payType = (lot['payType'] as String?)?.trim();
      final String? whereToBuyId = lot['whereToBuyId'] as String?;
      final String? whereToBuyName = (whereToBuyId == null || whereToBuyId.isEmpty) ? null : (whereToBuyNames[whereToBuyId] ?? whereToBuyId);
      final String? memo = (lot['memo'] as String?)?.trim();
      final String status = (lot['status'] as String?) ?? 'open';
      final bool deletable = status == 'open';
      // status가 'sold'면 trade는 true, 아니면 lot의 trade 값 (기본값 false)
      final bool? trade = status == 'sold' ? true : (lot['trade'] as bool?);
      final String name = giftcardNames[giftcardId] ?? giftcardId;
      entries.add(
        GiftcardLedgerEntry(
          type: GiftcardLedgerEntryType.buy,
          id: id,
          giftcardId: giftcardId,
          giftcardName: name,
          dateTime: dt,
          qty: qty,
          unitPrice: unit,
          amount: qty * unit,
          profit: 0,
          discount: discount,
          branchName: null,
          cardName: cardName,
          payType: payType,
          whereToBuyName: whereToBuyName,
          memo: (memo != null && memo.isNotEmpty) ? memo : null,
          deletable: deletable,
          trade: trade,
          raw: Map<String, dynamic>.from(lot),
        ),
      );
    }

    for (final sale in sales) {
      final String id = (sale['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final DateTime dt = _toDateTime(sale['sellDate']);
      final int qty = _asInt(sale['qty']);
      final int unit = _asInt(sale['sellUnit']);
      final int profit = _asInt(sale['profit']);
      final double? discount = (sale['discount'] as num?)?.toDouble();
      final String? branchId = sale['branchId'] as String?;
      final String? branchName = (branchId == null || branchId.isEmpty) ? null : (branchNames[branchId] ?? branchId);

      String giftcardId = (sale['giftcardId'] as String?) ?? '';
      final String? lotId = sale['lotId'] as String?;
      if (giftcardId.isEmpty && lotId != null) {
        final lot = lotById[lotId];
        giftcardId = (lot?['giftcardId'] as String?) ?? '';
      }
      if (giftcardId.isEmpty) continue;
      if (filterGiftcardIds.isNotEmpty && !filterGiftcardIds.contains(giftcardId)) {
        continue;
      }
      final String name = giftcardNames[giftcardId] ?? giftcardId;
      entries.add(
        GiftcardLedgerEntry(
          type: GiftcardLedgerEntryType.sell,
          id: id,
          giftcardId: giftcardId,
          giftcardName: name,
          dateTime: dt,
          qty: qty,
          unitPrice: unit,
          amount: qty * unit,
          profit: profit,
          discount: discount,
          branchName: branchName,
          cardName: null,
          payType: null,
          whereToBuyName: null,
          memo: null,
          deletable: true,
          raw: Map<String, dynamic>.from(sale),
        ),
      );
    }

    entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final Map<DateTime, List<GiftcardLedgerEntry>> byDay = {};
    for (final e in entries) {
      final day = _dayOf(e.dateTime);
      byDay.putIfAbsent(day, () => []).add(e);
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final d in days)
        _buildGroup(d, byDay[d]!),
    ];
  }

  static GiftcardLedgerDayGroup _buildGroup(DateTime day, List<GiftcardLedgerEntry> entries) {
    int sumBuy = 0;
    int sumSell = 0;
    int sumProfit = 0;
    for (final e in entries) {
      if (e.type == GiftcardLedgerEntryType.buy) {
        sumBuy += e.amount;
      } else {
        sumSell += e.amount;
        sumProfit += e.profit;
      }
    }
    return GiftcardLedgerDayGroup(
      day: day,
      entries: entries,
      sumBuyAmount: sumBuy,
      sumSellAmount: sumSell,
      sumProfit: sumProfit,
    );
  }
}

class GiftcardDailyLedger extends StatelessWidget {
  final List<GiftcardLedgerDayGroup> groups;
  final NumberFormat wonFormat;
  final DateFormat dayFormat;
  final void Function(GiftcardLedgerEntry entry) onEdit;
  final void Function(GiftcardLedgerEntry entry) onDelete;
  final void Function(GiftcardLedgerEntry entry, bool trade)? onTradeToggle;

  const GiftcardDailyLedger({
    super.key,
    required this.groups,
    required this.wonFormat,
    required this.dayFormat,
    required this.onEdit,
    required this.onDelete,
    this.onTradeToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
        child: Text('데이터가 없습니다.', style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      itemCount: _countItems(),
      itemBuilder: (context, index) {
        final item = _itemAt(index);
        if (item is _DayHeaderItem) {
          return _DayHeaderRow(
            dayText: dayFormat.format(item.group.day),
            sumSell: item.group.sumSellAmount,
            sumBuy: item.group.sumBuyAmount,
            won: wonFormat,
          );
        }
        if (item is _EntryItem) {
          return _LedgerEntryRow(
            entry: item.entry,
            won: wonFormat,
            onEdit: onEdit,
            onDelete: onDelete,
            onTradeToggle: onTradeToggle,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  int _countItems() {
    // (day header + entries)
    int n = 0;
    for (final g in groups) {
      n += 1 + g.entries.length;
    }
    return n;
  }

  _LedgerListItem _itemAt(int index) {
    int cursor = 0;
    for (final g in groups) {
      if (index == cursor) return _DayHeaderItem(g);
      cursor += 1;
      final int end = cursor + g.entries.length;
      if (index < end) {
        return _EntryItem(g.entries[index - cursor]);
      }
      cursor = end;
    }
    return const _EmptyItem();
  }
}

abstract class _LedgerListItem {
  const _LedgerListItem();
}

class _DayHeaderItem extends _LedgerListItem {
  final GiftcardLedgerDayGroup group;
  const _DayHeaderItem(this.group);
}

class _EntryItem extends _LedgerListItem {
  final GiftcardLedgerEntry entry;
  const _EntryItem(this.entry);
}

class _EmptyItem extends _LedgerListItem {
  const _EmptyItem();
}

class _DayHeaderRow extends StatelessWidget {
  final String dayText;
  final int sumSell;
  final int sumBuy;
  final NumberFormat won;

  const _DayHeaderRow({
    required this.dayText,
    required this.sumSell,
    required this.sumBuy,
    required this.won,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dayText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
            ),
          ),
          Text(
            '+${won.format(sumSell)}',
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Text(
            '-${won.format(sumBuy)}',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntryRow extends StatelessWidget {
  final GiftcardLedgerEntry entry;
  final NumberFormat won;
  final void Function(GiftcardLedgerEntry entry) onEdit;
  final void Function(GiftcardLedgerEntry entry) onDelete;
  final void Function(GiftcardLedgerEntry entry, bool trade)? onTradeToggle;

  const _LedgerEntryRow({
    required this.entry,
    required this.won,
    required this.onEdit,
    required this.onDelete,
    this.onTradeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSell = entry.type == GiftcardLedgerEntryType.sell;
    final Color typeColor = isSell ? Colors.blue : Colors.red;
    final String typeText = isSell ? '판매' : '구매';
    final Color amountColor = isSell ? Colors.blue : Colors.red;

    String fmtPercent(double v) {
      final s = v.toStringAsFixed(2);
      if (s.endsWith('00')) return s.substring(0, s.length - 3);
      if (s.endsWith('0')) return s.substring(0, s.length - 1);
      return s;
    }

    Widget pill(String text, {IconData? icon}) => _MiniPill(text: text, icon: icon);

    final pills = <Widget>[];
    if (isSell) {
      pills.add(pill('판매가 ${won.format(entry.unitPrice)}원', icon: Icons.sell_outlined));
      if (entry.discount != null) {
        pills.add(pill('할인율 ${fmtPercent(entry.discount!)}%', icon: Icons.percent));
      }
      pills.add(pill('손익 ${won.format(entry.profit)}원', icon: Icons.trending_up_outlined));
      pills.add(pill(entry.giftcardName, icon: Icons.card_giftcard_outlined));
      if (entry.branchName != null && entry.branchName!.isNotEmpty) {
        pills.add(pill(entry.branchName!, icon: Icons.store_outlined));
      }
    } else {
      pills.add(pill('매입가 ${won.format(entry.unitPrice)}원', icon: Icons.payments_outlined));
      if (entry.discount != null) {
        pills.add(pill('할인율 ${fmtPercent(entry.discount!)}%', icon: Icons.percent));
      }
      if (entry.cardName != null && entry.cardName!.isNotEmpty) {
        pills.add(pill('카드 ${entry.cardName!}', icon: Icons.credit_card_outlined));
      }
      if (entry.payType != null && entry.payType!.isNotEmpty) {
        pills.add(pill(entry.payType!, icon: Icons.account_balance_wallet_outlined));
      }
      if (entry.whereToBuyName != null && entry.whereToBuyName!.isNotEmpty) {
        pills.add(pill(entry.whereToBuyName!, icon: Icons.storefront_outlined));
      }
      if (entry.memo != null && entry.memo!.isNotEmpty) {
        pills.add(pill(entry.memo!, icon: Icons.note_outlined));
      }
      // status가 'open'인 구매 건에는 미교환/교환완료 버튼 추가 (클릭 가능)
      // status가 'sold'인 구매 건에는 교환완료 아이콘만 표시 (클릭 불가)
      final String status = (entry.raw['status'] as String?) ?? 'open';
      if (status == 'open' && onTradeToggle != null) {
        final bool isTraded = entry.trade == true;
        pills.add(
          GestureDetector(
            onTap: () => onTradeToggle!(entry, !isTraded),
            child: _MiniPill(
              text: isTraded ? '교환완료' : '미교환',
              icon: Icons.swap_horiz_outlined,
            ),
          ),
        );
      } else if (status == 'sold') {
        // sold 상태인 경우 교환완료 아이콘만 표시 (클릭 불가)
        pills.add(
          _MiniPill(
            text: '교환완료',
            icon: Icons.swap_horiz_outlined,
          ),
        );
      }
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(typeText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: typeColor)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.qty}장 · ${entry.giftcardName}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isSell ? '+' : '-'}${won.format(entry.amount)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: amountColor),
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.black54),
                onSelected: (v) {
                  if (v == 'edit') onEdit(entry);
                  if (v == 'delete') onDelete(entry);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('편집')),
                  PopupMenuItem(value: 'delete', enabled: entry.deletable, child: Text(entry.deletable ? '삭제' : '삭제 불가')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills,
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _MiniPill({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


