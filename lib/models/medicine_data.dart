// File: lib/models/medicine_data.dart
class MedicineData {
  final String medicineName;
  final String category;
  final String supplier;
  final int currentStock;
  final int predictedDemand;
  final String status;
  final int pendingRequests;
  final double unitPrice;
  final String expiryDate;

  MedicineData({
    required this.medicineName,
    required this.category,
    this.supplier = 'Unknown',
    required this.currentStock,
    this.predictedDemand = 0,
    this.status = 'In Stock',
    this.pendingRequests = 0,
    this.unitPrice = 0.0,
    this.expiryDate = '',
  });
}