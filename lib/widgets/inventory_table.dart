// File: lib/widgets/inventory_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine_data.dart';

class InventoryTable extends StatefulWidget {
  final List<MedicineData> medicines;
  final Function(MedicineData, int) onEdit;
  final Function(MedicineData) onRestock;

  const InventoryTable({
    super.key,
    required this.medicines,
    required this.onEdit,
    required this.onRestock,
  });

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  List<MedicineData> _sortedMedicines = [];

  @override
  void initState() {
    super.initState();
    _sortedMedicines = List.from(widget.medicines);
  }

  @override
  void didUpdateWidget(InventoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.medicines != oldWidget.medicines) {
      _sortedMedicines = List.from(widget.medicines);
      if (_sortColumnIndex != null) {
        _sort(_sortColumnIndex!, _sortAscending);
      }
    }
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      _sortedMedicines.sort((a, b) {
        int comparison = 0;
        switch (columnIndex) {
          case 0: // Medicine Name
            comparison = a.medicineName.compareTo(b.medicineName);
            break;
          case 1: // Category
            comparison = a.category.compareTo(b.category);
            break;
          case 2: // Supplier
            comparison = a.supplier.compareTo(b.supplier);
            break;
          case 3: // Current Stock
            comparison = a.currentStock.compareTo(b.currentStock);
            break;
          case 4: // Predicted Demand
            comparison = a.predictedDemand.compareTo(b.predictedDemand);
            break;
          case 5: // Status
            comparison = a.status.compareTo(b.status);
            break;
          case 6: // Unit Price
            comparison = a.unitPrice.compareTo(b.unitPrice);
            break;
          case 7: // Expiry Date
            comparison = a.expiryDate.compareTo(b.expiryDate);
            break;
        }
        return ascending ? comparison : -comparison;
      });
    });
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    return formatter.format(amount);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'low stock':
        return const Color(0xFFFF6B6B);
      case 'in stock':
        return const Color(0xFF50C878);
      case 'out of stock':
        return const Color(0xFFDC3545);
      default:
        return const Color(0xFF718096);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF8FAFB),
                  ),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A202C),
                    fontSize: 14,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 14,
                  ),
                  columnSpacing: 40,
                  horizontalMargin: 24,
                  columns: [
                    DataColumn(
                      label: const Text('Medicine Name'),
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Category'),
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Supplier'),
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Current Stock'),
                      numeric: true,
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Predicted Demand'),
                      numeric: true,
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Status'),
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Unit Price (PHP)'),
                      numeric: true,
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('Expiry Date'),
                      onSort: (columnIndex, ascending) => _sort(columnIndex, ascending),
                    ),
                    const DataColumn(
                      label: Text('Actions'),
                    ),
                  ],
                  rows: _sortedMedicines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final medicine = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            medicine.medicineName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(medicine.category)),
                        DataCell(Text(medicine.supplier)),
                        DataCell(
                          Text(
                            medicine.currentStock.toString(),
                            style: TextStyle(
                              color: medicine.currentStock < 20
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF4A5568),
                              fontWeight: medicine.currentStock < 20
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        DataCell(Text(medicine.predictedDemand.toString())),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(medicine.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(medicine.status).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              medicine.status,
                              style: TextStyle(
                                color: _getStatusColor(medicine.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(_formatCurrency(medicine.unitPrice))),
                        DataCell(Text(medicine.expiryDate)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: const Color(0xFF4169E1),
                                tooltip: 'Edit',
                                onPressed: () => widget.onEdit(medicine, index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_box_outlined, size: 20),
                                color: const Color(0xFF50C878),
                                tooltip: 'Restock',
                                onPressed: () => widget.onRestock(medicine),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}