import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../const/colors.dart';
import '../models/user_point_model.dart';
import '../services/user_point_service.dart';
import '../widgets/profile_point_summary.dart';

class PointBalanceManageScreen extends StatefulWidget {
  const PointBalanceManageScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<PointBalanceManageScreen> createState() =>
      _PointBalanceManageScreenState();
}

class _PointBalanceManageScreenState extends State<PointBalanceManageScreen> {
  final UserPointService _service = UserPointService();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _representativesByCategory = {};
  String _selectedCategory = PointCategory.airline;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final brand in PointBrandCatalog.brands) {
      _controllers[brand.id] = TextEditingController();
    }
    _loadBalances();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBalances() async {
    try {
      final balances = await _service.loadBalances(widget.uid);
      final positiveFallbacks = <String, String>{};

      for (final balance in balances) {
        final controller = _controllers[balance.brandId];
        if (controller != null) {
          controller.text =
              balance.balance > 0 ? balance.balance.toString() : '';
        }
        if (balance.isRepresentative) {
          _representativesByCategory[balance.category] = balance.brandId;
        }
        if (balance.balance > 0 &&
            !positiveFallbacks.containsKey(balance.category)) {
          positiveFallbacks[balance.category] = balance.brandId;
        }
      }

      for (final entry in positiveFallbacks.entries) {
        _representativesByCategory.putIfAbsent(entry.key, () => entry.value);
      }
    } catch (_) {
      Fluttertoast.showToast(msg: '포인트 정보를 불러오지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final balancesByBrandId = <String, int>{};
      for (final brand in PointBrandCatalog.brands) {
        balancesByBrandId[brand.id] = _parsePoint(_controllers[brand.id]?.text);
      }

      final representatives = Map<String, String?>.from(
        _representativesByCategory,
      );
      for (final category in PointCategory.values) {
        representatives[category] ??= _firstPositiveBrandId(
          category,
          balancesByBrandId,
        );
      }

      await _service.saveAllCatalogBalances(
        uid: widget.uid,
        balancesByBrandId: balancesByBrandId,
        representativesByCategory: representatives,
      );

      Fluttertoast.showToast(msg: '포인트가 저장되었습니다.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      Fluttertoast.showToast(msg: '포인트 저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text(
          '포인트 관리',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _buildCategoryTabs(),
                ),
                Expanded(child: _buildBrandList()),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading || _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: McColors.accent,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: PointCategory.values.map((category) {
          final selected = _selectedCategory == category;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = category),
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  PointCategory.label(category),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandList() {
    final brands = PointBrandCatalog.byCategory(_selectedCategory);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemBuilder: (context, index) {
        return _PointBalanceBrandRow(
          brand: brands[index],
          controller: _controllers[brands[index].id]!,
          selectedRepresentative: _representativesByCategory[_selectedCategory],
          onRepresentativeChanged: (brandId) {
            setState(() {
              _representativesByCategory[_selectedCategory] = brandId;
            });
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: brands.length,
    );
  }

  int _parsePoint(String? value) {
    if (value == null) return 0;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String? _firstPositiveBrandId(
    String category,
    Map<String, int> balancesByBrandId,
  ) {
    for (final brand in PointBrandCatalog.byCategory(category)) {
      if ((balancesByBrandId[brand.id] ?? 0) > 0) return brand.id;
    }
    return null;
  }
}

class _PointBalanceBrandRow extends StatelessWidget {
  const _PointBalanceBrandRow({
    required this.brand,
    required this.controller,
    required this.selectedRepresentative,
    required this.onRepresentativeChanged,
  });

  final PointBrand brand;
  final TextEditingController controller;
  final String? selectedRepresentative;
  final ValueChanged<String> onRepresentativeChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedRepresentative == brand.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: McColors.field,
              borderRadius: BorderRadius.circular(8),
            ),
            child: PointBrandLogo(
              assetPath: brand.assetPath,
              fallbackAssetPath: brand.fallbackAssetPath,
              size: 30,
              category: brand.category,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  selected ? '대표 포인트' : brand.pointLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? McColors.accent : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: brand.pointLabel,
                suffixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
                isDense: true,
                filled: true,
                fillColor: McColors.field,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '대표',
            child: InkWell(
              onTap: () => onRepresentativeChanged(brand.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? McColors.accent : Colors.black26,
                    width: selected ? 6 : 2,
                  ),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
