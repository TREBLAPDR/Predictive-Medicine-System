// File: lib/widgets/forecast_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/forecast_data.dart';

class ForecastChart extends StatelessWidget {
  final List<ForecastDataPoint> historicalData;
  final List<ForecastDataPoint> predictedData;
  final DateTime todayDate;

  const ForecastChart({
    super.key,
    required this.historicalData,
    required this.predictedData,
    required this.todayDate,
  });

  @override
  Widget build(BuildContext context) {
    if (historicalData.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      );
    }

    final allData = [...historicalData, ...predictedData];
    final minDate = allData.first.date;
    final maxDate = allData.last.date;
    final dateRange = maxDate.difference(minDate).inDays.toDouble();

    // Find min and max values for Y axis
    double minValue = double.infinity;
    double maxValue = double.negativeInfinity;

    for (var point in allData) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
      if (point.lowerBound != null && point.lowerBound! < minValue) {
        minValue = point.lowerBound!;
      }
      if (point.upperBound != null && point.upperBound! > maxValue) {
        maxValue = point.upperBound!;
      }
    }

    final yPadding = (maxValue - minValue) * 0.1;
    final yMin = (minValue - yPadding).floorToDouble();
    final yMax = (maxValue + yPadding).ceilToDouble();

    return LineChart(
        LineChartData(
            minX: 0,
            maxX: dateRange,
            minY: yMin,
            maxY: yMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: (yMax - yMin) / 5,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: dateRange / 6,
                  getTitlesWidget: (value, meta) {
                    final date = minDate.add(Duration(days: value.toInt()));
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MMM d').format(date),
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                left: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            lineBarsData: [
              // Confidence interval (area)
              if (predictedData.isNotEmpty) _buildConfidenceInterval(minDate, dateRange),
              // Historical line (solid)
              _buildHistoricalLine(minDate, dateRange),
              // Predicted line (dashed)
              if (predictedData.isNotEmpty) _buildPredictedLine(minDate, dateRange),
            ],
            extraLinesData: ExtraLinesData(
              verticalLines: [
                // "Today" marker line
                VerticalLine(
                  x: todayDate.difference(minDate).inDays.toDouble(),
                  color: const Color(0xFFFF6B6B),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    labelResolver: (line) => 'Today',
                  ),
                ),
              ],
            ),
            lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (tooltipItem) => Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: const BorderSide(color: Color(0xFFE2E8F0)),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = minDate.add(Duration(days: spot.x.toInt()));
                        final isHistorical = date.isBefore(todayDate) || date.isAtSameMomentAs(todayDate);

                        return LineTooltipItem(
                            '${DateFormat('MMM d, y').format(date)}\n${spot.y.toStringAsFixed(1)} units\n${isHistorical ? 'Actual' : 'Predicted'}',
                            TextStyle(
                                color: isHistorical ? const Color(0xFF4169E1) : const Color(0xFF50C878),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                        );
                      }).toList();
                    },
                ),
            ),
        ),
    );
  }
  LineChartBarData _buildHistoricalLine(DateTime minDate, double dateRange) {
    return LineChartBarData(
      spots: historicalData.map((point) {
        final x = point.date.difference(minDate).inDays.toDouble();
        return FlSpot(x, point.value);
      }).toList(),
      isCurved: true,
      color: const Color(0xFF4169E1), // Royal blue
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
  LineChartBarData _buildPredictedLine(DateTime minDate, double dateRange) {
    return LineChartBarData(
      spots: predictedData.map((point) {
        final x = point.date.difference(minDate).inDays.toDouble();
        return FlSpot(x, point.value);
      }).toList(),
      isCurved: true,
      color: const Color(0xFF50C878), // Emerald green
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [8, 4], // Dashed line
      belowBarData: BarAreaData(show: false),
    );
  }
  LineChartBarData _buildConfidenceInterval(DateTime minDate, double dateRange) {
// Create upper bound line
    final upperSpots = predictedData.map((point) {
      final x = point.date.difference(minDate).inDays.toDouble();
      return FlSpot(x, point.upperBound ?? point.value);
    }).toList();
// Create lower bound spots for the filled area
    final lowerSpots = predictedData.map((point) {
      final x = point.date.difference(minDate).inDays.toDouble();
      return FlSpot(x, point.lowerBound ?? point.value);
    }).toList();

    return LineChartBarData(
      spots: upperSpots,
      isCurved: true,
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: const Color(0xFF50C878).withOpacity(0.15),
        cutOffY: lowerSpots.isNotEmpty ? lowerSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) : 0,
        applyCutOffY: true,
      ),
    );
  }
}