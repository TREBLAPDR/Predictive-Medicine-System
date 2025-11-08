import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import '../../widgets/kpi_card.dart';
import '../../models/medicine_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int totalMedicines = 0;
  int totalStockUnits = 0;
  int lowStockCount = 0;
  int pendingRequests = 0;
  bool isLoading = false;
  bool hasLoadedData = false;

  Future<void> _loadDataFromFile() async {
    try {
      setState(() {
        isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
        dialogTitle: 'Select Medicine Data File',
        withData: true, // ✅ Important for web compatibility
      );

      if (result != null && result.files.isNotEmpty) {
        final fileBytes = result.files.single.bytes;
        final extension = result.files.single.extension?.toLowerCase();

        if (fileBytes == null) throw Exception('File data is empty');

        final content = utf8.decode(fileBytes);
        List<MedicineData> medicines = [];

        if (extension == 'csv') {
          medicines = await _parseCSV(content);
        } else if (extension == 'json') {
          medicines = await _parseJSON(content);
        } else {
          throw Exception('Unsupported file format');
        }

        if (medicines.isEmpty) {
          throw Exception('No valid data found in file');
        }

        _computeKPIs(medicines);

        setState(() {
          hasLoadedData = true;
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

  Future<List<MedicineData>> _parseCSV(String input) async {
    final fields = const CsvToListConverter().convert(input);

    if (fields.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final headers = fields[0].map((h) => h.toString().toLowerCase().trim()).toList();

    final medicineNameIdx = _findHeaderIndex(headers, ['medicine_name', 'medicinename', 'medicine', 'name']);
    final categoryIdx = _findHeaderIndex(headers, ['category']);
    final currentStockIdx = _findHeaderIndex(headers, ['current_stock', 'currentstock', 'stock']);
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
        medicines.add(MedicineData(
          medicineName: row[medicineNameIdx].toString().trim(),
          category: categoryIdx != -1 && row.length > categoryIdx ? row[categoryIdx].toString().trim() : '',
          currentStock: int.parse(row[currentStockIdx].toString()),
          pendingRequests: pendingRequestsIdx != -1 && row.length > pendingRequestsIdx
              ? int.parse(row[pendingRequestsIdx].toString())
              : 0,
          unitPrice: unitPriceIdx != -1 && row.length > unitPriceIdx
              ? double.parse(row[unitPriceIdx].toString())
              : 0.0,
          expiryDate: expiryDateIdx != -1 && row.length > expiryDateIdx ? row[expiryDateIdx].toString().trim() : '',
        ));
      } catch (_) {
        continue;
      }
    }

    return medicines;
  }

  Future<List<MedicineData>> _parseJSON(String input) async {
    final jsonData = json.decode(input);

    if (jsonData is! List) {
      throw Exception('JSON must be an array of objects');
    }

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

        medicines.add(MedicineData(
          medicineName: medicineName.trim(),
          category: getValue(['category']) ?? '',
          currentStock: int.parse(currentStockStr),
          pendingRequests: int.tryParse(getValue(['pending_requests', 'pendingrequests', 'pending']) ?? '0') ?? 0,
          unitPrice: double.tryParse(getValue(['unit_price', 'unitprice', 'price']) ?? '0') ?? 0.0,
          expiryDate: getValue(['expiry_date', 'expirydate', 'expiry']) ?? '',
        ));
      } catch (_) {
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

  void _computeKPIs(List<MedicineData> medicines) {
    final uniqueMedicines = medicines.map((m) => m.medicineName.toLowerCase()).toSet();

    setState(() {
      totalMedicines = uniqueMedicines.length;
      totalStockUnits = medicines.fold(0, (sum, m) => sum + m.currentStock);
      lowStockCount = medicines.where((m) => m.currentStock < 20).length;
      pendingRequests = medicines.fold(0, (sum, m) => sum + m.pendingRequests);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Load Data Button
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
              if (hasLoadedData) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF50C878).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF50C878).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF50C878), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Data Loaded',
                        style: TextStyle(
                          color: Color(0xFF50C878),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 48) / 2;
              const cardHeight = 200.0;

              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: KPICard(
                      icon: Icons.medical_services,
                      iconColor: const Color(0xFF50C878),
                      label: 'Total Medicines',
                      value: totalMedicines.toString(),
                      subtext: 'unique items',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: KPICard(
                      icon: Icons.inventory_2,
                      iconColor: const Color(0xFF4169E1),
                      label: 'Total Stock Units',
                      value: totalStockUnits.toString(),
                      subtext: 'units in inventory',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: KPICard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFFF6B6B),
                      label: 'Low Stock Alerts',
                      value: lowStockCount.toString(),
                      subtext: 'items below 20 units',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: KPICard(
                      icon: Icons.pending_actions,
                      iconColor: const Color(0xFFFFA500),
                      label: 'Pending Requests',
                      value: pendingRequests.toString(),
                      subtext: 'procurement requests',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
