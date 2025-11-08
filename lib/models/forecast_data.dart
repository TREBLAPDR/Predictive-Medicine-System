// File: lib/models/forecast_data.dart
class ForecastDataPoint {
  final DateTime date;
  final double value;
  final bool isActual;
  final double? upperBound;
  final double? lowerBound;

  ForecastDataPoint({
    required this.date,
    required this.value,
    required this.isActual,
    this.upperBound,
    this.lowerBound,
  });
}