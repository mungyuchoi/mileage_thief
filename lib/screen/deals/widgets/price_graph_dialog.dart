import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/deal_model.dart';
import '../../../services/deals_service.dart';
import 'package:intl/intl.dart';

class PriceGraphDialog extends StatefulWidget {
  final DealModel deal;

  const PriceGraphDialog({
    super.key,
    required this.deal,
  });

  @override
  State<PriceGraphDialog> createState() => _PriceGraphDialogState();
}

class _PriceGraphDialogState extends State<PriceGraphDialog> {
  List<Map<String, dynamic>> _priceHistory = [];
  bool _isLoading = true;
  int? _minPrice;
  int? _maxPrice;
  double? _avgPrice;
  DateTime? _minPriceTime;
  DateTime? _maxPriceTime;

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  Future<void> _loadPriceHistory() async {
    try {
      // 가격 이력 조회 (최근 30개)
      final stream = DealsService.getPriceHistory(widget.deal.dealId, limit: 30);
      final snapshot = await stream.first.timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _priceHistory = snapshot.reversed.toList(); // 시간순으로 정렬 (오래된 것부터)
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가격 이력을 불러올 수 없습니다: $e')),
        );
      }
    }
  }

  void _calculateStats() {
    // 현재 가격도 포함
    final allPrices = <int>[];
    
    // 가격 이력에서 가격 추출
    for (var item in _priceHistory) {
      if (item['price'] != null) {
        allPrices.add(item['price'] as int);
      }
    }
    
    // 현재 가격도 추가 (가격 이력에 없을 수 있으므로)
    if (widget.deal.price > 0) {
      allPrices.add(widget.deal.price);
    }

    if (allPrices.isEmpty) return;

    _minPrice = allPrices.reduce((a, b) => a < b ? a : b);
    _maxPrice = allPrices.reduce((a, b) => a > b ? a : b);
    _avgPrice = allPrices.reduce((a, b) => a + b) / allPrices.length;

    // 최저가 시간 찾기
    for (var item in _priceHistory) {
      if (item['price'] == _minPrice) {
        final recordedAt = item['recorded_at'];
        if (recordedAt != null) {
          if (recordedAt is Timestamp) {
            _minPriceTime = recordedAt.toDate();
          } else if (recordedAt is DateTime) {
            _minPriceTime = recordedAt;
          }
        }
        break;
      }
    }

    // 최고가 시간 찾기
    for (var item in _priceHistory) {
      if (item['price'] == _maxPrice) {
        final recordedAt = item['recorded_at'];
        if (recordedAt != null) {
          if (recordedAt is Timestamp) {
            _maxPriceTime = recordedAt.toDate();
          } else if (recordedAt is DateTime) {
            _maxPriceTime = recordedAt;
          }
        }
        break;
      }
    }
  }

  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('MM.dd HH시', 'ko').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '가격 추적',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  // 할인율 표시
                  if (widget.deal.priceChangePercent != null && widget.deal.priceChangePercent! < 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.deal.priceChangePercent!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 내용
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _priceHistory.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              '가격 이력 데이터가 없습니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 최저가, 평균가, 최고가 정보
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPriceInfoBox(
                                      '최저',
                                      _minPrice != null ? _formatPrice(_minPrice!) : '-',
                                      _minPriceTime != null
                                          ? _formatDateTime(_minPriceTime)
                                          : '',
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildPriceInfoBox(
                                      '평균가',
                                      _avgPrice != null
                                          ? _formatPrice(_avgPrice!.round())
                                          : '-',
                                      '',
                                      Colors.grey[700]!,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildPriceInfoBox(
                                      '최고',
                                      _maxPrice != null ? _formatPrice(_maxPrice!) : '-',
                                      _maxPriceTime != null
                                          ? _formatDateTime(_maxPriceTime)
                                          : '',
                                      Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // 차트
                              Container(
                                height: 250,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildChart(),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfoBox(String label, String price, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time.isNotEmpty ? time : ' ',
            style: TextStyle(
              fontSize: 9,
              color: time.isNotEmpty ? Colors.grey[500] : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_priceHistory.isEmpty || _minPrice == null || _maxPrice == null) {
      return const Center(
        child: Text('차트 데이터가 없습니다.'),
      );
    }

    final priceRange = _maxPrice! - _minPrice!;
    final pricePadding = priceRange * 0.1; // 10% 여백

    // 차트 데이터 포인트 생성 (가격 이력 + 현재 가격)
    final spots = <FlSpot>[];
    
    // 가격 이력 포인트
    for (var entry in _priceHistory.asMap().entries) {
      final index = entry.key.toDouble();
      final price = entry.value['price'] as int? ?? 0;
      // Y축: 가격을 0-1 범위로 정규화 (높은 가격이 위, 낮은 가격이 아래)
      final normalizedY = priceRange > 0
          ? ((price - _minPrice! + pricePadding) / (priceRange + pricePadding * 2))
          : 0.5;
      spots.add(FlSpot(index, normalizedY));
    }
    
    // 현재 가격을 마지막 포인트로 추가
    if (widget.deal.price > 0) {
      final currentPriceIndex = _priceHistory.length.toDouble();
      final normalizedY = priceRange > 0
          ? ((widget.deal.price - _minPrice! + pricePadding) / (priceRange + pricePadding * 2))
          : 0.5;
      spots.add(FlSpot(currentPriceIndex, normalizedY));
    }

    // X축 레이블 (날짜 + 현재)
    final xLabels = <String>[];
    for (var item in _priceHistory) {
      final recordedAt = item['recorded_at'];
      DateTime? dateTime;
      if (recordedAt != null) {
        if (recordedAt is Timestamp) {
          dateTime = recordedAt.toDate();
        } else if (recordedAt is DateTime) {
          dateTime = recordedAt;
        }
      }
      if (dateTime != null) {
        xLabels.add(DateFormat('MM.dd', 'ko').format(dateTime));
      } else {
        xLabels.add('');
      }
    }
    
    // 현재 가격 레이블 추가
    if (widget.deal.price > 0) {
      xLabels.add('현재');
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: xLabels.length > 10 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      xLabels[index],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 70,
              interval: 0.25,
              getTitlesWidget: (value, meta) {
                // 정규화된 값을 실제 가격으로 변환 (높은 가격이 위, 낮은 가격이 아래)
                final price = _minPrice! +
                    (value * (priceRange + pricePadding * 2) - pricePadding).round();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _formatPrice(price),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: spots.isNotEmpty ? spots.last.x : (_priceHistory.length - 1).toDouble(),
        minY: 0,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue[400],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue[400]!,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue[50]!,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _priceHistory.length) {
                  final item = _priceHistory[index];
                  final price = item['price'] as int? ?? 0;
                  final recordedAt = item['recorded_at'];
                  String timeStr = '';
                  if (recordedAt != null) {
                    DateTime? dateTime;
                    if (recordedAt is Timestamp) {
                      dateTime = recordedAt.toDate();
                    } else if (recordedAt is DateTime) {
                      dateTime = recordedAt;
                    }
                    if (dateTime != null) {
                      timeStr = DateFormat('MM.dd HH시', 'ko').format(dateTime);
                    }
                  }
                  return LineTooltipItem(
                    '${_formatPrice(price)}\n$timeStr',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                } else if (index == _priceHistory.length && widget.deal.price > 0) {
                  // 현재 가격
                  return LineTooltipItem(
                    '${_formatPrice(widget.deal.price)}\n현재',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

