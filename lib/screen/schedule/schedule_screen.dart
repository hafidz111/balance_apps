import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:starvy/utils/ads_helper.dart';

import '../../providers/schedule_provider.dart';
import '../../service/premium_service.dart';
import '../../service/shared_preferences_service.dart';
import '../widgets/ads/rewarded_ads.dart';
import '../widgets/custom_snack_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _prefsService = SharedPreferencesService();

  Map<String, String> get _schedules =>
      context.read<ScheduleProvider>().schedules;

  int get _shiftCount => context.read<ScheduleProvider>().shiftCount;

  DateTime get _currentMonth => context.read<ScheduleProvider>().currentMonth;
  final int _activeYear = DateTime.now().year;

  final ScreenshotController _screenshotController = ScreenshotController();
  static const platform = MethodChannel('gallery_saver');

  String get _storeCode => context.read<ScheduleProvider>().storeCode;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final provider = context.read<ScheduleProvider>();
    provider.setSchedules(await _prefsService.getSchedules());
    provider.setShiftCount(_prefsService.getShiftCount() ?? 2);

    final store = await _prefsService.getPointCoffeeStore();
    provider.setStoreCode(
      store?.kode.isNotEmpty == true ? store!.kode : "FBVO",
    );
  }

  Future<void> _setSchedule(String name, String date, String shift) async {
    await _prefsService.setSchedule(name, date, shift);
    _loadSchedules();
  }

  Future<void> _deleteSchedule(String name, String date) async {
    await _prefsService.deleteSchedule(name, date);
    _loadSchedules();
  }

  Future<void> _deleteSchedulesByCurrentMonth() async {
    final schedules = await _prefsService.getSchedules();

    final monthPrefix =
        "${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}";

    final hasData = schedules.keys.any((key) => key.contains(monthPrefix));

    if (!hasData) {
      if (!mounted) return;

      CustomSnackBar.show(
        context,
        message: "Tidak ada jadwal di bulan $_formattedMonth",
        type: SnackType.error,
      );
      return;
    }

    await _prefsService.clearSchedulesByMonth(
      _currentMonth.year,
      _currentMonth.month,
    );

    await _loadSchedules();

    if (!mounted) return;

    CustomSnackBar.show(
      context,
      message: "Jadwal bulan $_formattedMonth berhasil dihapus",
      type: SnackType.success,
    );
  }

  List<String> get _employeeNames {
    final monthPrefix =
        "${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}";

    final seen = <String>{};
    final names = <String>[];

    for (final key in _schedules.keys) {
      if (!key.contains(monthPrefix)) continue;

      final name = key.split("_").first;

      if (!seen.contains(name)) {
        seen.add(name);
        names.add(name);
      }
    }

    return names;
  }

  Future<void> _deleteEmployee(String name) async {
    final schedules = await _prefsService.getSchedules();

    final keysToDelete = schedules.keys
        .where((key) => key.startsWith("${name}_"))
        .toList();

    for (final key in keysToDelete) {
      final date = key.split("_")[1];
      await _prefsService.deleteSchedule(name, date);
    }

    await _loadSchedules();

    if (!mounted) return;

    CustomSnackBar.show(
      context,
      message: "$name berhasil dihapus",
      type: SnackType.success,
    );
  }

  Future<void> _confirmDeleteEmployee(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Karyawan"),
        content: Text("Semua jadwal $name akan dihapus."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteEmployee(name);
    }
  }

  final List<Color> _nameColors = [
    Colors.orange.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
    Colors.teal.shade100,
    Colors.red.shade100,
    Colors.cyan.shade100,
  ];

  Color _getColorForName(String name) {
    final index = _employeeNames.indexOf(name);
    return _nameColors[index % _nameColors.length];
  }

  int get _daysInMonth {
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  void _changeMonth(int offset) {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);

    if (newMonth.year != _activeYear) return;

    context.read<ScheduleProvider>().setCurrentMonth(newMonth);
  }

  String get _formattedMonth {
    const months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    return "${months[_currentMonth.month - 1]} ${_currentMonth.year}";
  }

  Future<void> _exportExcel() async {
    try {
      final byteData = await rootBundle.load('assets/file/schedule.xlsx');
      final bytes = byteData.buffer.asUint8List();

      await FileSaver.instance.saveFile(
        name: "balance_schedule",
        bytes: bytes,
        fileExtension: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;

      CustomSnackBar.show(
        context,
        message: "Template berhasil di download",
        type: SnackType.success,
      );
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Download gagal",
        type: SnackType.error,
      );
    }
  }

  Future<void> _importExcel() async {
    context.read<ScheduleProvider>().setLoading(true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        context.read<ScheduleProvider>().setLoading(false);
        return;
      }

      final file = result.files.single;
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        final path = file.path;
        if (path == null) {
          context.read<ScheduleProvider>().setLoading(false);
          return;
        }
        bytes = await File(path).readAsBytes();
      }

      final excel = ex.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final monthYear = _currentMonth;

      for (int row = 4; row <= 9; row++) {
        final name = sheet.rows[row][1]?.value?.toString().trim();
        if (name == null || name.isEmpty) continue;

        for (int col = 2; col <= 16; col++) {
          final dayCell = sheet.rows[2][col]?.value;
          final shiftCell = sheet.rows[row][col]?.value;

          if (dayCell == null || shiftCell == null) continue;

          final day = int.tryParse(dayCell.toString());
          if (day == null || day > _daysInMonth) continue;

          final date = DateTime(monthYear.year, monthYear.month, day);

          final dateString =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          await _prefsService.setSchedule(
            name,
            dateString,
            shiftCell.toString(),
          );
        }
      }

      for (int row = 13; row <= 18; row++) {
        final importedNames = <String>{..._employeeNames};
        final name = sheet.rows[row][1]?.value?.toString().trim();
        if (name == null || name.isEmpty) continue;

        if (!importedNames.contains(name) && importedNames.length >= 6) {
          continue;
        }

        for (int col = 2; col <= 17; col++) {
          final dayCell = sheet.rows[11][col]?.value;
          final shiftCell = sheet.rows[row][col]?.value;

          if (dayCell == null || shiftCell == null) continue;

          final day = int.tryParse(dayCell.toString());
          if (day == null || day > _daysInMonth) continue;

          final date = DateTime(monthYear.year, monthYear.month, day);

          final dateString =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          await _prefsService.setSchedule(
            name,
            dateString,
            shiftCell.toString(),
          );
        }
      }

      await _loadSchedules();

      if (!mounted) return;

      CustomSnackBar.show(
        context,
        message: "Import jadwal berhasil",
        type: SnackType.success,
      );
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Import gagal",
        type: SnackType.error,
      );
    } finally {
      if (mounted) {
        context.read<ScheduleProvider>().setLoading(false);
      }
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      final photos = await Permission.photos.request();

      if (storage.isGranted || photos.isGranted) {
        return true;
      }

      if (storage.isPermanentlyDenied || photos.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    } else {
      final photos = await Permission.photos.request();
      if (photos.isGranted || photos.isLimited) {
        return true;
      }

      if (photos.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    }
  }

  Future<void> _scanFile(String path) async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('scanFile', {"path": path});
      } catch (e) {
        debugPrint("Scan error: $e");
      }
    }
  }

  Future<void> _exportAsImage() async {
    if (_employeeNames.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Belum ada jadwal untuk diexport",
        type: SnackType.error,
      );
      return;
    }

    try {
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        CustomSnackBar.show(
          context,
          message: "Izin storage diperlukan",
          type: SnackType.error,
        );
        return;
      }

      final Uint8List? image = await _screenshotController.captureFromWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _buildExportLayoutOnly(),
        ),
        pixelRatio: 3.0,
      );

      if (image == null) return;

      Directory directory = Directory("/storage/emulated/0/Pictures/Balance");

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath =
          "${directory.path}/balance_jadwal_${DateTime.now().millisecondsSinceEpoch}.png";

      File file = File(filePath);
      await file.writeAsBytes(image);

      await _scanFile(file.path);

      CustomSnackBar.show(
        context,
        message: "Berhasil disimpan ke Gallery",
        type: SnackType.success,
      );
    } catch (e) {
      debugPrint("Save error: $e");
      CustomSnackBar.show(
        context,
        message: "Gagal menyimpan gambar",
        type: SnackType.error,
      );
    }
  }

  Widget _buildExportLayoutOnly() {
    final double nameWidth = 60;
    final double dayWidth = 20;
    final double fullWidth = nameWidth + (15 * dayWidth);

    Widget buildTable(int startDay, int endDay) {
      final dayCount = endDay - startDay + 1;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _buildExportCell('', width: nameWidth, isHeader: true),
              _buildExportCell('', width: nameWidth, isHeader: true),
              ..._employeeNames.map(
                (name) =>
                    _buildExportCell(name, width: nameWidth, isName: true),
              ),
            ],
          ),

          Column(
            children: [
              Row(
                children: List.generate(
                  dayCount,
                  (i) => _buildExportCell(
                    "${startDay + i}",
                    width: dayWidth,
                    isHeader: true,
                  ),
                ),
              ),

              Row(
                children: List.generate(dayCount, (i) {
                  final date = DateTime(
                    _currentMonth.year,
                    _currentMonth.month,
                    startDay + i,
                  );

                  const days = ['M', 'S', 'S', 'R', 'K', 'J', 'S'];

                  return _buildExportCell(
                    days[date.weekday % 7],
                    width: dayWidth,
                    isHeader: true,
                  );
                }),
              ),

              ..._employeeNames.map((name) {
                return Row(
                  children: List.generate(dayCount, (i) {
                    final day = startDay + i;

                    final date = DateTime(
                      _currentMonth.year,
                      _currentMonth.month,
                      day,
                    );

                    final dateString =
                        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

                    final shift = _schedules["${name}_$dateString"] ?? "";

                    return _buildExportCell(
                      shift,
                      width: dayWidth,
                      isLibur: shift == "X",
                    );
                  }),
                );
              }),
            ],
          ),
        ],
      );
    }

    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: fullWidth,
                child: Text(
                  "$_storeCode - $_formattedMonth",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              buildTable(1, 15),

              if (_daysInMonth > 15) ...[
                const SizedBox(height: 16),
                buildTable(16, _daysInMonth),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportCell(
    String text, {
    required double width,
    bool isHeader = false,
    bool isLibur = false,
    bool isName = false,
  }) {
    Color bgColor = Colors.white;

    if (isHeader) bgColor = Colors.green.shade300;
    if (isLibur) bgColor = Colors.red;
    if (isName) bgColor = _getColorForName(text);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isLibur ? Colors.white : Colors.black,
        ),
        overflow: TextOverflow.clip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<ScheduleProvider, bool>(
      (provider) => provider.isLoading,
    );
    context.select<ScheduleProvider, DateTime>(
      (provider) => provider.currentMonth,
    );
    context.select<ScheduleProvider, int>((provider) => provider.shiftCount);
    context.select<ScheduleProvider, String>((provider) => provider.storeCode);
    context.select<ScheduleProvider, Map<String, String>>(
      (provider) => provider.schedules,
    );

    return Stack(
      children: [
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
        Scaffold(
          backgroundColor: Colors.grey[100],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      PremiumService.cachedPremium
                          ? _headerButton(
                              Icons.download,
                              "Download Template",
                              onTap: _exportExcel,
                            )
                          : RewardedAds(
                              adUnitId:
                                  AdsHelper.rewardedDownloadTemplateAdUnitId,
                              interstitialAdUnitId: AdsHelper
                                  .rewardedDownloadScheduleTemplateAdUnitId,
                              featureName: "download_template",
                              customChild: _headerButton(
                                Icons.download,
                                "Download Template",
                              ),
                              onRewarded: () async {
                                await _exportExcel();
                              },
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PremiumService.cachedPremium
                            ? _headerButton(
                                Icons.upload,
                                "Import Excel",
                                onTap: _importExcel,
                              )
                            : RewardedAds(
                                adUnitId:
                                    AdsHelper.rewardedImportTemplateAdUnitId,
                                interstitialAdUnitId:
                                    AdsHelper.rewardedImportScheduleAdUnitId,
                                featureName: "import_excel",
                                customChild: _headerButton(
                                  Icons.upload,
                                  "Import Excel",
                                ),
                                onRewarded: () async {
                                  await _importExcel();
                                },
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddShiftDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text("Tambah Jadwal"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      SizedBox(
                        height: 40,
                        width: 48,
                        child: OutlinedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Hapus Jadwal Bulan Ini?"),
                                content: Text(
                                  "Semua jadwal $_formattedMonth akan dihapus.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Batal"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Hapus"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              _deleteSchedulesByCurrentMonth();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      PremiumService.cachedPremium
                          ? SizedBox(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _exportAsImage,
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : RewardedAds(
                              adUnitId: AdsHelper.rewardedSaveScheduleAdUnitId,
                              interstitialAdUnitId:
                                  AdsHelper.rewardedExportScheduleAdUnitId,
                              featureName: "export_image",
                              icon: Icons.image,
                              color: Colors.black,
                              customChild: SizedBox(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: null,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              onRewarded: () async {
                                await _exportAsImage();
                              },
                            ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _currentMonth.month == 1
                            ? null
                            : () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        _formattedMonth,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _currentMonth.month == 12
                            ? null
                            : () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildScheduleTable(context),
                  const SizedBox(height: 20),

                  _buildLegend(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerButton(IconData icon, String label, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.black),
      label: Text(label, style: TextStyle(color: Colors.black)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildScheduleTable(BuildContext context) {
    if (_employeeNames.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        height: 200,
        alignment: Alignment.center,
        child: Text(
          "Belum ada jadwal $_formattedMonth",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _buildFixedCell('', isHeader: true),
              _buildFixedCell('', isHeader: true),
              ..._employeeNames.map(
                (name) => GestureDetector(
                  onTap: () => _confirmDeleteEmployee(name),
                  child: _buildFixedCell(name, isHeader: false, isName: true),
                ),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      _daysInMonth,
                      (i) => _buildDateCell("${i + 1}", isHeader: true),
                    ),
                  ),

                  Row(
                    children: List.generate(_daysInMonth, (i) {
                      final date = DateTime(
                        _currentMonth.year,
                        _currentMonth.month,
                        i + 1,
                      );
                      const days = ['M', 'S', 'S', 'R', 'K', 'J', 'S'];
                      return _buildDateCell(
                        days[date.weekday % 7],
                        isHeader: true,
                      );
                    }),
                  ),

                  ..._employeeNames.map((name) {
                    return Row(
                      children: List.generate(_daysInMonth, (index) {
                        final date = DateTime(
                          _currentMonth.year,
                          _currentMonth.month,
                          index + 1,
                        );

                        final dateString =
                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

                        final key = "${name}_$dateString";
                        final shift = _schedules[key] ?? "";

                        return GestureDetector(
                          onTap: () =>
                              _showEditShiftDialog(context, name, date),
                          child: _buildDateCell(
                            shift,
                            isHeader: false,
                            isLibur: shift == 'X',
                          ),
                        );
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedCell(
    String text, {
    bool isHeader = false,
    bool isName = false,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHeader
            ? Colors.green[100]
            : isName
            ? _getColorForName(text)
            : Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDateCell(
    String text, {
    bool isHeader = false,
    bool isLibur = false,
  }) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isHeader
            ? Colors.green[100]
            : isLibur
            ? Colors.red
            : Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isLibur ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final shiftText = List.generate(_shiftCount, (i) => "${i + 1}").join(", ");

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Keterangan",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text("Shift $shiftText = Shift kerja")),
              Container(width: 20, height: 20, color: Colors.red),
              const SizedBox(width: 8),
              const Text("X = Hari Libur"),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddShiftDialog(BuildContext context) {
    final nameController = TextEditingController();
    final dateController = TextEditingController();
    String selectedShift = "1";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 24),
                          const Text(
                            "Tambah Shift",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      const Text("Masukkan detail shift baru"),

                      const SizedBox(height: 24),

                      _buildDialogField(
                        label: "Tanggal",
                        child: TextField(
                          controller: dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: "dd/mm/yyyy",
                            suffixIcon: const Icon(Icons.calendar_today),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _currentMonth,
                              firstDate: DateTime(_activeYear, 1, 1),
                              lastDate: DateTime(_activeYear, 12, 31),
                            );

                            if (pickedDate != null) {
                              dateController.text =
                                  "${pickedDate.day.toString().padLeft(2, '0')}/"
                                  "${pickedDate.month.toString().padLeft(2, '0')}/"
                                  "${pickedDate.year}";
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildDialogField(
                        label: "Nama",
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildDialogField(
                        label: "Shift",
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedShift,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            ...List.generate(
                              _shiftCount,
                              (i) => DropdownMenuItem(
                                value: "${i + 1}",
                                child: Text("Shift ${i + 1}"),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: "X",
                              child: Text("Libur (X)"),
                            ),
                          ],
                          onChanged: (val) {
                            setStateDialog(() {
                              selectedShift = val!;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Batal"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();

                              if (name.isEmpty || dateController.text.isEmpty) {
                                return;
                              }

                              final isNewEmployee = !_employeeNames.contains(
                                name,
                              );

                              if (isNewEmployee && _employeeNames.length >= 6) {
                                CustomSnackBar.show(
                                  context,
                                  message: "Maksimal 6 karyawan",
                                  type: SnackType.error,
                                );
                                return;
                              }

                              final parts = dateController.text.split("/");

                              final formattedDate =
                                  "${parts[2]}-${parts[1]}-${parts[0]}";

                              await _setSchedule(
                                name,
                                formattedDate,
                                selectedShift,
                              );

                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              "Tambah",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDialogField({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  void _showEditShiftDialog(BuildContext context, String name, DateTime date) {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    String selectedShift = _schedules["${name}_$dateString"] ?? "1";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Text(
                          "Edit Shift",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text("$name - $dateString"),

                    const SizedBox(height: 24),

                    _buildDialogField(
                      label: "Shift",
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedShift,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          ...List.generate(
                            _shiftCount,
                            (i) => DropdownMenuItem(
                              value: "${i + 1}",
                              child: Text("Shift ${i + 1}"),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: "X",
                            child: Text("Libur (X)"),
                          ),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedShift = val!;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: () async {
                              await _deleteSchedule(name, dateString);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(40, 40),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Batal"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                await _setSchedule(
                                  name,
                                  dateString,
                                  selectedShift,
                                );
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                "Simpan",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
