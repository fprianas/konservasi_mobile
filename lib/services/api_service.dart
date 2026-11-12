import '../models/recent_submission_item.dart';
import '../models/rekap_provinsi_item.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/report_item.dart';
import '../models/summary_data.dart';
import '../models/filter_options.dart';
import '../models/company_search_item.dart';
import '../models/analysis_data.dart';

enum ReportType { batubara, mineral }

class ApiService {
  // Reusable persistent HTTP client with connection pooling & Keep-Alive
  static final http.Client _client = http.Client();

  // In-memory caches for fast loading
  static FilterOptions? _cachedFiltersBatubara;
  static FilterOptions? _cachedFiltersMineral;

  // Preloaded data cache from SplashScreen
  static SummaryData? cachedSummaryBatubara;
  static ({List<ReportItem> items, PaginationData pagination, Map<String, double> totals})? cachedReportsBatubara;
  static RecentSubmissionsData? cachedRecentBatubara;
  static const String baseUrlBatubara = 'https://laporan-minerba.my.id/v2/api_batubara.php';
  static const String baseUrlMineral = 'https://laporan-minerba.my.id/v2/mineral/api_mineral.php';

  static String getBaseUrl(ReportType type) {
    return type == ReportType.batubara ? baseUrlBatubara : baseUrlMineral;
  }

  static String getFileUrl(ReportType type, String fileOrUrl, {String fileKind = 'laporan'}) {
    final trimmed = fileOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (type == ReportType.batubara) {
      // Batubara dilayani via endpoint download.php
      return 'https://laporan-minerba.my.id/v2/download.php?file=${Uri.encodeComponent(trimmed)}&type=$fileKind';
    } else {
      // Mineral dilayani via static folder uploads
      return 'https://laporan-minerba.my.id/v2/mineral/uploads/${Uri.encodeComponent(trimmed)}';
    }
  }

  static String getUploadBaseUrl(ReportType type) {
    return type == ReportType.batubara
        ? 'https://laporan-minerba.my.id/v2/download.php?type=laporan&file='
        : 'https://laporan-minerba.my.id/v2/mineral/uploads/';
  }

  // Ambil Ringkasan Statistik KPI
  static Future<SummaryData> fetchSummary(
    ReportType type, {
    String? provinsi,
    String? tahun,
    String? triwulan,
    String? jenisPerizinan,
  }) async {
    final Map<String, String> query = {'action': 'summary'};
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') {
      query['provinsi'] = provinsi;
    }
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') {
      query['tahun'] = tahun;
    }
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') {
      query['triwulan'] = triwulan;
    }
    if (jenisPerizinan != null && jenisPerizinan.isNotEmpty && jenisPerizinan != 'semua') {
      query['jenis_perizinan'] = jenisPerizinan;
    }

    final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        return SummaryData.fromJson(json['data']);
      }
      throw Exception(json['message'] ?? 'Gagal memuat ringkasan');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

    // Ambil Opsi Filter (menggunakan in-memory cache agar instan)
  static Future<FilterOptions> fetchFilters(ReportType type, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (type == ReportType.batubara && _cachedFiltersBatubara != null) {
        return _cachedFiltersBatubara!;
      }
      if (type == ReportType.mineral && _cachedFiltersMineral != null) {
        return _cachedFiltersMineral!;
      }
    }

    final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: {'action': 'filters'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        final res = FilterOptions.fromJson(json['data']);
        if (type == ReportType.batubara) {
          _cachedFiltersBatubara = res;
        } else {
          _cachedFiltersMineral = res;
        }
        return res;
      }
      throw Exception(json['message'] ?? 'Gagal memuat filter');
    } else {
      throw Exception('Server error: ');
    }
  }

  // Ambil Daftar Laporan (Paginasi + Filter + Pencarian + Totals)
  static Future<({List<ReportItem> items, PaginationData pagination, Map<String, double> totals})> fetchReports(
    ReportType type, {
    int page = 1,
    int limit = 15,
    String? search,
    String? provinsi,
    String? tahun,
    String? triwulan,
    String? komoditas,
    String? jenisPerizinan,
    String? statusProduksi,
  }) async {
    final Map<String, String> query = {
      'action': 'list',
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (provinsi != null && provinsi.isNotEmpty && provinsi != 'semua') {
      query['provinsi'] = provinsi;
    }
    if (tahun != null && tahun.isNotEmpty && tahun != 'semua') {
      query['tahun'] = tahun;
    }
    if (triwulan != null && triwulan.isNotEmpty && triwulan != 'semua') {
      query['triwulan'] = triwulan;
    }
    if (komoditas != null && komoditas.isNotEmpty && komoditas != 'semua') {
      query['komoditas'] = komoditas;
    }
    if (jenisPerizinan != null && jenisPerizinan.isNotEmpty && jenisPerizinan != 'semua') {
      query['jenis_perizinan'] = jenisPerizinan;
    }
    if (statusProduksi != null && statusProduksi.isNotEmpty && statusProduksi != 'semua') {
      query['status_produksi'] = statusProduksi;
    }

    final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        final list = (json['data'] as List?)
                ?.map((item) => ReportItem.fromJson(item))
                .toList() ??
            [];
        final pagination = PaginationData.fromJson(json['pagination'] ?? {});

        // Parse totals
        final totalsMap = <String, double>{};
        if (json['totals'] is Map) {
          (json['totals'] as Map).forEach((k, v) {
            totalsMap[k.toString()] = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
          });
        }

        return (items: list, pagination: pagination, totals: totalsMap);
      }
      throw Exception(json['message'] ?? 'Gagal memuat data laporan');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
  // Ambil Triwulan & Tahun default (Triwulan sebelumnya dari waktu saat ini)
  static ({String tahun, String triwulan}) getDefaultQuarter() {
    final now = DateTime.now();
    final int currentYear = now.year;
    final int month = now.month;

    // 1: Jan-Feb-Mar, 2: Apr-Mei-Jun, 3: Jul-Agu-Sep, 4: Okt-Nov-Des
    final int currentQuarter = ((month - 1) ~/ 3) + 1;

    // Ambil triwulan sebelumnya
    int prevQuarter = currentQuarter - 1;
    int targetYear = currentYear;

    if (prevQuarter < 1) {
      prevQuarter = 4;
      targetYear = currentYear - 1;
    }

    const quarterMap = {
      1: 'Triwulan I',
      2: 'Triwulan II',
      3: 'Triwulan III',
      4: 'Triwulan IV',
    };

    return (
      tahun: targetYear.toString(),
      triwulan: quarterMap[prevQuarter]!,
    );
  }
  // Ambil Rekapitulasi per Provinsi (dengan fallback jika server belum terupdate)
  static Future<List<RekapProvinsiItem>> fetchRekapProvinsi(
    ReportType type, {
    required String tahun,
    required String triwulan,
    String? jenisPerizinan,
  }) async {
    final Map<String, String> qParams = {
      'action': 'rekap_provinsi',
      'tahun': tahun,
      'triwulan': triwulan,
    };
    if (jenisPerizinan != null && jenisPerizinan.isNotEmpty && jenisPerizinan != 'semua') {
      qParams['jenis_perizinan'] = jenisPerizinan;
    }
    try {
      final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: qParams);

      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final rawList = json['data'] as List;
          if (rawList.isEmpty) return [];
          final first = rawList.first;
          if (first is Map && first.containsKey('total_perusahaan')) {
            return rawList.map((item) => RekapProvinsiItem.fromJson(item)).toList();
          }
        }
      }
    } catch (_) {}

    // Fallback: Ambil via summary per provinsi secara paralel
    try {
      final filters = await fetchFilters(type);
      final results = await Future.wait(
        filters.provinsi.map((prov) async {
          try {
            final summary = await fetchSummary(
              type,
              provinsi: prov,
              tahun: tahun,
              triwulan: triwulan,
            );
            if (summary.totalPerusahaan == 0 && summary.totalLaporanMasuk == 0) return null;
            return RekapProvinsiItem(
              namaProvinsi: prov,
              totalPerusahaan: summary.totalPerusahaan,
              totalLaporan: summary.totalLaporanMasuk,
              sudahLapor: summary.sudahLapor,
              belumLapor: summary.belumLapor,
              persentaseKepatuhan: summary.persentaseKepatuhan,
            );
          } catch (_) {
            return null;
          }
        }),
      );

      final list = results.whereType<RekapProvinsiItem>().toList();
      list.sort((a, b) {
        final cmp = b.persentaseKepatuhan.compareTo(a.persentaseKepatuhan);
        return cmp != 0 ? cmp : b.totalPerusahaan.compareTo(a.totalPerusahaan);
      });
      return list;
    } catch (e) {
      throw Exception('Gagal memuat rekap provinsi: $e');
    }
  }


  /// Mendapatkan daftar input perusahaan terkini (Hari Ini -> Minggu Ini -> Bulan Ini)
  static Future<RecentSubmissionsData> fetchRecentSubmissions(ReportType type) async {
    try {
      final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: {'action': 'recent_submissions'});
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return RecentSubmissionsData.fromJson(data);
        }
      }
    } catch (_) {}

    // Fallback: Analisis laporan terbaru secara lokal jika API belum dideploy
    try {
      final reportsResult = await fetchReports(type, page: 1, limit: 30);
      final items = reportsResult.items;
      if (items.isEmpty) return RecentSubmissionsData.empty();

      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startWeekStr = '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final startMonthStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';

      final todayItems = <RecentSubmissionItem>[];
      final weekItems = <RecentSubmissionItem>[];
      final monthItems = <RecentSubmissionItem>[];

      for (final r in items) {
        final w = r.waktuInput.trim();
        if (w.isEmpty || w == '-') continue;
        final datePart = w.length >= 10 ? w.substring(0, 10) : '';

        final subItem = RecentSubmissionItem(
          id: r.id,
          namaPerusahaan: r.namaPerusahaan,
          provinsi: r.provinsi,
          triwulan: r.triwulan,
          tahun: r.tahun,
          waktuInput: r.waktuInput,
        );

        if (datePart == todayStr) {
          todayItems.add(subItem);
        }
        if (datePart.compareTo(startWeekStr) >= 0 && datePart.compareTo(todayStr) <= 0) {
          weekItems.add(subItem);
        }
        if (datePart.compareTo(startMonthStr) >= 0 && datePart.compareTo(todayStr) <= 0) {
          monthItems.add(subItem);
        }
      }

      if (todayItems.isNotEmpty) {
        return RecentSubmissionsData(
          success: true,
          period: 'today',
          label: 'Hari Ini',
          title: 'Perusahaan yang mengisi data hari ini',
          total: todayItems.length,
          items: todayItems,
        );
      }
      if (weekItems.isNotEmpty) {
        return RecentSubmissionsData(
          success: true,
          period: 'week',
          label: 'Minggu Ini',
          title: 'Perusahaan yang mengisi data minggu ini',
          total: weekItems.length,
          items: weekItems,
        );
      }
      if (monthItems.isNotEmpty) {
        return RecentSubmissionsData(
          success: true,
          period: 'month',
          label: 'Bulan Ini',
          title: 'Perusahaan yang mengisi data bulan ini',
          total: monthItems.length,
          items: monthItems,
        );
      }
    } catch (_) {}

    return RecentSubmissionsData.empty();
  }

  /// Preload data awal Batubara saat Splash Screen berjalan
  static Future<void> preloadInitialData() async {
    try {
      final defaultQuarter = getDefaultQuarter();

      final sFuture = () async {
        try {
          cachedSummaryBatubara = await fetchSummary(
            ReportType.batubara,
            tahun: defaultQuarter.tahun,
            triwulan: defaultQuarter.triwulan,
          );
        } catch (_) {}
      }();

      final rFuture = () async {
        try {
          cachedReportsBatubara = await fetchReports(
            ReportType.batubara,
            page: 1,
            limit: 15,
            tahun: defaultQuarter.tahun,
            triwulan: defaultQuarter.triwulan,
          );
        } catch (_) {}
      }();

      final recFuture = () async {
        try {
          cachedRecentBatubara = await fetchRecentSubmissions(ReportType.batubara);
        } catch (_) {}
      }();

      final fFuture = () async {
        try {
          await fetchFilters(ReportType.batubara);
        } catch (_) {}
      }();

      await Future.wait([sFuture, rFuture, recFuture, fFuture]);
    } catch (_) {}
  }

  /// Mencari perusahaan (Batubara, Mineral, atau Keduanya) dengan filter tahun opsional
  static Future<List<CompanySearchItem>> searchCompanies({
    required String query,
    ReportType? type,
    String? tahun,
    int limit = 60,
  }) async {
    final searchTypes = type != null ? [type] : [ReportType.batubara, ReportType.mineral];
    final allResults = <CompanySearchItem>[];

    final tahunFilter = (tahun != null && tahun.isNotEmpty && tahun != 'semua') ? tahun : null;

    final futures = searchTypes.map((t) async {
      // 1. Coba endpoint langsung yang cepat dan ter-optimasi (search_companies)
      try {
        final Map<String, String> qParams = {
          'action': 'search_companies',
          'limit': limit.toString(),
        };
        if (query.trim().isNotEmpty) {
          qParams['q'] = query.trim();
        }
        if (tahunFilter != null) {
          qParams['tahun'] = tahunFilter;
        }

        final uri = Uri.parse(getBaseUrl(t)).replace(queryParameters: qParams);
        final response = await _client.get(uri).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] is List) {
            final list = (json['data'] as List)
                .map((item) => CompanySearchItem.fromJson(item as Map<String, dynamic>, t))
                .toList();
            if (list.isNotEmpty || query.trim().isNotEmpty) {
              return list;
            }
          }
        }
      } catch (_) {}

      // 2. Fallback: Kelompokkan dari fetchReports jika search_companies gagal
      try {
        final reportsResult = await fetchReports(
          t,
          page: 1,
          limit: limit,
          search: query.isNotEmpty ? query : null,
          tahun: tahunFilter,
        );

        final Map<String, List<ReportItem>> grouped = {};
        for (final item in reportsResult.items) {
          final key = item.skIup.isNotEmpty && item.skIup != '-'
              ? '${t.name}_${item.skIup.trim().toLowerCase()}'
              : '${t.name}_${item.namaPerusahaan.trim().toLowerCase()}';
          grouped.putIfAbsent(key, () => []).add(item);
        }

        final fallbackList = <CompanySearchItem>[];
        grouped.forEach((_, list) {
          if (list.isEmpty) return;
          list.sort((a, b) => b.id.compareTo(a.id));
          final latest = list.first;

          fallbackList.add(
            CompanySearchItem(
              namaPerusahaan: latest.namaPerusahaan,
              skIup: latest.skIup,
              provinsi: latest.provinsi,
              jenisPerizinan: latest.jenisPerizinan,
              komoditas: latest.komoditas,
              type: t,
              latestStatusProduksi: latest.statusProduksi,
              latestStatusProduksiCode: latest.statusProduksiCode,
              latestTahun: latest.tahun,
              latestTriwulan: latest.triwulan,
              latestWaktuInput: latest.waktuInput,
              totalReports: list.length,
              reports: list,
            ),
          );
        });
        return fallbackList;
      } catch (_) {
        return <CompanySearchItem>[];
      }
    });

    final resultsPerType = await Future.wait(futures);
    for (final res in resultsPerType) {
      allResults.addAll(res);
    }

    allResults.sort((a, b) => a.namaPerusahaan.compareTo(b.namaPerusahaan));
    return allResults;
  }

  /// Mengambil seluruh riwayat laporan suatu perusahaan tertentu
  static Future<List<ReportItem>> fetchCompanyFullHistory({
    required ReportType type,
    required String skIup,
    required String namaPerusahaan,
  }) async {
    // 1. Coba endpoint langsung company_history
    try {
      final Map<String, String> qParams = {
        'action': 'company_history',
      };
      if (skIup.isNotEmpty && skIup != '-') {
        qParams['sk_iup'] = skIup;
      }
      if (namaPerusahaan.isNotEmpty && namaPerusahaan != '-') {
        qParams['nama_perusahaan'] = namaPerusahaan;
      }

      final uri = Uri.parse(getBaseUrl(type)).replace(queryParameters: qParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final list = (json['data'] as List)
              .map((item) => ReportItem.fromJson(item as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: fetchReports grouping
    try {
      final searchKey = skIup.isNotEmpty && skIup != '-' ? skIup : namaPerusahaan;
      final reportsResult = await fetchReports(
        type,
        page: 1,
        limit: 100,
        search: searchKey,
      );
      final list = reportsResult.items.where((r) {
        if (skIup.isNotEmpty && skIup != '-' && r.skIup.isNotEmpty && r.skIup != '-') {
          return r.skIup.trim().toLowerCase() == skIup.trim().toLowerCase();
        }
        return r.namaPerusahaan.trim().toLowerCase() == namaPerusahaan.trim().toLowerCase();
      }).toList();

      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Mengambil data analisis trend (kenaikan/penurunan) dan analisis khusus
  static Future<AnalysisData> fetchAnalysisData({
    required ReportType type,
    required String tahunCurrent,
    required String triwulanCurrent,
    required String tahunPrev,
    required String triwulanPrev,
    String? provinsi,
  }) async {
    // 1. Ambil summary periode berjalan dan periode pembanding
    final summaryCurrentFuture = fetchSummary(
      type,
      tahun: tahunCurrent,
      triwulan: triwulanCurrent,
      provinsi: provinsi,
    );
    final summaryPrevFuture = fetchSummary(
      type,
      tahun: tahunPrev,
      triwulan: triwulanPrev,
      provinsi: provinsi,
    );

    // 2. Ambil rekap provinsi untuk kedua periode
    final rekapCurrentFuture = fetchRekapProvinsi(
      type,
      tahun: tahunCurrent,
      triwulan: triwulanCurrent,
    );
    final rekapPrevFuture = fetchRekapProvinsi(
      type,
      tahun: tahunPrev,
      triwulan: triwulanPrev,
    );

    // 3. Ambil sampel laporan periode berjalan untuk Analisis Khusus
    final reportsSampleFuture = fetchReports(
      type,
      tahun: tahunCurrent,
      triwulan: triwulanCurrent,
      provinsi: provinsi,
      page: 1,
      limit: 100,
    );

    final results = await Future.wait([
      summaryCurrentFuture,
      summaryPrevFuture,
      rekapCurrentFuture,
      rekapPrevFuture,
      reportsSampleFuture,
    ]);

    final sCurrent = results[0] as SummaryData;
    final sPrev = results[1] as SummaryData;
    final rCurrentList = results[2] as List<RekapProvinsiItem>;
    final rPrevList = results[3] as List<RekapProvinsiItem>;
    final reportsSample = results[4] as ({List<ReportItem> items, PaginationData pagination, Map<String, double> totals});

    // Petakan rekap prev berdasarkan nama provinsi
    final Map<String, RekapProvinsiItem> prevMap = {
      for (final item in rPrevList) item.namaProvinsi.trim().toLowerCase(): item
    };

    // Hitung perbandingan trend per provinsi
    final List<ProvinceAnalysisTrend> provinceTrends = [];
    for (final curr in rCurrentList) {
      final key = curr.namaProvinsi.trim().toLowerCase();
      final prev = prevMap[key];
      final double prevKepatuhan = prev != null ? prev.persentaseKepatuhan : 0.0;
      final double delta = curr.persentaseKepatuhan - prevKepatuhan;

      provinceTrends.add(
        ProvinceAnalysisTrend(
          namaProvinsi: curr.namaProvinsi,
          kepatuhanCurrent: curr.persentaseKepatuhan,
          kepatuhanPrev: prevKepatuhan,
          delta: double.parse(delta.toStringAsFixed(2)),
          totalPerusahaanCurrent: curr.totalPerusahaan,
          sudahLaporCurrent: curr.sudahLapor,
          sudahLaporPrev: prev?.sudahLapor ?? 0,
        ),
      );
    }

    // Urutkan provinsi berdasarkan delta tertinggi
    provinceTrends.sort((a, b) => b.delta.compareTo(a.delta));

    // Analisis Khusus
    int prodCount = 0;
    int belumProdCount = 0;
    int dokCount = 0;
    int petaCount = 0;
    final Map<String, int> perizinanMap = {};

    for (final rep in reportsSample.items) {
      if (rep.statusProduksiCode == 'P' || rep.statusProduksi.toLowerCase().contains('sudah')) {
        prodCount++;
      } else {
        belumProdCount++;
      }

      if (rep.laporanFile != null && rep.laporanFile!.isNotEmpty && rep.laporanFile != '-') {
        dokCount++;
      }
      if (rep.petaFile != null && rep.petaFile!.isNotEmpty && rep.petaFile != '-') {
        petaCount++;
      }

      final izin = rep.jenisPerizinan.trim();
      if (izin.isNotEmpty && izin != '-') {
        perizinanMap[izin] = (perizinanMap[izin] ?? 0) + 1;
      }
    }

    final totalItems = reportsSample.items.length;
    final double persentaseProduksi = totalItems > 0 ? (prodCount * 100.0) / totalItems : 0.0;
    final double persentaseDokumen = totalItems > 0 ? (dokCount * 100.0) / totalItems : 0.0;

    final specialData = SpecialAnalysisData(
      totalProduksi: prodCount,
      totalBelumProduksi: belumProdCount,
      persentaseProduksi: double.parse(persentaseProduksi.toStringAsFixed(1)),
      totalDenganDokumen: dokCount,
      totalDenganPeta: petaCount,
      persentaseKelengkapanDokumen: double.parse(persentaseDokumen.toStringAsFixed(1)),
      perizinanBreakdown: perizinanMap,
    );

    final double deltaKepatuhan = sCurrent.persentaseKepatuhan - sPrev.persentaseKepatuhan;

    return AnalysisData(
      type: type,
      tahunCurrent: tahunCurrent,
      triwulanCurrent: triwulanCurrent,
      tahunPrev: tahunPrev,
      triwulanPrev: triwulanPrev,
      selectedProvinsi: provinsi,
      kepatuhanCurrent: sCurrent.persentaseKepatuhan,
      kepatuhanPrev: sPrev.persentaseKepatuhan,
      deltaKepatuhan: double.parse(deltaKepatuhan.toStringAsFixed(2)),
      totalPerusahaan: sCurrent.totalPerusahaan,
      sudahLaporCurrent: sCurrent.sudahLapor,
      sudahLaporPrev: sPrev.sudahLapor,
      totalLaporanCurrent: sCurrent.totalLaporanMasuk,
      totalLaporanPrev: sPrev.totalLaporanMasuk,
      provinceTrends: provinceTrends,
      specialAnalysis: specialData,
    );
  }
}