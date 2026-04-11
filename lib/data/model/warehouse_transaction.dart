class WarehouseTransaction {
  final String id;
  final String barcodeCode;
  final String barcodeDescription;
  final String? barcodeType;
  final String type;
  final int quantity;
  final DateTime timestamp;
  final String? reason;

  WarehouseTransaction({
    required this.id,
    required this.barcodeCode,
    required this.barcodeDescription,
    this.barcodeType,
    required this.type,
    required this.quantity,
    required this.timestamp,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'barcodeCode': barcodeCode,
    'barcodeDescription': barcodeDescription,
    if (barcodeType != null) 'barcodeType': barcodeType,
    'type': type,
    'quantity': quantity,
    'timestamp': timestamp.toIso8601String(),
    if (reason != null) 'reason': reason,
  };

  factory WarehouseTransaction.fromJson(Map<String, dynamic> json) {
    return WarehouseTransaction(
      id: json['id'],
      barcodeCode: json['barcodeCode'],
      barcodeDescription: json['barcodeDescription'] ?? '',
      barcodeType: json['barcodeType'],
      type: json['type'],
      quantity: json['quantity'] ?? 1,
      timestamp: DateTime.parse(json['timestamp']),
      reason: json['reason'],
    );
  }
}
