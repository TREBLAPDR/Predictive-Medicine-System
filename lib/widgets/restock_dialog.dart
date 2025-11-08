// File: lib/widgets/restock_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medicine_data.dart';

class RestockDialog extends StatefulWidget {
  final MedicineData medicine;
  final Function(int) onRestock;

  const RestockDialog({
    super.key,
    required this.medicine,
    required this.onRestock,
  });

  @override
  State<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.parse(_quantityController.text);
      widget.onRestock(quantity);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newStock = (int.tryParse(_quantityController.text) ?? 0) + widget.medicine.currentStock;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF50C878).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_box,
                      color: Color(0xFF50C878),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Restock Medicine',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Medicine Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.medicine.medicineName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.category, size: 16, color: Color(0xFF718096)),
                        const SizedBox(width: 4),
                        Text(
                          widget.medicine.category,
                          style: const TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.inventory, size: 16, color: Color(0xFF718096)),
                        const SizedBox(width: 4),
                        Text(
                          'Current Stock: ${widget.medicine.currentStock}',
                          style: TextStyle(
                            color: widget.medicine.currentStock < 20
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF718096),
                            fontSize: 14,
                            fontWeight: widget.medicine.currentStock < 20
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add),
                  hintText: 'Enter quantity',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Rebuild to update preview
                },
              ),
              const SizedBox(height: 24),

              // Stock Preview
              if (_quantityController.text.isNotEmpty && int.tryParse(_quantityController.text) != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF50C878).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF50C878).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Stock Level:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A202C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${widget.medicine.currentStock}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF718096),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF50C878),
                            size: 20,
                          ),
                          Text(
                            '$newStock',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF50C878),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

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
                    label: const Text('Confirm Restock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF50C878),
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
    );
  }
}