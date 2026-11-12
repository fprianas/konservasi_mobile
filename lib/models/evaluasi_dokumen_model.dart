class EvaluasiRkpwStats {
  final int total;
  final int totalDisetujui;
  final int totalDitolak;
  final int totalProses;
  final double sumLuasDimohon;
  final double sumLuasDisetujui;
  final double sumKdiNilai;

  const EvaluasiRkpwStats({
    this.total = 0,
    this.totalDisetujui = 0,
    this.totalDitolak = 0,
    this.totalProses = 0,
    this.sumLuasDimohon = 0.0,
    this.sumLuasDisetujui = 0.0,
    this.sumKdiNilai = 0.0,
  });

  factory EvaluasiRkpwStats.fromJson(Map<String, dynamic> json) {
    return EvaluasiRkpwStats(
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      totalDisetujui: int.tryParse(json['total_disetujui']?.toString() ?? '0') ?? 0,
      totalDitolak: int.tryParse(json['total_ditolak']?.toString() ?? '0') ?? 0,
      totalProses: int.tryParse(json['total_proses']?.toString() ?? '0') ?? 0,
      sumLuasDimohon: double.tryParse(json['sum_luas_dimohon']?.toString() ?? '0') ?? 0.0,
      sumLuasDisetujui: double.tryParse(json['sum_luas_disetujui']?.toString() ?? '0') ?? 0.0,
      sumKdiNilai: double.tryParse(json['sum_kdi_nilai']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class EvaluasiRkpwItem {
  final int id;
  final String evaluator;
  final String namaPerusahaan;
  final String jenisKomoditas;
  final String noSkIup;
  final String masaBerlaku;
  final double luasWiup;
  final String komoditas;
  final String kecamatan;
  final String kabupaten;
  final String provinsi;
  final double luasPerluasanDimohon;
  final String suratPermohonanNomor;
  final String? suratPermohonanTanggal;
  final String? tglMasukDjmb;
  final String? tglMasukDbt;
  final String? tglMasukSdkm;
  final String ndDbtPermohonanNomor;
  final String ndDbtPermohonanTanggal;
  final String ndDbtKmNomor;
  final String? ndDbtKmTanggal;
  final String ndDbpPwNomor;
  final String? ndDbpPwTanggal;
  final String ndDbmPeNomor;
  final String? ndDbmPeTanggal;
  final String suratDjbNomor;
  final String? suratDjbTanggal;
  final String catatanEvaluasi;
  final String status; // 'Proses', 'Disetujui', 'Ditolak'
  final String suratMemNomor;
  final String? suratMemTanggal;
  final String skPerluasanNomor;
  final String? skPerluasanTanggal;
  final double luasDisetujui;
  final double kdiNilaiRp;
  final String kdiStatusBayar; // 'Lunas', 'Belum'
  final double totalLuasSekarang;
  final String? createdAt;

  const EvaluasiRkpwItem({
    required this.id,
    this.evaluator = '',
    required this.namaPerusahaan,
    this.jenisKomoditas = 'Mineral',
    this.noSkIup = '',
    this.masaBerlaku = '',
    this.luasWiup = 0.0,
    this.komoditas = '',
    this.kecamatan = '',
    this.kabupaten = '',
    this.provinsi = '',
    this.luasPerluasanDimohon = 0.0,
    this.suratPermohonanNomor = '',
    this.suratPermohonanTanggal,
    this.tglMasukDjmb,
    this.tglMasukDbt,
    this.tglMasukSdkm,
    this.ndDbtPermohonanNomor = '',
    this.ndDbtPermohonanTanggal = '',
    this.ndDbtKmNomor = '',
    this.ndDbtKmTanggal,
    this.ndDbpPwNomor = '',
    this.ndDbpPwTanggal,
    this.ndDbmPeNomor = '',
    this.ndDbmPeTanggal,
    this.suratDjbNomor = '',
    this.suratDjbTanggal,
    this.catatanEvaluasi = '',
    this.status = 'Proses',
    this.suratMemNomor = '',
    this.suratMemTanggal,
    this.skPerluasanNomor = '',
    this.skPerluasanTanggal,
    this.luasDisetujui = 0.0,
    this.kdiNilaiRp = 0.0,
    this.kdiStatusBayar = 'Belum',
    this.totalLuasSekarang = 0.0,
    this.createdAt,
  });

  factory EvaluasiRkpwItem.fromJson(Map<String, dynamic> json) {
    return EvaluasiRkpwItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      evaluator: json['evaluator']?.toString() ?? '',
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '',
      jenisKomoditas: json['jenis_komoditas']?.toString() ?? 'Mineral',
      noSkIup: json['no_sk_iup']?.toString() ?? '',
      masaBerlaku: json['masa_berlaku']?.toString() ?? '',
      luasWiup: double.tryParse(json['luas_wiup']?.toString() ?? '0') ?? 0.0,
      komoditas: json['komoditas']?.toString() ?? '',
      kecamatan: json['kecamatan']?.toString() ?? '',
      kabupaten: json['kabupaten']?.toString() ?? '',
      provinsi: json['provinsi']?.toString() ?? '',
      luasPerluasanDimohon: double.tryParse(json['luas_perluasan_dimohon']?.toString() ?? '0') ?? 0.0,
      suratPermohonanNomor: json['surat_permohonan_nomor']?.toString() ?? '',
      suratPermohonanTanggal: json['surat_permohonan_tanggal']?.toString(),
      tglMasukDjmb: json['tgl_masuk_djmb']?.toString(),
      tglMasukDbt: json['tgl_masuk_dbt']?.toString(),
      tglMasukSdkm: json['tgl_masuk_sdkm']?.toString(),
      ndDbtPermohonanNomor: json['nd_dbt_permohonan_nomor']?.toString() ?? '',
      ndDbtPermohonanTanggal: json['nd_dbt_permohonan_tanggal']?.toString() ?? '',
      ndDbtKmNomor: json['nd_dbt_km_nomor']?.toString() ?? '',
      ndDbtKmTanggal: json['nd_dbt_km_tanggal']?.toString(),
      ndDbpPwNomor: json['nd_dbp_pw_nomor']?.toString() ?? '',
      ndDbpPwTanggal: json['nd_dbp_pw_tanggal']?.toString(),
      ndDbmPeNomor: json['nd_dbm_pe_nomor']?.toString() ?? '',
      ndDbmPeTanggal: json['nd_dbm_pe_tanggal']?.toString(),
      suratDjbNomor: json['surat_djb_nomor']?.toString() ?? '',
      suratDjbTanggal: json['surat_djb_tanggal']?.toString(),
      catatanEvaluasi: json['catatan_evaluasi']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Proses',
      suratMemNomor: json['surat_mem_nomor']?.toString() ?? '',
      suratMemTanggal: json['surat_mem_tanggal']?.toString(),
      skPerluasanNomor: json['sk_perluasan_nomor']?.toString() ?? '',
      skPerluasanTanggal: json['sk_perluasan_tanggal']?.toString(),
      luasDisetujui: double.tryParse(json['luas_disetujui']?.toString() ?? '0') ?? 0.0,
      kdiNilaiRp: double.tryParse(json['kdi_nilai_rp']?.toString() ?? '0') ?? 0.0,
      kdiStatusBayar: json['kdi_status_bayar']?.toString() ?? 'Belum',
      totalLuasSekarang: double.tryParse(json['total_luas_sekarang']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'evaluator': evaluator,
    'nama_perusahaan': namaPerusahaan,
    'jenis_komoditas': jenisKomoditas,
    'no_sk_iup': noSkIup,
    'masa_berlaku': masaBerlaku,
    'luas_wiup': luasWiup,
    'komoditas': komoditas,
    'kecamatan': kecamatan,
    'kabupaten': kabupaten,
    'provinsi': provinsi,
    'luas_perluasan_dimohon': luasPerluasanDimohon,
    'surat_permohonan_nomor': suratPermohonanNomor,
    'surat_permohonan_tanggal': suratPermohonanTanggal,
    'tgl_masuk_djmb': tglMasukDjmb,
    'tgl_masuk_dbt': tglMasukDbt,
    'tgl_masuk_sdkm': tglMasukSdkm,
    'nd_dbt_permohonan_nomor': ndDbtPermohonanNomor,
    'nd_dbt_permohonan_tanggal': ndDbtPermohonanTanggal,
    'nd_dbt_km_nomor': ndDbtKmNomor,
    'nd_dbt_km_tanggal': ndDbtKmTanggal,
    'nd_dbp_pw_nomor': ndDbpPwNomor,
    'nd_dbp_pw_tanggal': ndDbpPwTanggal,
    'nd_dbm_pe_nomor': ndDbmPeNomor,
    'nd_dbm_pe_tanggal': ndDbmPeTanggal,
    'surat_djb_nomor': suratDjbNomor,
    'surat_djb_tanggal': suratDjbTanggal,
    'catatan_evaluasi': catatanEvaluasi,
    'status': status,
    'surat_mem_nomor': suratMemNomor,
    'surat_mem_tanggal': suratMemTanggal,
    'sk_perluasan_nomor': skPerluasanNomor,
    'sk_perluasan_tanggal': skPerluasanTanggal,
    'luas_disetujui': luasDisetujui,
    'kdi_nilai_rp': kdiNilaiRp,
    'kdi_status_bayar': kdiStatusBayar,
    'total_luas_sekarang': totalLuasSekarang,
  };
}

class EvaluasiFsStats {
  final int total;
  final int totalMemadai;
  final int totalBelumMemadai;
  final int totalProses;

  const EvaluasiFsStats({
    this.total = 0,
    this.totalMemadai = 0,
    this.totalBelumMemadai = 0,
    this.totalProses = 0,
  });

  factory EvaluasiFsStats.fromJson(Map<String, dynamic> json) {
    return EvaluasiFsStats(
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      totalMemadai: int.tryParse(json['total_memadai']?.toString() ?? '0') ?? 0,
      totalBelumMemadai: int.tryParse(json['total_belum_memadai']?.toString() ?? '0') ?? 0,
      totalProses: int.tryParse(json['total_proses']?.toString() ?? '0') ?? 0,
    );
  }
}

class EvaluasiFsItem {
  final int id;
  final String namaPerusahaan;
  final String evaluator;
  final String komoditas;
  final String ndPermohonanNomor;
  final String? ndPermohonanTanggal;
  final String eval1Nomor;
  final String? eval1Tanggal;
  final String? eval1Status; // 'Memadai', 'Belum Memadai', 'Proses'
  final String eval2Nomor;
  final String? eval2Tanggal;
  final String? eval2Status;
  final String eval3Nomor;
  final String? eval3Tanggal;
  final String? eval3Status;
  final String eval4Nomor;
  final String? eval4Tanggal;
  final String? eval4Status;
  final String latestStatus;
  final String catatan;
  final String? createdAt;

  const EvaluasiFsItem({
    required this.id,
    required this.namaPerusahaan,
    this.evaluator = '',
    this.komoditas = '',
    this.ndPermohonanNomor = '',
    this.ndPermohonanTanggal,
    this.eval1Nomor = '',
    this.eval1Tanggal,
    this.eval1Status,
    this.eval2Nomor = '',
    this.eval2Tanggal,
    this.eval2Status,
    this.eval3Nomor = '',
    this.eval3Tanggal,
    this.eval3Status,
    this.eval4Nomor = '',
    this.eval4Tanggal,
    this.eval4Status,
    this.latestStatus = 'Proses',
    this.catatan = '',
    this.createdAt,
  });

  factory EvaluasiFsItem.fromJson(Map<String, dynamic> json) {
    return EvaluasiFsItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '',
      evaluator: json['evaluator']?.toString() ?? '',
      komoditas: json['komoditas']?.toString() ?? '',
      ndPermohonanNomor: json['nd_permohonan_nomor']?.toString() ?? '',
      ndPermohonanTanggal: json['nd_permohonan_tanggal']?.toString(),
      eval1Nomor: json['eval_1_nomor']?.toString() ?? '',
      eval1Tanggal: json['eval_1_tanggal']?.toString(),
      eval1Status: json['eval_1_status']?.toString(),
      eval2Nomor: json['eval_2_nomor']?.toString() ?? '',
      eval2Tanggal: json['eval_2_tanggal']?.toString(),
      eval2Status: json['eval_2_status']?.toString(),
      eval3Nomor: json['eval_3_nomor']?.toString() ?? '',
      eval3Tanggal: json['eval_3_tanggal']?.toString(),
      eval3Status: json['eval_3_status']?.toString(),
      eval4Nomor: json['eval_4_nomor']?.toString() ?? '',
      eval4Tanggal: json['eval_4_tanggal']?.toString(),
      eval4Status: json['eval_4_status']?.toString(),
      latestStatus: json['latest_status']?.toString() ?? 'Proses',
      catatan: json['catatan']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama_perusahaan': namaPerusahaan,
    'evaluator': evaluator,
    'komoditas': komoditas,
    'nd_permohonan_nomor': ndPermohonanNomor,
    'nd_permohonan_tanggal': ndPermohonanTanggal,
    'eval_1_nomor': eval1Nomor,
    'eval_1_tanggal': eval1Tanggal,
    'eval_1_status': eval1Status,
    'eval_2_nomor': eval2Nomor,
    'eval_2_tanggal': eval2Tanggal,
    'eval_2_status': eval2Status,
    'eval_3_nomor': eval3Nomor,
    'eval_3_tanggal': eval3Tanggal,
    'eval_3_status': eval3Status,
    'eval_4_nomor': eval4Nomor,
    'eval_4_tanggal': eval4Tanggal,
    'eval_4_status': eval4Status,
    'catatan': catatan,
  };
}

