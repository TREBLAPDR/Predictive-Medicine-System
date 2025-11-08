// File: lib/widgets/edit_medicine_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medicine_data.dart';

class EditMedicineDialog extends StatefulWidget {
  final MedicineData medicine;
  final Function(MedicineData) onEdit;

  const EditMedicineDialog({
    super.key,
    required this.medicine,
    required this.onEdit,
  });

  @override
  State<EditMedicineDialog> createState() => _EditMedicineDialogState();
}

class _EditMedicineDialogState extends State<EditMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _medicineNameController;
  late TextEditingController _categoryController;
  late TextEditingController _supplierController;
  late TextEditingController _currentStockController;
  late TextEditingController _predictedDemandController;
  late TextEditingController _unitPriceController;
  late TextEditingController _expiryDateController;

  @override
  void initState() {
    super.initState();
    _medicineNameController = TextEditingController(text: widget.medicine.medicineName);
    _categoryController = TextEditingController(text: widget.medicine.category);
    _supplierController = TextEditingController(text: widget.medicine.supplier);
    _currentStockController = TextEditingController(text: widget.medicine.currentStock.toString());
    _predictedDemandController = TextEditingController(text: widget.medicine.predictedDemand.toString());
    _unitPriceController = TextEditingController(text: widget.medicine.unitPrice.toString());
    _expiryDateController = TextEditingController(text: widget.medicine.expiryDate);
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _categoryController.dispose();
    _supplierController.dispose();
    _currentStockController.dispose();
    _predictedDemandController.dispose();
    _unitPriceController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final currentStock = int.parse(_currentStockController.text);
      final updatedMedicine = MedicineData(
        medicineName: _medicineNameController.text.trim(),
        category: _categoryController.text.trim(),
        supplier: _supplierController.text.trim(),
        currentStock: currentStock,
        predictedDemand: int.parse(_predictedDemandController.text),
        status: currentStock < 20 ? 'Low Stock' : 'In Stock',
        pendingRequests: widget.medicine.pendingRequests,
        unitPrice: double.parse(_unitPriceController.text),
        expiryDate: _expiryDateController.text.trim(),
      );
      widget.onEdit(updatedMedicine);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4169E1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF4169E1),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Edit Medicine',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _medicineNameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter supplier';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _currentStockController,
                        decoration: const InputDecoration(
                          labelText: 'Current Stock *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _predictedDemandController,
                        decoration: const InputDecoration(
                          labelText: 'Predicted Demand',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.trending_up),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (PHP) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter unit price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _expiryDateController,
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                    hintText: '2025-12-31',
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF718096)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}