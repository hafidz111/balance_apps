class PointCoffeeHistory {
  final int tgl;
  final int spd;
  final int cup;
  final int akmCup;
  final double cpd;

  PointCoffeeHistory({
    required this.tgl,
    required this.spd,
    required this.cup,
    required this.akmCup,
    required this.cpd,
  });

  PointCoffeeHistory copyWith({
    int? tgl,
    int? spd,
    int? cup,
    int? akmCup,
    double? cpd,
  }) {
    return PointCoffeeHistory(
      tgl: tgl ?? this.tgl,
      spd: spd ?? this.spd,
      cup: cup ?? this.cup,
      akmCup: akmCup ?? this.akmCup,
      cpd: cpd ?? this.cpd,
    );
  }

  Map<String, dynamic> toJson() => {
    'tgl': tgl,
    'spd': spd,
    'cup': cup,
    'akmCup': akmCup,
    'cpd': cpd,
  };

  factory PointCoffeeHistory.fromJson(Map<String, dynamic> json) {
    return PointCoffeeHistory(
      tgl: json['tgl'],
      spd: json['spd'],
      cup: json['cup'],
      akmCup: json['akmCup'],
      cpd: (json['cpd'] as num).toDouble(),
    );
  }
}
