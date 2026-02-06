class SayBreadHistory {
  final int tgl;
  final int sales;
  final int qty;
  final int akmQty;
  final int akmSales;
  final double average;

  SayBreadHistory({
    required this.tgl,
    required this.sales,
    required this.qty,
    required this.akmQty,
    required this.akmSales,
    required this.average,
  });

  Map<String, dynamic> toJson() => {
    'tgl': tgl,
    'sales': sales,
    'qty': qty,
    'akmQty': akmQty,
    'akmSales': akmSales,
    'average': average,
  };

  factory SayBreadHistory.fromJson(Map<String, dynamic> json) {
    return SayBreadHistory(
      tgl: json['tgl'],
      sales: json['sales'],
      qty: json['qty'],
      akmQty: json['akmQty'],
      akmSales: json['akmSales'],
      average: (json['average'] as num).toDouble(),
    );
  }
}
