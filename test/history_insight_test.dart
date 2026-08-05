import 'package:flutter_test/flutter_test.dart';
import 'package:starvy/data/model/coffee_history.dart';
import 'package:starvy/utils/history_insight.dart';

void main() {
  test('coffeeHistoryInsight summarizes current month', () {
    final insight = coffeeHistoryInsight(
      [
        CoffeeHistory(tgl: 20260801, spd: 1000, cup: 10, akmCup: 10, cpd: 10),
        CoffeeHistory(tgl: 20260802, spd: 2000, cup: 20, akmCup: 30, cpd: 15),
        CoffeeHistory(tgl: 20260701, spd: 9999, cup: 1, akmCup: 1, cpd: 1),
      ],
      DateTime(2026, 8, 6),
    );

    expect(insight, isNotNull);
    expect(insight!.headline, contains('bulan ini'));
    expect(insight.headline, contains('2 hari'));
    expect(insight.bullets.any((b) => b.contains('1.500')), isTrue);
  });

  test('falls back to latest month when current month empty', () {
    final insight = coffeeHistoryInsight(
      [
        CoffeeHistory(tgl: 20260701, spd: 100, cup: 1, akmCup: 1, cpd: 1),
        CoffeeHistory(tgl: 20260702, spd: 300, cup: 3, akmCup: 4, cpd: 2),
      ],
      DateTime(2026, 8, 6),
    );
    expect(insight, isNotNull);
    expect(insight!.headline, contains('Jul 2026'));
    expect(insight.bullets.first, contains('Belum ada laporan coffee bulan ini'));
  });

  test('returns null when no history at all', () {
    expect(coffeeHistoryInsight(const [], DateTime(2026, 8, 6)), isNull);
  });
}
