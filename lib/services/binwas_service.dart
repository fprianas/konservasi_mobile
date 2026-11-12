import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/binwas_model.dart';

class BinwasService {
  static const String baseUrl = 'https://laporan-minerba.my.id/v2/api_binwas.php';
  static final http.Client _client = http.Client();

  // In-memory cache for master temuan
  static List<BinwasCategory>? _cachedCategories;

  // 1. Ambil Opsi Filter Binwas
  static Future<Map<String, dynamic>> fetchFilters(String tipe) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': 'get_filters',
      'tipe': tipe,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return json['data'] as Map<String, dynamic>;
      }
    }
    return {'provinsi': [], 'jenis_izin': [], 'komoditas': [], 'triwulan': [], 'tahun': []};
  }

  // 2. Pencarian Perusahaan Target
  static Future<List<Map<String, dynamic>>> searchCompanies({
    required String tipe,
    String? q,
    String? idProvinsi,
    String? namaProvinsi,
    String? jenisIzin,
    String? komoditas,
  }) async {
    final Map<String, String> query = {
      'action': 'search_companies',
      'tipe': tipe,
    };
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (idProvinsi != null && idProvinsi.isNotEmpty && idProvinsi != 'semua') {
      query['id_provinsi'] = idProvinsi;
    }
    if (namaProvinsi != null && namaProvinsi.isNotEmpty && namaProvinsi != 'semua') {
      query['nama_provinsi'] = namaProvinsi;
    }
    if (jenisIzin != null && jenisIzin.isNotEmpty && jenisIzin != 'semua') {
      query['jenis_izin'] = jenisIzin;
    }
    if (komoditas != null && komoditas.isNotEmpty && komoditas != 'semua') {
      query['komoditas'] = komoditas;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return (json['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // 3. Ambil Master Butir Temuan
  static Future<List<BinwasCategory>> fetchMasterTemuan({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _cachedCategories!.isNotEmpty) {
      return _cachedCategories!;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'get_master_temuan'});
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        final list = (json['data'] as List<dynamic>)
            .map((item) => BinwasCategory.fromJson(item))
            .toList();
        _cachedCategories = list;
        return list;
      }
    }
    throw Exception('Gagal memuat master butir temuan');
  }

  // 4. Submit Hasil Inspeksi Lapangan
  static Future<Map<String, dynamic>> submitInspeksi(Map<String, dynamic> data) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'submit_inspeksi'});
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return json;
      }
      throw Exception(json['message'] ?? 'Gagal menyimpan inspeksi');
    } else {
      throw Exception('Server error: ${res.statusCode}');
    }
  }

  // 4b. Update / Koreksi Hasil Inspeksi Lapangan
  static Future<Map<String, dynamic>> updateInspeksi(Map<String, dynamic> data) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'update_inspeksi'});
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return json;
      }
      throw Exception(json['message'] ?? 'Gagal memperbarui inspeksi');
    } else {
      throw Exception('Server error: ${res.statusCode}');
    }
  }

  // 4c. Hapus Data Hasil Inspeksi Lapangan (Pusat & Provinsi)
  static Future<Map<String, dynamic>> deleteInspeksi(int idInspeksi, String pin) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'delete_inspeksi'});
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_inspeksi': idInspeksi,
            'pin': pin,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return json;
      }
      throw Exception(json['message'] ?? 'Gagal menghapus data inspeksi');
    } else {
      try {
        final json = jsonDecode(res.body);
        throw Exception(json['message'] ?? 'Server error: ${res.statusCode}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Server error: ${res.statusCode}');
      }
    }
  }

  // 5. Ambil Riwayat Inspeksi (Mendukung Filter Provinsi & Asal Input)
  static Future<List<BinwasInspeksiRecord>> fetchHistory({
    String? tipe,
    String? tahun,
    String? triwulan,
    String? q,
    String? provinsi,
    String? asalInput,
  }) async {
    final Map<String, String> query = {'action': 'get_history'};
    if (tipe != null && tipe.isNotEmpty && tipe != 'semua') query['tipe'] = tipe;
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') query['tahun'] = tahun;
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') query['triwulan'] = triwulan;
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') query['provinsi'] = provinsi;
    if (asalInput != null && asalInput.isNotEmpty && asalInput != 'semua') query['asal_input'] = asalInput;

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return (json['data'] as List<dynamic>)
            .map((item) => BinwasInspeksiRecord.fromJson(item))
            .toList();
      }
    }
    return [];
  }

  // 6. Ambil Detail 1 Inspeksi
  static Future<BinwasInspeksiRecord> fetchDetail(int id) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': 'get_detail',
      'id': id.toString(),
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return BinwasInspeksiRecord.fromJson(json['data']);
      }
      throw Exception(json['message'] ?? 'Data inspeksi tidak ditemukan');
    }
    throw Exception('Gagal menghubungi server: ${res.statusCode}');
  }

  // 7. Ambil Rekapitulasi Dashboard (Mendukung Filter Provinsi & Asal Input)
  static Future<BinwasDashboardData> fetchDashboard({
    String? tipe,
    String? tahun,
    String? triwulan,
    String? provinsi,
    String? asalInput,
  }) async {
    final Map<String, String> query = {'action': 'get_rekap'};
    if (tipe != null && tipe.isNotEmpty && tipe != 'semua') query['tipe'] = tipe;
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') query['tahun'] = tahun;
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') query['triwulan'] = triwulan;
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') query['provinsi'] = provinsi;
    if (asalInput != null && asalInput.isNotEmpty && asalInput != 'semua') query['asal_input'] = asalInput;

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return BinwasDashboardData.fromJson(json['data']);
      }
      throw Exception(json['message'] ?? 'Gagal memuat rekapitulasi Binwas');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  // 8. Ambil Matriks Tabel Silang (Mendukung Filter Provinsi & Asal Input)
  static Future<BinwasMatrixData> fetchMatrix({
    String? tipe,
    String? tahun,
    String? triwulan,
    String? provinsi,
    String? asalInput,
  }) async {
    final Map<String, String> query = {'action': 'get_matrix'};
    if (tipe != null && tipe.isNotEmpty && tipe != 'semua') query['tipe'] = tipe;
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') query['tahun'] = tahun;
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') query['triwulan'] = triwulan;
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') query['provinsi'] = provinsi;
    if (asalInput != null && asalInput.isNotEmpty && asalInput != 'semua') query['asal_input'] = asalInput;

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return BinwasMatrixData.fromJson(json);
      }
      throw Exception(json['message'] ?? 'Gagal memuat matriks Binwas');
    }
    if (asalInput != null && res.statusCode != 200) {
      return fetchMatrix(tipe: tipe, tahun: tahun, triwulan: triwulan, provinsi: provinsi);
    }
    throw Exception('Server error: ${res.statusCode}');
  }


  // 10. URL file berkas (surat / foto dokumentasi)
  static String getFileUrl(String fileOrUrl) {
    final trimmed = fileOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://laporan-minerba.my.id/v2/uploads/binwas/${Uri.encodeComponent(trimmed)}';
  }

  // 11. Upload Surat Dasar Tindakan
  static Future<Map<String, dynamic>> uploadSurat({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'upload_surat'});
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'surat',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return json;
        }
        throw Exception(json['message'] ?? 'Gagal mengupload berkas surat');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Gagal upload surat: $e');
    }
  }

  // 12. Simpan Langkah Temuan / Tindak Lanjut
  static Future<bool> updateTindakLanjut({
    required int idInspeksi,
    required int idTemuanDetail,
    required String statusTindakan,
    required String langkahTemuan,
    String? nomorSurat,
    String? fileSurat,
    String? tanggalSurat,
    String? petugas,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'update_tindak_lanjut'});
    final body = jsonEncode({
      'id_inspeksi': idInspeksi,
      'id_temuan_detail': idTemuanDetail,
      'status_tindakan': statusTindakan,
      'langkah_temuan': langkahTemuan,
      'nomor_surat': nomorSurat ?? '',
      'file_surat': fileSurat ?? '',
      'tanggal_surat': tanggalSurat ?? DateTime.now().toIso8601String().substring(0, 10),
      'petugas': petugas ?? 'Petugas Binwas',
    });

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return true;
      }
      throw Exception(json['message'] ?? 'Gagal menyimpan tindak lanjut');
    }
    try {
      final json = jsonDecode(res.body);
      throw Exception(json['message'] ?? 'Server error: ${res.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Server error: ${res.statusCode}');
    }
  }

  // 12. Ambil Daftar Petugas Binwas untuk Filter
  static Future<List<String>> fetchPetugasList({String? asalInput}) async {
    try {
      final Map<String, String> query = {'action': 'get_petugas_list'};
      if (asalInput != null && asalInput.isNotEmpty && asalInput != 'semua') {
        query['asal_input'] = asalInput;
      }
      final uri = Uri.parse(baseUrl).replace(queryParameters: query);
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List<dynamic>).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // 13. Ambil Laporan Khusus Evaluasi Pembinaan & Pengawasan
  static Future<List<BinwasLaporanKhusus>> fetchLaporanKhusus({
    String? tahun,
    String? triwulan,
    String? namaPetugas,
    String? provinsi,
    String? asalInput,
    int? idPerusahaan,
    int? idInspeksi,
  }) async {
    final Map<String, String> query = {'action': 'get_laporan_khusus'};
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') query['tahun'] = tahun;
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') query['triwulan'] = triwulan;
    if (namaPetugas != null && namaPetugas.isNotEmpty && namaPetugas != 'semua') query['nama_petugas'] = namaPetugas;
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') query['provinsi'] = provinsi;
    if (asalInput != null && asalInput.isNotEmpty && asalInput != 'semua') query['asal_input'] = asalInput;
    if (idPerusahaan != null && idPerusahaan > 0) query['id_perusahaan'] = idPerusahaan.toString();
    if (idInspeksi != null && idInspeksi > 0) query['id_inspeksi'] = idInspeksi.toString();

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return (json['data'] as List<dynamic>)
            .map((item) => BinwasLaporanKhusus.fromJson(item))
            .toList();
      }
    }
    return [];
  }

  // 14. Update Status & Catatan Evaluasi Laporan Khusus
  static Future<bool> updateEvaluasi({
    required int idDetail,
    required String status,
    required String catatanEvaluasi,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'update_evaluasi'});
    final body = jsonEncode({
      'id_detail': idDetail,
      'status': status,
      'catatan_evaluasi': catatanEvaluasi,
    });

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        return true;
      }
      throw Exception(json['message'] ?? 'Gagal menyimpan tindak lanjut');
    }
    try {
      final json = jsonDecode(res.body);
      throw Exception(json['message'] ?? 'Server error: ${res.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Server error: ${res.statusCode}');
    }
  }
}
