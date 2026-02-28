String formatDate(int ymd) {
  final year = ymd ~/ 10000;
  final month = (ymd % 10000) ~/ 100;
  final day = (ymd % 100).toString().padLeft(2, '0');

  const monthNames = [
    "",
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  return '$day ${monthNames[month]} $year';
}

String formatDayFromYmd(int ymd) {
  final day = ymd % 100;
  return day.toString().padLeft(2, '0');
}

String formatDateV1(DateTime date) {
  const monthNames = [
    "",
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  return "${date.day.toString().padLeft(2, '0')} "
      "${monthNames[date.month]} "
      "${date.year}";
}

String formatDateCaps(DateTime date) {
  const bulan = [
    "",
    "JANUARI",
    "FEBRUARI",
    "MARET",
    "APRIL",
    "MEI",
    "JUNI",
    "JULI",
    "AGUSTUS",
    "SEPTEMBER",
    "OKTOBER",
    "NOVEMBER",
    "DESEMBER",
  ];
  return "${date.day.toString().padLeft(2, '0')} ${bulan[date.month]} ${date.year}";
}

String formatMonth(DateTime date) {
  const bulan = [
    "",
    "JANUARI",
    "FEBRUARI",
    "MARET",
    "APRIL",
    "MEI",
    "JUNI",
    "JULI",
    "AGUSTUS",
    "SEPTEMBER",
    "OKTOBER",
    "NOVEMBER",
    "DESEMBER",
  ];
  return bulan[date.month];
}

String formatPrevMonth(DateTime date) {
  final prev = DateTime(date.year, date.month - 1);

  const bulan = [
    "",
    "JANUARI",
    "FEBRUARI",
    "MARET",
    "APRIL",
    "MEI",
    "JUNI",
    "JULI",
    "AGUSTUS",
    "SEPTEMBER",
    "OKTOBER",
    "NOVEMBER",
    "DESEMBER",
  ];

  return bulan[prev.month];
}

String formatDates(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}/"
      "${date.month.toString().padLeft(2, '0')}/"
      "${date.year} "
      "${date.hour.toString().padLeft(2, '0')}:"
      "${date.minute.toString().padLeft(2, '0')}";
}
