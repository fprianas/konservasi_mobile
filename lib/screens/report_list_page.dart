import '../models/recent_submission_item.dart';
import '../widgets/recent_submissions_ticker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/report_item.dart';
import '../models/summary_data.dart';
import '../models/filter_options.dart';
import '../models/evaluasi_perusahaan_model.dart';
import '../services/api_service.dart';
import '../services/evaluasi_perusahaan_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/report_card.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/column_selector_dialog.dart';
import '../widgets/totals_footer.dart';
import 'info_page.dart';
import 'evaluasi_dokumen_page.dart';
import 'rekap_evaluasi_perusahaan_page.dart';

class ReportListPage extends StatefulWidget {
  final ReportType type;

  const ReportListPage({super.key, required this.type});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  SummaryData? _summary;
  FilterOptions? _filters;
  RecentSubmissionsData? _recentSubmissions;
  bool _isLoadingRecent = false;
  final List<ReportItem> _items = [];
  Map<String, double> _grandTotals = {};
  int _totalRecords = 0;
  bool _isLoadingSummary = false;
  bool _isLoadingList = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Evaluasi Perusahaan Map (Key: lowercase trimmed nama_perusahaan)
  Map<String, EvaluasiPerusahaanItem> _evaluasiMap = {};

  // Pagination
  int _currentPage = 1;
  bool _hasMore = false;
  final ScrollController _scrollController = ScrollController();

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Filters
  String? _filterTahun;
  String? _filterTriwulan;
  String? _filterProvinsi;
  String? _filterStatusProduksi;
  String? _filterKomoditas;
  String? _filterJenisPerizinan;

  // Column choices
  final Set<String> _selectedColumns = {};
  final GlobalKey<TotalsFooterState> _totalsFooterKey = GlobalKey<TotalsFooterState>();
  bool _isTotalsExpanded = false;

  bool get _hasActiveFilters =>
      (_filterTahun != null && _filterTahun != 'semua') ||
      (_filterTriwulan != null && _filterTriwulan != 'semua') ||
      (_filterProvinsi != null && _filterProvinsi != 'semua') ||
      (_filterStatusProduksi != null && _filterStatusProduksi != 'semua') ||
      (_filterKomoditas != null && _filterKomoditas != 'semua') ||
      (_filterJenisPerizinan != null && _filterJenisPerizinan != 'semua');

  @override
  void initState() {
    super.initState();
    final defaultQuarter = ApiService.getDefaultQuarter();
    _filterTahun = defaultQuarter.tahun;
    _filterTriwulan = defaultQuarter.triwulan;

    if (widget.type == ReportType.batubara) {
      _selectedColumns.addAll({'bkr_kuantitas', 'ctt_kuantitas'});
    } else {
      _selectedColumns.addAll({'mkr_kuantitas', 'cmtt_kuantitas'});
    }

    // Gunakan preloaded data dari Splash Screen jika sudah tersedia
    if (widget.type == ReportType.batubara) {
      if (ApiService.cachedSummaryBatubara != null) {
        _summary = ApiService.cachedSummaryBatubara;
        _isLoadingSummary = false;
      }
      if (ApiService.cachedReportsBatubara != null) {
        final cached = ApiService.cachedReportsBatubara!;
        _items.addAll(cached.items);
        _grandTotals = cached.totals;
        _totalRecords = cached.pagination.totalRecords;
        _hasMore = cached.pagination.hasMore;
        _isLoadingList = false;
      }
      if (ApiService.cachedRecentBatubara != null) {
        _recentSubmissions = ApiService.cachedRecentBatubara;
        _isLoadingRecent = false;
      }
    }

    _scrollController.addListener(_onScroll);

    // Jika data belum terisi dari preloader, muat sekarang
    if (_items.isEmpty || _summary == null) {
      _loadInitialData();
    } else {
      _loadFilters();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingList && !_isLoadingMore && _hasMore) {
        _loadMoreReports();
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadReports(resetPage: true);
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSummary(),
      _loadReports(resetPage: true),
      _loadRecentSubmissions(),
      _loadFilters(),
      _loadEvaluasiMap(),
    ]);
  }

  Future<void> _loadEvaluasiMap() async {
    try {
      final map = await EvaluasiPerusahaanService.fetchEvaluasiMap(
        tipe: widget.type == ReportType.batubara ? 'batubara' : 'mineral',
      );
      if (mounted) {
        setState(() => _evaluasiMap = map);
      }
    } catch (_) {}
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final data = await ApiService.fetchSummary(
        widget.type,
        provinsi: _filterProvinsi,
        tahun: _filterTahun,
        triwulan: _filterTriwulan,
        jenisPerizinan: _filterJenisPerizinan,
      );
      if (mounted) {
        setState(() {
          _summary = data;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  
  Future<void> _loadRecentSubmissions() async {
    setState(() => _isLoadingRecent = true);
    try {
      final res = await ApiService.fetchRecentSubmissions(widget.type);
      if (mounted) {
        setState(() {
          _recentSubmissions = res;
          _isLoadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await ApiService.fetchFilters(widget.type);
      if (mounted) {
        setState(() => _filters = filters);
      }
    } catch (_) {}
  }

  Future<void> _loadReports({bool resetPage = false}) async {
    if (resetPage) {
      setState(() {
        _currentPage = 1;
        _isLoadingList = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await ApiService.fetchReports(
        widget.type,
        page: _currentPage,
        limit: 15,
        search: _searchController.text,
        provinsi: _filterProvinsi,
        tahun: _filterTahun,
        triwulan: _filterTriwulan,
        jenisPerizinan: _filterJenisPerizinan,
        statusProduksi: _filterStatusProduksi,
        komoditas: _filterKomoditas,
      );

      if (mounted) {
        setState(() {
          if (resetPage) {
            _items.clear();
          }
          _items.addAll(result.items);
          _grandTotals = result.totals;
          _totalRecords = result.pagination.totalRecords;
          _hasMore = result.pagination.hasMore;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingList = false;
        });
      }
    }
  }

  Future<void> _loadMoreReports() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
      final result = await ApiService.fetchReports(
        widget.type,
        page: _currentPage,
        limit: 15,
        search: _searchController.text,
        provinsi: _filterProvinsi,
        tahun: _filterTahun,
        triwulan: _filterTriwulan,
        jenisPerizinan: _filterJenisPerizinan,
        statusProduksi: _filterStatusProduksi,
        komoditas: _filterKomoditas,
      );

      if (mounted) {
        setState(() {
          _items.addAll(result.items);
          _hasMore = result.pagination.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _openColumnSelector() {
    showDialog(
      context: context,
      builder: (ctx) => ColumnSelectorDialog(
        type: widget.type,
        selectedColumns: _selectedColumns,
        onSave: (updated) {
          setState(() {
            _selectedColumns.clear();
            _selectedColumns.addAll(updated);
          });
        },
      ),
    );
  }

  void _openFilterSheet() {
    if (_filters == null) return;
    FilterSheet.show(
      context,
      type: widget.type,
      options: _filters!,
      currentTahun: _filterTahun,
      currentTriwulan: _filterTriwulan,
      currentProvinsi: _filterProvinsi,
      currentStatusProduksi: _filterStatusProduksi,
      currentKomoditas: _filterKomoditas,
      currentJenisPerizinan: _filterJenisPerizinan,
      onApply: ({tahun, triwulan, provinsi, statusProduksi, komoditas, jenisPerizinan}) {
        setState(() {
          _filterTahun = tahun;
          _filterTriwulan = triwulan;
          _filterProvinsi = provinsi;
          _filterStatusProduksi = statusProduksi;
          _filterKomoditas = komoditas;
          _filterJenisPerizinan = jenisPerizinan;
        });
        _loadSummary();
        _loadReports(resetPage: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBatubara = widget.type == ReportType.batubara;

    return PopScope(
      canPop: !_isTotalsExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isTotalsExpanded) {
          _totalsFooterKey.currentState?.collapse();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isBatubara ? 'PELAPORAN BATUBARA' : 'PELAPORAN MINERAL',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF18181B),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            Text(
              isBatubara
                  ? 'Sistem Monitoring Konservasi Batubara'
                  : 'Sistem Monitoring Konservasi Mineral',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rekap Evaluasi Konservasi (7 Objek)',
            icon: const Icon(Icons.fact_check_outlined, color: Color(0xFF18181B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RekapEvaluasiPerusahaanPage(
                    initialTipe: widget.type == ReportType.batubara ? 'batubara' : 'mineral',
                  ),
                ),
              ).then((_) {
                _loadEvaluasiMap();
              });
            },
          ),
          IconButton(
            tooltip: 'Evaluasi Dokumen (RKPW & FS)',
            icon: const Icon(Icons.assignment_outlined, color: Color(0xFF18181B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EvaluasiDokumenPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Tentang Aplikasi',
            icon: const Icon(Icons.info_outline, color: Color(0xFF18181B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InfoPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Pilih Kolom Opsional',
            icon: const Icon(Icons.view_column_outlined, color: Color(0xFF18181B)),
            onPressed: _openColumnSelector,
          ),
          Stack(
            children: [
              IconButton(
                tooltip: 'Filter Laporan',
                icon: const Icon(Icons.filter_list, color: Color(0xFF18181B)),
                onPressed: _openFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Main Scroll View
          RefreshIndicator(
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFF18181B),
            onRefresh: _loadInitialData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Running text informasi input terbaru di atas card KPI
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: RecentSubmissionsTicker(
                      data: _recentSubmissions,
                      isLoading: _isLoadingRecent,
                      onItemTap: (item) {
                        _searchController.text = item.namaPerusahaan;
                        _loadReports(resetPage: true);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildKpiSection()),
                SliverToBoxAdapter(child: _buildSearchBarAndFilters()),
                _buildListSliver(),
                if (_isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                // Padding so list does not hide behind totals footer
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),

          // Backdrop transparan jika footer rekapitulasi sedang terbuka (klik di luar untuk menutup)
          if (_isTotalsExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _totalsFooterKey.currentState?.collapse();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),

          // Sticky Totals Footer pinned at bottom of page
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TotalsFooter(
              key: _totalsFooterKey,
              type: widget.type,
              grandTotals: _grandTotals,
              totalRecords: _totalRecords,
              selectedColumns: _selectedColumns,
              onExpandedChanged: (expanded) {
                setState(() => _isTotalsExpanded = expanded);
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildKpiSection() {
    if (_isLoadingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF59E0B),
          ),
        ),
      );
    }

    if (_summary == null) return const SizedBox.shrink();

    final cards = [
      KpiCard(
        title: 'Total Perusahaan',
        value: _summary!.totalPerusahaan.toString(),
        subtitle: 'Terdaftar di database',
        icon: Icons.business,
      ),
      KpiCard(
        title: 'Sudah Lapor',
        value: _summary!.sudahLapor.toString(),
        subtitle: '${_summary!.totalLaporanMasuk} laporan masuk',
        icon: Icons.check_circle_outline,
      ),
      KpiCard(
        title: 'Belum Lapor',
        value: _summary!.belumLapor.toString(),
        subtitle: 'Perusahaan belum lapor',
        icon: Icons.access_time,
      ),
      KpiCard(
        title: 'Tingkat Kepatuhan',
        value: '${_summary!.persentaseKepatuhan}%',
        subtitle: 'Persentase kepatuhan',
        icon: Icons.pie_chart_outline,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Layar smartphone / mobile (< 600px): Grid 2x2 Kompak
        if (constraints.maxWidth < 600) {
          final double ratio = constraints.maxWidth < 360 ? 1.9 : 2.1;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: ratio,
              children: cards,
            ),
          );
        }

        // Layar tablet / lebar (>= 600px): 1 baris 4 kolom seimbang
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBarAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari nama perusahaan atau nomor SK IUP...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF71717A)),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF18181B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF18181B)),
                      onPressed: () {
                        _searchController.clear();
                        _loadReports(resetPage: true);
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF18181B), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_filterTahun != null && _filterTahun != 'semua')
                  _buildFilterBadge('Tahun: $_filterTahun', () {
                    setState(() => _filterTahun = null);
                    _loadReports(resetPage: true);
                  }),
                if (_filterTriwulan != null && _filterTriwulan != 'semua')
                  _buildFilterBadge(_filterTriwulan!, () {
                    setState(() => _filterTriwulan = null);
                    _loadReports(resetPage: true);
                  }),
                if (_filterProvinsi != null && _filterProvinsi != 'semua')
                  _buildFilterBadge(_filterProvinsi!, () {
                    setState(() => _filterProvinsi = null);
                    _loadReports(resetPage: true);
                  }),
                if (_filterStatusProduksi != null && _filterStatusProduksi != 'semua')
                  _buildFilterBadge('Status: $_filterStatusProduksi', () {
                    setState(() => _filterStatusProduksi = null);
                    _loadReports(resetPage: true);
                  }),
                                if (_filterJenisPerizinan != null && _filterJenisPerizinan != 'semua')
                  _buildFilterBadge('Izin: $_filterJenisPerizinan', () {
                    setState(() => _filterJenisPerizinan = null);
                    _loadSummary();
                    _loadReports(resetPage: true);
                  }),
                if (_filterKomoditas != null && _filterKomoditas != 'semua')
                  _buildFilterBadge('Komoditas: $_filterKomoditas', () {
                    setState(() => _filterKomoditas = null);
                    _loadReports(resetPage: true);
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBadge(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFFFBBF24)),
          ),
        ],
      ),
    );
  }

  Widget _buildListSliver() {
    if (_isLoadingList) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: Color(0xFFF59E0B)),
                SizedBox(height: 14),
                Text(
                  'Memuat data laporan...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18181B),
                    foregroundColor: const Color(0xFFFBBF24),
                  ),
                  onPressed: () => _loadReports(resetPage: true),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50),
          child: Center(
            child: Column(
              children: const [
                Icon(Icons.inventory_2_outlined, size: 54, color: Color(0xFFD4D4D8)),
                SizedBox(height: 12),
                Text(
                  'Tidak ada laporan yang sesuai kriteria',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3F3F46)),
                ),
                SizedBox(height: 4),
                Text(
                  'Coba ubah kata kunci pencarian atau reset filter',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF71717A)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _items[index];
          final periodKey = EvaluasiPerusahaanService.buildKey(item.namaPerusahaan, item.tahun, item.triwulan);
          final evalItem = _evaluasiMap[periodKey] ?? _evaluasiMap[item.namaPerusahaan.trim().toLowerCase()];
          return ReportCard(
            item: item,
            type: widget.type,
            selectedColumns: _selectedColumns,
            initialEvaluasi: evalItem,
            onEvaluasiChanged: (newItem) {
              final baseKey = item.namaPerusahaan.trim().toLowerCase();
              setState(() {
                if (newItem == null) {
                  _evaluasiMap.remove(periodKey);
                  _evaluasiMap.remove(baseKey);
                } else {
                  _evaluasiMap[periodKey] = newItem;
                  _evaluasiMap[baseKey] = newItem;
                }
              });
            },
          );
        },
        childCount: _items.length,
      ),
    );
  }
}
