import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../data/model/bread_history.dart';
import '../service/shared_preferences_service.dart';
import '../utils/date_format.dart';

class BreadProvider extends ChangeNotifier {
  BreadProvider(this._prefs);

  final SharedPreferencesService _prefs;

  static const int maxShift = 4;

  int _shiftCount = 2;
  int _formVersion = 0;

  int accumSalesRupiah = 0;
  int accumQty = 0;

  List<String> shiftLabels = List<String>.from(
    SharedPreferencesService.defaultShiftTimeLabels,
  );

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
    refreshShiftLabels();
    await refreshSummary();
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

  static int parseInt(String text) {
    final clean = text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  Future<void> refreshSummary() async {
    final list = await _prefs.getBread();
    accumSalesRupiah = list.fold<int>(0, (a, e) => a + e.sales);
    accumQty = list.fold<int>(0, (a, e) => a + e.qty);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> loadDraftForToday() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    return _prefs.getBreadDraft(tgl);
  }

  Future<void> saveDraft({
    required List<String> sales,
    required List<String> qty,
    required String akmLastMonth,
  }) async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    await _prefs.saveBreadDraft(tgl, {
      'shiftCount': _shiftCount,
      'sales': sales,
      'qty': qty,
      'akmLastMonth': akmLastMonth,
    });
    FirebaseAnalytics.instance.logEvent(name: 'bread_draft_saved');
  }

  Future<void> saveEntry({
    required int totalSales,
    required int totalQty,
  }) async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;
    final history = await _prefs.getBread();
    final akmQty = history.fold(0, (sum, e) => sum + e.qty) + totalQty;
    final akmSales = history.fold(0, (sum, e) => sum + e.sales) + totalSales;

    await _prefs.saveBread(
      BreadHistory(
        tgl: tgl,
        sales: totalSales,
        qty: totalQty,
        akmQty: akmQty,
        akmSales: akmSales,
        average: akmQty / now.day,
      ),
    );
    await _prefs.clearBreadDraft(tgl);

    FirebaseAnalytics.instance.logEvent(
      name: 'bread_saved',
      parameters: {'total_sales': totalSales, 'total_qty': totalQty},
    );
  }

  Future<String> buildMonthlyHistoryText() async {
    final history = await _prefs.getBread();
    final now = DateTime.now();
    final thisMonth = now.year * 100 + now.month;

    final filtered = history.where((e) {
      final ym = e.tgl ~/ 100;
      return ym == thisMonth;
    }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

    final buffer = StringBuffer()..writeln('TGL_QTY_AKM_AVG');
    for (final e in filtered) {
      buffer.writeln(
        '${formatDayFromYmd(e.tgl)}_${e.qty}_${e.akmQty}_${e.average.toStringAsFixed(0)}',
      );
    }
    return buffer.toString();
  }

  Future<String> buildWhatsAppMessage({
    required int totalSales,
    required int totalQty,
    required List<String> shiftSales,
    required List<String> shiftQty,
  }) async {
    final today = DateTime.now();
    final tgl = formatDateV1(today);
    final blnIni = formatMonth(today);
    final store = await _prefs.getBreadStore();
    final historyText = await buildMonthlyHistoryText();
    final history = await _prefs.getBread();
    final thisMonth = today.year * 100 + today.month;
    final currentMonthHistory = history.where((e) {
      final ym = e.tgl ~/ 100;
      return ym == thisMonth;
    });
    final akmQty = currentMonthHistory.fold(0, (sum, e) => sum + e.qty);
    final akmSales = currentMonthHistory.fold(0, (sum, e) => sum + e.sales);

    final sbtitle = store?.title ?? 'LAPORAN BREAD';
    final sbnama = store?.nama ?? '-';
    final sbcode = store?.kode ?? '-';
    final sbtgl = store?.tgl ?? '-';
    final sbarea = store?.area ?? '-';

    final shiftBuffer = StringBuffer();
    for (int i = 0; i < _shiftCount; i++) {
      shiftBuffer.writeln(
        '*Shift ${i + 1}*\n'
        '```Sales : ${formatRupiah(parseInt(shiftSales[i]))}\n'
        'Qty   : ${parseInt(shiftQty[i])}\n'
        '```',
      );
    }

    return '''
*$sbtitle*
```Tanggal $tgl```

${shiftBuffer.toString().trim()}

*TOTAL* ```
Sales.     : ${formatRupiah(totalSales)}
Qty.       : $totalQty
```
=========+=========
```
Nama toko = $sbnama
Kode toko = $sbcode
Tgl GO    = $sbtgl
Area toko = $sbarea
```
*TREND AKM & SPD*

```Sales berjalan : ```
$blnIni
```
$historyText```
*Total sales = ${formatRupiah(akmSales)}*

*Qty Akm = $akmQty*
*SPD          = ${formatRupiah(totalSales)}*
''';
  }
}
