import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluasi_dokumen_model.dart';
import '../services/evaluasi_dokumen_service.dart';
import '../widgets/form_rkpw_dialog.dart';
import '../widgets/form_fs_dialog.dart';
import '../widgets/detail_rkpw_modal.dart';
import '../widgets/detail_fs_modal.dart';
import '../widgets/delete_evaluasi_dialog.dart';
import '../services/evaluasi_exporter_service.dart';

class EvaluasiDokumenPage extends StatefulWidget {
  const EvaluasiDokumenPage({super.key});

  @override
  State<EvaluasiDokumenPage> createState() => _EvaluasiDokumenPageState();
}

class _EvaluasiDokumenPageState extends State<EvaluasiDokumenPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State Tab RKPW
  bool _isLoadingRkpw = false;
  List<EvaluasiRkpwItem> _rkpwList = [];
  EvaluasiRkpwStats _rkpwStats = const EvaluasiRkpwStats();
  String _rkpwSearchQuery = '';
  String _rkpwFilterTahun = 'semua';
  String _rkpwFilterStatus = 'semua';
  String _rkpwFilterJenis = 'semua';
  String _rkpwFilterEvaluator = 'semua';
  final TextEditingController _rkpwSearchCtrl = TextEditingController();

  // State Tab FS
  bool _isLoadingFs = false;
  List<EvaluasiFsItem> _fsList = [];
  EvaluasiFsStats _fsStats = const EvaluasiFsStats();
  String _fsSearchQuery = '';
  String _fsFilterStatus = 'semua';
  String _fsFilterKomoditas = 'semua';
  String _fsFilterEvaluator = 'semua';
  final TextEditingController _fsSearchCtrl = TextEditingController();

  // Filter options
  List<String> _rkpwTahunOptions = ['semua', '2026', '2025', '2024', '2023'];
  List<String> _rkpwEvaluatorOptions = ['semua'];
  List<String> _fsEvaluatorOptions = ['semua'];
  List<String> _fsKomoditasOptions = ['semua'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _loadRkpw();
    _loadFs();
    _loadFilters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rkpwSearchCtrl.dispose();
    _fsSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final rkpwFilters = await EvaluasiDokumenService.fetchRkpwFilters();
    final fsFilters = await EvaluasiDokumenService.fetchFsFilters();
    if (!mounted) return;

    setState(() {
      if (rkpwFilters['tahun'] is List) {
        _rkpwTahunOptions = ['semua', ...(rkpwFilters['tahun'] as List).map((e) => e.toString())];
      }
      if (rkpwFilters['evaluator'] is List) {
        _rkpwEvaluatorOptions = ['semua', ...(rkpwFilters['evaluator'] as List).map((e) => e.toString())];
      }
      if (fsFilters['evaluator'] is List) {
        _fsEvaluatorOptions = ['semua', ...(fsFilters['evaluator'] as List).map((e) => e.toString())];
      }
      if (fsFilters['komoditas'] is List) {
        _fsKomoditasOptions = ['semua', ...(fsFilters['komoditas'] as List).map((e) => e.toString())];
      }
    });
  }

  Future<void> _loadRkpw() async {
    setState(() => _isLoadingRkpw = true);
    try {
      final res = await EvaluasiDokumenService.fetchRkpwList(
        q: _rkpwSearchQuery,
        tahun: _rkpwFilterTahun,
        status: _rkpwFilterStatus,
        jenisKomoditas: _rkpwFilterJenis,
        evaluator: _rkpwFilterEvaluator,
      );
      if (!mounted) return;
      setState(() {
        _rkpwList = res.items;
        _rkpwStats = res.stats;
        _isLoadingRkpw = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRkpw = false);
    }
  }

  Future<void> _loadFs() async {
    setState(() => _isLoadingFs = true);
    try {
      final res = await EvaluasiDokumenService.fetchFsList(
        q: _fsSearchQuery,
        evaluator: _fsFilterEvaluator,
        komoditas: _fsFilterKomoditas,
        status: _fsFilterStatus,
      );
      if (!mounted) return;
      setState(() {
        _fsList = res.items;
        _fsStats = res.stats;
        _isLoadingFs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingFs = false);
    }
  }

  String _formatNumber(double val) {
    if (val == 0) return '0';
    return NumberFormat('#,##0.##', 'id_ID').format(val);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Memadai':
        return const Color(0xFF15803D);
      case 'Ditolak':
      case 'Belum Memadai':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  bool _isExporting = false;

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan berkas Excel...'), duration: Duration(seconds: 1)),
    );

    final isRkpw = _tabController.index == 0;
    EvaluasiExportResult res;
    if (isRkpw) {
      res = await EvaluasiExporterService.exportRkpwExcel(items: _rkpwList, stats: _rkpwStats);
    } else {
      res = await EvaluasiExporterService.exportFsExcel(items: _fsList, stats: _fsStats);
    }

    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan dokumen PDF...'), duration: Duration(seconds: 1)),
    );

    final isRkpw = _tabController.index == 0;
    EvaluasiExportResult res;
    if (isRkpw) {
      res = await EvaluasiExporterService.exportRkpwPdf(items: _rkpwList, stats: _rkpwStats);
    } else {
      res = await EvaluasiExporterService.exportFsPdf(items: _fsList, stats: _fsStats);
    }

    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRkpwTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Evaluasi Dokumen Minerba',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              'Monitoring Permohonan RKPW & Telaah Studi Kelayakan (FS)',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ekspor Dokumen',
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined, color: Color(0xFF1E3A8A)),
            onSelected: (val) {
              if (val == 'excel') {
                _exportExcel();
              } else if (val == 'pdf') {
                _exportPdf();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    const Icon(Icons.table_chart, size: 18, color: Color(0xFF15803D)),
                    const SizedBox(width: 10),
                    Text(
                      isRkpwTab ? 'Ekspor RKPW ke Excel (.xlsx)' : 'Ekspor FS ke Excel (.xlsx)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Text(
                      isRkpwTab ? 'Ekspor RKPW ke PDF (.pdf)' : 'Ekspor FS ke PDF (.pdf)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
            tooltip: 'Segarkan Data',
            onPressed: () {
              _loadRkpw();
              _loadFs();
              _loadFilters();
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E3A8A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1E3A8A),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description, size: 17),
                      const SizedBox(width: 8),
                      const Text('Sheet RKPW (Perluasan)'),
                      if (_rkpwList.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_rkpwList.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 17),
                      const SizedBox(width: 8),
                      const Text('Sheet FS (Studi Kelayakan)'),
                      if (_fsList.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_fsList.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: RKPW
          _buildRkpwTab(),

          // TAB 2: FS
          _buildFsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isRkpwTab ? const Color(0xFF1E3A8A) : const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          isRkpwTab ? 'Tambah RKPW' : 'Tambah FS',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (isRkpwTab) {
            FormRkpwDialog.show(context, onSaved: _loadRkpw);
          } else {
            FormFsDialog.show(context, onSaved: _loadFs);
          }
        },
      ),
    );
  }

  // =================================================================
  // TAB 1: SHEET RKPW WIDGETS
  // =================================================================

  Widget _buildRkpwTab() {
    return Column(
      children: [
        // Summary KPI Banner
        _buildRkpwKpiCards(),

        // Filter Bar & Search
        _buildRkpwFilterBar(),

        // Content
        Expanded(
          child: _isLoadingRkpw
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
              : _rkpwList.isEmpty
                  ? _buildEmptyState('Belum ada data permohonan RKPW', 'Klik tombol "+ Tambah RKPW" untuk menambahkan permohonan baru.')
                  : RefreshIndicator(
                      onRefresh: _loadRkpw,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _rkpwList.length,
                        itemBuilder: (context, idx) {
                          final item = _rkpwList[idx];
                          return _buildRkpwCard(item);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildRkpwKpiCards() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return Row(
            children: [
              _buildMiniKpi('Total Permohonan', '${_rkpwStats.total}', Icons.description_outlined, const Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              _buildMiniKpi('Disetujui', '${_rkpwStats.totalDisetujui}', Icons.check_circle_outline, const Color(0xFF15803D)),
              const SizedBox(width: 8),
              _buildMiniKpi('Ditolak', '${_rkpwStats.totalDitolak}', Icons.cancel_outlined, const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              _buildMiniKpi('Sedang Proses', '${_rkpwStats.totalProses}', Icons.hourglass_top_outlined, const Color(0xFFD97706)),
              if (isWide) ...[
                const SizedBox(width: 8),
                _buildMiniKpi('Luas Dimohon', '${_formatNumber(_rkpwStats.sumLuasDimohon)} Ha', Icons.crop_landscape, const Color(0xFF475569)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRkpwFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _rkpwSearchCtrl,
            onChanged: (val) {
              _rkpwSearchQuery = val;
              _loadRkpw();
            },
            decoration: InputDecoration(
              hintText: 'Cari nama perusahaan, no IUP, atau nomor surat...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _rkpwSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _rkpwSearchCtrl.clear();
                        _rkpwSearchQuery = '';
                        _loadRkpw();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Chips Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFilter<String>(
                  icon: Icons.flag_outlined,
                  label: _rkpwFilterStatus == 'semua' ? 'Status: Semua' : 'Status: $_rkpwFilterStatus',
                  value: _rkpwFilterStatus,
                  items: const [
                    DropdownMenuItem(value: 'semua', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                    DropdownMenuItem(value: 'Disetujui', child: Text('Disetujui')),
                    DropdownMenuItem(value: 'Ditolak', child: Text('Ditolak')),
                  ],
                  onChanged: (v) {
                    setState(() => _rkpwFilterStatus = v ?? 'semua');
                    _loadRkpw();
                  },
                ),
                const SizedBox(width: 8),
                _buildChipFilter<String>(
                  icon: Icons.calendar_today_outlined,
                  label: _rkpwFilterTahun == 'semua' ? 'Tahun: Semua' : 'Tahun: $_rkpwFilterTahun',
                  value: _rkpwFilterTahun,
                  items: _rkpwTahunOptions.map((t) => DropdownMenuItem(value: t, child: Text(t == 'semua' ? 'Semua Tahun' : 'Tahun $t'))).toList(),
                  onChanged: (v) {
                    setState(() => _rkpwFilterTahun = v ?? 'semua');
                    _loadRkpw();
                  },
                ),
                const SizedBox(width: 8),
                _buildChipFilter<String>(
                  icon: Icons.category_outlined,
                  label: _rkpwFilterJenis == 'semua' ? 'Komoditas: Semua' : _rkpwFilterJenis,
                  value: _rkpwFilterJenis,
                  items: const [
                    DropdownMenuItem(value: 'semua', child: Text('Semua Jenis')),
                    DropdownMenuItem(value: 'Mineral', child: Text('Mineral')),
                    DropdownMenuItem(value: 'Batubara', child: Text('Batubara')),
                  ],
                  onChanged: (v) {
                    setState(() => _rkpwFilterJenis = v ?? 'semua');
                    _loadRkpw();
                  },
                ),
                if (_rkpwEvaluatorOptions.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildChipFilter<String>(
                    icon: Icons.person_outline,
                    label: _rkpwFilterEvaluator == 'semua' ? 'Evaluator: Semua' : _rkpwFilterEvaluator,
                    value: _rkpwFilterEvaluator,
                    items: _rkpwEvaluatorOptions.map((e) => DropdownMenuItem(value: e, child: Text(e == 'semua' ? 'Semua Evaluator' : e))).toList(),
                    onChanged: (v) {
                      setState(() => _rkpwFilterEvaluator = v ?? 'semua');
                      _loadRkpw();
                    },
                  ),
                ],
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Ekspor Data RKPW',
                  onSelected: (val) {
                    if (val == 'excel') _exportExcel();
                    if (val == 'pdf') _exportPdf();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, size: 16, color: Color(0xFF15803D)),
                          SizedBox(width: 8),
                          Text('Ekspor Excel (.xlsx)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Ekspor PDF (.pdf)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 15, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 4),
                        Text('Ekspor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRkpwCard(EvaluasiRkpwItem item) {
    final statusColor = _getStatusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => DetailRkpwModal.show(context, item, onDataChanged: _loadRkpw),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Nama Perusahaan & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaPerusahaan,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.noSkIup.isNotEmpty ? 'IUP: ${item.noSkIup}' : 'Komoditas: ${item.komoditas.isNotEmpty ? item.komoditas : item.jenisKomoditas}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),

                // Lokasi Tambang (Kecamatan, Kabupaten, Provinsi)
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [item.kecamatan, item.kabupaten, item.provinsi].where((e) => e.isNotEmpty).join(', ').ifEmpty('Lokasi belum diset'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Grid Ringkasan Luas
                Row(
                  children: [
                    Expanded(
                      child: _buildItemStat('Luas Awal', '${_formatNumber(item.luasWiup)} Ha'),
                    ),
                    Expanded(
                      child: _buildItemStat('Permohonan', '${_formatNumber(item.luasPerluasanDimohon)} Ha', isHighlight: true),
                    ),
                    Expanded(
                      child: _buildItemStat('Disetujui', '${_formatNumber(item.luasDisetujui)} Ha'),
                    ),
                    Expanded(
                      child: _buildItemStat('Total Akhir', '${_formatNumber(item.totalLuasSekarang)} Ha'),
                    ),
                  ],
                ),

                const Divider(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.evaluator.isNotEmpty)
                            Text('Evaluator: ${item.evaluator}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (item.suratPermohonanTanggal != null)
                            Text('Tgl Surat: ${item.suratPermohonanTanggal}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    // Quick Action Edit
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => FormRkpwDialog.show(context, item: item, onSaved: _loadRkpw),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 13, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Action Hapus (PIN 3636)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final deleted = await DeleteEvaluasiDialog.show(
                          context,
                          title: 'Hapus Permohonan RKPW?',
                          namaPerusahaan: item.namaPerusahaan,
                          itemType: 'RKPW',
                          onDelete: (pin) async {
                            await EvaluasiDokumenService.deleteRkpw(item.id, pin: pin);
                          },
                        );
                        if (deleted == true) {
                          _loadRkpw();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, size: 13, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =================================================================
  // TAB 2: SHEET FS WIDGETS
  // =================================================================

  Widget _buildFsTab() {
    return Column(
      children: [
        // Summary KPI Banner
        _buildFsKpiCards(),

        // Filter Bar & Search
        _buildFsFilterBar(),

        // Content
        Expanded(
          child: _isLoadingFs
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
              : _fsList.isEmpty
                  ? _buildEmptyState('Belum ada data evaluasi FS', 'Klik tombol "+ Tambah FS" untuk menambahkan dokumen studi kelayakan baru.')
                  : RefreshIndicator(
                      onRefresh: _loadFs,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _fsList.length,
                        itemBuilder: (context, idx) {
                          final item = _fsList[idx];
                          return _buildFsCard(item);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFsKpiCards() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          _buildMiniKpi('Total Dokumen FS', '${_fsStats.total}', Icons.analytics_outlined, const Color(0xFF0F766E)),
          const SizedBox(width: 8),
          _buildMiniKpi('Memadai', '${_fsStats.totalMemadai}', Icons.check_circle_outline, const Color(0xFF15803D)),
          const SizedBox(width: 8),
          _buildMiniKpi('Belum Memadai', '${_fsStats.totalBelumMemadai}', Icons.error_outline, const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          _buildMiniKpi('Sedang Proses', '${_fsStats.totalProses}', Icons.hourglass_top_outlined, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _buildFsFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _fsSearchCtrl,
            onChanged: (val) {
              _fsSearchQuery = val;
              _loadFs();
            },
            decoration: InputDecoration(
              hintText: 'Cari nama perusahaan atau nomor ND permohonan...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _fsSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _fsSearchCtrl.clear();
                        _fsSearchQuery = '';
                        _loadFs();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Chips Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFilter<String>(
                  icon: Icons.flag_outlined,
                  label: _fsFilterStatus == 'semua' ? 'Status: Semua' : 'Status: $_fsFilterStatus',
                  value: _fsFilterStatus,
                  items: const [
                    DropdownMenuItem(value: 'semua', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'Memadai', child: Text('Memadai')),
                    DropdownMenuItem(value: 'Belum Memadai', child: Text('Belum Memadai')),
                    DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                  ],
                  onChanged: (v) {
                    setState(() => _fsFilterStatus = v ?? 'semua');
                    _loadFs();
                  },
                ),
                if (_fsKomoditasOptions.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildChipFilter<String>(
                    icon: Icons.category_outlined,
                    label: _fsFilterKomoditas == 'semua' ? 'Komoditas: Semua' : _fsFilterKomoditas,
                    value: _fsFilterKomoditas,
                    items: _fsKomoditasOptions.map((k) => DropdownMenuItem(value: k, child: Text(k == 'semua' ? 'Semua Komoditas' : k))).toList(),
                    onChanged: (v) {
                      setState(() => _fsFilterKomoditas = v ?? 'semua');
                      _loadFs();
                    },
                  ),
                ],
                if (_fsEvaluatorOptions.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildChipFilter<String>(
                    icon: Icons.person_outline,
                    label: _fsFilterEvaluator == 'semua' ? 'Evaluator: Semua' : _fsFilterEvaluator,
                    value: _fsFilterEvaluator,
                    items: _fsEvaluatorOptions.map((e) => DropdownMenuItem(value: e, child: Text(e == 'semua' ? 'Semua Evaluator' : e))).toList(),
                    onChanged: (v) {
                      setState(() => _fsFilterEvaluator = v ?? 'semua');
                      _loadFs();
                    },
                  ),
                ],
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Ekspor Data FS',
                  onSelected: (val) {
                    if (val == 'excel') _exportExcel();
                    if (val == 'pdf') _exportPdf();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, size: 16, color: Color(0xFF15803D)),
                          SizedBox(width: 8),
                          Text('Ekspor Excel (.xlsx)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Ekspor PDF (.pdf)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 15, color: Color(0xFF0F766E)),
                        SizedBox(width: 4),
                        Text('Ekspor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFsCard(EvaluasiFsItem item) {
    final statusColor = _getStatusColor(item.latestStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => DetailFsModal.show(context, item, onDataChanged: _loadFs),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaPerusahaan,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Komoditas: ${item.komoditas.isNotEmpty ? item.komoditas : "-"} • Evaluator: ${item.evaluator.isNotEmpty ? item.evaluator : "-"}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        item.latestStatus,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),

                // Permohonan
                if (item.ndPermohonanNomor.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'ND Permohonan: ${item.ndPermohonanNomor} (${item.ndPermohonanTanggal ?? "-"})',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Tahapan Evaluasi Pills (1..4)
                Row(
                  children: [
                    _buildEvalPill('Ke-1', item.eval1Status),
                    const SizedBox(width: 6),
                    _buildEvalPill('Ke-2', item.eval2Status),
                    const SizedBox(width: 6),
                    _buildEvalPill('Ke-3', item.eval3Status),
                    const SizedBox(width: 6),
                    _buildEvalPill('Ke-4', item.eval4Status),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.evaluator.isNotEmpty ? 'Evaluator: ${item.evaluator}' : 'Komoditas: ${item.komoditas}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Quick Action Edit
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => FormFsDialog.show(context, item: item, onSaved: _loadFs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 13, color: Color(0xFF15803D)),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Action Hapus (PIN 3636)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final deleted = await DeleteEvaluasiDialog.show(
                          context,
                          title: 'Hapus Evaluasi FS?',
                          namaPerusahaan: item.namaPerusahaan,
                          itemType: 'FS',
                          onDelete: (pin) async {
                            await EvaluasiDokumenService.deleteFs(item.id, pin: pin);
                          },
                        );
                        if (deleted == true) {
                          _loadFs();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, size: 13, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvalPill(String stage, String? status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF94A3B8);
    String label = stage;

    if (status != null && status.isNotEmpty) {
      if (status == 'Memadai') {
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = '$stage: OK';
      } else if (status == 'Belum Memadai') {
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = '$stage: Revisi';
      } else {
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = '$stage: Pros';
      }
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          maxLines: 1,
        ),
      ),
    );
  }

  // =================================================================
  // SHARED HELPERS
  // =================================================================

  Widget _buildMiniKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildItemStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildChipFilter<T>({
    required IconData icon,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isActive = value != 'semua' && value != null;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E3A8A).withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.folder_open, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

extension StringExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

