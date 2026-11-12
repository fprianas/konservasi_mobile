import 'dart:convert';
import 'package:http/http.dart' as http;

class WilayahItem {
  final String id;
  final String name;

  const WilayahItem({required this.id, required this.name});

  factory WilayahItem.fromJson(Map<String, dynamic> json) {
    return WilayahItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  String get formattedName => WilayahService.toTitleCase(name);
}

class WilayahService {
  static const String _baseUrl = 'https://www.emsifa.com/api-wilayah-indonesia/api';
  static final http.Client _client = http.Client();

  // In-memory cache
  static List<WilayahItem>? _cachedProvinces;
  static final Map<String, List<WilayahItem>> _cachedRegencies = {};
  static final Map<String, List<WilayahItem>> _cachedDistricts = {};

  /// Convert string to Proper Title Case (e.g. "HALMAHERA SELATAN" -> "Halmahera Selatan")
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Khusus kata singkatan seperti IUP, D.I., DKI dll tetap
      if (word.toUpperCase() == 'DKI' || word.toUpperCase() == 'DI') {
        return word.toUpperCase();
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// 1. Ambil Semua Provinsi di Indonesia
  static Future<List<WilayahItem>> getProvinces() async {
    if (_cachedProvinces != null && _cachedProvinces!.isNotEmpty) {
      return _cachedProvinces!;
    }
    try {
      final uri = Uri.parse('$_baseUrl/provinces.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _cachedProvinces = data.map((e) => WilayahItem.fromJson(e)).toList();
        return _cachedProvinces!;
      }
    } catch (_) {}
    return _cachedProvinces ?? [];
  }

  /// 2. Ambil Kabupaten/Kota Berdasarkan ID Provinsi
  static Future<List<WilayahItem>> getRegencies(String provinceId) async {
    if (provinceId.isEmpty) return [];
    if (_cachedRegencies.containsKey(provinceId)) {
      return _cachedRegencies[provinceId]!;
    }
    try {
      final uri = Uri.parse('$_baseUrl/regencies/$provinceId.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final list = data.map((e) => WilayahItem.fromJson(e)).toList();
        _cachedRegencies[provinceId] = list;
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// 3. Ambil Kecamatan Berdasarkan ID Kabupaten
  static Future<List<WilayahItem>> getDistricts(String regencyId) async {
    if (regencyId.isEmpty) return [];
    if (_cachedDistricts.containsKey(regencyId)) {
      return _cachedDistricts[regencyId]!;
    }
    try {
      final uri = Uri.parse('$_baseUrl/districts/$regencyId.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final list = data.map((e) => WilayahItem.fromJson(e)).toList();
        _cachedDistricts[regencyId] = list;
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Helper mencari ID Provinsi berdasarkan nama provinsi
  static Future<String?> findProvinceIdByName(String name) async {
    if (name.isEmpty) return null;
    final provinces = await getProvinces();
    final clean = name.trim().toUpperCase();
    for (final p in provinces) {
      if (p.name.toUpperCase() == clean || clean.contains(p.name.toUpperCase())) {
        return p.id;
      }
    }
    return null;
  }

  /// Helper mencari ID Kabupaten berdasarkan nama kabupaten & ID provinsi
  static Future<String?> findRegencyIdByName(String provinceId, String name) async {
    if (provinceId.isEmpty || name.isEmpty) return null;
    final regencies = await getRegencies(provinceId);
    final clean = name.trim().toUpperCase().replaceAll('KABUPATEN ', '').replaceAll('KOTA ', '');
    for (final r in regencies) {
      final rClean = r.name.toUpperCase().replaceAll('KABUPATEN ', '').replaceAll('KOTA ', '');
      if (rClean == clean || r.name.toUpperCase() == name.trim().toUpperCase()) {
        return r.id;
      }
    }
    return null;
  }
}

