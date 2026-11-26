import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class CompanyStatusItem {
  final int id;
  final String namaPerusahaan;
  final String skIup;
  final String provinsi;
  final String jenisIzin;
  final String komoditas;
  final bool isActive;
  final ReportType type;

  const CompanyStatusItem({
    required this.id,
    required this.namaPerusahaan,
    required this.skIup,
    required this.provinsi,
    required this.jenisIzin,
    required this.komoditas,
    required this.isActive,
    required this.type,
  });

  factory CompanyStatusItem.fromJson(Map<String, dynamic> json, ReportType defaultType) {
    final sektorStr = json['sektor']?.toString().toLowerCase() ?? '';
    final type = sektorStr == 'mineral'
        ? ReportType.mineral
        : (sektorStr == 'batubara' ? ReportType.batubara : defaultType);
    final rawActive = json['is_active'];
    final active = rawActive == null
        ? true
        : (rawActive == true || rawActive == 1 || rawActive.toString() == '1' || rawActive.toString().toLowerCase() == 'true');

    return CompanyStatusItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '-',
      skIup: json['sk_iup']?.toString() ?? '-',
      provinsi: json['provinsi']?.toString() ?? '-',
      jenisIzin: json['jenis_izin']?.toString() ?? '-',
      komoditas: json['komoditas']?.toString() ?? '-',
      isActive: active,
      type: type,
    );
  }

  CompanyStatusItem copyWith({bool? isActive}) {
    return CompanyStatusItem(
      id: id,
      namaPerusahaan: namaPerusahaan,
      skIup: skIup,
      provinsi: provinsi,
      jenisIzin: jenisIzin,
      komoditas: komoditas,
      isActive: isActive ?? this.isActive,
      type: type,
    );
  }
}

class CompanyStatusListResult {
  final List<CompanyStatusItem> items;
  final int total;
  final int aktif;
  final int nonaktif;

  const CompanyStatusListResult({
    required this.items,
    required this.total,
    required this.aktif,
    required this.nonaktif,
  });
}

class CompanyStatusService {
  static Future<CompanyStatusListResult> fetchCompanies({
    required ReportType type,
    String query = '',
    String status = 'semua',
    String provinsi = 'semua',
    int limit = 500,
  }) async {
    final baseUrl = ApiService.getBaseUrl(type);
    final params = <String, String>{
      'action': 'companies_status',
      'status': status,
      'limit': limit.toString(),
    };
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (provinsi.trim().isNotEmpty && provinsi != 'semua') params['provinsi'] = provinsi;

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri).timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Server mengembalikan status ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Gagal memuat daftar status perusahaan');
    }

    final list = (decoded['data'] as List? ?? [])
        .map((e) => CompanyStatusItem.fromJson(Map<String, dynamic>.from(e), type))
        .toList();
    final sum = decoded['summary'] as Map<String, dynamic>? ?? {};

    return CompanyStatusListResult(
      items: list,
      total: (sum['total'] as num?)?.toInt() ?? list.length,
      aktif: (sum['aktif'] as num?)?.toInt() ?? list.where((e) => e.isActive).length,
      nonaktif: (sum['nonaktif'] as num?)?.toInt() ?? list.where((e) => !e.isActive).length,
    );
  }

  static Future<bool> toggleStatus({
    required ReportType type,
    int? id,
    String? skIup,
    String? namaPerusahaan,
    required bool isActive,
    String pin = '3636',
  }) async {
    final baseUrl = ApiService.getBaseUrl(type);
    final uri = Uri.parse('$baseUrl?action=toggle_company_status');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (id != null && id > 0) 'id': id,
            if (skIup != null && skIup.isNotEmpty) 'sk_iup': skIup,
            if (namaPerusahaan != null && namaPerusahaan.isNotEmpty) 'nama_perusahaan': namaPerusahaan,
            'is_active': isActive ? 1 : 0,
            'pin': pin,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Gagal memperbarui status perusahaan');
    }
    return decoded['is_active'] == true;
  }
}

