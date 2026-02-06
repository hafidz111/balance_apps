class StoreData {
  final String title;
  final String nama;
  final String kode;
  final String tgl;
  final String area;

  StoreData({
    required this.title,
    required this.nama,
    required this.kode,
    required this.tgl,
    required this.area,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'nama': nama,
    'kode': kode,
    'tgl': tgl,
    'area': area,
  };

  factory StoreData.fromJson(Map<String, dynamic> json) {
    return StoreData(
      title: json['title'],
      nama: json['nama'],
      kode: json['kode'],
      tgl: json['tgl'],
      area: json['area'],
    );
  }
}
