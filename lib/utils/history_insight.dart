import '../data/model/bread_history.dart';
import '../data/model/coffee_history.dart';

class HistoryInsight {
  const HistoryInsight({
    required this.headline,
    required this.bullets,
  });

  final String headline;
  final List<String> bullets;
}

String _rp(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
}

const _bulan = <String>[
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

int _ym(int tgl) => tgl ~/ 100;

String _labelYm(int ym) {
  final y = ym ~/ 100;
  final m = ym % 100;
  final name = (m >= 1 && m <= 12) ? _bulan[m] : '$m';
  return '$name $y';
}

List<T> _pickScope<T>(
  List<T> all,
  int Function(T) tglOf,
  DateTime now,
) {
  if (all.isEmpty) return const [];

  final currentKey = now.year * 100 + now.month;
  final thisMonth = all.where((e) => _ym(tglOf(e)) == currentKey).toList();
  if (thisMonth.isNotEmpty) return thisMonth;

  var bestYm = 0;
  for (final e in all) {
    final ym = _ym(tglOf(e));
    if (ym > bestYm) bestYm = ym;
  }
  return all.where((e) => _ym(tglOf(e)) == bestYm).toList();
}

HistoryInsight? _buildSalesInsight({
  required String product,
  required List<({int tgl, int sales, int qty})> rows,
  required DateTime now,
  required String qtyLabel,
}) {
  if (rows.isEmpty) return null;

  rows.sort((a, b) => a.tgl.compareTo(b.tgl));
  final currentKey = now.year * 100 + now.month;
  final scopeYm = _ym(rows.first.tgl);
  final isCurrentMonth = scopeYm == currentKey;
  final periodLabel = isCurrentMonth
      ? 'bulan ini'
      : _labelYm(scopeYm);

  final salesSum = rows.fold<int>(0, (a, e) => a + e.sales);
  final qtySum = rows.fold<int>(0, (a, e) => a + e.qty);
  final avgSales = salesSum ~/ rows.length;
  final avgQty = qtySum ~/ rows.length;
  final best = rows.reduce((a, b) => a.sales >= b.sales ? a : b);
  final worst = rows.reduce((a, b) => a.sales <= b.sales ? a : b);

  final recent = rows.length >= 4
      ? rows.sublist(rows.length - (rows.length >= 7 ? 7 : 3))
      : rows;
  final olderCount = rows.length - recent.length;
  var trend = rows.length < 4
      ? 'Data masih tipis untuk baca tren.'
      : 'Tren relatif stabil di periode ini.';
  if (olderCount > 0) {
    final recentAvg =
        recent.fold<int>(0, (a, e) => a + e.sales) / recent.length;
    final older = rows.sublist(0, olderCount);
    final olderAvg = older.fold<int>(0, (a, e) => a + e.sales) / older.length;
    if (olderAvg > 0) {
      final pct = ((recentAvg - olderAvg) / olderAvg) * 100;
      if (pct > 5) {
        trend = 'Tren naik ${pct.toStringAsFixed(0)}% vs awal periode.';
      } else if (pct < -5) {
        trend =
            'Tren turun ${pct.abs().toStringAsFixed(0)}% vs awal periode.';
      }
    }
  }

  final note = isCurrentMonth
      ? null
      : 'Belum ada laporan $product bulan ini — insight dari $periodLabel.';

  return HistoryInsight(
    headline: 'Insight $product $periodLabel (${rows.length} hari)',
    bullets: [
      if (note != null) note,
      'Rata-rata sales/hari: ${_rp(avgSales)} · $qtyLabel: ${_rp(avgQty)}',
      'Terbaik tgl ${best.tgl % 100} (${_rp(best.sales)}) · '
          'terendah tgl ${worst.tgl % 100} (${_rp(worst.sales)})',
      trend,
    ],
  );
}

HistoryInsight? coffeeHistoryInsight(
  List<CoffeeHistory> all, [
  DateTime? now,
]) {
  if (all.isEmpty) return null;
  final d = now ?? DateTime.now();
  final scope = _pickScope(all, (e) => e.tgl, d);
  return _buildSalesInsight(
    product: 'coffee',
    rows: [
      for (final e in scope) (tgl: e.tgl, sales: e.spd, qty: e.cup),
    ],
    now: d,
    qtyLabel: 'cup',
  );
}

HistoryInsight? breadHistoryInsight(
  List<BreadHistory> all, [
  DateTime? now,
]) {
  if (all.isEmpty) return null;
  final d = now ?? DateTime.now();
  final scope = _pickScope(all, (e) => e.tgl, d);
  return _buildSalesInsight(
    product: 'bread',
    rows: [
      for (final e in scope) (tgl: e.tgl, sales: e.sales, qty: e.qty),
    ],
    now: d,
    qtyLabel: 'qty',
  );
}
