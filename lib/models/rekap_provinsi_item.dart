class RekapProvinsiItem {
  final String namaProvinsi;
  final int totalPerusahaan;
  final int totalLaporan;
  final int sudahLapor;
  final int belumLapor;
  final double persentaseKepatuhan;

  const RekapProvinsiItem({
    required this.namaProvinsi,
    required this.totalPerusahaan,
    required this.totalLaporan,
    required this.sudahLapor,
    required this.belumLapor,
    required this.persentaseKepatuhan,
  });

  factory RekapProvinsiItem.fromJson(Map<String, dynamic> json) {
    final rawTotal = (json['total_perusahaan'] as num?)?.toInt() ?? 0;
    final sudah = (json['sudah_lapor'] as num?)?.toInt() ?? 0;
    final total = rawTotal < sudah ? sudah : rawTotal;
    final belum = (total - sudah) >= 0 ? (total - sudah) : 0;
    
    double patuh = (json['persentase_kepatuhan'] as num?)?.toDouble() ?? 0.0;
    if (patuh > 100.0 || patuh <= 0.0) {
      patuh = total > 0 ? ((sudah * 100.0) / total) : 0.0;
      if (patuh > 100.0) patuh = 100.0;
    }

    return RekapProvinsiItem(
      namaProvinsi: json['nama_provinsi']?.toString().trim() ?? '-',
      totalPerusahaan: total,
      totalLaporan: (json['total_laporan'] as num?)?.toInt() ?? 0,
      sudahLapor: sudah,
      belumLapor: belum,
      persentaseKepatuhan: double.parse(patuh.toStringAsFixed(2)),
    );
  }
}