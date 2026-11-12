import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_search_item.dart';
import '../models/evaluasi_perusahaan_model.dart';
import '../models/report_item.dart';
import '../services/api_service.dart';
import '../services/evaluasi_exporter_service.dart';
import '../services/evaluasi_perusahaan_service.dart';
import '../widgets/delete_evaluasi_dialog.dart';
import '../widgets/detail_modal.dart';
import '../widgets/evaluasi_perusahaan_dialog.dart';
import '../widgets/security_pin_dialog.dart';
import 'info_page.dart';
import 'rekap_evaluasi_perusahaan_page.dart';

class CompanySearchPage extends StatefulWidget {
  const CompanySearchPage({super.key});

  @override
  State<CompanySearchPage> createState() => _CompanySearchPageState();
}

class _CompanySearchPageState extends State<CompanySearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Filter states
  ReportType? _selectedTypeFilter; // null means 'Semua Sektor'
  String _selectedTahun = 'semua'; // default semua tahun agar pencarian komprehensif
  List<String> _availableYears = ['2026', '2025', '2024', '2023', '2022', '2021', '2020'];

  // Search results state
  List<CompanySearchItem> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  // Evaluasi Map state untuk pencarian perusahaan & color coding
  Map<String, EvaluasiPerusahaanItem> _evaluasiMap = {};
  bool _isLoadingEvaluasi = false;

  @override
  void initState() {
    super.initState();
    _selectedTahun = 'semua';
    _initYears();
    _loadEvaluasiMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initYears() async {
    try {
      final fb = await ApiService.fetchFilters(ReportType.batubara);
      final fm = await ApiService.fetchFilters(ReportType.mineral);
      final Set<String> years = {...fb.tahun, ...fm.tahun};
      if (years.isNotEmpty) {
        final list = years.toList()..sort((a, b) => b.compareTo(a));
        if (mounted) {
          setState(() {
            _availableYears = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadEvaluasiMap() async {
    setState(() => _isLoadingEvaluasi = true);
    try {
      final map = await EvaluasiPerusahaanService.fetchEvaluasiMap();
      if (mounted) {
        setState(() {
          _evaluasiMap = map;
          _isLoadingEvaluasi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEvaluasi = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiService.searchCompanies(
        query: trimmed,
        type: _selectedTypeFilter,
        tahun: _selectedTahun,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mencari perusahaan: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Menampilkan semua perusahaan di tahun terpilih (eksplorasi cepat)
  Future<void> _exploreAllCompaniesInYear() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiService.searchCompanies(
        query: '',
        type: _selectedTypeFilter,
        tahun: _selectedTahun,
        limit: 80,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat perusahaan tahun $_selectedTahun: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                const Text(
                  'PENCARIAN PERUSAHAAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF18181B),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const Text(
              'Cari Perusahaan, Filter Tahun & Histori',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rekap Evaluasi Perusahaan',
            icon: const Icon(Icons.fact_check_outlined, color: Color(0xFFB45309)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RekapEvaluasiPerusahaanPage()),
              ).then((_) => _loadEvaluasiMap());
            },
          ),
          IconButton(
            tooltip: 'Refresh Status Evaluasi',
            icon: _isLoadingEvaluasi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF18181B)),
            onPressed: _isLoadingEvaluasi ? null : _loadEvaluasiMap,
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
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (val) {
                      _debounce?.cancel();
                      _performSearch(val);
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Ketik nama perusahaan, SK IUP, provinsi...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFA1A1AA)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFB45309), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF71717A)),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Sector Filter Chips
                Row(
                  children: [
                    const Text(
                      'Sektor:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF71717A)),
                    ),
                    const SizedBox(width: 8),
                    _buildSectorFilterChip('Semua Sektor', null),
                    const SizedBox(width: 6),
                    _buildSectorFilterChip('Batubara', ReportType.batubara),
                    const SizedBox(width: 6),
                    _buildSectorFilterChip('Mineral', ReportType.mineral),
                  ],
                ),

                const SizedBox(height: 8),

                // Year Filter Chips Row
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 5),
                    const Text(
                      'Tahun:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF71717A)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildYearFilterChip('Semua Tahun', 'semua'),
                            const SizedBox(width: 6),
                            ..._availableYears.map((y) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _buildYearFilterChip(y, y),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _buildContentArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorFilterChip(String label, ReportType? type) {
    final isSelected = _selectedTypeFilter == type;
    return GestureDetector(
      onTap: () {
        if (_selectedTypeFilter == type) return;
        setState(() {
          _selectedTypeFilter = type;
        });
        if (_searchController.text.isNotEmpty || _hasSearched) {
          _performSearch(_searchController.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF18181B) : const Color(0xFFE4E4E7),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFF52525B),
          ),
        ),
      ),
    );
  }

  Widget _buildYearFilterChip(String label, String value) {
    final isSelected = _selectedTahun == value;
    return GestureDetector(
      onTap: () {
        if (_selectedTahun == value) return;
        setState(() {
          _selectedTahun = value;
        });
        if (_searchController.text.isNotEmpty || _hasSearched) {
          _performSearch(_searchController.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE4E4E7),
            width: isSelected ? 1.2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 11, color: Color(0xFFFBBF24)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFF52525B),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildContentArea() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFF59E0B)),
            const SizedBox(height: 14),
            Text(
              'Mencari data perusahaan tahun ${_selectedTahun == 'semua' ? 'semua periode' : _selectedTahun}...',
              style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: const Color(0xFFFBBF24),
                ),
                onPressed: () => _performSearch(_searchController.text),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return _buildInitialGuideState();
    }

    if (_searchResults.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off, size: 36, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Perusahaan Tidak Ditemukan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
              ),
              const SizedBox(height: 6),
              Text(
                'Tidak ditemukan data perusahaan untuk filter tahun ${_selectedTahun == 'semua' ? 'Semua' : _selectedTahun}. '
                'Coba ubah kata kunci atau ganti filter tahun.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF71717A)),
              ),
            ],
          ),
        ),
      );
    }

    final prodCount = _searchResults.where((c) => c.isProduksi).length;
    final belumProdCount = _searchResults.length - prodCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counter Header & Breakdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'Ditemukan ${_searchResults.length} Perusahaan',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$prodCount Produksi',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$belumProdCount Belum Prod.',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ),

        // Company Results List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final company = _searchResults[index];
              return _buildCompanyCard(company);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInitialGuideState() {
    final yearLabel = _selectedTahun == 'semua' ? 'Semua Tahun' : 'Tahun $_selectedTahun';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      child: Column(
        children: [
          // Tombol Eksplorasi Cepat untuk Tahun ini
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: const Color(0xFFFBBF24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.1),
                ),
                onPressed: _exploreAllCompaniesInYear,
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(
                  'Jelajahi Perusahaan Melaporkan di $yearLabel',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Search Tips Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.manage_search, size: 30, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pusat Pencarian Perusahaan',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Temukan profil izin usaha pertambangan dan rekam jejak histori pelaporan triwulan konservasi minerba.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF71717A)),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildTipRow(Icons.business, 'Cari berdasarkan nama PT atau CV'),
                  _buildTipRow(Icons.confirmation_number_outlined, 'Cari nomor SK IUP / Izin Usaha'),
                  _buildTipRow(Icons.location_on_outlined, 'Filter berdasarkan wilayah provinsi'),
                  _buildTipRow(Icons.history_edu, 'Lihat timeline riwayat semua laporan yang pernah diinput'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF3F3F46)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(CompanySearchItem company) {
    final isBatubara = company.type == ReportType.batubara;
    final isProd = company.isProduksi;
    final eval = _evaluasiMap[company.namaPerusahaan.trim().toLowerCase()];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCompanyHistory(company),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Sector Badge, Status Produksi, Status Evaluasi (Merah/Kuning/Hijau), Total Laporan
              Wrap(
                spacing: 6,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isBatubara ? const Color(0xFF18181B) : const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBatubara ? Icons.terrain : Icons.diamond_outlined,
                          size: 11,
                          color: isBatubara ? const Color(0xFFFBBF24) : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBatubara ? 'Batubara' : 'Mineral',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isBatubara ? const Color(0xFFFBBF24) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isProd ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isProd ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      company.latestStatusProduksi,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isProd ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  // Badge Evaluasi (Merah: belum di Evaluasi, Kuning: belum memadai, Hijau: memadai)
                  _buildEvaluasiBadge(eval),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '${company.totalReports} Laporan',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Company Name
              Text(
                company.namaPerusahaan,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF18181B),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 4),

              // SK IUP
              Text(
                'SK IUP: ${company.skIup}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF52525B),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 12),

              // Info Row: Provinsi & Aksi
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF71717A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      company.provinsi,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.history, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  const Text(
                    'Lihat Histori',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFFB45309)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluasiBadge(EvaluasiPerusahaanItem? eval) {
    final bool isEvaluated = eval != null;
    final bool isMemadai = isEvaluated && eval.isMemadai;

    final Color bg = !isEvaluated
        ? const Color(0xFFFEF2F2)
        : (isMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFFFBEB));
    final Color border = !isEvaluated
        ? const Color(0xFFFECACA)
        : (isMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A));
    final Color text = !isEvaluated
        ? const Color(0xFFDC2626)
        : (isMemadai ? const Color(0xFF15803D) : const Color(0xFFB45309));
    final IconData icon = !isEvaluated
        ? Icons.cancel_outlined
        : (isMemadai ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded);
    final String label = !isEvaluated
        ? 'Belum Evaluasi'
        : (isMemadai ? 'Memadai' : 'Belum Memadai');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: text),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  void _openCompanyHistory(CompanySearchItem company) {
    final key = company.namaPerusahaan.trim().toLowerCase();
    final eval = _evaluasiMap[key];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompanyHistoryModal(
        company: company,
        initialTahun: _selectedTahun,
        initialEvaluasi: eval,
        onEvaluasiChanged: (updated) {
          setState(() {
            if (updated == null) {
              _evaluasiMap.remove(key);
            } else {
              _evaluasiMap[key] = updated;
            }
          });
        },
      ),
    );
  }
}

class _SummableMetricDef {
  final String key;
  final List<String> altKeys;
  final String title;
  final String subTitle;
  final String unit;
  final IconData icon;
  final bool isAverage;

  const _SummableMetricDef({
    required this.key,
    this.altKeys = const [],
    required this.title,
    required this.subTitle,
    required this.unit,
    required this.icon,
    this.isAverage = false,
  });
}

class _CompanyHistoryModal extends StatefulWidget {
  final CompanySearchItem company;
  final String? initialTahun;
  final EvaluasiPerusahaanItem? initialEvaluasi;
  final ValueChanged<EvaluasiPerusahaanItem?>? onEvaluasiChanged;

  const _CompanyHistoryModal({
    required this.company,
    this.initialTahun,
    this.initialEvaluasi,
    this.onEvaluasiChanged,
  });

  @override
  State<_CompanyHistoryModal> createState() => _CompanyHistoryModalState();
}

class _CompanyHistoryModalState extends State<_CompanyHistoryModal> {
  late List<ReportItem> _reports;
  bool _isLoadingAll = false;
  String _historyYearFilter = 'semua';
  bool _showTableView = true;
  EvaluasiPerusahaanItem? _evaluasi;
  Map<String, EvaluasiPerusahaanItem> _companyEvaluasiByPeriod = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _reports = widget.company.reports;
    _evaluasi = widget.initialEvaluasi;
    if (widget.initialTahun != null && widget.initialTahun != 'semua') {
      _historyYearFilter = widget.initialTahun!;
    } else if (_reports.isNotEmpty) {
      final years = _reports
          .map((r) => r.tahun.trim())
          .where((t) => t.isNotEmpty && t != '-')
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (years.isNotEmpty) {
        _historyYearFilter = years.first;
      }
    }
    _fetchFullHistoryIfNeeded();
    _fetchLatestEvaluasi();
  }

  Future<void> _fetchLatestEvaluasi() async {
    try {
      final list = await EvaluasiPerusahaanService.fetchEvaluasiList(
        tipe: widget.company.type == ReportType.batubara ? 'batubara' : 'mineral',
      );
      final myItems = list.where((e) => e.namaPerusahaan.trim().toLowerCase() == widget.company.namaPerusahaan.trim().toLowerCase()).toList();
      final Map<String, EvaluasiPerusahaanItem> byPeriod = {};
      for (final it in myItems) {
        final key = EvaluasiPerusahaanService.buildKey(it.namaPerusahaan, it.tahun, it.triwulan);
        byPeriod[key] = it;
      }
      if (mounted) {
        setState(() {
          _companyEvaluasiByPeriod = byPeriod;
          if (myItems.isNotEmpty) {
            _evaluasi = myItems.first;
            widget.onEvaluasiChanged?.call(myItems.first);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openQuarterEvaluasi(int quarterIndex, ReportItem? rep, EvaluasiPerusahaanItem? eval) async {
    final twLabels = ['Triwulan I', 'Triwulan II', 'Triwulan III', 'Triwulan IV'];
    final tw = rep?.triwulan.isNotEmpty == true ? rep!.triwulan : twLabels[quarterIndex - 1];
    final year = int.tryParse(rep?.tahun ?? '') ??
        int.tryParse(_historyYearFilter) ??
        (eval != null && eval.tahun > 0 ? eval.tahun : DateTime.now().year);

    final periodKey = EvaluasiPerusahaanService.buildKey(widget.company.namaPerusahaan, year, tw);
    final existing = eval ?? _companyEvaluasiByPeriod[periodKey];

    if (existing != null) {
      final pinOk = await SecurityPinDialog.verify(
        context,
        title: 'Verifikasi Kode Keamanan',
        subtitle: 'Masukkan kode keamanan untuk mengubah hasil evaluasi $tw $year.',
      );
      if (pinOk != true || !mounted) return;
    }

    if (!mounted) return;
    final latestRep = _reports.isNotEmpty ? _reports.first : null;
    final result = await EvaluasiPerusahaanDialog.show(
      context,
      namaPerusahaan: widget.company.namaPerusahaan,
      tipe: widget.company.type == ReportType.batubara ? 'batubara' : 'mineral',
      komoditas: rep?.komoditas ?? latestRep?.komoditas ?? existing?.komoditas,
      skIup: widget.company.skIup,
      provinsi: widget.company.provinsi,
      triwulan: tw,
      tahun: year,
      statusProduksi: rep?.statusProduksi ?? widget.company.latestStatusProduksi,
      initialData: existing,
    );

    if (result != null && mounted) {
      setState(() {
        if (result.id == -1) {
          _companyEvaluasiByPeriod.remove(periodKey);
          if (_evaluasi?.id == existing?.id) {
            _evaluasi = _companyEvaluasiByPeriod.values.isNotEmpty ? _companyEvaluasiByPeriod.values.first : null;
          }
          widget.onEvaluasiChanged?.call(_evaluasi);
        } else {
          _companyEvaluasiByPeriod[periodKey] = result;
          _evaluasi = result;
          widget.onEvaluasiChanged?.call(result);
        }
      });
    }
  }

  Future<void> _handleHapusPeriodEvaluasi(EvaluasiPerusahaanItem item) async {
    final deleted = await DeleteEvaluasiDialog.show(
      context,
      title: 'Hapus Evaluasi Perusahaan?',
      namaPerusahaan: item.namaPerusahaan,
      itemType: 'Evaluasi ${item.triwulan} ${item.tahun}',
      onDelete: (pin) async {
        await EvaluasiPerusahaanService.deleteEvaluasi(
          id: item.id,
          namaPerusahaan: item.namaPerusahaan,
          pin: pin,
        );
      },
    );

    if (deleted == true && mounted) {
      final periodKey = EvaluasiPerusahaanService.buildKey(item.namaPerusahaan, item.tahun, item.triwulan);
      setState(() {
        _companyEvaluasiByPeriod.remove(periodKey);
        if (_evaluasi?.id == item.id) {
          _evaluasi = _companyEvaluasiByPeriod.values.isNotEmpty ? _companyEvaluasiByPeriod.values.first : null;
        }
      });
      widget.onEvaluasiChanged?.call(_evaluasi);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Evaluasi ${item.triwulan} ${item.tahun} berhasil dihapus'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportCompanyEvaluasi(String format) async {
    final list = _companyEvaluasiByPeriod.values.toList();
    if (list.isEmpty && _evaluasi != null) {
      list.add(_evaluasi!);
    }
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada data evaluasi tersimpan untuk perusahaan ini.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    list.sort((a, b) {
      final yComp = b.tahun.compareTo(a.tahun);
      if (yComp != 0) return yComp;
      return b.triwulan.compareTo(a.triwulan);
    });

    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menyiapkan berkas ${format.toUpperCase()}...'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      EvaluasiExportResult res;
      if (format == 'excel') {
        res = await EvaluasiExporterService.exportEvaluasiPerusahaanExcel(
          items: list,
          tipe: widget.company.namaPerusahaan,
        );
      } else {
        res = await EvaluasiExporterService.exportEvaluasiPerusahaanPdf(
          items: list,
          tipe: widget.company.namaPerusahaan,
        );
      }

      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openPeriodEvaluasi(ReportItem rep) async {
    final qIdx = rep.triwulan.contains('IV') ? 4 : (rep.triwulan.contains('III') ? 3 : (rep.triwulan.contains('II') ? 2 : 1));
    final periodKey = EvaluasiPerusahaanService.buildKey(rep.namaPerusahaan, rep.tahun, rep.triwulan);
    final existing = _companyEvaluasiByPeriod[periodKey];
    await _openQuarterEvaluasi(qIdx, rep, existing);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildModalHeaderEvaluasiBadge() {
    final eval = _evaluasi;
    final isEvaluated = eval != null;
    final isMemadai = isEvaluated && eval.isMemadai;

    final Color bg = !isEvaluated
        ? const Color(0xFFFEF2F2)
        : (isMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFFFBEB));
    final Color border = !isEvaluated
        ? const Color(0xFFFECACA)
        : (isMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A));
    final Color text = !isEvaluated
        ? const Color(0xFFDC2626)
        : (isMemadai ? const Color(0xFF15803D) : const Color(0xFFB45309));
    final IconData icon = !isEvaluated
        ? Icons.cancel_outlined
        : (isMemadai ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded);
    final String label = !isEvaluated
        ? 'Belum Evaluasi'
        : (isMemadai ? 'Memadai' : 'Belum Memadai');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchFullHistoryIfNeeded() async {
    setState(() => _isLoadingAll = true);
    try {
      final all = await ApiService.fetchCompanyFullHistory(
        type: widget.company.type,
        skIup: widget.company.skIup,
        namaPerusahaan: widget.company.namaPerusahaan,
      );
      if (mounted && all.isNotEmpty) {
        setState(() {
          _reports = all;
          _isLoadingAll = false;
          if (_historyYearFilter != 'semua' && !all.any((r) => r.tahun.trim() == _historyYearFilter)) {
            _historyYearFilter = 'semua';
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingAll = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _openFile(BuildContext context, String fileOrUrl, {String fileKind = 'laporan'}) async {
    final fileUrl = ApiService.getFileUrl(widget.company.type, fileOrUrl, fileKind: fileKind);
    final fileUri = Uri.parse(fileUrl);
    try {
      final launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(fileUri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka tautan file: $e')),
        );
      }
    }
  }

  List<ReportItem> get _displayReports {
    if (_historyYearFilter == 'semua' || _historyYearFilter.isEmpty) {
      return _reports;
    }
    final filtered = _reports.where((r) => r.tahun == _historyYearFilter).toList();
    return filtered.isNotEmpty ? filtered : _reports;
  }

  @override
  Widget build(BuildContext context) {
    final isBatubara = widget.company.type == ReportType.batubara;

    // Ambil tahun unik yang ada di laporan perusahaan ini
    final uniqueYears = _reports
        .map((r) => r.tahun.trim())
        .where((t) => t.isNotEmpty && t != '-')
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final displayList = _displayReports;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 20),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D4D8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Profil Perusahaan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBatubara ? const Color(0xFF18181B) : const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBatubara ? 'BATUBARA' : 'MINERAL',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isBatubara ? const Color(0xFFFBBF24) : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_reports.length} Histori Laporan',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                          const SizedBox(width: 6),
                          _buildModalHeaderEvaluasiBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.company.namaPerusahaan,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF18181B),
                        ),
                      ),
                      Text(
                        'SK IUP: ${widget.company.skIup} • ${widget.company.provinsi}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ekspor Evaluasi Perusahaan (Excel / PDF)',
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                        )
                      : const Icon(Icons.download_rounded, color: Color(0xFF0F766E), size: 22),
                  onSelected: (val) => _exportCompanyEvaluasi(val),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 10),
                          Text('Ekspor ke Excel (.xlsx)', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 10),
                          Text('Ekspor ke PDF (.pdf)', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF71717A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Filter Tahun Khusus Modal Perusahaan
          if (uniqueYears.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildModalYearChip('Semua (${_reports.length})', 'semua'),
                    const SizedBox(width: 6),
                    ...uniqueYears.map((yr) {
                      final count = _reports.where((r) => r.tahun.trim() == yr).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildModalYearChip('$yr ($count)', yr),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 6),

          // Scrollable Area: Rekapitulasi Objek Penjumlahan & Timeline Histori
          Expanded(
            child: _isLoadingAll && _reports.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : ListView(
                    padding: const EdgeInsets.only(top: 2, bottom: 20),
                    children: [
                      // Card Rekapitulasi Pelaporan untuk Tahun yang Dipilih
                      _buildCompanyYearRecapCard(displayList, _historyYearFilter),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(height: 1),
                      ),

                      // Timeline Laporan
                      if (displayList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              'Belum ada histori pelaporan.',
                              style: TextStyle(color: Color(0xFF71717A)),
                            ),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 14, color: Color(0xFF71717A)),
                              const SizedBox(width: 6),
                              Text(
                                'Daftar Laporan Triwulan (${displayList.length})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF52525B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: List.generate(displayList.length, (index) {
                              final rep = displayList[index];
                              return _buildTimelineItem(context, rep, index == 0, index == displayList.length - 1);
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<_SummableMetricDef> _getSummableDefinitions() {
    final isBatubara = widget.company.type == ReportType.batubara;
    if (isBatubara) {
      return const [
        _SummableMetricDef(
          key: 'bkr_kuantitas',
          altKeys: ['bkr', 'kuantitas_bkr'],
          title: 'Kuantitas BKR',
          subTitle: 'Batubara Kualitas Rendah',
          unit: 'ton',
          icon: Icons.layers_outlined,
        ),
        _SummableMetricDef(
          key: 'pbkr_volume',
          altKeys: ['pbkr', 'volume_pbkr'],
          title: 'Volume PBKR',
          subTitle: 'Pemanfaatan BKR',
          unit: 'ton',
          icon: Icons.recycling_outlined,
        ),
        _SummableMetricDef(
          key: 'cm_kuantitas',
          altKeys: ['cm', 'kuantitas_cm'],
          title: 'Cadangan Marginal (CM)',
          subTitle: 'Kuantitas Cadangan',
          unit: 'ton',
          icon: Icons.terrain_outlined,
        ),
        _SummableMetricDef(
          key: 'shp_kuantitas',
          altKeys: ['shp', 'kuantitas_shp', 'pshp_volume'],
          title: 'Sisa Hasil Pengolahan (SHP)',
          subTitle: 'Kuantitas SHP',
          unit: 'ton',
          icon: Icons.filter_alt_outlined,
        ),
        _SummableMetricDef(
          key: 'ctt_kuantitas',
          altKeys: ['ctt', 'kuantitas_ctt'],
          title: 'Cadangan Tdk Tertambang (CTT)',
          subTitle: 'Kuantitas CTT',
          unit: 'ton',
          icon: Icons.block_outlined,
        ),
        _SummableMetricDef(
          key: 'rec_penambangan',
          altKeys: [
            'recovery_penambangan_survey_2_3',
            'recovery_penambangan_truck_2_2',
            'recovery_penambangan_survey_2_2',
            'recovery_penambangan_truck_2_1',
          ],
          title: 'Recovery Penambangan',
          subTitle: 'Rata-rata Penambangan',
          unit: '%',
          icon: Icons.speed_outlined,
          isAverage: true,
        ),
        _SummableMetricDef(
          key: 'rec_pengolahan',
          altKeys: ['recovery_pengolahan_2_5', 'recovery_pengolahan_2_3'],
          title: 'Recovery Pengolahan',
          subTitle: 'Rata-rata Pengolahan',
          unit: '%',
          icon: Icons.precision_manufacturing_outlined,
          isAverage: true,
        ),
      ];
    } else {
      return const [
        _SummableMetricDef(
          key: 'mkr_kuantitas',
          altKeys: ['mkr', 'volume_kuantitas_kr'],
          title: 'Kuantitas MKR',
          subTitle: 'Mineral Kadar Rendah',
          unit: 'tonase',
          icon: Icons.layers_outlined,
        ),
        _SummableMetricDef(
          key: 'pmkr_volume',
          altKeys: ['pmkr', 'volume_kuantitas_pemanfaatan_kr', 'pemanfaatan_mineral_kr'],
          title: 'Volume PMKR',
          subTitle: 'Pemanfaatan MKR',
          unit: 'tonase',
          icon: Icons.recycling_outlined,
        ),
        _SummableMetricDef(
          key: 'cm_kuantitas',
          altKeys: ['cm', 'volume_kuantitas_cm'],
          title: 'Cadangan Marginal (CM)',
          subTitle: 'Kuantitas Cadangan',
          unit: 'tonase',
          icon: Icons.terrain_outlined,
        ),
        _SummableMetricDef(
          key: 'shp_kuantitas',
          altKeys: ['shp', 'volume_kuantitas_shp', 'volume_kuantitas_shpp'],
          title: 'Sisa Hasil Pengolahan (SHP)',
          subTitle: 'Kuantitas SHP',
          unit: 'tonase',
          icon: Icons.filter_alt_outlined,
        ),
        _SummableMetricDef(
          key: 'cmtt_kuantitas',
          altKeys: ['cmtt_kuantitas_cadangan', 'kuantitas_cadangan_ctt'],
          title: 'Cadangan Min. Tdk Tertambang (CMTT)',
          subTitle: 'Kuantitas CMTT',
          unit: 'tonase',
          icon: Icons.block_outlined,
        ),
        _SummableMetricDef(
          key: 'rec_penambangan',
          altKeys: [
            'recovery_penambangan_survey_2_3',
            'recovery_penambangan_truck_2_2',
            'recovery_truck',
          ],
          title: 'Recovery Penambangan',
          subTitle: 'Rata-rata Penambangan',
          unit: '%',
          icon: Icons.speed_outlined,
          isAverage: true,
        ),
        _SummableMetricDef(
          key: 'rec_pengolahan',
          altKeys: [
            'recovery_pemulihan_2_6',
            'recovery_pengolahan_2_3',
          ],
          title: 'Recovery Pengolahan',
          subTitle: 'Rata-rata Pengolahan',
          unit: '%',
          icon: Icons.precision_manufacturing_outlined,
          isAverage: true,
        ),
      ];
    }
  }

  int _getQuarterIndex(String triwulanStr) {
    final t = triwulanStr.toUpperCase().trim();
    // Prioritaskan cek dari IV / 4 ke bawah agar tidak tertukar substring Roman numeral
    if (t.contains('IV') || t.contains('TW 4') || t.contains('TRIWULAN 4') || t == '4') {
      return 4;
    }
    if (t.contains('III') || t.contains('TW 3') || t.contains('TRIWULAN 3') || t == '3') {
      return 3;
    }
    if (t.contains('II') || t.contains('TW 2') || t.contains('TRIWULAN 2') || t == '2') {
      return 2;
    }
    if (t.contains('TW 1') || t.contains('TW I') || t.contains('TRIWULAN 1') || t.contains('TRIWULAN I') || t == 'I' || t == '1') {
      return 1;
    }
    return 0;
  }

  double? _extractMetricFromReport(ReportItem rep, String key, List<String> altKeys) {
    if (rep.metrics.containsKey(key)) {
      final v = _parseNumeric(rep.metrics[key]);
      if (v != null) return v;
    }
    if (rep.rawDetails.containsKey(key)) {
      final v = _parseNumeric(rep.rawDetails[key]);
      if (v != null) return v;
    }
    for (final alt in altKeys) {
      if (rep.metrics.containsKey(alt)) {
        final v = _parseNumeric(rep.metrics[alt]);
        if (v != null) return v;
      }
      if (rep.rawDetails.containsKey(alt)) {
        final v = _parseNumeric(rep.rawDetails[alt]);
        if (v != null) return v;
      }
    }
    return null;
  }

  double? _parseNumeric(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim().replaceAll(' ', '');
    if (str.isEmpty || str == '-' || str == 'null') return null;
    String cleaned;
    if (str.contains(',') && str.contains('.')) {
      if (str.lastIndexOf(',') > str.lastIndexOf('.')) {
        cleaned = str.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = str.replaceAll(',', '');
      }
    } else if (str.contains(',')) {
      cleaned = str.replaceAll(',', '.');
    } else {
      cleaned = str;
    }
    return double.tryParse(cleaned);
  }

  Map<String, double?> _calculateQuarterValuesForDef(
    _SummableMetricDef def,
    List<ReportItem> yearReports,
  ) {
    final Map<int, List<double>> qValues = {1: [], 2: [], 3: [], 4: []};
    final Map<int, bool> qReported = {1: false, 2: false, 3: false, 4: false};

    for (final r in yearReports) {
      final q = _getQuarterIndex(r.triwulan);
      if (q >= 1 && q <= 4) {
        qReported[q] = true;
        final v = _extractMetricFromReport(r, def.key, def.altKeys);
        if (v != null) {
          qValues[q]!.add(v);
        }
      }
    }

    double? computeQ(int q) {
      if (!qReported[q]!) return null;
      final list = qValues[q]!;
      if (list.isEmpty) return 0.0;
      if (def.isAverage) {
        return list.reduce((a, b) => a + b) / list.length;
      } else {
        return list.reduce((a, b) => a + b);
      }
    }

    final q1 = computeQ(1);
    final q2 = computeQ(2);
    final q3 = computeQ(3);
    final q4 = computeQ(4);

    double? total;
    if (def.isAverage) {
      final active = [q1, q2, q3, q4].whereType<double>().toList();
      total = active.isNotEmpty ? active.reduce((a, b) => a + b) / active.length : null;
    } else {
      final active = [q1, q2, q3, q4].whereType<double>().toList();
      total = active.isNotEmpty ? active.reduce((a, b) => a + b) : 0.0;
    }

    return {
      'q1': q1,
      'q2': q2,
      'q3': q3,
      'q4': q4,
      'total': total,
    };
  }

  Map<String, double> _calculateGrandTotalTonase(
    List<ReportItem> yearReports,
    List<_SummableMetricDef> defs,
  ) {
    double gQ1 = 0.0;
    double gQ2 = 0.0;
    double gQ3 = 0.0;
    double gQ4 = 0.0;
    double gTotal = 0.0;

    for (final def in defs) {
      if (def.isAverage) continue;
      final vals = _calculateQuarterValuesForDef(def, yearReports);
      gQ1 += (vals['q1'] ?? 0.0);
      gQ2 += (vals['q2'] ?? 0.0);
      gQ3 += (vals['q3'] ?? 0.0);
      gQ4 += (vals['q4'] ?? 0.0);
      gTotal += (vals['total'] ?? 0.0);
    }

    return {
      'q1': gQ1,
      'q2': gQ2,
      'q3': gQ3,
      'q4': gQ4,
      'total': gTotal,
    };
  }

  String _formatVal(double? val, {bool isPct = false}) {
    if (val == null) return '-';
    if (val == 0.0) return '0,00';
    final formatted = DetailModal.formatIndonesianNumber(val.toStringAsFixed(2));
    return isPct ? '$formatted%' : formatted;
  }

  Widget _buildCompanyYearRecapCard(List<ReportItem> yearReports, String selectedYear) {
    final isSemua = selectedYear == 'semua' || selectedYear.isEmpty;
    final yearTitle = isSemua ? 'SEMUA PERIODE' : 'TAHUN $selectedYear';

    final repQ1 = yearReports.cast<ReportItem?>().firstWhere((r) => _getQuarterIndex(r?.triwulan ?? '') == 1, orElse: () => null);
    final repQ2 = yearReports.cast<ReportItem?>().firstWhere((r) => _getQuarterIndex(r?.triwulan ?? '') == 2, orElse: () => null);
    final repQ3 = yearReports.cast<ReportItem?>().firstWhere((r) => _getQuarterIndex(r?.triwulan ?? '') == 3, orElse: () => null);
    final repQ4 = yearReports.cast<ReportItem?>().firstWhere((r) => _getQuarterIndex(r?.triwulan ?? '') == 4, orElse: () => null);

    final activeYear = selectedYear != 'semua' ? selectedYear : (yearReports.isNotEmpty ? yearReports.first.tahun : '');

    final evalQ1 = _companyEvaluasiByPeriod[EvaluasiPerusahaanService.buildKey(widget.company.namaPerusahaan, repQ1?.tahun ?? activeYear, 'Triwulan I')];
    final evalQ2 = _companyEvaluasiByPeriod[EvaluasiPerusahaanService.buildKey(widget.company.namaPerusahaan, repQ2?.tahun ?? activeYear, 'Triwulan II')];
    final evalQ3 = _companyEvaluasiByPeriod[EvaluasiPerusahaanService.buildKey(widget.company.namaPerusahaan, repQ3?.tahun ?? activeYear, 'Triwulan III')];
    final evalQ4 = _companyEvaluasiByPeriod[EvaluasiPerusahaanService.buildKey(widget.company.namaPerusahaan, repQ4?.tahun ?? activeYear, 'Triwulan IV')];

    final defs = _getSummableDefinitions();
    final isBatubara = widget.company.type == ReportType.batubara;
    final defaultUnit = isBatubara ? 'ton' : 'tonase';
    final grandTotals = _calculateGrandTotalTonase(yearReports, defs);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Solid Obsidian Black
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Toggle Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calculate_outlined, color: Color(0xFFFBBF24), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REKAPITULASI OBJEK PENJUMLAHAN',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        '$yearTitle • Rincian TW 1 - TW 4 & Total Akumulasi',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFFA1A1AA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // View Switcher (Tabel / Kartu)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTableView = !_showTableView;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showTableView ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                          size: 11,
                          color: const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showTableView ? 'Mode Kartu' : 'Mode Tabel',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Keterangan petunjuk klik kotak TW
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 5),
                  const Text(
                    'Klik icon TW ini untuk mengisi evaluasi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),

            // Quarters status bar & Grand total pill (Merah: belum dinilai, Kuning: belum memadai, Hijau: memadai, Abu: belum lapor)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildQuarterBadge(label: 'TW I', quarterIndex: 1, rep: repQ1, eval: evalQ1),
                      const SizedBox(width: 6),
                      _buildQuarterBadge(label: 'TW II', quarterIndex: 2, rep: repQ2, eval: evalQ2),
                      const SizedBox(width: 6),
                      _buildQuarterBadge(label: 'TW III', quarterIndex: 3, rep: repQ3, eval: evalQ3),
                      const SizedBox(width: 6),
                      _buildQuarterBadge(label: 'TW IV', quarterIndex: 4, rep: repQ4, eval: evalQ4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL TONASE (∑)',
                        style: TextStyle(fontSize: 8, color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_formatVal(grandTotals['total'])} $defaultUnit',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content: Table Matrix or Cards
            if (_showTableView)
              _buildRecapTable(yearReports, defs, defaultUnit)
            else
              _buildRecapCardsList(yearReports, defs),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapTable(
    List<ReportItem> yearReports,
    List<_SummableMetricDef> defs,
    String defaultUnit,
  ) {
    final grandTotals = _calculateGrandTotalTonase(yearReports, defs);
    final summableOnly = defs.where((d) => !d.isAverage).toList();
    final averageOnly = defs.where((d) => d.isAverage).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF27272A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 155,
                    child: Text(
                      'Objek Konservasi',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                    ),
                  ),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'TW 1',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'TW 2',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'TW 3',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'TW 4',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 105,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF451A03),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                    ),
                    child: const Text(
                      'TOTAL (∑)',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 45,
                    child: Text(
                      'Satuan',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: Color(0xFFA1A1AA)),
                    ),
                  ),
                ],
              ),
            ),

            // Summable Object Rows
            ...summableOnly.asMap().entries.map((entry) {
              final idx = entry.key;
              final def = entry.value;
              final vals = _calculateQuarterValuesForDef(def, yearReports);
              final isEven = idx % 2 == 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isEven ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 155,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            def.title,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            def.subTitle,
                            style: const TextStyle(fontSize: 8.5, color: Color(0xFFA1A1AA)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatVal(vals['q1']),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: vals['q1'] != null && vals['q1']! > 0 ? Colors.white : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatVal(vals['q2']),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: vals['q2'] != null && vals['q2']! > 0 ? Colors.white : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatVal(vals['q3']),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: vals['q3'] != null && vals['q3']! > 0 ? Colors.white : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatVal(vals['q4']),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: vals['q4'] != null && vals['q4']! > 0 ? Colors.white : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 105,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        _formatVal(vals['total']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        def.unit,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 8.5, color: Color(0xFFA1A1AA)),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Grand Total Row (Tonase)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A).withValues(alpha: 0.9),
                border: const Border(
                  top: BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 155,
                    child: Row(
                      children: [
                        Icon(Icons.functions, size: 12, color: Color(0xFFFBBF24)),
                        SizedBox(width: 4),
                        Text(
                          'TOTAL KUANTITAS (∑)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatVal(grandTotals['q1']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatVal(grandTotals['q2']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatVal(grandTotals['q3']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatVal(grandTotals['q4']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 105,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                    ),
                    child: Text(
                      _formatVal(grandTotals['total']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      defaultUnit,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                    ),
                  ),
                ],
              ),
            ),

            // Average Recovery Rows
            if (averageOnly.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.white.withValues(alpha: 0.03),
                child: const Text(
                  'Kinerja Pemulihan (Recovery) — Rata-rata Persentase (%)',
                  style: TextStyle(fontSize: 8.5, fontStyle: FontStyle.italic, color: Color(0xFFA1A1AA)),
                ),
              ),
              ...averageOnly.map((def) {
                final vals = _calculateQuarterValuesForDef(def, yearReports);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 155,
                        child: Text(
                          def.title,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFFD4D4D8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatVal(vals['q1'], isPct: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFA1A1AA)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatVal(vals['q2'], isPct: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFA1A1AA)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatVal(vals['q3'], isPct: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFA1A1AA)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatVal(vals['q4'], isPct: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFA1A1AA)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 105,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          _formatVal(vals['total'], isPct: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF67E8F9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 45,
                        child: Text(
                          '%',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 8.5, color: Color(0xFFA1A1AA)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecapCardsList(
    List<ReportItem> yearReports,
    List<_SummableMetricDef> defs,
  ) {
    return Column(
      children: defs.map((def) {
        final vals = _calculateQuarterValuesForDef(def, yearReports);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title + Total Badge
              Row(
                children: [
                  Icon(def.icon, size: 14, color: const Color(0xFFFBBF24)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.title,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          def.subTitle,
                          style: const TextStyle(fontSize: 8.5, color: Color(0xFFA1A1AA)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF451A03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                    ),
                    child: Text(
                      'TOTAL: ${_formatVal(vals['total'], isPct: def.isAverage)} ${def.isAverage ? '' : def.unit}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 4 Quarters Strip
              Row(
                children: [
                  _buildQuarterValueTile('TW 1', vals['q1'], def.isAverage, def.unit),
                  const SizedBox(width: 4),
                  _buildQuarterValueTile('TW 2', vals['q2'], def.isAverage, def.unit),
                  const SizedBox(width: 4),
                  _buildQuarterValueTile('TW 3', vals['q3'], def.isAverage, def.unit),
                  const SizedBox(width: 4),
                  _buildQuarterValueTile('TW 4', vals['q4'], def.isAverage, def.unit),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuarterValueTile(String label, double? val, bool isPct, String unit) {
    final hasVal = val != null && val > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: hasVal ? const Color(0xFF27272A) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasVal ? const Color(0xFF52525B) : Colors.white.withValues(alpha: 0.05),
            width: 0.6,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFA1A1AA)),
            ),
            const SizedBox(height: 1),
            Text(
              _formatVal(val, isPct: isPct),
              style: TextStyle(
                fontSize: 9,
                fontWeight: hasVal ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'monospace',
                color: hasVal ? Colors.white : const Color(0xFF71717A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterBadge({
    required String label,
    required int quarterIndex,
    required ReportItem? rep,
    required EvaluasiPerusahaanItem? eval,
  }) {
    final bool hasReport = rep != null;
    final bool isEvaluated = eval != null;
    final bool isMemadai = isEvaluated && eval.isMemadai;

    final Color bg = hasReport ? const Color(0xFF064E3B) : const Color(0xFF27272A);
    final Color border = hasReport ? const Color(0xFF10B981) : const Color(0xFF3F3F46);
    final Color titleColor = hasReport ? const Color(0xFF34D399) : const Color(0xFFA1A1AA);
    final Color subColor = hasReport ? const Color(0xFF6EE7B7) : const Color(0xFF71717A);
    final String subText = hasReport ? '✓ Lapor' : 'Belum Lapor';

    // Notifikasi status evaluasi di atas kotak TW:
    // Merah: Belum dievaluasi
    // Kuning: Belum memadai
    // Hijau: Memadai
    Color? notifColor;
    if (hasReport) {
      if (!isEvaluated) {
        notifColor = const Color(0xFFEF4444);
      } else if (!isMemadai) {
        notifColor = const Color(0xFFF59E0B);
      } else {
        notifColor = const Color(0xFF10B981);
      }
    } else if (isEvaluated) {
      notifColor = isMemadai ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    }

    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              mouseCursor: hasReport ? SystemMouseCursors.click : SystemMouseCursors.basic,
              onTap: hasReport ? () => _showQuarterEvaluasiDetail(quarterIndex, rep, eval) : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border, width: 1.1),
                  boxShadow: hasReport
                      ? [
                          BoxShadow(
                            color: border.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: 7.8,
                        fontWeight: FontWeight.bold,
                        color: subColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (notifColor != null)
            Positioned(
              top: -8,
              right: -5,
              child: IgnorePointer(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: notifColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: notifColor.withValues(alpha: 0.65),
                        blurRadius: 5,
                        spreadRadius: 0.8,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showQuarterEvaluasiDetail(int q, ReportItem? rep, EvaluasiPerusahaanItem? eval) {
    final twLabels = ['Triwulan I', 'Triwulan II', 'Triwulan III', 'Triwulan IV'];
    final twLabel = twLabels[q - 1];
    final year = rep?.tahun ?? (_historyYearFilter != 'semua' ? _historyYearFilter : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isEvaluated = eval != null;
        final isMemadai = isEvaluated && eval.isMemadai;
        final Color primaryColor = !isEvaluated
            ? const Color(0xFFDC2626)
            : (isMemadai ? const Color(0xFF15803D) : const Color(0xFFB45309));
        final Color bgColor = !isEvaluated
            ? const Color(0xFFFEF2F2)
            : (isMemadai ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB));
        final Color borderColor = !isEvaluated
            ? const Color(0xFFFECACA)
            : (isMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A));

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 14,
            left: 18,
            right: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0 ? MediaQuery.of(ctx).padding.bottom + 14 : 24),
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              // Header Triwulan
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '$twLabel $year'.trim(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.company.namaPerusahaan,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      !isEvaluated
                          ? Icons.cancel_outlined
                          : (isMemadai ? Icons.check_circle_rounded : Icons.warning_amber_rounded),
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !isEvaluated
                                ? 'Status Evaluasi: Belum Dinilai'
                                : (isMemadai ? 'Status Evaluasi: Memadai (Lolos 7 Objek)' : 'Status Evaluasi: Belum Memadai'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          if (isEvaluated && eval.namaPetugas.isNotEmpty)
                            Text(
                              'Petugas: ${eval.namaPetugas}${eval.updatedAt != null ? ' • ${_formatDate(eval.updatedAt!)}' : ''}',
                              style: TextStyle(fontSize: 10.5, color: primaryColor.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Rincian 7 Objek Evaluasi
              const Text(
                'Rincian 7 Objek Evaluasi Konservasi:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: SingleChildScrollView(
                  child: !isEvaluated
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Triwulan ini belum dievaluasi oleh petugas evaluator.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      : _buildQuarterObjekList(eval),
                ),
              ),

              const SizedBox(height: 10),

              // Tombol Aksi
              if (isEvaluated) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openQuarterEvaluasi(q, rep, eval);
                        },
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: Text(
                          'Ubah Evaluasi $twLabel',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleHapusPeriodEvaluasi(eval);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text(
                        'Hapus',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openQuarterEvaluasi(q, rep, null);
                    },
                    icon: const Icon(Icons.add_task, size: 16),
                    label: Text(
                      'Input Evaluasi $twLabel Sekarang',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuarterObjekList(EvaluasiPerusahaanItem eval) {
    const Map<String, String> labels = {
      'format_laporan': '1. Format Laporan',
      'recovery_penambangan': '2. Recovery Penambangan',
      'recovery_pengolahan': '3. Recovery Pengolahan',
      'cadangan_marginal': '4. Cadangan Marginal',
      'kualitas_kadar_rendah': '5. Batubara/Mineral Kualitas Rendah',
      'sisa_hasil_pengolahan': '6. Sisa Hasil Pengolahan',
      'cadangan_tidak_tertambang': '7. Cadangan Tidak Tertambang',
    };

    final details = eval.detailEvaluasi;

    return Column(
      children: labels.entries.map((entry) {
        final key = entry.key;
        final label = entry.value;
        final objData = details[key];
        final bool isObjMemadai = objData is Map
            ? (objData['status']?.toString() == 'Memadai')
            : true;
        final String tanggapan = objData is Map ? (objData['tanggapan']?.toString() ?? '') : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isObjMemadai ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isObjMemadai ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isObjMemadai ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14,
                    color: isObjMemadai ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isObjMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isObjMemadai ? 'Memadai' : 'Belum Memadai',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isObjMemadai ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isObjMemadai && tanggapan.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    'Tanggapan: $tanggapan',
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF7F1D1D)),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }



  Widget _buildModalYearChip(String label, String value) {
    final isSelected = _historyYearFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _historyYearFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFF52525B),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, ReportItem rep, bool isFirst, bool isLast) {
    final isProd = rep.statusProduksiCode == 'P';
    final hasLaporan = rep.laporanFile != null && rep.laporanFile!.isNotEmpty && rep.laporanFile != '-';
    final hasPeta = rep.petaFile != null && rep.petaFile!.isNotEmpty && rep.petaFile != '-';

    final periodKey = EvaluasiPerusahaanService.buildKey(rep.namaPerusahaan, rep.tahun, rep.triwulan);
    final periodEval = _companyEvaluasiByPeriod[periodKey];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Periode & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${rep.triwulan} ${rep.tahun}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isProd ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isProd ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  rep.statusProduksi,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isProd ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Badge Evaluasi khusus triwulan ini
              _buildTimelineEvaluasiBadge(periodEval),
              const Spacer(),
              Text(
                'Input: ${rep.waktuInput.length > 10 ? rep.waktuInput.substring(0, 10) : rep.waktuInput}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sistem Penambangan & Komoditas
          Text(
            'Sistem: ${rep.sistemPenambangan}${rep.komoditas != null ? " • Komoditas: ${rep.komoditas}" : ""}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF3F3F46)),
          ),

          // Key metrics summary
          if (rep.metrics.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rep.metrics.entries
                  .where((e) =>
                      e.value != null &&
                      e.value.toString().trim().isNotEmpty &&
                      e.value.toString().trim() != '-' &&
                      e.value.toString().trim() != 'null' &&
                      e.value.toString().trim() != '0' &&
                      e.value.toString().trim() != '0.00' &&
                      e.value.toString().trim() != '0,00')
                  .take(3)
                  .map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${DetailModal.formatLabel(e.key)}: ${DetailModal.formatDisplayValue(e.key, e.value, widget.company.type)}',
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF52525B)),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 10),

          // Action Buttons: Unduh Dokumen, Unduh Peta, Evaluasi Triwulan, Rincian
          Row(
            children: [
              if (hasLaporan) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                  onPressed: () => _openFile(context, rep.laporanFile!, fileKind: 'laporan'),
                  icon: const Icon(Icons.picture_as_pdf, size: 13),
                  label: const Text('Laporan PDF', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 6),
              ],
              if (hasPeta) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                  ),
                  onPressed: () => _openFile(context, rep.petaFile!, fileKind: 'peta'),
                  icon: const Icon(Icons.map, size: 13),
                  label: const Text('Peta Teknis', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              // Tombol Evaluasi per Triwulan
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  foregroundColor: periodEval == null
                      ? const Color(0xFFDC2626)
                      : (periodEval.isMemadai ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                  side: BorderSide(
                    color: periodEval == null
                        ? const Color(0xFFFECACA)
                        : (periodEval.isMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                  ),
                ),
                onPressed: () => _openPeriodEvaluasi(rep),
                icon: Icon(periodEval == null ? Icons.add_task : Icons.edit_note, size: 13),
                label: Text(
                  periodEval == null ? 'Evaluasi' : 'Ubah Evaluasi',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF18181B),
                ),
                onPressed: () {
                  DetailModal.show(context, rep, widget.company.type);
                },
                icon: const Icon(Icons.open_in_new, size: 13),
                label: const Text('Rincian', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvaluasiBadge(EvaluasiPerusahaanItem? eval) {
    final bool isEvaluated = eval != null;
    final bool isMemadai = isEvaluated && eval.isMemadai;

    final Color bg = !isEvaluated
        ? const Color(0xFFFEF2F2)
        : (isMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFFFBEB));
    final Color border = !isEvaluated
        ? const Color(0xFFFECACA)
        : (isMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A));
    final Color text = !isEvaluated
        ? const Color(0xFFDC2626)
        : (isMemadai ? const Color(0xFF15803D) : const Color(0xFFB45309));
    final IconData icon = !isEvaluated
        ? Icons.cancel_outlined
        : (isMemadai ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded);
    final String label = !isEvaluated
        ? 'Belum Evaluasi'
        : (isMemadai ? 'Memadai' : 'Belum Memadai');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
