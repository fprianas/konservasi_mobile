import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/binwas_model.dart';
import '../services/binwas_excel_exporter.dart';
import '../services/binwas_service.dart';
import '../widgets/binwas_chart.dart';
import '../widgets/delete_inspeksi_dialog.dart';
import 'laporan_khusus_page.dart';

/// Halaman Monitoring Binwas Khusus Wilayah Provinsi (Read-Only)
/// Digunakan oleh tim utama untuk memantau, memeriksa, dan mengevaluasi hasil input
/// dari para petugas pengawas di 34 provinsi yang menggunakan aplikasi Binwas Mobile.
class BinwasProvinsiReadonlyPage extends StatefulWidget {
  const BinwasProvinsiReadonlyPage({super.key});

  @override
  State<BinwasProvinsiReadonlyPage> createState() => _BinwasProvinsiReadonlyPageState();
}

class _BinwasProvinsiReadonlyPageState extends State<BinwasProvinsiReadonlyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter Global
  String _selectedTipe = 'semua'; // semua, batubara, mineral
  String _selectedTahun = '2026';
  String _selectedTriwulan = 'semua';
  String _selectedProvinsi = 'semua';
  List<String> _provinsiList = [];

  // State Tab 1: Dashboard Rekap
  bool _isLoadingDashboard = false;
  BinwasDashboardData? _dashboardData;
  String? _errorDashboard;
  int _chartTabIndex = 0; // 0: Kategori, 1: Komoditas, 2: Objek Konservasi, 3: Semua

  // State Tab 2: Riwayat Inspeksi Lapangan
  bool _isLoadingHistory = false;
  List<BinwasInspeksiRecord> _historyRecords = [];
  String? _errorHistory;
  final TextEditingController _historySearchController = TextEditingController();
  String _historySearchQuery = '';

  // State Tab 3: Matriks Rekapitulasi & Excel
  bool _isLoadingMatrix = false;
  BinwasMatrixData? _matrixData;
  String? _errorMatrix;
  bool _isExportingExcel = false;
  int? _selectedMatrixKategoriId;

  // 34 Provinsi Indonesia (Fallback default)
  static const List<String> kDefaultProvinsi = [
    'ACEH',
    'BALI',
    'BANTEN',
    'BENGKULU',
    'D.I. YOGYAKARTA',
    'DKI JAKARTA',
    'GORONTALO',
    'JAMBI',
    'JAWA BARAT',
    'JAWA TENGAH',
    'JAWA TIMUR',
    'KALIMANTAN BARAT',
    'KALIMANTAN SELATAN',
    'KALIMANTAN TENGAH',
    'KALIMANTAN TIMUR',
    'KALIMANTAN UTARA',
    'KEPULAUAN BANGKA BELITUNG',
    'KEPULAUAN RIAU',
    'LAMPUNG',
    'MALUKU',
    'MALUKU UTARA',
    'NUSA TENGGARA BARAT',
    'NUSA TENGGARA TIMUR',
    'PAPUA',
    'PAPUA BARAT',
    'PAPUA BARAT DAYA',
    'PAPUA PEGUNUNGAN',
    'PAPUA SELATAN',
    'PAPUA TENGAH',
    'RIAU',
    'SULAWESI BARAT',
    'SULAWESI SELATAN',
    'SULAWESI TENGAH',
    'SULAWESI TENGGARA',
    'SULAWESI UTARA',
    'SUMATERA BARAT',
    'SUMATERA SELATAN',
    'SUMATERA UTARA',
  ];

  @override
  void initState() {
    super.initState();
    _provinsiList = List.from(kDefaultProvinsi);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) _loadDashboard();
        if (_tabController.index == 1) _loadHistory();
        if (_tabController.index == 2) _loadMatrix();
      }
    });

    _loadProvinsiFilters();
    _loadDashboard();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  // ================= LOAD DATA =================
  Future<void> _loadProvinsiFilters() async {
    try {
      final filters = await BinwasService.fetchFilters(_selectedTipe);
      if (filters['provinsi'] is List) {
        final list = (filters['provinsi'] as List)
            .map((p) => (p['nama_provinsi'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        list.sort();
        if (list.isNotEmpty && mounted) {
          setState(() {
            _provinsiList = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _errorDashboard = null;
    });

    try {
      final data = await BinwasService.fetchDashboard(
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        provinsi: _selectedProvinsi,
        asalInput: 'provinsi',
      );
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorDashboard = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _errorHistory = null;
    });

    try {
      final list = await BinwasService.fetchHistory(
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        provinsi: _selectedProvinsi,
        asalInput: 'provinsi',
      );
      if (mounted) {
        setState(() {
          _historyRecords = list;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorHistory = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadMatrix() async {
    setState(() {
      _isLoadingMatrix = true;
      _errorMatrix = null;
    });

    try {
      final data = await BinwasService.fetchMatrix(
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        provinsi: _selectedProvinsi,
        asalInput: 'provinsi',
      );
      if (mounted) {
        setState(() {
          _matrixData = data;
          _isLoadingMatrix = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMatrix = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingMatrix = false;
        });
      }
    }
  }

  void _refreshAll() {
    _loadDashboard();
    _loadHistory();
    if (_tabController.index == 2) {
      _loadMatrix();
    }
  }

  // ================= EXPORT EXCEL =================
  Future<void> _exportMatrixExcel() async {
    if (_matrixData == null || _matrixData!.columns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data matriks untuk diekspor pada filter ini.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isExportingExcel = true);
    try {
      final result = await BinwasExcelExporter.exportMatrix(
        matrixData: _matrixData!,
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        dashboardData: _dashboardData,
      );

      if (!mounted) return;
      setState(() => _isExportingExcel = false);

      if (result.success && result.filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message, style: const TextStyle(fontSize: 12))),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Buka File',
              textColor: Colors.yellowAccent,
              onPressed: () {
                OpenFilex.open(result.filePath!);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExportingExcel = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export Excel: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ================= DETAIL MODAL (READ ONLY) =================
  void _openDetailModal(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
    );

    try {
      final detail = await BinwasService.fetchDetail(id);
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _BinwasProvinsiDetailModal(
            record: detail,
            onRecordDeleted: () {
              _loadDashboard();
              _loadHistory();
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildReadOnlyBanner(),
            _buildFilterBar(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildHistoryTab(),
                  _buildMatrixTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. TOP BAR
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.domain_verification, color: Color(0xFF1E3A8A), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Binwas (Provinsi)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E40AF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'READ ONLY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Monitoring Laporan Hasil Pengawasan 34 Provinsi',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A), size: 22),
                      tooltip: 'Segarkan Data',
                      onPressed: _refreshAll,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.table_chart, size: 16),
                    label: const Text('Laporan Khusus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => LaporanKhususPage(
                            isCentral: false,
                            initialProvinsi: _selectedProvinsi != 'semua' ? _selectedProvinsi : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          // Desktop / Tablet (Single Row)
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.domain_verification, color: Color(0xFF1E3A8A), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Binwas (Provinsi)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'READ ONLY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Monitoring Laporan Hasil Pengawasan 34 Provinsi',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Laporan Khusus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => LaporanKhususPage(
                        isCentral: false,
                        initialProvinsi: _selectedProvinsi != 'semua' ? _selectedProvinsi : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A), size: 22),
                tooltip: 'Segarkan Data',
                onPressed: _refreshAll,
              ),
            ],
          );
        },
      ),
    );
  }

  // 2. READ-ONLY BANNER
  Widget _buildReadOnlyBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft Blue
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1D4ED8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Pemantauan Resmi: Menampilkan seluruh data inspeksi yang diinput oleh petugas lapangan provinsi melalui Binwas Mobile.',
              style: TextStyle(
                fontSize: 10.5,
                color: Color(0xFF1E40AF),
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. FILTER BAR
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filter Provinsi
            _buildDropdownChip(
              icon: Icons.location_on_outlined,
              label: _selectedProvinsi == 'semua'
                  ? 'Semua Provinsi'
                  : (_selectedProvinsi.length > 15
                      ? '${_selectedProvinsi.substring(0, 13)}...'
                      : _selectedProvinsi),
              onTap: _showProvinsiPicker,
              isActive: _selectedProvinsi != 'semua',
            ),
            const SizedBox(width: 6),

            // Filter Komoditas
            _buildDropdownChip(
              icon: Icons.category_outlined,
              label: _selectedTipe == 'semua'
                  ? 'Semua Sektor'
                  : (_selectedTipe == 'batubara' ? 'Batubara' : 'Mineral'),
              onTap: _showTipePicker,
              isActive: _selectedTipe != 'semua',
            ),
            const SizedBox(width: 6),

            // Filter Triwulan
            _buildDropdownChip(
              icon: Icons.calendar_today_outlined,
              label: _selectedTriwulan == 'semua' ? 'Semua TW' : _selectedTriwulan,
              onTap: _showTriwulanPicker,
              isActive: _selectedTriwulan != 'semua',
            ),
            const SizedBox(width: 6),

            // Filter Tahun
            _buildDropdownChip(
              icon: Icons.event_note_outlined,
              label: _selectedTahun,
              onTap: _showTahunPicker,
              isActive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E3A8A).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 15,
              color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // 4. TAB BAR
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF475569),
        indicator: BoxDecoration(
          color: const Color(0xFF1E3A8A), // Provincial Blue Accent
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'Riwayat Lapangan'),
          Tab(text: 'Matriks & Excel'),
        ],
      ),
    );
  }

  // ================= TAB 1: DASHBOARD REKAP =================
  Widget _buildDashboardTab() {
    if (_isLoadingDashboard) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
    }

    if (_errorDashboard != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat rekapitulasi: $_errorDashboard',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final d = _dashboardData;
    if (d == null) {
      return const Center(child: Text('Data tidak tersedia'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF1E3A8A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        children: [
          // KPI GRID
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Total Laporan',
                  d.totalInspeksi == 0 ? '0 (Nihil)' : '${d.totalInspeksi}',
                  Icons.assignment_turned_in,
                  const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKPICard(
                  'Total Temuan',
                  d.totalTemuan == 0 ? '0 (Nihil)' : '${d.totalTemuan}',
                  Icons.warning_amber_rounded,
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Perusahaan',
                  d.totalPerusahaan == 0 ? '0 (Nihil)' : '${d.totalPerusahaan}',
                  Icons.business_outlined,
                  const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKPICard(
                  'Rata-rata/Lap',
                  d.totalInspeksi == 0 ? '0.0 (Nihil)' : d.rataRataTemuan.toStringAsFixed(1),
                  Icons.analytics_outlined,
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (d.totalInspeksi == 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DATA MASIH NIHIL',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Belum Ada Laporan Binwas dari Provinsi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Belum ada hasil inspeksi yang diinput oleh petugas provinsi untuk filter yang dipilih. Status pemantauan saat ini masih NIHIL.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.35),
                  ),
                ],
              ),
            ),
          ],

          // CHART SELECTOR & VISUALIZATION
          _buildChartSection(d),
          const SizedBox(height: 14),

          // BREAKDOWN PER KATEGORI TEMUAN
          _buildCardContainer(
            title: 'Distribusi Temuan per Kategori',
            icon: Icons.pie_chart_outline_rounded,
            child: Column(
              children: d.rekapKategori.map((k) {
                return _buildProgressRow(
                  label: k.namaKategori,
                  count: k.jumlahTemuan,
                  percentage: k.persentase,
                  color: const Color(0xFF1E3A8A),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // BREAKDOWN PER OBJEK KONSERVASI
          _buildCardContainer(
            title: 'Distribusi per Objek Konservasi',
            icon: Icons.hub_outlined,
            child: Column(
              children: d.rekapObjekKonservasi.map((obj) {
                return _buildProgressRow(
                  label: obj.objekKonservasi,
                  count: obj.jumlahTemuan,
                  percentage: obj.persentase,
                  color: const Color(0xFF0284C7),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BinwasDashboardData d) {
    final kategoriItems = BinwasChartPalette.fromKategori(d.rekapKategori);
    final komoditasItems = BinwasChartPalette.fromKomoditas(d.rekapKomoditas);
    final objekItems = BinwasChartPalette.fromObjek(d.rekapObjekKonservasi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab switcher grafik
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildChartTabItem(0, 'Kategori', Icons.category_outlined),
              _buildChartTabItem(1, 'Komoditas', Icons.pie_chart_outline),
              _buildChartTabItem(2, 'Objek Konservasi', Icons.shield_outlined),
              _buildChartTabItem(3, 'Semua', Icons.grid_view_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_chartTabIndex == 0)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Kategori Temuan',
            subtitle: 'Proporsi temuan berdasarkan area fasilitas operasional tambang',
            icon: Icons.category_outlined,
            items: kategoriItems,
            isDonut: true,
            centerLabel: 'Kategori',
          )
        else if (_chartTabIndex == 1)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Komoditas Tambang',
            subtitle: 'Proporsi temuan berdasarkan jenis komoditas bahan galian',
            icon: Icons.pie_chart,
            items: komoditasItems,
            isDonut: false,
            centerLabel: 'Komoditas',
          )
        else if (_chartTabIndex == 2)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Objek Konservasi',
            subtitle: 'Proporsi temuan berdasarkan kaidah teknis konservasi',
            icon: Icons.shield_outlined,
            items: objekItems,
            isDonut: true,
            centerLabel: 'Objek',
          )
        else ...[
          BinwasPieDonutCard(
            title: 'Rekapitulasi Kategori Temuan',
            subtitle: 'Proporsi temuan berdasarkan area fasilitas operasional',
            icon: Icons.category_outlined,
            items: kategoriItems,
            isDonut: true,
            centerLabel: 'Kategori',
          ),
          const SizedBox(height: 12),
          BinwasPieDonutCard(
            title: 'Rekapitulasi Komoditas Tambang',
            subtitle: 'Proporsi temuan berdasarkan komoditas galian',
            icon: Icons.pie_chart,
            items: komoditasItems,
            isDonut: false,
            centerLabel: 'Komoditas',
          ),
          const SizedBox(height: 12),
          BinwasPieDonutCard(
            title: 'Rekapitulasi Objek Konservasi',
            subtitle: 'Proporsi temuan berdasarkan sasaran teknis konservasi',
            icon: Icons.shield_outlined,
            items: objekItems,
            isDonut: true,
            centerLabel: 'Objek',
          ),
        ],
      ],
    );
  }

  Widget _buildChartTabItem(int index, String label, IconData icon) {
    final isSelected = _chartTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _chartTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int count,
    required double percentage,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                count > 0 ? color : const Color(0xFFE2E8F0),
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: RIWAYAT LAPANGAN =================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
    }

    if (_errorHistory != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat riwayat: $_errorHistory', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _loadHistory, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    // Filter lokal berdasarkan search bar
    final filtered = _historyRecords.where((r) {
      if (_historySearchQuery.isEmpty) return true;
      final q = _historySearchQuery.toLowerCase();
      return r.namaPerusahaan.toLowerCase().contains(q) ||
          r.namaPetugas.toLowerCase().contains(q) ||
          r.namaProvinsi.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar Riwayat
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: TextField(
            controller: _historySearchController,
            decoration: InputDecoration(
              hintText: 'Cari perusahaan, petugas provinsi, atau wilayah...',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _historySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _historySearchController.clear();
                        setState(() => _historySearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (val) => setState(() => _historySearchQuery = val.trim()),
          ),
        ),

        // List View
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_historyRecords.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle_outline, size: 16, color: Color(0xFFD97706)),
                                SizedBox(width: 6),
                                Text(
                                  'DATA MASIH NIHIL',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E), letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum Ada Riwayat Laporan Provinsi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Belum ada hasil inspeksi yang dilaporkan oleh petugas provinsi pada kriteria ini. Data riwayat saat ini berstatus NIHIL.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, height: 1.4),
                          ),
                        ] else ...[
                          const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 10),
                          Text(
                            'Tidak ada hasil pencarian untuk "$_historySearchQuery"',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: const Color(0xFF1E3A8A),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final r = filtered[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openDetailModal(r.id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: r.tipeKomoditas == 'batubara'
                                            ? const Color(0xFF18181B)
                                            : const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.tipeKomoditas.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      '${r.triwulan} ${r.tahun}',
                                      style: const TextStyle(
                                          fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r.namaPerusahaan,
                                  style: const TextStyle(
                                      fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        '${r.namaProvinsi} • Izin: ${r.jenisIzin}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF1E3A8A)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Petugas: ${r.namaPetugas}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: r.totalTemuan > 0
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            r.totalTemuan > 0 ? '${r.totalTemuan} Temuan' : 'Nol Temuan (Patuh)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: r.totalTemuan > 0
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                          tooltip: 'Hapus Data Inspeksi Provinsi',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            DeleteInspeksiDialog.show(
                                              context,
                                              idInspeksi: r.id,
                                              namaPerusahaan: r.namaPerusahaan,
                                              onDeleted: () {
                                                _loadDashboard();
                                                _loadHistory();
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ================= TAB 3: MATRIKS & EXCEL =================
  Widget _buildMatrixTab() {
    if (_isLoadingMatrix) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
    }

    if (_errorMatrix != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_chart_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat matriks: $_errorMatrix',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: _loadMatrix,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final m = _matrixData;
    if (m == null || m.columns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            const Text(
              'Belum ada data laporan inspeksi provinsi untuk filter ini.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: _loadMatrix,
              child: const Text('Muat Ulang', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Top Bar Matriks: Info & Kategori Filter Chips
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Matriks Temuan (${m.columns.length} Perusahaan)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Provinsi: ${_selectedProvinsi == 'semua' ? 'Semua' : _selectedProvinsi}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMatrixKategoriChip('Semua Kategori', null),
                        ...m.rekapKategori.map(
                          (kat) => _buildMatrixKategoriChip(kat.namaKategori, kat.idKategori),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // SPREADSHEET TABLE
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildMatrixDataTable(m),
                ),
              ),
            ),
          ],
        ),

        // FLOATING ACTION BUTTON: EXPORT EXCEL
        Positioned(
          bottom: 24,
          right: 20,
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF15803D), // Excel Emerald Green
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: _isExportingExcel ? null : _exportMatrixExcel,
            icon: _isExportingExcel
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_rounded, size: 20),
            label: Text(
              _isExportingExcel ? 'Mengekspor...' : 'Export Excel (.xlsx)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixKategoriChip(String label, int? id) {
    final isSelected = _selectedMatrixKategoriId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedMatrixKategoriId = id;
          });
        },
        selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF1E3A8A),
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF475569),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildMatrixDataTable(BinwasMatrixData m) {
    final displayedCategories = _selectedMatrixKategoriId == null
        ? m.rekapKategori
        : m.rekapKategori.where((k) => k.idKategori == _selectedMatrixKategoriId).toList();

    final List<DataRow> rows = [];

    for (var kat in displayedCategories) {
      final katRows = m.rows.where((r) => r.idKategori == kat.idKategori).toList();
      for (var r in katRows) {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text(r.namaKategori, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(r.objekKonservasi, style: const TextStyle(fontSize: 9.5)),
              )),
              DataCell(SizedBox(
                width: 200,
                child: Text(r.deskripsiTemuan, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              )),
              DataCell(Center(
                child: Text(
                  '${r.jumlah}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: r.jumlah > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              )),
              ...m.columns.map((c) {
                final val = r.scores[c.idInspeksi.toString()] ?? 0;
                return DataCell(
                  Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: val == 1 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        val.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: val == 1 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }

      // Baris Subtotal Kategori
      rows.add(
        DataRow(
          color: WidgetStateProperty.all(const Color(0xFFFEF3C7).withValues(alpha: 0.6)),
          cells: [
            DataCell(
              Text(
                'SUBTOTAL ${kat.namaKategori.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFFB45309)),
              ),
            ),
            const DataCell(Center(child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))))),
            DataCell(
              Text(
                'Subtotal temuan ${kat.namaKategori}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF78350F)),
              ),
            ),
            DataCell(Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kat.totalTemuan > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${kat.totalTemuan}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                ),
              ),
            )),
            ...m.columns.map((c) {
              int subtotalCompany = 0;
              for (var row in katRows) {
                subtotalCompany += (row.scores[c.idInspeksi.toString()] ?? 0);
              }
              return DataCell(
                Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: subtotalCompany > 0 ? const Color(0xFFFDE68A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$subtotalCompany',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        color: subtotalCompany > 0 ? const Color(0xFF92400E) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }

    return DataTable(
      headingRowHeight: 46,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 52,
      columnSpacing: 16,
      headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
      columns: [
        const DataColumn(
          label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
        ),
        const DataColumn(
          label: Text('Objek', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
        ),
        const DataColumn(
          label: Text('Deskripsi Temuan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
        ),
        const DataColumn(
          label: Text('Jml', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
        ),
        ...m.columns.map(
          (c) => DataColumn(
            label: SizedBox(
              width: 90,
              child: Text(
                c.namaPerusahaan,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
      rows: rows,
    );
  }

  // ================= PICKER MODALS =================
  void _showProvinsiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Pilih Provinsi Pemantauan',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.public, color: Color(0xFF1E3A8A)),
                        title: const Text('Semua Provinsi (Seluruh Indonesia)', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: _selectedProvinsi == 'semua',
                        onTap: () {
                          setState(() => _selectedProvinsi = 'semua');
                          Navigator.pop(ctx);
                          _refreshAll();
                        },
                      ),
                      const Divider(height: 1),
                      ..._provinsiList.map((p) => ListTile(
                            title: Text(p, style: const TextStyle(fontSize: 13)),
                            selected: _selectedProvinsi == p,
                            onTap: () {
                              setState(() => _selectedProvinsi = p);
                              Navigator.pop(ctx);
                              _refreshAll();
                            },
                          )),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTipePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Sektor Komoditas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ListTile(
              title: const Text('Semua Sektor (Batubara & Mineral)'),
              selected: _selectedTipe == 'semua',
              onTap: () {
                setState(() => _selectedTipe = 'semua');
                Navigator.pop(ctx);
                _refreshAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain, color: Color(0xFF18181B)),
              title: const Text('Batubara'),
              selected: _selectedTipe == 'batubara',
              onTap: () {
                setState(() => _selectedTipe = 'batubara');
                Navigator.pop(ctx);
                _refreshAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.diamond, color: Color(0xFF0284C7)),
              title: const Text('Mineral'),
              selected: _selectedTipe == 'mineral',
              onTap: () {
                setState(() => _selectedTipe = 'mineral');
                Navigator.pop(ctx);
                _refreshAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTriwulanPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Triwulan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ...['semua', 'Triwulan 1', 'Triwulan 2', 'Triwulan 3', 'Triwulan 4'].map(
              (tw) => ListTile(
                title: Text(tw == 'semua' ? 'Semua Triwulan' : tw),
                selected: _selectedTriwulan == tw,
                onTap: () {
                  setState(() => _selectedTriwulan = tw);
                  Navigator.pop(ctx);
                  _refreshAll();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTahunPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Tahun Evaluasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ...['2026', '2025', '2024'].map(
              (th) => ListTile(
                title: Text(th),
                selected: _selectedTahun == th,
                onTap: () {
                  setState(() => _selectedTahun = th);
                  Navigator.pop(ctx);
                  _refreshAll();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// MODAL DETAIL INSPEKSI (READ ONLY)
// =========================================================================
class _BinwasProvinsiDetailModal extends StatelessWidget {
  final BinwasInspeksiRecord record;
  final VoidCallback? onRecordDeleted;

  const _BinwasProvinsiDetailModal({
    required this.record,
    this.onRecordDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final temuanList = r.items.where((i) => i.adaTemuan).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'READ ONLY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Detail Pengawasan Lapangan Provinsi',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus Data Inspeksi Provinsi',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                  onPressed: () {
                    DeleteInspeksiDialog.show(
                      context,
                      idInspeksi: r.id,
                      namaPerusahaan: r.namaPerusahaan,
                      onDeleted: () {
                        onRecordDeleted?.call();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.namaPerusahaan,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildMiniBadge('Sektor: ${r.tipeKomoditas.toUpperCase()}'),
                          const SizedBox(width: 6),
                          _buildMiniBadge('Wilayah: ${r.namaProvinsi}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Izin: ${r.jenisIzin}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text('Tanggal: ${r.tanggalInspeksi} (${r.triwulan} ${r.tahun})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 13, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 4),
                          Text('Petugas Lapangan: ${r.namaPetugas}',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        ],
                      ),
                      if (r.catatanUmum != null && r.catatanUmum!.isNotEmpty) ...[
                        const Divider(height: 16),
                        const Text('Catatan Petugas:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 2),
                        Text(r.catatanUmum!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            DeleteInspeksiDialog.show(
                              context,
                              idInspeksi: r.id,
                              namaPerusahaan: r.namaPerusahaan,
                              onDeleted: () {
                                onRecordDeleted?.call();
                                Navigator.pop(context);
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Hapus Data Inspeksi Provinsi',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Butir Temuan (${temuanList.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      temuanList.isEmpty ? 'Patuh / Tidak Ada Temuan' : '${temuanList.length} Butir Pelanggaran',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: temuanList.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // List Items
                if (temuanList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF15803D), size: 18),
                        SizedBox(width: 8),
                        Text('Perusahaan dinyatakan Patuh terhadap seluruh butir konservasi.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  ...temuanList.map((it) => _buildTemuanItemCard(context, it)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
    );
  }

  Widget _buildTemuanItemCard(BuildContext context, BinwasItemDetail it) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  it.namaKategori,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  it.objekKonservasi,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                ),
              ),
              const Spacer(),
              _buildStatusPill(it.statusTindakan),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            it.deskripsiTemuan,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          if (it.keteranganLapangan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan Lapangan: ${it.keteranganLapangan}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ],
          if (it.rekomendasi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Rekomendasi: ${it.rekomendasi}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontStyle: FontStyle.italic),
            ),
          ],
          if (it.langkahTemuan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Langkah Temuan: ${it.langkahTemuan}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFFEE2E2);
    Color fg = const Color(0xFFDC2626);
    String label = 'Belum';

    final s = status.toLowerCase().trim();
    if (s == 'sudah' || s == 'selesai') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Selesai';
    } else if (s.contains('proses') || s.contains('sedang')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'Dalam Proses';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
