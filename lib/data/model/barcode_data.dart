import 'package:flutter/material.dart';

class BarcodeData {
  final String id;
  final String type;
  final String code;
  final String description;

  BarcodeData({
    required this.id,
    required this.type,
    required this.code,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'code': code,
    'description': description,
  };

  factory BarcodeData.fromJson(Map<String, dynamic> json) {
    return BarcodeData(
      id: json['id'] ?? UniqueKey().toString(),
      type: json['type'],
      code: json['code'],
      description: json['description'],
    );
  }
}
