import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:starvy/utils/ads_helper.dart';

import '../../providers/schedule_provider.dart';
import '../../service/premium_service.dart';
import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/gallery_access_helper.dart';
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

    final store = await _prefsService.getCoffeeStore();
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
    final confirm = await _showScheduleConfirmDialog(
      title: 'Hapus karyawan?',
      message: 'Semua jadwal $name di bulan ini akan dihapus.',
      destructive: true,
      confirmLabel: 'Hapus',
    );

    if (confirm == true) {
      await _deleteEmployee(name);
    }
  }

  Future<bool?> _showScheduleConfirmDialog({
    required String title,
    required String message,
    bool destructive = false,
    String confirmLabel = 'Oke',
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: destructive
                            ? Colors.red.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        destructive
                            ? Icons.person_remove_rounded
                            : Icons.calendar_month_rounded,
                        color: destructive
                            ? Colors.red.shade700
                            : AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: destructive
                              ? Colors.red.shade700
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final List<Color> _nameColors = [
    AppColors.primaryLight,
    const Color(0xFFE0F7FA),
    const Color(0xFFC8E6C9).withValues(alpha: 0.65),
    const Color(0xFFFFF9C4).withValues(alpha: 0.85),
    const Color(0xFFE1BEE7).withValues(alpha: 0.45),
    const Color(0xFFFFCCBC).withValues(alpha: 0.65),
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
        name: "starvy_schedule",
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
      if (!mounted) return;

      final Uint8List? image = await _screenshotController.captureFromWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _buildExportLayoutOnly(),
        ),
        pixelRatio: 3.0,
      );

      if (image == null) return;
      if (!mounted) return;

      final saved = await GalleryAccessHelper.savePngToGallery(
        image,
        fileName: "starvy_jadwal_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (!mounted) return;

      if (!saved) {
        CustomSnackBar.show(
          context,
          message: "Gagal menyimpan gambar",
          type: SnackType.error,
        );
        return;
      }

      CustomSnackBar.show(
        context,
        message: "Berhasil disimpan ke galeri",
        type: SnackType.success,
      );
    } catch (e) {
      debugPrint("Save error: $e");
      if (!mounted) return;
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

    if (isHeader) bgColor = AppColors.primaryLight;
    if (isLibur) bgColor = Colors.red.shade600;
    if (isName) bgColor = _getColorForName(text);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isLibur
              ? Colors.white
              : isHeader
              ? AppColors.primaryDark
              : Colors.black87,
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
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PremiumService.cachedPremium
                          ? _scheduleOutlineButton(
                              context,
                              Icons.download_rounded,
                              'Unduh template',
                              onTap: _exportExcel,
                            )
                          : RewardedAds(
                              adUnitId:
                                  AdsHelper.rewardedDownloadTemplateAdUnitId,
                              interstitialAdUnitId: AdsHelper
                                  .rewardedDownloadScheduleTemplateAdUnitId,
                              featureName: "download_template",
                              customChild: _scheduleOutlineButton(
                                context,
                                Icons.download_rounded,
                                'Unduh template',
                              ),
                              onRewarded: () async {
                                await _exportExcel();
                              },
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumService.cachedPremium
                            ? _scheduleOutlineButton(
                                context,
                                Icons.upload_file_rounded,
                                'Import Excel',
                                onTap: _importExcel,
                              )
                            : RewardedAds(
                                adUnitId:
                                    AdsHelper.rewardedImportTemplateAdUnitId,
                                interstitialAdUnitId:
                                    AdsHelper.rewardedImportScheduleAdUnitId,
                                featureName: "import_excel",
                                customChild: _scheduleOutlineButton(
                                  context,
                                  Icons.upload_file_rounded,
                                  'Import Excel',
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
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showAddShiftDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          label: const Text(
                            'Tambah jadwal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryLight.withValues(
                              alpha: 0.85,
                            ),
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          foregroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await _showScheduleConfirmDialog(
                            title: 'Hapus jadwal bulan ini?',
                            message:
                                'Semua entri jadwal untuk $_formattedMonth akan dihapus.',
                            destructive: true,
                            confirmLabel: 'Hapus',
                          );
                          if (confirm == true) {
                            _deleteSchedulesByCurrentMonth();
                          }
                        },
                        tooltip: 'Hapus bulan ini',
                        icon: const Icon(Icons.delete),
                      ),
                      const SizedBox(width: 8),
                      PremiumService.cachedPremium
                          ? IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.85),
                                foregroundColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _exportAsImage,
                              tooltip: 'Simpan ke gambar',
                              icon: const Icon(Icons.image_rounded),
                            )
                          : RewardedAds(
                              adUnitId: AdsHelper.rewardedSaveScheduleAdUnitId,
                              interstitialAdUnitId:
                                  AdsHelper.rewardedExportScheduleAdUnitId,
                              featureName: "export_image",
                              icon: Icons.image_rounded,
                              color: AppColors.primaryDark,
                              customChild: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.image_rounded),
                              ),
                              onRewarded: () async {
                                await _exportAsImage();
                              },
                            ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildMonthNavigator(context),
                  const SizedBox(height: 16),
                  _buildScheduleTable(context),
                  const SizedBox(height: 16),
                  _buildLegend(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scheduleOutlineButton(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: AppColors.primaryDark),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        foregroundColor: AppColors.primaryDark,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: scheme.surface,
      ),
    );
  }

  Widget _buildMonthNavigator(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _currentMonth.month == 1
                  ? null
                  : () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                _formattedMonth,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _currentMonth.month == 12
                  ? null
                  : () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTable(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_employeeNames.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  size: 40,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada jadwal',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_formattedMonth — Import Excel atau tap tambah jadwal.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.primaryLight
            : isName
            ? _getColorForName(text)
            : Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isName ? 13 : 12,
          color: isHeader ? AppColors.primaryDark : null,
        ),
      ),
    );
  }

  Widget _buildDateCell(
    String text, {
    bool isHeader = false,
    bool isLibur = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.65);
    return Container(
      width: 50,
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.primaryLight
            : isLibur
            ? Colors.red.shade600
            : scheme.surface,
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: isHeader
              ? AppColors.primaryDark
              : isLibur
              ? Colors.white
              : scheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shiftText = List.generate(_shiftCount, (i) => "${i + 1}").join(", ");

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Text(
                  'Keterangan',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Angka $shiftText = Shift Kerja (Sesuai Pengaturan).',
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'X = Hari Libur',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _scheduleFieldDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
      ),
    );
    return InputDecoration(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: base,
      enabledBorder: base,
      focusedBorder: base.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildDialogField({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _showAddShiftDialog(BuildContext context) {
    final nameController = TextEditingController();
    final dateController = TextEditingController();
    String selectedShift = "1";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              final scheme = Theme.of(context).colorScheme;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_task_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tambah jadwal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Isi tanggal, nama, dan shift.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDialogField(
                            context: context,
                            label: 'Tanggal',
                            child: TextField(
                              controller: dateController,
                              readOnly: true,
                              decoration: _scheduleFieldDecoration(context)
                                  .copyWith(
                                    hintText: 'dd/mm/yyyy',
                                    suffixIcon: Icon(
                                      Icons.calendar_month_rounded,
                                      color: AppColors.primary,
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
                            context: context,
                            label: 'Nama',
                            child: TextField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _scheduleFieldDecoration(context)
                                  .copyWith(
                                    hintText: 'Masukkan nama',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDialogField(
                            context: context,
                            label: 'Shift',
                            child: DropdownButtonFormField<String>(
                              value: selectedShift,
                              decoration: _scheduleFieldDecoration(context),
                              items: [
                                ...List.generate(
                                  _shiftCount,
                                  (i) => DropdownMenuItem(
                                    value: "${i + 1}",
                                    child: Text('Shift ${i + 1}'),
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: "X",
                                  child: Text('Libur (X)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setStateDialog(() {
                                  selectedShift = val;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    final name = nameController.text.trim();

                                    if (name.isEmpty ||
                                        dateController.text.isEmpty) {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'Lengkapi tanggal dan nama',
                                        type: SnackType.error,
                                      );
                                      return;
                                    }

                                    final isNewEmployee = !_employeeNames
                                        .contains(name);

                                    if (isNewEmployee &&
                                        _employeeNames.length >= 6) {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'Maksimal 6 karyawan',
                                        type: SnackType.error,
                                      );
                                      return;
                                    }

                                    final parts = dateController.text.split(
                                      "/",
                                    );

                                    final formattedDate =
                                        "${parts[2]}-${parts[1]}-${parts[0]}";

                                    await _setSchedule(
                                      name,
                                      formattedDate,
                                      selectedShift,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Simpan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void _showEditShiftDialog(BuildContext context, String name, DateTime date) {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    var selectedShift = _schedules["${name}_$dateString"] ?? "1";
    if (selectedShift.isEmpty) selectedShift = "1";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              final scheme = Theme.of(context).colorScheme;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.edit_calendar_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit shift',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$name · $dateString',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDialogField(
                            context: context,
                            label: 'Shift',
                            child: DropdownButtonFormField<String>(
                              value: selectedShift,
                              decoration: _scheduleFieldDecoration(context),
                              items: [
                                ...List.generate(
                                  _shiftCount,
                                  (i) => DropdownMenuItem(
                                    value: "${i + 1}",
                                    child: Text('Shift ${i + 1}'),
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: "X",
                                  child: Text('Libur (X)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setStateDialog(() {
                                  selectedShift = val;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: Colors.red.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  await _deleteSchedule(name, dateString);
                                  if (context.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Hapus',
                              ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Batal'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: () async {
                                  await _setSchedule(
                                    name,
                                    dateString,
                                    selectedShift,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: const Text(
                                  'Simpan',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
