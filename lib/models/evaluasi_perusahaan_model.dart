import 'dart:convert';

class EvaluasiPerusahaanItem {
  final int id;
  final String namaPerusahaan;
  final String tipe; // 'batubara' | 'mineral'
  final String? komoditas;
  final String skIup;
  final String provinsi;
  final String triwulan;
  final int tahun;
  final String statusProduksi;
  final String namaPetugas;
  final String status; // 'Memadai' | 'Belum Memadai'
  final String formatLaporan; // 'Memadai' | 'Belum Memadai'
  final String catatan;
  final Map<String, dynamic> detailEvaluasi; // Map 7 Objek Evaluasi
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EvaluasiPerusahaanItem({
    required this.id,
    required this.namaPerusahaan,
    this.tipe = 'batubara',
    this.komoditas,
    this.skIup = '',
    this.provinsi = '',
    this.triwulan = '',
    this.tahun = 0,
    this.statusProduksi = '',
    required this.namaPetugas,
    required this.status,
    this.formatLaporan = 'Memadai',
    this.catatan = '',
    this.detailEvaluasi = const {},
    this.createdAt,
    this.updatedAt,
  });

  bool get isMemadai =>
      status.toLowerCase().contains('memadai') && !status.toLowerCase().contains('belum') ||
      status == 'Layak';

  bool get isLayak => isMemadai;

  bool get isFormatMemadai =>
      formatLaporan.toLowerCase().contains('memadai') && !formatLaporan.toLowerCase().contains('belum') ||
      formatLaporan.toLowerCase().contains('sesuai') && !formatLaporan.toLowerCase().contains('belum');

  bool get isFormatSesuai => isFormatMemadai;

  int get belumMemadaiCount {
    if (detailEvaluasi.isEmpty) {
      return isMemadai ? 0 : 1;
    }
    int count = 0;
    for (final val in detailEvaluasi.values) {
      if (val is Map && val['status']?.toString() == 'Belum Memadai') {
        count++;
      }
    }
    return count;
  }

  factory EvaluasiPerusahaanItem.fromJson(Map<String, dynamic> json) {
    String st = json['status']?.toString() ?? 'Memadai';
    if (st == 'Layak') st = 'Memadai';
    if (st == 'Belum Layak') st = 'Belum Memadai';

    String fl = json['format_laporan']?.toString() ?? 'Memadai';
    if (fl == 'Sesuai') fl = 'Memadai';
    if (fl == 'Belum Sesuai') fl = 'Belum Memadai';
    if (fl.isEmpty) fl = 'Memadai';

    // Parse detail_evaluasi
    Map<String, dynamic> detailMap = {};
    final rawDetail = json['detail_evaluasi'];
    if (rawDetail is Map) {
      detailMap = Map<String, dynamic>.from(rawDetail);
    } else if (rawDetail is String && rawDetail.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDetail);
        if (decoded is Map) {
          detailMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return EvaluasiPerusahaanItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? 'batubara',
      komoditas: json['komoditas']?.toString(),
      skIup: json['sk_iup']?.toString() ?? '',
      provinsi: json['provinsi']?.toString() ?? '',
      triwulan: json['triwulan']?.toString() ?? '',
      tahun: int.tryParse(json['tahun']?.toString() ?? '') ?? 0,
      statusProduksi: json['status_produksi']?.toString() ?? '',
      namaPetugas: json['nama_petugas']?.toString() ?? '',
      status: st,
      formatLaporan: fl,
      catatan: json['catatan']?.toString() ?? '',
      detailEvaluasi: detailMap,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'nama_perusahaan': namaPerusahaan,
      'tipe': tipe,
      if (komoditas != null) 'komoditas': komoditas,
      'sk_iup': skIup,
      'provinsi': provinsi,
      'triwulan': triwulan,
      'tahun': tahun,
      'status_produksi': statusProduksi,
      'nama_petugas': namaPetugas,
      'status': status,
      'format_laporan': formatLaporan,
      'catatan': catatan,
      'detail_evaluasi': detailEvaluasi,
    };
  }

  EvaluasiPerusahaanItem copyWith({
    int? id,
    String? namaPerusahaan,
    String? tipe,
    String? komoditas,
    String? skIup,
    String? provinsi,
    String? triwulan,
    int? tahun,
    String? statusProduksi,
    String? namaPetugas,
    String? status,
    String? formatLaporan,
    String? catatan,
    Map<String, dynamic>? detailEvaluasi,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EvaluasiPerusahaanItem(
      id: id ?? this.id,
      namaPerusahaan: namaPerusahaan ?? this.namaPerusahaan,
      tipe: tipe ?? this.tipe,
      komoditas: komoditas ?? this.komoditas,
      skIup: skIup ?? this.skIup,
      provinsi: provinsi ?? this.provinsi,
      triwulan: triwulan ?? this.triwulan,
      tahun: tahun ?? this.tahun,
      statusProduksi: statusProduksi ?? this.statusProduksi,
      namaPetugas: namaPetugas ?? this.namaPetugas,
      status: status ?? this.status,
      formatLaporan: formatLaporan ?? this.formatLaporan,
      catatan: catatan ?? this.catatan,
      detailEvaluasi: detailEvaluasi ?? this.detailEvaluasi,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
