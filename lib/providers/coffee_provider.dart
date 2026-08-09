import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../data/model/coffee_history.dart';
import '../data/model/store_data.dart';
import '../service/shared_preferences_service.dart';
import '../utils/date_format.dart';
import '../utils/history_insight.dart';

class CoffeeProvider extends ChangeNotifier {
  CoffeeProvider(this._prefs);

  final SharedPreferencesService _prefs;

  static const int maxShift = 4;

  int _shiftCount = 2;
  int _formVersion = 0;

  int accumSalesRupiah = 0;
  int accumCup = 0;
  int achievTargetDaily = 0;
  double achievTargetPercent = 0;
  bool hasPreviousMonthBaseline = false;
  bool usingManualSalesPrev = false;

  StoreData? store;
  List<String> shiftLabels = List<String>.from(
    SharedPreferencesService.defaultShiftTimeLabels,
  );

  String? cpdManual;
  String? salesPrevManual;
  HistoryInsight? historyInsight;

  int get shiftCount => _shiftCount;
  int get formVersion => _formVersion;

  void setShiftCount(int value) {
    final next = value.clamp(1, maxShift);
    if (_shiftCount == next) return;
    _shiftCount = next;
    notifyListeners();
  }

  void markFormChanged() {
    _formVersion++;
    notifyListeners();
  }

  Future<void> initialize() async {
    await loadStore();
    refreshShiftLabels();
    cpdManual = await _prefs.getCoffeeCpdManual();
    await syncSalesPrevManual();
    notifyListeners();
  }

  Future<void> loadStore() async {
    store = await _prefs.getCoffeeStore();
    notifyListeners();
  }

  void refreshShiftLabels() {
    shiftLabels = _prefs.getShiftTimeLabels();
    notifyListeners();
  }

  static String formatRupiah(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  static String formatRupiahShort(int value) {
    final juta = value / 1000000;
    final truncated = (juta * 10).floor() / 10;
    return truncated.toStringAsFixed(1);
  }

  static String formatAchievTarget(
    int dailyRupiah,
    double achievementPercent,
    bool hasBaseline,
  ) {
    if (!hasBaseline) return '—';
    final rupiahStr = formatRupiah(dailyRupiah);
    final pct = achievementPercent.toStringAsFixed(1).replaceAll('.', ',');
    return '$rupiahStr ($pct%)';
  }

  static double apcValue(int sales, int std) {
    if (std == 0) return 0;
    return (sales / std) / 1000;
  }

  static String apcDisplay(int sales, int std) {
    final v = apcValue(sales, std);
    if (v == 0) return '0';
    return v.toStringAsFixed(3).replaceAll('.', ',');
  }

  static int parseInt(String text) {
    final clean = text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  int _remainingDaysInMonth(DateTime now) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return (daysInMonth - now.day).clamp(1, daysInMonth);
  }

  int _monthSalesFromEntries(List<CoffeeHistory> entries) {
    return entries.fold<int>(0, (sum, e) => sum + e.spd);
  }

  Future<void> refreshSummary({
    required int totalSales,
    int? salesPrevManualField,
  }) async {
    await syncSalesPrevManual();

    final list = await _prefs.getCoffee();
    final now = DateTime.now();
    final prevMonth = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);

    final currentMonthEntries = await _prefs.getCoffeeByMonth(
      now.year,
      now.month,
    );
    final previousMonthEntries = await _prefs.getCoffeeByMonth(
      prevMonth.year,
      prevMonth.month,
    );

    var previousMonthSales = _monthSalesFromEntries(previousMonthEntries);
    var usingManual = false;

    if (previousMonthSales <= 0) {
      final manualSaved = salesPrevManual;
      if (manualSaved != null && manualSaved.isNotEmpty) {
        previousMonthSales = parseInt(manualSaved);
        usingManual = previousMonthSales > 0;
      }
      if (previousMonthSales <= 0 && salesPrevManualField != null) {
        if (salesPrevManualField > 0) {
          previousMonthSales = salesPrevManualField;
          usingManual = true;
        }
      }
    }

    final todayTgl = now.year * 10000 + now.month * 100 + now.day;
    var currentMonthSales = currentMonthEntries
        .where((e) => e.tgl != todayTgl)
        .fold<int>(0, (sum, e) => sum + e.spd);
    currentMonthSales += totalSales;

    final gap = previousMonthSales - currentMonthSales;
    final hasBaseline = previousMonthSales > 0;
    final remainingDays = _remainingDaysInMonth(now);
    final dailyNeeded = hasBaseline && gap > 0
        ? (gap / remainingDays).round()
        : 0;
    final achievementPercent = hasBaseline
        ? (currentMonthSales / previousMonthSales) * 100
        : 0.0;

    accumSalesRupiah = list.fold<int>(0, (a, e) => a + e.spd);
    accumCup = list.fold<int>(0, (a, e) => a + e.cup);
    achievTargetDaily = dailyNeeded;
    achievTargetPercent = achievementPercent;
    hasPreviousMonthBaseline = hasBaseline;
    usingManualSalesPrev = usingManual;
    historyInsight = coffeeHistoryInsight(list);
    notifyListeners();
  }

  Future<void> reloadAfterSync() async {
    await refreshSummary(totalSales: 0);
  }

  Future<void> syncSalesPrevManual() async {
    await _prefs.expireCoffeeSalesPrevManualIfNeeded();
    salesPrevManual = await _prefs.getCoffeeSalesPrevManual();
    notifyListeners();
  }

  Future<void> saveCpdManual(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.clearCoffeeCpdManual();
      cpdManual = null;
    } else {
      await _prefs.saveCoffeeCpdManual(trimmed);
      cpdManual = trimmed;
    }
    notifyListeners();
  }

  Future<void> saveSalesPrevManual(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.clearCoffeeSalesPrevManual();
      salesPrevManual = null;
    } else {
      await _prefs.saveCoffeeSalesPrevManual(trimmed);
      salesPrevManual = trimmed;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> loadDraftForToday() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    return _prefs.getCoffeeDraft(tgl);
  }

  Future<void> saveDraft({
    required List<String> sales,
    required List<String> std,
    required List<String> cup,
    required List<String> add,
  }) async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    await _prefs.saveCoffeeDraft(tgl, {
      'shiftCount': _shiftCount,
      'sales': sales,
      'std': std,
      'cup': cup,
      'add': add,
    });
    FirebaseAnalytics.instance.logEvent(name: 'coffee_draft_saved');
  }

  Future<void> saveEntry({
    required int totalSales,
    required int totalCup,
    required int totalStd,
  }) async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    final history = await _prefs.getCoffee();
    final akmCup = history.fold(0, (sum, e) => sum + e.cup) + totalCup;

    await _prefs.saveCoffee(
      CoffeeHistory(
        tgl: tgl,
        spd: totalSales,
        cup: totalCup,
        akmCup: akmCup,
        cpd: akmCup / now.day,
        apc: apcValue(totalSales, totalStd),
      ),
    );

    FirebaseAnalytics.instance.logEvent(
      name: 'coffee_saved',
      parameters: {'total_sales': totalSales, 'total_cup': totalCup},
    );
  }

  Future<String> buildMonthlyHistoryText() async {
    final history = await _prefs.getCoffee();
    final now = DateTime.now();
    final thisMonth = now.year * 100 + now.month;

    final filtered = history.where((e) {
      final ym = e.tgl ~/ 100;
      return ym == thisMonth;
    }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

    final buffer = StringBuffer()..writeln('TGL_SPD_CUP_AKMCUP_CPD');
    for (final e in filtered) {
      buffer.writeln(
        '${formatDayFromYmd(e.tgl)}_${formatRupiahShort(e.spd)}_${e.cup}_${e.akmCup}_${e.cpd.toStringAsFixed(0)}',
      );
    }
    return buffer.toString();
  }

  Future<String> buildWhatsAppMessage({
    required int totalSales,
    required int totalStd,
    required int totalCup,
    required int totalAdd,
    required List<String> shiftSales,
    required List<String> shiftStd,
    required List<String> shiftApc,
    required List<String> shiftCup,
    required List<String> shiftAdd,
  }) async {
    final today = DateTime.now();
    final tgl = formatDateV1(today);
    final blnIni = formatMonth(today);
    final historyText = await buildMonthlyHistoryText();
    final manualCpd = cpdManual ?? await _prefs.getCoffeeCpdManual();

    final title = store?.title ?? 'LAPORAN COFFEE';
    final nama = store?.nama ?? '-';
    final kode = store?.kode ?? '-';
    final tglGo = store?.tgl ?? '-';
    final area = store?.area ?? '-';

    final shiftBuffer = StringBuffer();
    for (int i = 0; i < _shiftCount; i++) {
      shiftBuffer.writeln(
        '*Shift ${i + 1}*\n'
        '```Sales : ${formatRupiah(parseInt(shiftSales[i]))}\n'
        'Std   : ${parseInt(shiftStd[i])}\n'
        'Apc   : ${shiftApc[i]}\n'
        'Cup   : ${parseInt(shiftCup[i])}\n'
        'Add   : ${parseInt(shiftAdd[i])}\n'
        '```',
      );
    }

    return '''
*$title*
```Tanggal $tgl```

${shiftBuffer.toString().trim()}

*TOTAL* ```
Sales    : ${formatRupiah(totalSales)}
Std.     : $totalStd
Apc      : ${apcDisplay(totalSales, totalStd)}
Cup.     : $totalCup
Add      : $totalAdd

Nama toko  = $nama
Kode toko  = $kode
Tgl GO     = $tglGo
Area toko  = $area
${manualCpd != null && manualCpd.isNotEmpty ? '\nCPD: $manualCpd\n' : ''}
_Bulan berjalan :
$blnIni

$historyText```
''';
  }
}
