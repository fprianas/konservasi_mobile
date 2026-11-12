class BinwasCategory {
  final int id;
  final String namaKategori;
  final int urutan;
  final List<BinwasItem> items;

  BinwasCategory({
    required this.id,
    required this.namaKategori,
    required this.urutan,
    required this.items,
  });

  factory BinwasCategory.fromJson(Map<String, dynamic> json) {
    return BinwasCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
      urutan: json['urutan'] is int ? json['urutan'] : int.tryParse(json['urutan'].toString()) ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BinwasItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class BinwasItem {
  final int id;
  final int idKategori;
  final String deskripsiTemuan;
  final String objekKonservasi;

  BinwasItem({
    required this.id,
    required this.idKategori,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
  });

  factory BinwasItem.fromJson(Map<String, dynamic> json) {
    return BinwasItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      idKategori: json['id_kategori'] is int ? json['id_kategori'] : int.tryParse(json['id_kategori'].toString()) ?? 0,
      deskripsiTemuan: json['deskripsi_temuan'] ?? '',
      objekKonservasi: json['objek_konservasi'] ?? 'Administrasi',
    );
  }
}

class BinwasFindingEntry {
  String keteranganLapangan;
  String rekomendasi;

  BinwasFindingEntry({
    this.keteranganLapangan = '',
    this.rekomendasi = '',
  });
}

class BinwasInspeksiItemInput {
  static const List<String> kDaftarObjekKonservasi = [
    'Recovery Penambangan',
    'Recovery Pengolahan',
    'Batubara Kualitas Rendah',
    'Mineral Kadar Rendah',
    'Mineral Ikutan',
    'Cadangan Marginal',
    'Cadangan Tidak Tertambang',
    'Sisa Hasil Pengolahan',
    'Dilusi dan Losses',
  ];

  final int idItemTemuan;
  final int idKategori;
  final String deskripsiTemuan;
  final String objekKonservasi;
  bool adaTemuan;
  String keteranganLapangan;
  String rekomendasi;
  String fotoTemuan;
  List<String> selectedObjekKonservasi;
  List<BinwasFindingEntry> entries;

  BinwasInspeksiItemInput({
    required this.idItemTemuan,
    required this.idKategori,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
    this.adaTemuan = false,
    this.keteranganLapangan = '',
    this.rekomendasi = '',
    this.fotoTemuan = '',
    List<String>? selectedObjekKonservasi,
    List<BinwasFindingEntry>? entries,
  })  : selectedObjekKonservasi = selectedObjekKonservasi ??
            (kDaftarObjekKonservasi.contains(objekKonservasi) ? [objekKonservasi] : []),
        entries = entries ?? [BinwasFindingEntry(keteranganLapangan: keteranganLapangan, rekomendasi: rekomendasi)];

  Map<String, dynamic> toJson() {
    final objekStr = selectedObjekKonservasi.isNotEmpty
        ? selectedObjekKonservasi.join(', ')
        : objekKonservasi;

    return {
      'id_item_temuan': idItemTemuan,
      'id_kategori': idKategori,
      'ada_temuan': adaTemuan ? 1 : 0,
      'keterangan_lapangan': entries.isNotEmpty ? entries.first.keteranganLapangan : keteranganLapangan,
      'rekomendasi': entries.isNotEmpty ? entries.first.rekomendasi : rekomendasi,
      'foto_temuan': fotoTemuan,
      'objek_konservasi': objekStr,
    };
  }

  List<Map<String, dynamic>> toEntriesJson() {
    final objekStr = selectedObjekKonservasi.isNotEmpty
        ? selectedObjekKonservasi.join(', ')
        : objekKonservasi;

    if (!adaTemuan) {
      return [
        {
          'id_item_temuan': idItemTemuan,
          'id_kategori': idKategori,
          'ada_temuan': 0,
          'keterangan_lapangan': '',
          'rekomendasi': '',
          'foto_temuan': '',
          'objek_konservasi': objekStr,
        }
      ];
    }

    final valid = entries
        .where((e) => e.keteranganLapangan.trim().isNotEmpty || e.rekomendasi.trim().isNotEmpty)
        .toList();

    if (valid.isEmpty) {
      return [
        {
          'id_item_temuan': idItemTemuan,
          'id_kategori': idKategori,
          'ada_temuan': 1,
          'keterangan_lapangan': '',
          'rekomendasi': '',
          'foto_temuan': '',
          'objek_konservasi': objekStr,
        }
      ];
    }

    return valid.map((e) {
      return {
        'id_item_temuan': idItemTemuan,
        'id_kategori': idKategori,
        'ada_temuan': 1,
        'keterangan_lapangan': e.keteranganLapangan.trim(),
        'rekomendasi': e.rekomendasi.trim(),
        'foto_temuan': '',
        'objek_konservasi': objekStr,
      };
    }).toList();
  }
}

class BinwasInspeksiRecord {
  final int id;
  final String tipeKomoditas;
  final int idPerusahaan;
  final String namaPerusahaan;
  final String namaProvinsi;
  final String jenisIzin;
  final String namaPetugas;
  final String tanggalInspeksi;
  final String triwulan;
  final int tahun;
  final int totalTemuan;
  final String status;
  final String? catatanUmum;
  final List<BinwasItemDetail> items;

  BinwasInspeksiRecord({
    required this.id,
    required this.tipeKomoditas,
    required this.idPerusahaan,
    required this.namaPerusahaan,
    required this.namaProvinsi,
    required this.jenisIzin,
    required this.namaPetugas,
    required this.tanggalInspeksi,
    required this.triwulan,
    required this.tahun,
    required this.totalTemuan,
    required this.status,
    this.catatanUmum,
    this.items = const [],
  });

  factory BinwasInspeksiRecord.fromJson(Map<String, dynamic> json) {
    return BinwasInspeksiRecord(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      tipeKomoditas: json['tipe_komoditas'] ?? 'batubara',
      idPerusahaan: json['id_perusahaan'] is int ? json['id_perusahaan'] : int.tryParse(json['id_perusahaan'].toString()) ?? 0,
      namaPerusahaan: json['nama_perusahaan'] ?? '-',
      namaProvinsi: json['nama_provinsi'] ?? '-',
      jenisIzin: json['jenis_izin'] ?? '-',
      namaPetugas: json['nama_petugas'] ?? '-',
      tanggalInspeksi: json['tanggal_inspeksi'] ?? '-',
      triwulan: json['triwulan'] ?? '-',
      tahun: json['tahun'] is int ? json['tahun'] : int.tryParse(json['tahun'].toString()) ?? 2026,
      totalTemuan: json['total_temuan'] is int ? json['total_temuan'] : int.tryParse(json['total_temuan'].toString()) ?? 0,
      status: json['status'] ?? 'Submitted',
      catatanUmum: json['catatan_umum'],
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BinwasItemDetail.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class BinwasItemDetail {
  final int id;
  final int idItemTemuan;
  final String namaKategori;
  final String deskripsiTemuan;
  final String objekKonservasi;
  final bool adaTemuan;
  final String keteranganLapangan;
  final String rekomendasi;
  final String fotoTemuan;
  final String statusTindakan; // 'Belum', 'Sedang Dilakukan', 'Sudah'
  final String langkahTemuan; // Uraian tindakan penanganan temuan
  final String? nomorSurat; // Nomor surat dasar tindakan
  final String? tanggalSurat;
  final String? fileSurat; // File surat (PDF / Gambar)
  final String? petugasTindakLanjut;

  BinwasItemDetail({
    required this.id,
    required this.idItemTemuan,
    required this.namaKategori,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
    required this.adaTemuan,
    required this.keteranganLapangan,
    required this.rekomendasi,
    required this.fotoTemuan,
    this.statusTindakan = 'Belum',
    this.langkahTemuan = '',
    this.nomorSurat,
    this.tanggalSurat,
    this.fileSurat,
    this.petugasTindakLanjut,
  });

  factory BinwasItemDetail.fromJson(Map<String, dynamic> json) {
    return BinwasItemDetail(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      idItemTemuan: json['id_item_temuan'] is int ? json['id_item_temuan'] : int.tryParse(json['id_item_temuan'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
      deskripsiTemuan: json['deskripsi_temuan'] ?? '',
      objekKonservasi: json['objek_konservasi'] ?? '',
      adaTemuan: json['ada_temuan'] == true || json['ada_temuan'] == 1 || json['ada_temuan'] == '1',
      keteranganLapangan: json['keterangan_lapangan'] ?? '',
      rekomendasi: json['rekomendasi'] ?? '',
      fotoTemuan: json['foto_temuan'] ?? '',
      statusTindakan: json['status_tindakan']?.toString() ?? 'Belum',
      langkahTemuan: json['langkah_temuan']?.toString() ?? '',
      nomorSurat: json['nomor_surat']?.toString(),
      tanggalSurat: json['tanggal_surat']?.toString(),
      fileSurat: json['file_surat']?.toString(),
      petugasTindakLanjut: json['petugas_tindak_lanjut']?.toString(),
    );
  }
}

class BinwasDashboardData {
  final int totalInspeksi;
  final int totalPerusahaan;
  final int totalTemuan;
  final double rataRataTemuan;
  final List<BinwasRekapKategori> rekapKategori;
  final List<BinwasRekapObjek> rekapObjekKonservasi;
  final List<BinwasRekapKomoditas> rekapKomoditas;
  final List<BinwasTopTemuan> topTemuan;

  BinwasDashboardData({
    required this.totalInspeksi,
    required this.totalPerusahaan,
    required this.totalTemuan,
    required this.rataRataTemuan,
    required this.rekapKategori,
    required this.rekapObjekKonservasi,
    this.rekapKomoditas = const [],
    required this.topTemuan,
  });

  factory BinwasDashboardData.fromJson(Map<String, dynamic> json) {
    final sum = json['summary'] as Map<String, dynamic>? ?? {};
    return BinwasDashboardData(
      totalInspeksi: sum['total_inspeksi'] is int ? sum['total_inspeksi'] : int.tryParse(sum['total_inspeksi'].toString()) ?? 0,
      totalPerusahaan: sum['total_perusahaan'] is int ? sum['total_perusahaan'] : int.tryParse(sum['total_perusahaan'].toString()) ?? 0,
      totalTemuan: sum['total_temuan'] is int ? sum['total_temuan'] : int.tryParse(sum['total_temuan'].toString()) ?? 0,
      rataRataTemuan: (sum['rata_rata_temuan'] as num?)?.toDouble() ?? 0.0,
      rekapKategori: (json['rekap_kategori'] as List<dynamic>?)
              ?.map((item) => BinwasRekapKategori.fromJson(item))
              .toList() ??
          [],
      rekapObjekKonservasi: (json['rekap_objek_konservasi'] as List<dynamic>?)
              ?.map((item) => BinwasRekapObjek.fromJson(item))
              .toList() ??
          [],
      rekapKomoditas: (json['rekap_komoditas'] as List<dynamic>?)
              ?.map((item) => BinwasRekapKomoditas.fromJson(item))
              .toList() ??
          [],
      topTemuan: (json['top_temuan'] as List<dynamic>?)
              ?.map((item) => BinwasTopTemuan.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class BinwasRekapKategori {
  final int idKategori;
  final String namaKategori;
  final int jumlahTemuan;
  final double persentase;

  BinwasRekapKategori({
    required this.idKategori,
    required this.namaKategori,
    required this.jumlahTemuan,
    required this.persentase,
  });

  factory BinwasRekapKategori.fromJson(Map<String, dynamic> json) {
    return BinwasRekapKategori(
      idKategori: json['id_kategori'] is int ? json['id_kategori'] : int.tryParse(json['id_kategori'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
      jumlahTemuan: json['jumlah_temuan'] is int ? json['jumlah_temuan'] : int.tryParse(json['jumlah_temuan'].toString()) ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BinwasRekapObjek {
  final String objekKonservasi;
  final int jumlahTemuan;
  final double persentase;

  BinwasRekapObjek({
    required this.objekKonservasi,
    required this.jumlahTemuan,
    required this.persentase,
  });

  factory BinwasRekapObjek.fromJson(Map<String, dynamic> json) {
    return BinwasRekapObjek(
      objekKonservasi: json['objek_konservasi'] ?? '',
      jumlahTemuan: json['jumlah_temuan'] is int ? json['jumlah_temuan'] : int.tryParse(json['jumlah_temuan'].toString()) ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BinwasRekapKomoditas {
  final String namaKomoditas;
  final int jumlahTemuan;
  final double persentase;

  BinwasRekapKomoditas({
    required this.namaKomoditas,
    required this.jumlahTemuan,
    required this.persentase,
  });

  factory BinwasRekapKomoditas.fromJson(Map<String, dynamic> json) {
    return BinwasRekapKomoditas(
      namaKomoditas: json['nama_komoditas']?.toString() ?? 'Lainnya',
      jumlahTemuan: json['jumlah_temuan'] is int
          ? json['jumlah_temuan']
          : int.tryParse(json['jumlah_temuan'].toString()) ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BinwasTopTemuan {
  final int id;
  final String deskripsiTemuan;
  final String objekKonservasi;
  final String namaKategori;
  final int totalPelanggaran;

  BinwasTopTemuan({
    required this.id,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
    required this.namaKategori,
    required this.totalPelanggaran,
  });

  factory BinwasTopTemuan.fromJson(Map<String, dynamic> json) {
    return BinwasTopTemuan(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      deskripsiTemuan: json['deskripsi_temuan'] ?? '',
      objekKonservasi: json['objek_konservasi'] ?? '',
      namaKategori: json['nama_kategori'] ?? '',
      totalPelanggaran: json['total_pelanggaran'] is int ? json['total_pelanggaran'] : int.tryParse(json['total_pelanggaran'].toString()) ?? 0,
    );
  }
}

class BinwasMatrixCategorySummary {
  final int idKategori;
  final String namaKategori;
  final int totalTemuan;
  final int jumlahButir;
  final double persentase;
  final Map<String, int> scores;

  BinwasMatrixCategorySummary({
    required this.idKategori,
    required this.namaKategori,
    required this.totalTemuan,
    required this.jumlahButir,
    required this.persentase,
    required this.scores,
  });

  factory BinwasMatrixCategorySummary.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    final scores = rawScores.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0));
    return BinwasMatrixCategorySummary(
      idKategori: json['id_kategori'] is int ? json['id_kategori'] : int.tryParse(json['id_kategori'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
      totalTemuan: json['total_temuan'] is int ? json['total_temuan'] : int.tryParse(json['total_temuan'].toString()) ?? 0,
      jumlahButir: json['jumlah_butir'] is int ? json['jumlah_butir'] : int.tryParse(json['jumlah_butir'].toString()) ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
      scores: scores,
    );
  }
}

class BinwasMatrixData {
  final int totalPerusahaan;
  final int grandTotal;
  final Map<String, int> companyTotals;
  final List<BinwasMatrixCategorySummary> rekapKategori;
  final List<BinwasMatrixColumn> columns;
  final List<BinwasMatrixRow> rows;

  BinwasMatrixData({
    required this.totalPerusahaan,
    this.grandTotal = 0,
    this.companyTotals = const {},
    this.rekapKategori = const [],
    required this.columns,
    required this.rows,
  });

  factory BinwasMatrixData.fromJson(Map<String, dynamic> json) {
    final columns = (json['columns'] as List<dynamic>?)
            ?.map((item) => BinwasMatrixColumn.fromJson(item))
            .toList() ??
        [];
    final rows = (json['rows'] as List<dynamic>?)
            ?.map((item) => BinwasMatrixRow.fromJson(item))
            .toList() ??
        [];

    // Parse backend rekap_kategori if available
    List<BinwasMatrixCategorySummary> rekapKategori = [];
    if (json['rekap_kategori'] is List && (json['rekap_kategori'] as List).isNotEmpty) {
      rekapKategori = (json['rekap_kategori'] as List<dynamic>)
          .map((item) => BinwasMatrixCategorySummary.fromJson(item))
          .toList();
    } else {
      // Client-side fallback calculation
      final Map<int, String> catNames = {};
      final Map<int, Map<String, int>> catScores = {};
      final Map<int, int> catCounts = {};
      final Map<int, int> catItemCounts = {};

      for (var r in rows) {
        catNames[r.idKategori] = r.namaKategori;
        catCounts[r.idKategori] = (catCounts[r.idKategori] ?? 0) + r.jumlah;
        catItemCounts[r.idKategori] = (catItemCounts[r.idKategori] ?? 0) + 1;
        catScores.putIfAbsent(r.idKategori, () => {});
        for (var entry in r.scores.entries) {
          if (entry.value == 1) {
            catScores[r.idKategori]![entry.key] = (catScores[r.idKategori]![entry.key] ?? 0) + 1;
          }
        }
      }

      int computedGrandTotal = 0;
      for (var r in rows) {
        computedGrandTotal += r.jumlah;
      }

      catNames.forEach((catId, catName) {
        final totalKat = catCounts[catId] ?? 0;
        final pct = computedGrandTotal > 0 ? (totalKat * 100.0) / computedGrandTotal : 0.0;
        rekapKategori.add(BinwasMatrixCategorySummary(
          idKategori: catId,
          namaKategori: catName,
          totalTemuan: totalKat,
          jumlahButir: catItemCounts[catId] ?? 0,
          persentase: pct,
          scores: catScores[catId] ?? {},
        ));
      });
    }

    // Company totals
    Map<String, int> companyTotals = {};
    if (json['company_totals'] is Map) {
      final rawTotals = json['company_totals'] as Map<String, dynamic>;
      companyTotals = rawTotals.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0));
    } else {
      for (var c in columns) {
        int cTotal = 0;
        for (var r in rows) {
          if ((r.scores[c.idInspeksi.toString()] ?? 0) == 1) {
            cTotal++;
          }
        }
        companyTotals[c.idInspeksi.toString()] = cTotal;
      }
    }

    int grandTotal = 0;
    if (json['grand_total'] != null) {
      grandTotal = json['grand_total'] is int ? json['grand_total'] : int.tryParse(json['grand_total'].toString()) ?? 0;
    } else {
      for (var r in rows) {
        grandTotal += r.jumlah;
      }
    }

    return BinwasMatrixData(
      totalPerusahaan: json['total_perusahaan'] is int
          ? json['total_perusahaan']
          : int.tryParse(json['total_perusahaan'].toString()) ?? columns.length,
      grandTotal: grandTotal,
      companyTotals: companyTotals,
      rekapKategori: rekapKategori,
      columns: columns,
      rows: rows,
    );
  }
}

class BinwasMatrixColumn {
  final int idInspeksi;
  final String namaPerusahaan;
  final String tipeKomoditas;
  final int totalTemuan;
  final String tanggalInspeksi;

  BinwasMatrixColumn({
    required this.idInspeksi,
    required this.namaPerusahaan,
    required this.tipeKomoditas,
    required this.totalTemuan,
    required this.tanggalInspeksi,
  });

  factory BinwasMatrixColumn.fromJson(Map<String, dynamic> json) {
    return BinwasMatrixColumn(
      idInspeksi: json['id_inspeksi'] is int ? json['id_inspeksi'] : int.tryParse(json['id_inspeksi'].toString()) ?? 0,
      namaPerusahaan: json['nama_perusahaan'] ?? '',
      tipeKomoditas: json['tipe_komoditas'] ?? '',
      totalTemuan: json['total_temuan'] is int ? json['total_temuan'] : int.tryParse(json['total_temuan'].toString()) ?? 0,
      tanggalInspeksi: json['tanggal_inspeksi'] ?? '',
    );
  }
}

class BinwasMatrixRow {
  final int idItem;
  final int idKategori;
  final String namaKategori;
  final String deskripsiTemuan;
  final String objekKonservasi;
  final Map<String, int> scores;
  final int jumlah;
  final double persentase;

  BinwasMatrixRow({
    required this.idItem,
    required this.idKategori,
    required this.namaKategori,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
    required this.scores,
    required this.jumlah,
    required this.persentase,
  });

  factory BinwasMatrixRow.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    final scores = rawScores.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0));
    return BinwasMatrixRow(
      idItem: json['id_item'] is int ? json['id_item'] : int.tryParse(json['id_item'].toString()) ?? 0,
      idKategori: json['id_kategori'] is int ? json['id_kategori'] : int.tryParse(json['id_kategori'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
      deskripsiTemuan: json['deskripsi_temuan'] ?? '',
      objekKonservasi: json['objek_konservasi'] ?? '',
      scores: scores,
      jumlah: json['jumlah'] is int ? json['jumlah'] : int.tryParse(json['jumlah'].toString()) ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BinwasLaporanKhususItem {
  final int idDetail;
  final String temuan;
  final String rekomendasi;
  final String kategori;
  final String objekKonservasi;
  final String objekKategori;
  String status; // 'Memadai', 'Belum Memadai', 'On Progress'
  String catatanEvaluasi;
  final String fotoTemuan;

  BinwasLaporanKhususItem({
    required this.idDetail,
    required this.temuan,
    required this.rekomendasi,
    required this.kategori,
    required this.objekKonservasi,
    required this.objekKategori,
    this.status = 'On Progress',
    this.catatanEvaluasi = '',
    this.fotoTemuan = '',
  });

  factory BinwasLaporanKhususItem.fromJson(Map<String, dynamic> json) {
    return BinwasLaporanKhususItem(
      idDetail: json['id_detail'] is int ? json['id_detail'] : int.tryParse(json['id_detail'].toString()) ?? 0,
      temuan: json['temuan'] ?? '',
      rekomendasi: json['rekomendasi'] ?? '-',
      kategori: json['kategori'] ?? '',
      objekKonservasi: json['objek_konservasi'] ?? '',
      objekKategori: json['objek_kategori'] ?? '',
      status: json['status'] ?? 'On Progress',
      catatanEvaluasi: json['catatan_evaluasi'] ?? '',
      fotoTemuan: json['foto_temuan'] ?? '',
    );
  }
}

class BinwasLaporanKhusus {
  final int idInspeksi;
  final String namaPetugas;
  final String perusahaan;
  final int idPerusahaan;
  final String komoditas;
  final String tanggalBinwas;
  final String triwulan;
  final int tahun;
  final String namaProvinsi;
  final int totalTemuan;
  final List<BinwasLaporanKhususItem> items;

  BinwasLaporanKhusus({
    required this.idInspeksi,
    required this.namaPetugas,
    required this.perusahaan,
    required this.idPerusahaan,
    required this.komoditas,
    required this.tanggalBinwas,
    required this.triwulan,
    required this.tahun,
    required this.namaProvinsi,
    required this.totalTemuan,
    required this.items,
  });

  factory BinwasLaporanKhusus.fromJson(Map<String, dynamic> json) {
    return BinwasLaporanKhusus(
      idInspeksi: json['id_inspeksi'] is int ? json['id_inspeksi'] : int.tryParse(json['id_inspeksi'].toString()) ?? 0,
      namaPetugas: json['nama_petugas'] ?? '',
      perusahaan: json['perusahaan'] ?? '',
      idPerusahaan: json['id_perusahaan'] is int ? json['id_perusahaan'] : int.tryParse(json['id_perusahaan'].toString()) ?? 0,
      komoditas: json['komoditas'] ?? '',
      tanggalBinwas: json['tanggal_binwas'] ?? '',
      triwulan: json['triwulan'] ?? '',
      tahun: json['tahun'] is int ? json['tahun'] : int.tryParse(json['tahun'].toString()) ?? 0,
      namaProvinsi: json['nama_provinsi'] ?? '',
      totalTemuan: json['total_temuan'] is int ? json['total_temuan'] : int.tryParse(json['total_temuan'].toString()) ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BinwasLaporanKhususItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

