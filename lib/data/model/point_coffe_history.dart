class PointCoffeeHistory {
  final int tgl;
  final int spd;
  final int cup;
  final int akmCup;
  final double cpd;

  final double apc;

  PointCoffeeHistory({
    required this.tgl,
    required this.spd,
    required this.cup,
    required this.akmCup,
    required this.cpd,
    this.apc = 0,
  });

  PointCoffeeHistory copyWith({
    int? tgl,
    int? spd,
    int? cup,
    int? akmCup,
    double? cpd,
    double? apc,
  }) {
    return PointCoffeeHistory(
      tgl: tgl ?? this.tgl,
      spd: spd ?? this.spd,
      cup: cup ?? this.cup,
      akmCup: akmCup ?? this.akmCup,
      cpd: cpd ?? this.cpd,
      apc: apc ?? this.apc,
    );
  }

  Map<String, dynamic> toJson() => {
    'tgl': tgl,
    'spd': spd,
    'cup': cup,
    'akmCup': akmCup,
    'cpd': cpd,
    'apc': apc,
  };

  static double _coerceApc(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return 0;
      return double.tryParse(t.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  factory PointCoffeeHistory.fromJson(Map<String, dynamic> json) {
    return PointCoffeeHistory(
      tgl: json['tgl'],
      spd: json['spd'],
      cup: json['cup'],
      akmCup: json['akmCup'],
      cpd: (json['cpd'] as num).toDouble(),
      apc: _coerceApc(json['apc']),
    );
  }
}
