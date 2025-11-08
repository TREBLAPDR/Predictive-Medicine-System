// File: lib/pages/inventory_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/medicine_data.dart';
import '../widgets/inventory_table.dart';
import '../widgets/add_medicine_dialog.dart';
import '../widgets/edit_medicine_dialog.dart';
import '../widgets/restock_dialog.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<MedicineData> allMedicines = [];
  List<MedicineData> filteredMedicines = [];
  bool isLoading = false;
  bool hasLoadedData = false;

  String selectedCategory = 'All';
  bool showLowStockOnly = false;
  String searchQuery = '';

  Set<String> get categories {
    final cats = allMedicines.map((m) => m.category).where((c) => c.isNotEmpty).toSet();
    return {'All', ...cats};
  }

  @override
  void initState() {
    super.initState();
    filteredMedicines = allMedicines;
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

        List<MedicineData> medicines = [];

        if (extension == 'csv') {
          medicines = await _parseCSV(file);
        } else if (extension == 'json') {
          medicines = await _parseJSON(file);
        } else {
          throw Exception('Unsupported file format');
        }

        if (medicines.isEmpty) {
          throw Exception('No valid data found in file');
        }

        setState(() {
          allMedicines = medicines;
          hasLoadedData = true;
          _applyFilters();
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

    if (fields.isEmpty) {
      throw Exception('CSV file is empty');
    }

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
      if (row.length <= medicineNameIdx || row.length <= currentStockIdx) {
        continue;
      }

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

        if (medicineName == null || currentStockStr == null) {
          continue;
        }

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

  void _applyFilters() {
    setState(() {
      filteredMedicines = allMedicines.where((medicine) {
        // Category filter
        if (selectedCategory != 'All' && medicine.category != selectedCategory) {
          return false;
        }

        // Low stock filter
        if (showLowStockOnly && medicine.currentStock >= 20) {
          return false;
        }

        // Search filter
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          return medicine.medicineName.toLowerCase().contains(query) ||
              medicine.category.toLowerCase().contains(query) ||
              medicine.supplier.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMedicineDialog(
        onAdd: (medicine) {
          setState(() {
            allMedicines.add(medicine);
            _applyFilters();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine added successfully'),
              backgroundColor: Color(0xFF50C878),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showEditMedicineDialog(MedicineData medicine, int index) {
    showDialog(
      context: context,
      builder: (context) => EditMedicineDialog(
        medicine: medicine,
        onEdit: (updatedMedicine) {
          setState(() {
            final actualIndex = allMedicines.indexOf(medicine);
            if (actualIndex != -1) {
              allMedicines[actualIndex] = updatedMedicine;
              _applyFilters();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine updated successfully'),
              backgroundColor: Color(0xFF50C878),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showRestockDialog(MedicineData medicine) {
    showDialog(
      context: context,
      builder: (context) => RestockDialog(
        medicine: medicine,
        onRestock: (quantity) {
          setState(() {
            final actualIndex = allMedicines.indexOf(medicine);
            if (actualIndex != -1) {
              final updated = MedicineData(
                medicineName: medicine.medicineName,
                category: medicine.category,
                supplier: medicine.supplier,
                currentStock: medicine.currentStock + quantity,
                predictedDemand: medicine.predictedDemand,
                status: (medicine.currentStock + quantity) < 20 ? 'Low Stock' : 'In Stock',
                pendingRequests: medicine.pendingRequests,
                unitPrice: medicine.unitPrice,
                expiryDate: medicine.expiryDate,
              );
              allMedicines[actualIndex] = updated;
              _applyFilters();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restocked $quantity units successfully'),
              backgroundColor: const Color(0xFF50C878),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Action Bar
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
              ElevatedButton.icon(
                onPressed: hasLoadedData ? _showAddMedicineDialog : null,
                icon: const Icon(Icons.add),
                label: const Text('Add Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4169E1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Spacer(),
              if (hasLoadedData) ...[
                // Search Bar
                Container(
                  width: 300,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      searchQuery = value;
                      _applyFilters();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search medicines...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF718096)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          if (hasLoadedData) ...[
            Row(
              children: [
                // Category Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF718096)),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Low Stock Filter
                FilterChip(
                  label: const Text('Low Stock Only'),
                  selected: showLowStockOnly,
                  onSelected: (selected) {
                    setState(() {
                      showLowStockOnly = selected;
                      _applyFilters();
                    });
                  },
                  selectedColor: const Color(0xFFFF6B6B).withOpacity(0.2),
                  checkmarkColor: const Color(0xFFFF6B6B),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: showLowStockOnly ? const Color(0xFFFF6B6B) : const Color(0xFFE2E8F0),
                  ),
                ),
                const Spacer(),
                Text(
                  'Showing ${filteredMedicines.length} of ${allMedicines.length} items',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Inventory Table
          Expanded(
            child: hasLoadedData
                ? InventoryTable(
              medicines: filteredMedicines,
              onEdit: _showEditMedicineDialog,
              onRestock: _showRestockDialog,
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No data loaded',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF718096),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click "Load Data" to import inventory from CSV or JSON',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFA0AEC0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}