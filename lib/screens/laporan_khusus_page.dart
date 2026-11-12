import 'package:flutter/material.dart';
import '../models/binwas_model.dart';
import '../models/user_session.dart';
import '../services/binwas_service.dart';
import '../services/binwas_excel_exporter.dart';

class LaporanKhususPage extends StatefulWidget {
  final bool isCentral;
  final UserSession? session;
  final String? initialProvinsi;

  const LaporanKhususPage({
    super.key,
    this.isCentral = true,
    this.session,
    this.initialProvinsi,
  });

  @override
  State<LaporanKhususPage> createState() => _LaporanKhususPageState();
}

class _LaporanKhususPageState extends State<LaporanKhususPage> {
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Filter options
  List<String> _petugasList = [];
  String? _selectedPetugas;
  String? _selectedProvinsi;
  String _selectedTahun = '2026';
  String _selectedTriwulan = 'semua';

  // Data
  List<BinwasLaporanKhusus> _laporanList = [];
  int _selectedInspectionIndex = 0;

  final List<String> _tahunOptions = ['2026', '2025', '2024', '2023'];
  final List<Map<String, String>> _triwulanOptions = [
    {'value': 'semua', 'label': 'Semua TW'},
    {'value': 'Triwulan 1', 'label': 'Triwulan 1'},
    {'value': 'Triwulan 2', 'label': 'Triwulan 2'},
    {'value': 'Triwulan 3', 'label': 'Triwulan 3'},
    {'value': 'Triwulan 4', 'label': 'Triwulan 4'},
  ];

  static const List<String> _kProvinsiOptions = [
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
    _selectedProvinsi = widget.initialProvinsi ?? widget.session?.namaProvinsi;
    _initData();
  }

  Future<void> _initData() async {
    if (widget.isCentral) {
      // Pusat: Ambil daftar nama petugas binwas pusat saja
      setState(() => _isLoading = true);
      try {
        final list = await BinwasService.fetchPetugasList(asalInput: 'pusat');
        if (mounted) {
          setState(() {
            _petugasList = list;
            if (_petugasList.isNotEmpty && _selectedPetugas == null) {
              _selectedPetugas = _petugasList.first;
            }
          });
        }
      } catch (e) {
        // Fallback jika get_petugas_list belum aktif
      }
    }
    _loadLaporan();
  }

  Future<void> _loadLaporan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedInspectionIndex = 0;
    });

    try {
      final list = await BinwasService.fetchLaporanKhusus(
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        namaPetugas: widget.isCentral
            ? (_selectedPetugas == 'semua' ? null : _selectedPetugas)
            : null,
        provinsi: widget.isCentral
            ? null
            : (_selectedProvinsi == 'semua'
                ? null
                : (_selectedProvinsi ?? widget.session?.namaProvinsi)),
        asalInput: widget.isCentral ? 'pusat' : 'provinsi',
      );

      if (mounted) {
        setState(() {
          _laporanList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportExcel(BinwasLaporanKhusus laporan) async {
    setState(() => _isExporting = true);
    try {
      final result = await BinwasExcelExporter.exportLaporanKhusus(laporan: laporan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? const Color(0xFF15803D) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor berkas Excel: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showEditEvaluasiModal(BinwasLaporanKhususItem item) {
    String currentStatus = item.status;
    final catatanCtrl = TextEditingController(text: item.catatanEvaluasi);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_turned_in, color: Color(0xFF1E3A8A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Evaluasi Temuan Binwas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Ringkasan Temuan
              Container(
                width: double.infinity,
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
                      'Objek / Kategori: ${item.objekKategori}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.temuan,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pemilihan Status (d)
              const Text(
                'Status Evaluasi (d):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChoiceChip(
                    label: 'Memadai',
                    color: const Color(0xFF15803D),
                    isSelected: currentStatus == 'Memadai',
                    onTap: () => setModalState(() => currentStatus = 'Memadai'),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChoiceChip(
                    label: 'Belum Memadai',
                    color: const Color(0xFFDC2626),
                    isSelected: currentStatus == 'Belum Memadai',
                    onTap: () => setModalState(() => currentStatus = 'Belum Memadai'),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChoiceChip(
                    label: 'On Progress',
                    color: const Color(0xFFD97706),
                    isSelected: currentStatus == 'On Progress',
                    onTap: () => setModalState(() => currentStatus = 'On Progress'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Catatan Evaluasi (e)
              const Text(
                'Catatan Evaluasi (e) - Berisi Paragraf:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catatanCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tuliskan catatan evaluasi, rekomendasi tindak lanjut, atau penilaian teknis...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            final success = await BinwasService.updateEvaluasi(
                              idDetail: item.idDetail,
                              status: currentStatus,
                              catatanEvaluasi: catatanCtrl.text.trim(),
                            );
                            if (success) {
                              setState(() {
                                item.status = currentStatus;
                                item.catatanEvaluasi = catatanCtrl.text.trim();
                              });
                              if (modalCtx.mounted) Navigator.pop(modalCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Catatan evaluasi berhasil diperbarui'),
                                    backgroundColor: Color(0xFF15803D),
                                  ),
                                );
                              }
                            } else {
                              throw Exception('Gagal menyimpan evaluasi');
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menyimpan evaluasi: $e'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(isSaving ? 'Menyimpan...' : 'Simpan Evaluasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChoiceChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isCentral ? 'Laporan Khusus Evaluasi Binwas' : 'Laporan Khusus (Evaluasi)',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
            tooltip: 'Segarkan Data',
            onPressed: _loadLaporan,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  )
                : _errorMessage != null
                    ? _buildErrorView()
                    : _laporanList.isEmpty
                        ? _buildEmptyState()
                        : _buildLaporanContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner info bila provinsi
          if (!widget.isCentral && widget.session != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield, size: 14, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Petugas: ${widget.session!.username} • Wilayah: ${widget.session!.namaProvinsi}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filter Nama Petugas (Hanya untuk Aplikasi Pusat)
                if (widget.isCentral) ...[
                  _buildPetugasFilterChip(),
                  const SizedBox(width: 8),
                ],

                // Filter Provinsi (Jika dibuka mode provinsi dari pusat / tanpa login sesi provinsi)
                if (!widget.isCentral && widget.session == null) ...[
                  _buildProvinsiFilterChip(),
                  const SizedBox(width: 8),
                ],

                // Filter Triwulan
                _buildTriwulanFilterChip(),
                const SizedBox(width: 8),

                // Filter Tahun
                _buildTahunFilterChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetugasFilterChip() {
    final label = (_selectedPetugas == null || _selectedPetugas == 'semua')
        ? 'Semua Petugas'
        : _selectedPetugas!;
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _selectedPetugas = (val == 'semua' ? null : val));
        _loadLaporan();
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(
            value: 'semua',
            child: Text('Semua Petugas', style: TextStyle(fontSize: 12.5)),
          ),
          const PopupMenuDivider(),
        ];
        items.addAll(
          _petugasList.map(
            (p) => PopupMenuItem(
              value: p,
              child: Text(p, style: const TextStyle(fontSize: 12.5)),
            ),
          ),
        );
        return items;
      },
      child: _buildChipBadge(
        icon: Icons.person_search_rounded,
        label: label,
        isActive: _selectedPetugas != null && _selectedPetugas != 'semua',
      ),
    );
  }

  Widget _buildProvinsiFilterChip() {
    final curLabel = (_selectedProvinsi == null || _selectedProvinsi == 'semua')
        ? 'Semua Provinsi'
        : _selectedProvinsi!;
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _selectedProvinsi = (val == 'semua' ? null : val));
        _loadLaporan();
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(
            value: 'semua',
            child: Text('Semua Provinsi', style: TextStyle(fontSize: 12.5)),
          ),
          const PopupMenuDivider(),
        ];
        items.addAll(
          _kProvinsiOptions.map(
            (p) => PopupMenuItem(
              value: p,
              child: Text(p, style: const TextStyle(fontSize: 12.5)),
            ),
          ),
        );
        return items;
      },
      child: _buildChipBadge(
        icon: Icons.map_outlined,
        label: curLabel,
        isActive: _selectedProvinsi != null && _selectedProvinsi != 'semua',
      ),
    );
  }

  Widget _buildTriwulanFilterChip() {
    final curLabel = _triwulanOptions.firstWhere(
      (opt) => opt['value'] == _selectedTriwulan,
      orElse: () => {'label': 'Semua TW'},
    )['label']!;

    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _selectedTriwulan = val);
        _loadLaporan();
      },
      itemBuilder: (context) => _triwulanOptions
          .map(
            (opt) => PopupMenuItem(
              value: opt['value']!,
              child: Text(opt['label']!, style: const TextStyle(fontSize: 12.5)),
            ),
          )
          .toList(),
      child: _buildChipBadge(
        icon: Icons.calendar_view_week,
        label: curLabel,
        isActive: _selectedTriwulan != 'semua',
      ),
    );
  }

  Widget _buildTahunFilterChip() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _selectedTahun = val);
        _loadLaporan();
      },
      itemBuilder: (context) => _tahunOptions
          .map(
            (t) => PopupMenuItem(
              value: t,
              child: Text('Tahun $t', style: const TextStyle(fontSize: 12.5)),
            ),
          )
          .toList(),
      child: _buildChipBadge(
        icon: Icons.calendar_today,
        label: 'Tahun $_selectedTahun',
        isActive: true,
      ),
    );
  }

  Widget _buildChipBadge({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E3A8A).withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_chart_outlined, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Data Laporan Khusus Masih Nihil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Belum ada hasil inspeksi binwas pada filter yang dipilih. Silakan ubah filter Petugas, Triwulan, atau Tahun.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text('Gagal memuat laporan: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLaporan,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaporanContent() {
    if (_selectedInspectionIndex >= _laporanList.length) {
      _selectedInspectionIndex = 0;
    }
    final laporan = _laporanList[_selectedInspectionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bila terdapat lebih dari 1 inspeksi untuk filter ini, tampilkan selector
          if (_laporanList.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.domain, size: 16, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  const Text('Pilih Perusahaan Diinspeksi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedInspectionIndex,
                        isExpanded: true,
                        items: List.generate(_laporanList.length, (idx) {
                          final item = _laporanList[idx];
                          return DropdownMenuItem<int>(
                            value: idx,
                            child: Text(
                              '${item.perusahaan} (${item.totalTemuan} temuan)',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedInspectionIndex = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Header Card (Persis Format Spreadsheet Pengawasan)
          _buildSpreadsheetHeaderCard(laporan),
          const SizedBox(height: 16),

          // 2. Action Bar (Total Temuan & Tombol Ekspor Excel)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      'Total: ${laporan.items.length} Butir Temuan',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                  const Text(
                    '(Ketuk baris untuk edit catatan)',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : () => _exportExcel(laporan),
                icon: _isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.file_download, size: 16),
                label: Text(_isExporting ? 'Mengekspor...' : 'Ekspor Excel (.xlsx)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Tabel Data Persis Gambar (Temuan a, Rekomendasi b, Objek/Kategori c, Status d, Catatan evaluasi e)
          _buildSpreadsheetTable(laporan),
          const SizedBox(height: 20),

          // 4. Keterangan Section (Persis Format Spreadsheet)
          _buildKeteranganBox(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetHeaderCard(BinwasLaporanKhusus laporan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeaderRow('Nama Petugas Binwas', laporan.namaPetugas, isFirst: true),
          _buildHeaderRow('Perusahaan', laporan.perusahaan),
          _buildHeaderRow('Komoditas', laporan.komoditas),
          _buildHeaderRow('Tanggal Binwas', '${laporan.tanggalBinwas} (${laporan.triwulan} - ${laporan.tahun})', isLast: true),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value, {bool isFirst = false, bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFF0F172A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Kolom Label
          Container(
            width: 145,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                right: BorderSide(color: Color(0xFF0F172A), width: 1),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
          // Kolom Nilai
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                value.isNotEmpty ? value : '-',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetTable(BinwasLaporanKhusus laporan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 980,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Titles (Row 1)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                ),
                child: Row(
                  children: [
                    _buildColHeaderCell('Temuan', 240),
                    _buildColHeaderCell('Rekomendasi', 240),
                    _buildColHeaderCell('Objek/Kategori', 160),
                    _buildColHeaderCell('Status', 120),
                    _buildColHeaderCell('Catatan evaluasi', 170),
                    _buildColHeaderCell('Aksi', 50),
                  ],
                ),
              ),
              // Header Codes: a, b, c, d, e (Row 2)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                ),
                child: Row(
                  children: [
                    _buildColSubHeaderCell('a', 240),
                    _buildColSubHeaderCell('b', 240),
                    _buildColSubHeaderCell('c', 160),
                    _buildColSubHeaderCell('d', 120),
                    _buildColSubHeaderCell('e', 170),
                    _buildColSubHeaderCell('-', 50),
                  ],
                ),
              ),

              // Data Rows
              if (laporan.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text(
                    'Tidak ada temuan lapangan yang dicatat (Kondisi Lapangan Patuh / Nihil).',
                    style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                )
              else
                ...laporan.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isLast = idx == laporan.items.length - 1;

                  return InkWell(
                    onTap: () => _showEditEvaluasiModal(item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // a: Temuan
                          _buildDataCell(item.temuan, 240, isBold: true),
                          // b: Rekomendasi
                          _buildDataCell(item.rekomendasi, 240),
                          // c: Objek/Kategori
                          _buildObjekKategoriCell(item.objekKategori, 160),
                          // d: Status
                          _buildStatusCell(item.status, 120),
                          // e: Catatan evaluasi
                          _buildCatatanCell(item.catatanEvaluasi, 170),
                          // Action edit
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF1E3A8A)),
                              tooltip: 'Edit Evaluasi',
                              onPressed: () => _showEditEvaluasiModal(item),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColHeaderCell(String title, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF0F172A), width: 1)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildColSubHeaderCell(String code, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF0F172A), width: 1)),
      ),
      child: Text(
        code,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Text(
        text.isNotEmpty ? text : '-',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFF0F172A),
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildObjekKategoriCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          text.isNotEmpty ? text : '-',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status, double width) {
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFD97706);
    IconData icon = Icons.hourglass_top_rounded;

    final norm = status.trim().toLowerCase();
    if (norm == 'memadai') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    } else if (norm.contains('belum')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatatanCell(String catatan, double width) {
    final hasContent = catatan.trim().isNotEmpty;
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Text(
        hasContent ? catatan : '(Klik untuk mengisi catatan)',
        style: TextStyle(
          fontSize: 11,
          fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
          color: hasContent ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildKeteranganBox() {
    final legends = [
      ('a', 'Temuan sesuai hasil inputan aplikasi'),
      ('b', 'Rekomendasi sesuai hasil inputan aplikasi'),
      ('c', 'sesuai dengan objek/kategori'),
      ('d', '(Memadai, Belum Memadai, On Progress)'),
      ('e', 'berisi paragraf'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keterangan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          ...legends.map((lg) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        lg.$1,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const Text(' :  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Expanded(
                      child: Text(
                        lg.$2,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

