class SummaryData {
  final int totalPerusahaan;
  final int sudahLapor;
  final int belumLapor;
  final int totalLaporanMasuk;
  final double persentaseKepatuhan;

  SummaryData({
    required this.totalPerusahaan,
    required this.sudahLapor,
    required this.belumLapor,
    required this.totalLaporanMasuk,
    required this.persentaseKepatuhan,
  });

  factory SummaryData.fromJson(Map<String, dynamic> json) {
    return SummaryData(
      totalPerusahaan: json['total_perusahaan'] is int
          ? json['total_perusahaan']
          : int.tryParse(json['total_perusahaan'].toString()) ?? 0,
      sudahLapor: json['sudah_lapor'] is int
          ? json['sudah_lapor']
          : int.tryParse(json['sudah_lapor'].toString()) ?? 0,
      belumLapor: json['belum_lapor'] is int
          ? json['belum_lapor']
          : int.tryParse(json['belum_lapor'].toString()) ?? 0,
      totalLaporanMasuk: json['total_laporan_masuk'] is int
          ? json['total_laporan_masuk']
          : int.tryParse(json['total_laporan_masuk'].toString()) ?? 0,
      persentaseKepatuhan: json['persentase_kepatuhan'] is num
          ? (json['persentase_kepatuhan'] as num).toDouble()
          : double.tryParse(json['persentase_kepatuhan'].toString()) ?? 0.0,
    );
  }
}
