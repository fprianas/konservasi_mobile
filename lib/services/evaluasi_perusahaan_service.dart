import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/evaluasi_perusahaan_model.dart';

class EvaluasiPerusahaanService {
  // Daftar endpoint dengan auto-fallback (prioritas /v2/mineral/ sesuai lokasi file di server)
  static const List<String> baseUrls = [
    'https://laporan-minerba.my.id/v2/mineral/api_evaluasi_produksi.php',
    'https://laporan-minerba.my.id/v2/api_evaluasi_produksi.php',
  ];

  static final http.Client _client = http.Client();

  static const List<String> kDefaultPetugas = [
    'Aryanti',
    'Alpon',
    'Dody',
    'Rozy',
    'A.Suryanti',
    'Nyke',
    'Marthin',
    'Rangga',
    'Hastomo',
    'Zakie',
    'Reny',
    'Putu',
    'Ilham',
    'Sari',
  ];

  /// Helper HTTP GET dengan auto-fallback jika endpoint pertama 404
  static Future<http.Response> _getWithFallback(Map<String, String> query) async {
    http.Response? lastResponse;
    for (final url in baseUrls) {
      try {
        final uri = Uri.parse(url).replace(queryParameters: query);
        final res = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode != 404) {
          return res;
        }
        lastResponse = res;
      } catch (_) {}
    }
    return lastResponse ?? http.Response('{"success":false,"message":"Network error"}', 500);
  }

  /// Helper HTTP POST dengan auto-fallback jika endpoint pertama 404
  static Future<http.Response> _postWithFallback(Map<String, String> query, Object body) async {
    http.Response? lastResponse;
    for (final url in baseUrls) {
      try {
        final uri = Uri.parse(url).replace(queryParameters: query);
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode != 404) {
          return res;
        }
        lastResponse = res;
      } catch (_) {}
    }
    return lastResponse ?? http.Response('{"success":false,"message":"Network error"}', 500);
  }

  /// Helper pembuat kunci lookup evaluasi per periode (perusahaan + tahun + triwulan)
  static String buildKey(String namaPerusahaan, [dynamic tahun, String? triwulan]) {
    final p = namaPerusahaan.trim().toLowerCase();
    final t = (tahun != null && tahun.toString().isNotEmpty && tahun.toString() != '0')
        ? tahun.toString().trim()
        : '';
    final q = (triwulan != null && triwulan.trim().isNotEmpty)
        ? triwulan.trim().toLowerCase()
        : '';
    if (t.isNotEmpty && q.isNotEmpty) {
      return '$p|$t|$q';
    } else if (t.isNotEmpty) {
      return '$p|$t';
    }
    return p;
  }

  /// Mengambil daftar petugas untuk dropdown
  static Future<List<String>> fetchPetugasList() async {
    try {
      final res = await _getWithFallback({
        'action': 'get_petugas_evaluasi_list',
      });
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] is List) {
          final List<String> list = (json['data'] as List).map((e) => e.toString().trim()).toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}
    return kDefaultPetugas;
  }

  /// Mengambil seluruh data evaluasi perusahaan (opsional filter tipe, tahun, triwulan)
  static Future<List<EvaluasiPerusahaanItem>> fetchEvaluasiList({
    String? tipe,
    dynamic tahun,
    String? triwulan,
  }) async {
    final Map<String, String> query = {'action': 'get_evaluasi_perusahaan_list'};
    if (tipe != null && tipe.isNotEmpty && tipe != 'semua') {
      query['tipe'] = tipe;
    }
    if (tahun != null && tahun.toString().isNotEmpty && tahun.toString() != '0' && tahun.toString() != 'semua') {
      query['tahun'] = tahun.toString();
    }
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') {
      query['triwulan'] = triwulan;
    }

    try {
      final res = await _getWithFallback(query);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] is List) {
          return (json['data'] as List).map((e) => EvaluasiPerusahaanItem.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Mengambil map evaluasi keyed by nama_perusahaan dan periode (perusahaan|tahun|triwulan)
  static Future<Map<String, EvaluasiPerusahaanItem>> fetchEvaluasiMap({
    String? tipe,
    dynamic tahun,
    String? triwulan,
  }) async {
    final list = await fetchEvaluasiList(tipe: tipe, tahun: tahun, triwulan: triwulan);
    final Map<String, EvaluasiPerusahaanItem> map = {};
    for (final item in list) {
      final baseKey = item.namaPerusahaan.trim().toLowerCase();
      if (baseKey.isNotEmpty) {
        // Simpan kunci spesifik periode
        final periodKey = buildKey(item.namaPerusahaan, item.tahun, item.triwulan);
        map[periodKey] = item;

        // Fallback kunci umum perusahaan (menyimpan evaluasi terbaru)
        if (!map.containsKey(baseKey)) {
          map[baseKey] = item;
        }
      }
    }
    return map;
  }

  /// Mengambil evaluasi untuk 1 perusahaan (opsional spesifik tahun dan triwulan)
  static Future<EvaluasiPerusahaanItem?> fetchEvaluasiByPerusahaan(
    String namaPerusahaan, {
    dynamic tahun,
    String? triwulan,
  }) async {
    try {
      final Map<String, String> query = {
        'action': 'get_evaluasi_perusahaan',
        'nama_perusahaan': namaPerusahaan.trim(),
      };
      if (tahun != null && tahun.toString().isNotEmpty && tahun.toString() != '0' && tahun.toString() != 'semua') {
        query['tahun'] = tahun.toString();
      }
      if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') {
        query['triwulan'] = triwulan;
      }

      final res = await _getWithFallback(query);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] != null) {
          return EvaluasiPerusahaanItem.fromJson(json['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Menyimpan atau mengupdate evaluasi perusahaan
  static Future<EvaluasiPerusahaanItem> saveEvaluasi(Map<String, dynamic> data) async {
    final res = await _postWithFallback(
      {'action': 'save_evaluasi_perusahaan'},
      data,
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return EvaluasiPerusahaanItem.fromJson(json['data']);
      }
      throw Exception(json['message'] ?? 'Gagal menyimpan evaluasi');
    }
    throw Exception('Server error: ${res.statusCode}');
  }

  /// Menghapus evaluasi dengan kode rahasia PIN 3636
  static Future<bool> deleteEvaluasi({
    int? id,
    String? namaPerusahaan,
    String pin = '3636',
  }) async {
    final res = await _postWithFallback(
      {'action': 'delete_evaluasi_perusahaan'},
      {
        if (id != null && id > 0) 'id': id,
        if (namaPerusahaan != null && namaPerusahaan.isNotEmpty) 'nama_perusahaan': namaPerusahaan,
        'pin': pin,
      },
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true) return true;
      throw Exception(json['message'] ?? 'Kode Salah');
    }
    throw Exception('Server error: ${res.statusCode}');
  }
}

