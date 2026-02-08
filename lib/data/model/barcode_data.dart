class BarcodeData {
  final String type;
  final String code;
  final String description;

  BarcodeData({
    required this.type,
    required this.code,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'code': code,
    'description': description,
  };

  factory BarcodeData.fromJson(Map<String, dynamic> json) {
    return BarcodeData(
      type: json['type'],
      code: json['code'],
      description: json['description'],
    );
  }
}
