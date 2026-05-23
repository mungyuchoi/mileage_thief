import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/marriott_stay_calculator.dart';
import '../models/marriott_stay_record.dart';
import '../services/analytics_service.dart';
import '../services/marriott_stay_service.dart';

class MarriottStayFormScreen extends StatefulWidget {
  final MarriottStayRecord? initialRecord;
  final Color accentColor;

  const MarriottStayFormScreen({
    super.key,
    this.initialRecord,
    this.accentColor = PointStayColors.accent,
  });

  @override
  State<MarriottStayFormScreen> createState() => _MarriottStayFormScreenState();
}

class _MarriottStayFormScreenState extends State<MarriottStayFormScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat _numberFormat = NumberFormat('#,###');

  late MarriottStayType _stayType;
  late MarriottEliteTierOption _tier;
  late DateTime _checkIn;
  late DateTime _checkOut;

  late final TextEditingController _hotelController;
  late final TextEditingController _roomRateController;
  late final TextEditingController _taxController;
  late final TextEditingController _serviceChargeController;
  late final TextEditingController _exchangeRateController;
  late final TextEditingController _pointValueController;
  late final TextEditingController _welcomePointsController;
  late final TextEditingController _promoPointsController;
  late final TextEditingController _earnedPointsController;
  late final TextEditingController _bookingNumberController;
  late final TextEditingController _memoController;

  bool _saving = false;
  bool _syncingEarnedPoints = false;
  bool _earnedPointsEdited = false;

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    _stayType = record?.stayType ?? MarriottStayType.paid;
    _tier = _tierForRecord(record);
    _checkIn = _dateOnly(record?.checkIn ?? DateTime.now());
    _checkOut = _dateOnly(
      record?.checkOut ?? DateTime.now().add(const Duration(days: 1)),
    );

    _hotelController = TextEditingController(text: record?.hotelName ?? '');
    _roomRateController =
        TextEditingController(text: _initialInt(record?.roomRate));
    _taxController =
        TextEditingController(text: _initialInt(record?.taxAmount));
    _serviceChargeController =
        TextEditingController(text: _initialInt(record?.serviceCharge));
    _exchangeRateController = TextEditingController(
      text: _initialDouble(record?.exchangeRateKrwPerUsd, fallback: 1200),
    );
    _pointValueController = TextEditingController(
      text: _initialDouble(record?.pointValueKrw, fallback: 10),
    );
    _welcomePointsController =
        TextEditingController(text: _initialInt(record?.welcomePoints ?? 500));
    _promoPointsController =
        TextEditingController(text: _initialInt(record?.promoPoints ?? 2000));
    _earnedPointsController =
        TextEditingController(text: _initialInt(record?.earnedPoints));
    _bookingNumberController =
        TextEditingController(text: record?.bookingNumber ?? '');
    _memoController = TextEditingController(text: record?.memo ?? '');

    _earnedPointsEdited = record != null;
    for (final controller in [
      _roomRateController,
      _taxController,
      _serviceChargeController,
      _exchangeRateController,
      _pointValueController,
      _welcomePointsController,
      _promoPointsController,
    ]) {
      controller.addListener(_handleFormulaInputChanged);
    }
    _earnedPointsController.addListener(_handleEarnedPointsEdited);
    if (record == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncEarnedPointsFromFormula();
      });
    }
  }

  MarriottEliteTierOption _tierForRecord(MarriottStayRecord? record) {
    if (record == null) return MarriottEliteTierOption.defaultOption;
    final stored = MarriottEliteTierOption.fromStored(
      name: record.eliteTierName,
      multiplier: record.eliteMultiplier,
    );
    return MarriottEliteTierOption.options.firstWhere(
      (option) =>
          option.name == stored.name ||
          (option.multiplier - stored.multiplier).abs() < 0.0001,
      orElse: () => MarriottEliteTierOption.defaultOption,
    );
  }

  @override
  void dispose() {
    _hotelController.dispose();
    _roomRateController.dispose();
    _taxController.dispose();
    _serviceChargeController.dispose();
    _exchangeRateController.dispose();
    _pointValueController.dispose();
    _welcomePointsController.dispose();
    _promoPointsController.dispose();
    _earnedPointsController.dispose();
    _bookingNumberController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _handleFormulaInputChanged() {
    if (!_earnedPointsEdited) {
      _syncEarnedPointsFromFormula();
    }
    if (mounted) setState(() {});
  }

  void _handleEarnedPointsEdited() {
    if (_syncingEarnedPoints) return;
    _earnedPointsEdited = true;
    if (mounted) setState(() {});
  }

  void _syncEarnedPointsFromFormula() {
    final autoPoints = _autoEarnedPoints();
    final nextText = autoPoints <= 0 ? '' : autoPoints.toString();
    if (_earnedPointsController.text == nextText) return;
    _syncingEarnedPoints = true;
    _earnedPointsController.text = nextText;
    _syncingEarnedPoints = false;
  }

  int _autoEarnedPoints() {
    if (_stayType != MarriottStayType.paid) return 0;
    final roomRate = _parseInt(_roomRateController.text);
    if (roomRate <= 0) return 0;
    return MarriottStayCalculator.calculateEarnedPoints(
      roomRate: roomRate,
      exchangeRateKrwPerUsd: _parseDouble(
        _exchangeRateController.text,
        fallback: 1200,
      ),
      eliteMultiplier: _tier.multiplier,
      welcomePoints: _parseInt(_welcomePointsController.text),
      promoPoints: _parseInt(_promoPointsController.text),
    );
  }

  MarriottStayCalculationResult _calculation() {
    final bool paid = _stayType == MarriottStayType.paid;
    final earnedPointsText = _earnedPointsController.text.trim();
    final earnedOverride =
        earnedPointsText.isEmpty ? 0 : _parseInt(earnedPointsText);
    return MarriottStayCalculator.calculate(
      MarriottStayCalculationInput(
        checkIn: _checkIn,
        checkOut: _checkOut,
        roomRate: paid ? _parseInt(_roomRateController.text) : 0,
        taxAmount: paid ? _parseInt(_taxController.text) : 0,
        serviceCharge: paid ? _parseInt(_serviceChargeController.text) : 0,
        exchangeRateKrwPerUsd: _parseDouble(
          _exchangeRateController.text,
          fallback: 1200,
        ),
        eliteMultiplier: _tier.multiplier,
        welcomePoints: paid ? _parseInt(_welcomePointsController.text) : 0,
        promoPoints: paid ? _parseInt(_promoPointsController.text) : 0,
        pointValueKrw: _parseDouble(_pointValueController.text, fallback: 10),
        earnedPointsOverride: earnedOverride,
      ),
    );
  }

  Future<void> _pickDate({required bool checkIn}) async {
    final initial = checkIn ? _checkIn : _checkOut;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: widget.accentColor),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (checkIn) {
        _checkIn = _dateOnly(picked);
        if (_checkOut.isBefore(_checkIn)) {
          _checkOut = _checkIn;
        }
      } else {
        _checkOut = _dateOnly(picked);
      }
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final hotelName = _hotelController.text.trim();
    if (hotelName.isEmpty) {
      Fluttertoast.showToast(msg: '호텔명을 입력해주세요.');
      return;
    }
    if (_checkOut.isBefore(_checkIn)) {
      Fluttertoast.showToast(msg: '체크아웃 날짜를 확인해주세요.');
      return;
    }
    if (_stayType == MarriottStayType.paid &&
        _parseInt(_roomRateController.text) <= 0) {
      Fluttertoast.showToast(msg: '룸레이트를 입력해주세요.');
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final paid = _stayType == MarriottStayType.paid;
      final calculation = _calculation();
      final record = MarriottStayRecord(
        id: widget.initialRecord?.id ?? '',
        stayType: _stayType,
        checkIn: _checkIn,
        checkOut: _checkOut,
        nights: calculation.nights,
        hotelName: hotelName,
        totalAmount: calculation.totalAmount,
        roomRate: paid ? _parseInt(_roomRateController.text) : 0,
        taxAmount: paid ? _parseInt(_taxController.text) : 0,
        serviceCharge: paid ? _parseInt(_serviceChargeController.text) : 0,
        earnedPoints: calculation.earnedPoints,
        returnRate: calculation.returnRate,
        bookingNumber: _bookingNumberController.text.trim(),
        memo: _memoController.text.trim(),
        pointValueKrw: _parseDouble(_pointValueController.text, fallback: 10),
        exchangeRateKrwPerUsd: _parseDouble(
          _exchangeRateController.text,
          fallback: 1200,
        ),
        eliteTierName: _tier.name,
        eliteMultiplier: _tier.multiplier,
        welcomePoints: paid ? _parseInt(_welcomePointsController.text) : 0,
        promoPoints: paid ? _parseInt(_promoPointsController.text) : 0,
        createdAt: widget.initialRecord?.createdAt,
        updatedAt: widget.initialRecord?.updatedAt,
      );
      await MarriottStayService.saveStay(uid: uid, record: record);
      AnalyticsService.instance.logAction('marriott_stay_saved', params: {
        'mode': widget.initialRecord == null ? 'create' : 'edit',
        'stay_type': _stayType.value,
        'nights': calculation.nights,
        'total_amount': calculation.totalAmount,
      });
      Fluttertoast.showToast(
        msg: widget.initialRecord == null ? '숙박기록이 저장되었습니다.' : '숙박기록이 수정되었습니다.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('메리어트 숙박기록 저장 오류: $e');
      Fluttertoast.showToast(msg: '저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculation = _calculation();
    final paid = _stayType == MarriottStayType.paid;

    return Theme(
      data: _accentTheme(context),
      child: Scaffold(
        backgroundColor: McColors.background,
        appBar: AppBar(
          title: Text(
            widget.initialRecord == null ? '메리어트 숙박 기록 추가' : '메리어트 숙박 기록 수정',
          ),
          backgroundColor: Colors.white,
          foregroundColor: McColors.ink,
          elevation: 0.4,
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _FormSection(
                  title: '숙박 유형',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in MarriottStayType.values)
                          ChoiceChip(
                            label: Text(type.label),
                            selected: _stayType == type,
                            onSelected: (_) {
                              setState(() {
                                _stayType = type;
                                _earnedPointsEdited = false;
                                _syncEarnedPointsFromFormula();
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FormSection(
                  title: '기본 정보',
                  children: [
                    const _FieldLabel('호텔명'),
                    TextFormField(
                      controller: _hotelController,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(hintText: '예: 코트야드 보타닉 파크'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: '체크인',
                            value: _dateFormat.format(_checkIn),
                            onTap: () => _pickDate(checkIn: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateButton(
                            label: '체크아웃',
                            value: _dateFormat.format(_checkOut),
                            onTap: () => _pickDate(checkIn: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (paid) ...[
                  const SizedBox(height: 10),
                  _FormSection(
                    title: '금액',
                    children: [
                      _MoneyField(
                        label: '룸레이트',
                        controller: _roomRateController,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MoneyField(
                              label: '세금',
                              controller: _taxController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MoneyField(
                              label: '봉사료',
                              controller: _serviceChargeController,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FormSection(
                    title: '포인트 계산',
                    children: [
                      const _FieldLabel('티어'),
                      DropdownButtonFormField<MarriottEliteTierOption>(
                        initialValue: _tier,
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(),
                        items: [
                          for (final option in MarriottEliteTierOption.options)
                            DropdownMenuItem(
                              value: option,
                              child:
                                  Text('${option.name} x${option.multiplier}'),
                            ),
                        ],
                        onChanged: (option) {
                          if (option == null) return;
                          setState(() {
                            _tier = option;
                            if (!_earnedPointsEdited) {
                              _syncEarnedPointsFromFormula();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DecimalField(
                              label: '1달러 환율',
                              controller: _exchangeRateController,
                              suffixText: '원',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DecimalField(
                              label: '1포인트 가치',
                              controller: _pointValueController,
                              suffixText: '원',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              label: '웰컴 포인트',
                              controller: _welcomePointsController,
                              suffixText: 'P',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NumberField(
                              label: '프로모션 포인트',
                              controller: _promoPointsController,
                              suffixText: 'P',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _FormSection(
                  title: '획득 포인트',
                  trailing: paid && _earnedPointsEdited
                      ? TextButton(
                          onPressed: () {
                            setState(() {
                              _earnedPointsEdited = false;
                              _syncEarnedPointsFromFormula();
                            });
                          },
                          child: const Text('자동계산'),
                        )
                      : null,
                  children: [
                    _NumberField(
                      label: '획득 포인트',
                      controller: _earnedPointsController,
                      suffixText: 'P',
                    ),
                    const SizedBox(height: 10),
                    _CalculationPreview(
                      calculation: calculation,
                      numberFormat: _numberFormat,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FormSection(
                  title: '메모',
                  children: [
                    const _FieldLabel('예약번호'),
                    TextFormField(
                      controller: _bookingNumberController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: '선택 입력'),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('비고'),
                    TextFormField(
                      controller: _memoController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '예: BRG 5,000P / 35,000P 사용',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? '저장 중' : '저장'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _accentTheme(BuildContext context) {
    final base = Theme.of(context);
    final colorScheme = base.colorScheme.copyWith(
      primary: widget.accentColor,
      secondary: widget.accentColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: widget.accentColor,
      chipTheme: base.chipTheme.copyWith(
        selectedColor: PointStayColors.accentSoft,
        checkmarkColor: widget.accentColor,
        secondaryLabelStyle: McTextStyles.meta.copyWith(
          color: widget.accentColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: widget.accentColor,
          textStyle: McTextStyles.bodyStrong,
          visualDensity: VisualDensity.compact,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.accentColor,
          foregroundColor: Colors.white,
        ),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: widget.accentColor,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.accentColor, width: 1.2),
        ),
      ),
    );
  }
}

class _CalculationPreview extends StatelessWidget {
  final MarriottStayCalculationResult calculation;
  final NumberFormat numberFormat;

  const _CalculationPreview({
    required this.calculation,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          _PreviewValue(label: '박수', value: '${calculation.nights}박'),
          _PreviewValue(
            label: '총액',
            value: '${numberFormat.format(calculation.totalAmount)}원',
          ),
          _PreviewValue(
            label: '회수율',
            value: '${calculation.returnRate.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _PreviewValue extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: McTextStyles.micro),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.bodyStrong,
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _FormSection({
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: McTextStyles.cardTitle)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: McTextStyles.meta),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value, style: McTextStyles.bodyStrong),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MoneyField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return _NumberField(
      label: label,
      controller: controller,
      suffixText: '원',
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffixText;

  const _NumberField({
    required this.label,
    required this.controller,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: suffixText),
        ),
      ],
    );
  }
}

class _DecimalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffixText;

  const _DecimalField({
    required this.label,
    required this.controller,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(suffixText: suffixText),
        ),
      ],
    );
  }
}

String _initialInt(int? value) {
  if (value == null || value == 0) return '';
  return value.toString();
}

String _initialDouble(double? value, {required double fallback}) {
  final actual = value ?? fallback;
  if (actual % 1 == 0) return actual.toInt().toString();
  return actual.toString();
}

int _parseInt(String value) {
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.trim()) ?? fallback;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
