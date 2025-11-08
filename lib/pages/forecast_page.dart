// File: lib/pages/forecast_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import '../models/medicine_data.dart';
import '../models/forecast_data.dart';
import '../widgets/forecast_chart.dart';


class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  List<MedicineData> medicines = [];
  bool hasLoadedData = false;
  bool isLoading = false;

  String selectedMedicine = '';
  String forecastHorizon = 'End of Month';
  DateTime? specificDate;

  final List<String> horizonOptions = [
    'End of Week',
    'End of Month',
    'End of Year',
    'Specific Date',
  ];

  List<ForecastDataPoint> historicalData = [];
  List<ForecastDataPoint> predictedData = [];
  DateTime todayDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  void _generateMockData() {
    // Generate 60 days of historical data
    final random = Random(42); // Fixed seed for consistent results
    final today = DateTime.now();
    historicalData.clear();

    double baseValue = 50.0;
    for (int i = -60; i <= 0; i++) {
      final date = today.add(Duration(days: i));
      // Add some realistic variation
      final variation = (random.nextDouble() - 0.5) * 15;
      final trend = i * 0.1; // Slight upward trend
      final value = baseValue + variation + trend;

      historicalData.add(ForecastDataPoint(
        date: date,
        value: value.clamp(10, 100),
        isActual: true,
      ));
    }

    _updateForecast();
  }

  void _updateForecast() {
    final random = Random(123);
    predictedData.clear();

    final today = DateTime.now();
    DateTime endDate;

    switch (forecastHorizon) {
      case 'End of Week':
        endDate = today.add(Duration(days: 7 - today.weekday));
        break;
      case 'End of Month':
        endDate = DateTime(today.year, today.month + 1, 0);
        break;
      case 'End of Year':
        endDate = DateTime(today.year, 12, 31);
        break;
      case 'Specific Date':
        endDate = specificDate ?? today.add(const Duration(days: 30));
        break;
      default:
        endDate = today.add(const Duration(days: 30));
    }

    final daysToForecast = endDate.difference(today).inDays;

    // Get last historical value to continue the trend
    final lastValue = historicalData.isNotEmpty ? historicalData.last.value : 50.0;
    double currentValue = lastValue;

    for (int i = 1; i <= daysToForecast; i++) {
      final date = today.add(Duration(days: i));

      // Generate predicted value with trend and variation
      final trend = i * 0.15;
      final variation = (random.nextDouble() - 0.5) * 10;
      currentValue = (lastValue + trend + variation).clamp(20, 120);

      // Calculate confidence interval (wider as we go further)
      final confidenceWidth = 5.0 + (i * 0.3);
      final upperBound = (currentValue + confidenceWidth).clamp(0.0, 150.0);
      final lowerBound = (currentValue - confidenceWidth).clamp(0.0, 150.0);

      predictedData.add(ForecastDataPoint(
        date: date,
        value: currentValue,
        isActual: false,
        upperBound: upperBound,
        lowerBound: lowerBound,
      ));
    }

    setState(() {});
  }

  Future<void> _loadDataFromFile() async {
    try {
      setState(() {
        isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
        dialogTitle: 'Select Medicine Data File',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();

        List<MedicineData> loadedMedicines = [];

        if (extension == 'csv') {
          loadedMedicines = await _parseCSV(file);
        } else if (extension == 'json') {
          loadedMedicines = await _parseJSON(file);
        } else {
          throw Exception('Unsupported file format');
        }

        if (loadedMedicines.isEmpty) {
          throw Exception('No valid data found in file');
        }

        setState(() {
          medicines = loadedMedicines;
          hasLoadedData = true;
          if (medicines.isNotEmpty) {
            selectedMedicine = medicines[0].medicineName;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully loaded ${medicines.length} medicine records'),
              backgroundColor: const Color(0xFF50C878),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Loading File'),
            content: Text('Invalid file format or structure.\n\nDetails: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<MedicineData>> _parseCSV(File file) async {
    final input = await file.readAsString();
    final fields = const CsvToListConverter().convert(input);

    if (fields.isEmpty) throw Exception('CSV file is empty');

    final headers = fields[0].map((h) => h.toString().toLowerCase().trim()).toList();

    final medicineNameIdx = _findHeaderIndex(headers, ['medicine_name', 'medicinename', 'medicine', 'name']);
    final categoryIdx = _findHeaderIndex(headers, ['category']);
    final supplierIdx = _findHeaderIndex(headers, ['supplier']);
    final currentStockIdx = _findHeaderIndex(headers, ['current_stock', 'currentstock', 'stock']);
    final predictedDemandIdx = _findHeaderIndex(headers, ['predicted_demand', 'predicteddemand', 'demand']);
    final statusIdx = _findHeaderIndex(headers, ['status']);
    final pendingRequestsIdx = _findHeaderIndex(headers, ['pending_requests', 'pendingrequests', 'pending']);
    final unitPriceIdx = _findHeaderIndex(headers, ['unit_price', 'unitprice', 'price']);
    final expiryDateIdx = _findHeaderIndex(headers, ['expiry_date', 'expirydate', 'expiry']);

    if (medicineNameIdx == -1 || currentStockIdx == -1) {
      throw Exception('CSV must contain "medicine_name" and "current_stock" columns');
    }

    List<MedicineData> medicines = [];

    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.length <= medicineNameIdx || row.length <= currentStockIdx) continue;

      try {
        final currentStock = int.parse(row[currentStockIdx].toString());
        medicines.add(MedicineData(
          medicineName: row[medicineNameIdx].toString().trim(),
          category: categoryIdx != -1 && row.length > categoryIdx ? row[categoryIdx].toString().trim() : 'General',
          supplier: supplierIdx != -1 && row.length > supplierIdx ? row[supplierIdx].toString().trim() : 'Unknown',
          currentStock: currentStock,
          predictedDemand: predictedDemandIdx != -1 && row.length > predictedDemandIdx
              ? int.tryParse(row[predictedDemandIdx].toString()) ?? 0
              : 0,
          status: statusIdx != -1 && row.length > statusIdx
              ? row[statusIdx].toString().trim()
              : (currentStock < 20 ? 'Low Stock' : 'In Stock'),
          pendingRequests: pendingRequestsIdx != -1 && row.length > pendingRequestsIdx
              ? int.parse(row[pendingRequestsIdx].toString())
              : 0,
          unitPrice: unitPriceIdx != -1 && row.length > unitPriceIdx
              ? double.parse(row[unitPriceIdx].toString())
              : 0.0,
          expiryDate: expiryDateIdx != -1 && row.length > expiryDateIdx ? row[expiryDateIdx].toString().trim() : '',
        ));
      } catch (e) {
        continue;
      }
    }

    return medicines;
  }

  Future<List<MedicineData>> _parseJSON(File file) async {
    final input = await file.readAsString();
    final jsonData = json.decode(input);

    if (jsonData is! List) throw Exception('JSON must be an array of objects');

    List<MedicineData> medicines = [];

    for (var item in jsonData) {
      if (item is! Map) continue;

      String? getValue(List<String> possibleKeys) {
        for (var key in possibleKeys) {
          for (var itemKey in item.keys) {
            if (itemKey.toString().toLowerCase() == key.toLowerCase()) {
              return item[itemKey]?.toString();
            }
          }
        }
        return null;
      }

      try {
        final medicineName = getValue(['medicine_name', 'medicinename', 'medicine', 'name']);
        final currentStockStr = getValue(['current_stock', 'currentstock', 'stock']);

        if (medicineName == null || currentStockStr == null) continue;

        final currentStock = int.parse(currentStockStr);
        medicines.add(MedicineData(
          medicineName: medicineName.trim(),
          category: getValue(['category']) ?? 'General',
          supplier: getValue(['supplier']) ?? 'Unknown',
          currentStock: currentStock,
          predictedDemand: int.tryParse(getValue(['predicted_demand', 'predicteddemand', 'demand']) ?? '0') ?? 0,
          status: getValue(['status']) ?? (currentStock < 20 ? 'Low Stock' : 'In Stock'),
          pendingRequests: int.tryParse(getValue(['pending_requests', 'pendingrequests', 'pending']) ?? '0') ?? 0,
          unitPrice: double.tryParse(getValue(['unit_price', 'unitprice', 'price']) ?? '0') ?? 0.0,
          expiryDate: getValue(['expiry_date', 'expirydate', 'expiry']) ?? '',
        ));
      } catch (e) {
        continue;
      }
    }

    return medicines;
  }

  int _findHeaderIndex(List<String> headers, List<String> possibleNames) {
    for (var name in possibleNames) {
      final index = headers.indexOf(name.toLowerCase());
      if (index != -1) return index;
    }
    return -1;
  }

  Future<void> _pickSpecificDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF50C878),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        specificDate = picked;
        _updateForecast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Controls
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _loadDataFromFile,
                icon: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.upload_file),
                label: Text(isLoading ? 'Loading...' : 'Load Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50C878),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (hasLoadedData && medicines.isNotEmpty) ...[
                // Medicine Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButton<String>(
                    value: selectedMedicine,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF718096)),
                    items: medicines.map((medicine) {
                      return DropdownMenuItem(
                        value: medicine.medicineName,
                        child: Text(medicine.medicineName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMedicine = value;
                        });
                      }
                    },
                  ),
                ),
              ],
              const Spacer(),
              // Forecast Horizon Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String>(
                  value: forecastHorizon,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF718096)),
                  items: horizonOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4169E1)),
                          const SizedBox(width: 8),
                          Text(option),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        forecastHorizon = value;
                        if (value == 'Specific Date') {
                          _pickSpecificDate();
                        } else {
                          _updateForecast();
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Chart Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.show_chart,
                        color: Color(0xFF4169E1),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Demand Forecast',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      const Spacer(),
                      // Legend
                      _buildLegendItem('Actual Demand', const Color(0xFF4169E1), true),
                      const SizedBox(width: 24),
                      _buildLegendItem('Predicted Demand', const Color(0xFF50C878), false),
                      const SizedBox(width: 24),
                      _buildLegendItem('Confidence Interval', const Color(0xFF50C878).withOpacity(0.2), false, isArea: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ForecastChart(
                      historicalData: historicalData,
                      predictedData: predictedData,
                      todayDate: todayDate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // AI Model Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4169E1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Color(0xFF4169E1),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AI Model Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Using LSTM Neural Network for time-series forecasting',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildInfoBadge('Model', 'LSTM-v2'),
                const SizedBox(width: 16),
                _buildInfoBadge('Last Trained', '2025-11-01'),
                const SizedBox(width: 16),
                _buildInfoBadge('Accuracy', '94.2%', isAccuracy: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isSolid, {bool isArea = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isArea)
          Container(
            width: 24,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          CustomPaint(
            size: const Size(24, 12),
            painter: _LinePainter(color: color, isDashed: !isSolid),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4A5568),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(String label, String value, {bool isAccuracy = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAccuracy
            ? const Color(0xFF50C878).withOpacity(0.1)
            : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAccuracy
              ? const Color(0xFF50C878).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isAccuracy ? const Color(0xFF50C878) : const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;

  _LinePainter({required this.color, required this.isDashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (isDashed) {
      final dashWidth = 4.0;
      final dashSpace = 3.0;
      double startX = 0;

      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}