import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/evaluasi_dokumen_model.dart';

class EvaluasiDokumenService {
  static const String baseUrl = 'https://laporan-minerba.my.id/v2/api_evaluasi.php';
  static final http.Client _client = http.Client();

  // -------------------------------------------------------------
  // SHEET RKPW (PERLUASAN WIUP / WIUPK)
  // -------------------------------------------------------------

  static Future<({List<EvaluasiRkpwItem> items, EvaluasiRkpwStats stats})> fetchRkpwList({
    String? q,
    String? tahun,
    String? status,
    String? jenisKomoditas,
    String? evaluator,
  }) async {
    final Map<String, String> query = {'action': 'get_rkpw_list'};
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') query['tahun'] = tahun;
    if (status != null && status.isNotEmpty && status != 'semua') query['status'] = status;
    if (jenisKomoditas != null && jenisKomoditas.isNotEmpty && jenisKomoditas != 'semua') {
      query['jenis_komoditas'] = jenisKomoditas;
    }
    if (evaluator != null && evaluator.isNotEmpty && evaluator != 'semua') {
      query['evaluator'] = evaluator;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        final List<dynamic> listRaw = json['data'] ?? [];
        final items = listRaw.map((e) => EvaluasiRkpwItem.fromJson(e)).toList();
        final stats = json['stats'] != null
            ? EvaluasiRkpwStats.fromJson(json['stats'])
            : const EvaluasiRkpwStats();
        return (items: items, stats: stats);
      }
    }
    return (items: <EvaluasiRkpwItem>[], stats: const EvaluasiRkpwStats());
  }

  static Future<bool> saveRkpw(Map<String, dynamic> data, {bool isEdit = false}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': isEdit ? 'update_rkpw' : 'create_rkpw',
    });

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) return true;
      throw Exception(json['message'] ?? 'Gagal menyimpan data RKPW');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  static Future<bool> deleteRkpw(int id, {String pin = '3636'}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'delete_rkpw'});
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'pin': pin}),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) return true;
      throw Exception(json['message'] ?? 'Gagal menghapus data RKPW');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> fetchRkpwFilters() async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'get_rkpw_filters'});
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'evaluator': <String>[],
      'komoditas': <String>[],
      'tahun': ['2026', '2025', '2024', '2023'],
      'status': ['Proses', 'Disetujui', 'Ditolak'],
      'jenis_komoditas': ['Mineral', 'Batubara'],
    };
  }

  // -------------------------------------------------------------
  // SHEET FS (STUDI KELAYAKAN BERTAHAP)
  // -------------------------------------------------------------

  static Future<({List<EvaluasiFsItem> items, EvaluasiFsStats stats})> fetchFsList({
    String? q,
    String? evaluator,
    String? komoditas,
    String? status,
  }) async {
    final Map<String, String> query = {'action': 'get_fs_list'};
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    if (evaluator != null && evaluator.isNotEmpty && evaluator != 'semua') {
      query['evaluator'] = evaluator;
    }
    if (komoditas != null && komoditas.isNotEmpty && komoditas != 'semua') {
      query['komoditas'] = komoditas;
    }
    if (status != null && status.isNotEmpty && status != 'semua') {
      query['status'] = status;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        final List<dynamic> listRaw = json['data'] ?? [];
        final items = listRaw.map((e) => EvaluasiFsItem.fromJson(e)).toList();
        final stats = json['stats'] != null
            ? EvaluasiFsStats.fromJson(json['stats'])
            : const EvaluasiFsStats();
        return (items: items, stats: stats);
      }
    }
    return (items: <EvaluasiFsItem>[], stats: const EvaluasiFsStats());
  }

  static Future<bool> saveFs(Map<String, dynamic> data, {bool isEdit = false}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': isEdit ? 'update_fs' : 'create_fs',
    });

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) return true;
      throw Exception(json['message'] ?? 'Gagal menyimpan data FS');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  static Future<bool> deleteFs(int id, {String pin = '3636'}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'delete_fs'});
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'pin': pin}),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) return true;
      throw Exception(json['message'] ?? 'Gagal menghapus data FS');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> fetchFsFilters() async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'action': 'get_fs_filters'});
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'evaluator': <String>[],
      'komoditas': <String>[],
      'status': ['Memadai', 'Belum Memadai', 'Proses'],
    };
  }
}

