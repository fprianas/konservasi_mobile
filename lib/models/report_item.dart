class ReportItem {
  final int id;
  final String namaPerusahaan;
  final String skIup;
  final String provinsi;
  final String tahun;
  final String triwulan;
  final String jenisPerizinan;
  final String sistemPenambangan;
  final String statusProduksi;
  final String statusProduksiCode;
  final String waktuInput;
  final String? komoditas;
  final Map<String, dynamic> metrics;
  final String? laporanFile;
  final String? petaFile;
  final Map<String, dynamic> rawDetails;

  ReportItem({
    required this.id,
    required this.namaPerusahaan,
    required this.skIup,
    required this.provinsi,
    required this.tahun,
    required this.triwulan,
    required this.jenisPerizinan,
    required this.sistemPenambangan,
    required this.statusProduksi,
    required this.statusProduksiCode,
    required this.waktuInput,
    this.komoditas,
    required this.metrics,
    this.laporanFile,
    this.petaFile,
    required this.rawDetails,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['raw_details'] is Map ? Map<String, dynamic>.from(json['raw_details']) : <String, dynamic>{};

    String? pickFile(dynamic direct, List<String> fallbackKeys) {
      final d = direct?.toString().trim();
      if (d != null && d.isNotEmpty && d != '-' && d.toLowerCase() != 'null') return d;
      for (final k in fallbackKeys) {
        final v = rawDetails[k]?.toString().trim();
        if (v != null && v.isNotEmpty && v != '-' && v.toLowerCase() != 'null') return v;
      }
      return null;
    }

    return ReportItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '-',
      skIup: json['sk_iup']?.toString() ?? '-',
      provinsi: json['provinsi']?.toString() ?? '-',
      tahun: json['tahun']?.toString() ?? '-',
      triwulan: json['triwulan']?.toString() ?? '-',
      jenisPerizinan: json['jenis_perizinan']?.toString() ?? '-',
      sistemPenambangan: json['sistem_penambangan']?.toString() ?? '-',
      statusProduksi: json['status_produksi']?.toString() ?? 'Belum Produksi',
      statusProduksiCode: json['status_produksi_code']?.toString() ?? 'BP',
      waktuInput: json['waktu_input']?.toString() ?? '-',
      komoditas: json['komoditas_mineral']?.toString(),
      metrics: json['metrics'] is Map ? Map<String, dynamic>.from(json['metrics']) : {},
      laporanFile: pickFile(json['laporan_file'], ['laporan_7_1', 'laporan']),
      petaFile: pickFile(json['peta_file'], ['peta_konservasi_7_2', 'peta_konservasi', 'peta']),
      rawDetails: rawDetails,
    );
  }
}

class PaginationData {
  final int currentPage;
  final int perPage;
  final int totalRecords;
  final int totalPages;
  final bool hasMore;

  PaginationData({
    required this.currentPage,
    required this.perPage,
    required this.totalRecords,
    required this.totalPages,
    required this.hasMore,
  });

  factory PaginationData.fromJson(Map<String, dynamic> json) {
    return PaginationData(
      currentPage: json['current_page'] is int ? json['current_page'] : int.tryParse(json['current_page'].toString()) ?? 1,
      perPage: json['per_page'] is int ? json['per_page'] : int.tryParse(json['per_page'].toString()) ?? 15,
      totalRecords: json['total_records'] is int ? json['total_records'] : int.tryParse(json['total_records'].toString()) ?? 0,
      totalPages: json['total_pages'] is int ? json['total_pages'] : int.tryParse(json['total_pages'].toString()) ?? 1,
      hasMore: json['has_more'] == true,
    );
  }
}
