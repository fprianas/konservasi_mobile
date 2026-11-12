import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluasi_perusahaan_model.dart';
import '../services/evaluasi_exporter_service.dart';
import '../services/evaluasi_perusahaan_service.dart';
import '../widgets/delete_evaluasi_dialog.dart';
import '../widgets/evaluasi_perusahaan_dialog.dart';
import '../widgets/security_pin_dialog.dart';

class RekapEvaluasiPerusahaanPage extends StatefulWidget {
  final String initialTipe; // 'semua' | 'batubara' | 'mineral'

  const RekapEvaluasiPerusahaanPage({
    super.key,
    this.initialTipe = 'semua',
  });

  @override
  State<RekapEvaluasiPerusahaanPage> createState() => _RekapEvaluasiPerusahaanPageState();
}

class _RekapEvaluasiPerusahaanPageState extends State<RekapEvaluasiPerusahaanPage> {
  late String _selectedTipe;
  String _selectedStatus = 'semua'; // 'semua' | 'Memadai' | 'Belum Memadai'
  String _selectedPetugas = 'semua';
  String _searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();

  List<EvaluasiPerusahaanItem> _allItems = [];
  List<String> _petugasOptions = ['semua'];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTipe = widget.initialTipe;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await EvaluasiPerusahaanService.fetchEvaluasiList(
        tipe: _selectedTipe == 'semua' ? null : _selectedTipe,
      );

      final Set<String> petugasSet = {'semua'};
      for (final item in list) {
        if (item.namaPetugas.trim().isNotEmpty) {
          petugasSet.add(item.namaPetugas.trim());
        }
      }

      if (mounted) {
        setState(() {
          _allItems = list;
          _petugasOptions = petugasSet.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<EvaluasiPerusahaanItem> get _filteredItems {
    return _allItems.where((item) {
      // Filter tipe jika _selectedTipe != 'semua'
      if (_selectedTipe != 'semua' && item.tipe.toLowerCase() != _selectedTipe.toLowerCase()) {
        return false;
      }

      // Filter status
      if (_selectedStatus != 'semua') {
        if (_selectedStatus == 'Memadai' && !item.isMemadai) return false;
        if (_selectedStatus == 'Belum Memadai' && item.isMemadai) return false;
      }

      // Filter petugas
      if (_selectedPetugas != 'semua' && item.namaPetugas != _selectedPetugas) {
        return false;
      }

      // Filter query pencarian
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.namaPerusahaan.toLowerCase().contains(q);
        final matchIup = item.skIup.toLowerCase().contains(q);
        final matchProv = item.provinsi.toLowerCase().contains(q);
        final matchPetugas = item.namaPetugas.toLowerCase().contains(q);
        if (!matchName && !matchIup && !matchProv && !matchPetugas) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _exportExcel() async {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data evaluasi yang dapat diekspor.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final res = await EvaluasiExporterService.exportEvaluasiPerusahaanExcel(
        items: filtered,
        tipe: _selectedTipe.toUpperCase(),
      );

      if (!mounted) return;
      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor berkas: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _exportPdf() async {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data evaluasi yang dapat diekspor.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan dokumen PDF...'), duration: Duration(seconds: 1)),
    );

    try {
      final res = await EvaluasiExporterService.exportEvaluasiPerusahaanPdf(
        items: filtered,
        tipe: _selectedTipe.toUpperCase(),
      );

      if (!mounted) return;
      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor berkas PDF: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _openEditEvaluasi(EvaluasiPerusahaanItem item) async {
    final updated = await EvaluasiPerusahaanDialog.show(
      context,
      namaPerusahaan: item.namaPerusahaan,
      tipe: item.tipe,
      komoditas: item.komoditas,
      skIup: item.skIup,
      provinsi: item.provinsi,
      triwulan: item.triwulan,
      tahun: item.tahun,
      statusProduksi: item.statusProduksi,
      initialData: item,
    );

    if (updated != null && mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final totalCount = _allItems.length;
    final memadaiCount = _allItems.where((e) => e.isMemadai).length;
    final belumMemadaiCount = totalCount - memadaiCount;
    final kepatuhanPct = totalCount > 0 ? ((memadaiCount / totalCount) * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekap Evaluasi Konservasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Rekapitulasi 7 Objek Evaluasi Perusahaan Tambang',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ekspor Rekap Evaluasi (Excel / PDF)',
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, color: Color(0xFF38BDF8)),
            onSelected: (val) {
              if (val == 'excel') {
                _exportExcel();
              } else if (val == 'pdf') {
                _exportPdf();
              }
            },
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
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // KPI Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Evaluasi',
                    value: '$totalCount',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF0F766E),
                    bgColor: const Color(0xFFCCFBF1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Memadai',
                    value: '$memadaiCount',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Belum Memadai',
                    value: '$belumMemadaiCount',
                    icon: Icons.error_outline,
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Kepatuhan',
                    value: '$kepatuhanPct%',
                    icon: Icons.pie_chart_outline,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
              ],
            ),
          ),

          // Filters & Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                // Row 1: Search & Filter Tipe
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari perusahaan, IUP, provinsi, atau petugas...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _searchCtrl.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tipe Toggle
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypeTab('semua', 'Semua'),
                          _buildTypeTab('batubara', 'Batubara'),
                          _buildTypeTab('mineral', 'Mineral'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: Status & Petugas Filter
                Row(
                  children: [
                    // Status Filter Pills
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusPill('semua', 'Semua Status'),
                        const SizedBox(width: 6),
                        _buildStatusPill('Memadai', '✓ Memadai'),
                        const SizedBox(width: 6),
                        _buildStatusPill('Belum Memadai', '! Belum Memadai'),
                      ],
                    ),
                    const Spacer(),
                    // Petugas Filter Dropdown
                    if (_petugasOptions.length > 1) ...[
                      const Text('Petugas: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPetugas,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                            items: _petugasOptions.map((p) {
                              return DropdownMenuItem<String>(
                                value: p,
                                child: Text(p == 'semua' ? 'Semua Petugas' : p),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPetugas = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
                            const SizedBox(height: 12),
                            Text('Gagal memuat: $_errorMessage', style: const TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadData, child: const Text('Coba Lagi')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada data evaluasi perusahaan yang sesuai filter.',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Silakan lakukan evaluasi melalui tombol "Evaluasi" di kartu perusahaan Home.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final item = filtered[index];
                              return _buildEvaluasiCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String key, String label) {
    final isSelected = _selectedTipe == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTipe = key;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String key, String label) {
    final isSelected = _selectedStatus == key;
    Color activeColor = const Color(0xFF0F766E);
    Color activeBg = const Color(0xFFCCFBF1);
    if (key == 'Memadai') {
      activeColor = const Color(0xFF16A34A);
      activeBg = const Color(0xFFDCFCE7);
    } else if (key == 'Belum Memadai') {
      activeColor = const Color(0xFFDC2626);
      activeBg = const Color(0xFFFEE2E2);
    }

    return InkWell(
      onTap: () => setState(() => _selectedStatus = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluasiCard(EvaluasiPerusahaanItem item) {
    final isBatubara = item.tipe.toLowerCase() == 'batubara';
    final isMemadai = item.isMemadai;
    final badgeBg = isMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final badgeColor = isMemadai ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final badgeText = isMemadai ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    // Ambil daftar aspek yang belum memadai
    final List<MapEntry<String, dynamic>> belumMemadaiEntries = [];
    final List<MapEntry<String, dynamic>> memadaiEntries = [];

    if (item.detailEvaluasi.isNotEmpty) {
      for (final entry in item.detailEvaluasi.entries) {
        if (entry.value is Map) {
          final st = entry.value['status']?.toString();
          if (st == 'Belum Memadai') {
            belumMemadaiEntries.add(entry);
          } else {
            memadaiEntries.add(entry);
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMemadai ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
          width: isMemadai ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMemadai ? const Color(0xFFFAFAFA) : const Color(0xFFFEF2F2).withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isBatubara ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.tipe.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isBatubara ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                          if (item.triwulan.isNotEmpty || item.tahun > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF18181B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.triwulan.isNotEmpty ? item.triwulan : ""} ${item.tahun > 0 ? item.tahun : ""}'.trim(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                            ),
                          ],
                          if (item.statusProduksi.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: item.statusProduksi.toLowerCase().contains('belum')
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.statusProduksi,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: item.statusProduksi.toLowerCase().contains('belum')
                                      ? const Color(0xFF475569)
                                      : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.namaPerusahaan,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.skIup.isNotEmpty ? item.skIup : "-"} • ${item.provinsi.isNotEmpty ? item.provinsi : "-"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Badge Status Akhir
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isMemadai ? Icons.check_circle : Icons.warning_amber_rounded, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Card
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Evaluator & Waktu
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Evaluator: ${item.namaPetugas}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const Spacer(),
                    if (item.updatedAt != null)
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(item.updatedAt!),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),

                const Divider(height: 18),

                // Rincian 7 Objek Evaluasi
                if (item.detailEvaluasi.isNotEmpty) ...[
                  const Text(
                    'Rincian 7 Aspek Konservasi:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  // Tampilkan Aspek Belum Memadai lebih dulu dengan Tanggapannya
                  if (belumMemadaiEntries.isNotEmpty) ...[
                    ...belumMemadaiEntries.map((e) {
                      final label = e.value['label']?.toString() ?? e.key;
                      final tanggapan = e.value['tanggapan']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel, size: 14, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Belum Memadai', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            if (tanggapan.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Tanggapan: "$tanggapan"',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],

                  // Tampilkan Aspek yang Memadai sebagai Chip Ringkas
                  if (memadaiEntries.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: memadaiEntries.map((e) {
                        final label = e.value['label']?.toString() ?? e.key;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 12, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF166534))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ] else ...[
                  // Data evaluasi lama sebelum format 7 objek
                  Row(
                    children: [
                      Text(
                        'Format Laporan: ${item.formatLaporan}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.isFormatMemadai ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],

                // Catatan Umum
                if (item.catatan.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Catatan Umum: ${item.catatan}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Tombol Aksi: Hapus (PIN 3636) & Ubah (PIN 3636)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final deleted = await DeleteEvaluasiDialog.show(
                          context,
                          title: 'Hapus Evaluasi Perusahaan?',
                          namaPerusahaan: item.namaPerusahaan,
                          itemType: 'Evaluasi',
                          onDelete: (pin) async {
                            await EvaluasiPerusahaanService.deleteEvaluasi(
                              id: item.id,
                              namaPerusahaan: item.namaPerusahaan,
                              pin: pin,
                            );
                          },
                        );
                        if (deleted == true && mounted) {
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Hapus', style: TextStyle(color: Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final verified = await SecurityPinDialog.verify(
                          context,
                          title: 'Ubah Data Evaluasi',
                          subtitle: item.namaPerusahaan,
                          confirmLabel: 'Buka Form Ubah',
                          confirmColor: const Color(0xFF0F766E),
                          icon: Icons.edit_note,
                        );
                        if (verified == true && mounted) {
                          _openEditEvaluasi(item);
                        }
                      },
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Ubah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

