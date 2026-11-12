import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/binwas_model.dart';
import '../services/binwas_excel_exporter.dart';
import '../services/binwas_service.dart';
import '../widgets/binwas_chart.dart';
import '../widgets/delete_inspeksi_dialog.dart';
import '../widgets/edit_inspeksi_dialog.dart';
import 'laporan_khusus_page.dart';
import 'evaluasi_dokumen_page.dart';

class BinwasPage extends StatefulWidget {
  const BinwasPage({super.key});

  @override
  State<BinwasPage> createState() => _BinwasPageState();
}

class _BinwasPageState extends State<BinwasPage> with SingleTickerProviderStateMixin {
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

  // State Tab 2: Form Inspeksi
  static const List<String> kDaftarPetugas = [
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

  bool _isLoadingMaster = false;
  List<BinwasCategory> _masterCategories = [];
  final Map<int, BinwasInspeksiItemInput> _formInputs = {}; // key: id_item_temuan
  Map<String, dynamic>? _selectedCompany;
  final TextEditingController _searchCompanyController = TextEditingController();
  String? _selectedPetugas = 'Aryanti';
  final TextEditingController _catatanUmumController = TextEditingController();
  DateTime _tanggalInspeksi = DateTime.now();
  String _formTriwulan = 'Triwulan 2';
  int _formTahun = 2026;
  String _formTipeKomoditas = 'batubara';
  bool _isSubmitting = false;

  // State Tab 3: Riwayat
  bool _isLoadingHistory = false;
  List<BinwasInspeksiRecord> _historyRecords = [];
  String? _errorHistory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) _loadDashboard();
        if (_tabController.index == 1 && _masterCategories.isEmpty) _loadMasterTemuan();
        if (_tabController.index == 2) _loadHistory();
      }
    });

    _loadDashboard();
    _loadMasterTemuan();
    _loadProvinsiList();
  }

  Future<void> _loadProvinsiList() async {
    try {
      final filters = await BinwasService.fetchFilters(_selectedTipe);
      if (filters['provinsi'] is List) {
        final list = (filters['provinsi'] as List)
            .map((p) => (p['nama_provinsi'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        list.sort();
        if (mounted) {
          setState(() {
            _provinsiList = list;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCompanyController.dispose();
    _catatanUmumController.dispose();
    super.dispose();
  }

  // ================= LOAD DATA =================
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
        asalInput: 'pusat',
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
          _errorDashboard = e.toString();
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _loadMasterTemuan() async {
    setState(() => _isLoadingMaster = true);
    try {
      final cats = await BinwasService.fetchMasterTemuan();
      if (mounted) {
        setState(() {
          _masterCategories = cats;
          _formInputs.clear();
          for (final cat in cats) {
            for (final item in cat.items) {
              _formInputs[item.id] = BinwasInspeksiItemInput(
                idItemTemuan: item.id,
                idKategori: cat.id,
                deskripsiTemuan: item.deskripsiTemuan,
                objekKonservasi: item.objekKonservasi,
                adaTemuan: false,
              );
            }
          }
          _isLoadingMaster = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMaster = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _errorHistory = null;
    });

    try {
      final records = await BinwasService.fetchHistory(
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        provinsi: _selectedProvinsi,
        asalInput: 'pusat',
      );
      if (mounted) {
        setState(() {
          _historyRecords = records;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorHistory = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  // ================= MODAL MATRIKS EXCEL =================

  Future<void> _openMatrixModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );

    try {
      final matrixData = await BinwasService.fetchMatrix(
        tipe: _selectedTipe,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        provinsi: _selectedProvinsi,
        asalInput: 'pusat',
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildMatrixSheet(matrixData),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat matriks: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportMatrixToExcel(BinwasMatrixData data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
    );

    final result = await BinwasExcelExporter.exportMatrix(
      matrixData: data,
      tipe: _selectedTipe,
      tahun: _selectedTahun,
      triwulan: _selectedTriwulan,
      dashboardData: _dashboardData,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.success && result.filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Berkas Excel (.xlsx) berhasil diekspor!\n${result.filePath}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Buka File',
            textColor: Colors.amberAccent,
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
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildMatrixSheet(BinwasMatrixData data) {
    int? selectedKategoriId;

    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        // Filter kategori yang ditampilkan berdasarkan chip pilihan
        final displayedCategories = selectedKategoriId == null
            ? data.rekapKategori
            : data.rekapKategori.where((k) => k.idKategori == selectedKategoriId).toList();

        // Susun baris DataRow: butir temuan + baris subtotal tiap kategori
        final List<DataRow> tableRows = [];

        for (var kat in displayedCategories) {
          final katRows = data.rows.where((r) => r.idKategori == kat.idKategori).toList();
          for (var r in katRows) {
            tableRows.add(
              DataRow(
                cells: [
                  DataCell(Text(r.namaKategori, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(r.objekKonservasi, style: const TextStyle(fontSize: 9.5)),
                  )),
                  DataCell(SizedBox(
                    width: 220,
                    child: Text(r.deskripsiTemuan, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Center(
                    child: Text(
                      r.jumlah.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.jumlah > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  )),
                  DataCell(Center(
                    child: Text('${r.persentase.toStringAsFixed(1)}%'),
                  )),
                  ...data.columns.map((c) {
                    final val = r.scores[c.idInspeksi.toString()] ?? 0;
                    return DataCell(
                      Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: val == 1 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            val.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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

          // Baris SUB-TOTAL untuk kategori ini
          tableRows.add(
            DataRow(
              color: WidgetStateProperty.all(const Color(0xA6FEF3C7)),
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                    ),
                    child: Text(
                      'SUBTOTAL ${kat.namaKategori.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFFB45309)),
                    ),
                  ),
                ),
                const DataCell(Center(child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))))),
                DataCell(
                  Text(
                    'Subtotal temuan ${kat.namaKategori} (${kat.jumlahButir} butir)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ),
                DataCell(Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kat.totalTemuan > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kat.totalTemuan.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                    ),
                  ),
                )),
                DataCell(Center(
                  child: Text(
                    '${kat.persentase.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  ),
                )),
                ...data.columns.map((c) {
                  final katScore = kat.scores[c.idInspeksi.toString()] ?? 0;
                  return DataCell(
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: katScore > 0 ? const Color(0xFFFDE68A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          katScore.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: katScore > 0 ? const Color(0xFF92400E) : const Color(0xFF94A3B8),
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

        // Baris TOTAL KESELURUHAN (Grand Total)
        if (selectedKategoriId == null) {
          tableRows.add(
            DataRow(
              color: WidgetStateProperty.all(const Color(0xFFE0E7FF)),
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TOTAL KESELURUHAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                  ),
                ),
                const DataCell(Center(child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))))),
                const DataCell(
                  Text(
                    'Grand Total Seluruh Kategori Temuan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF312E81)),
                  ),
                ),
                DataCell(Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.grandTotal.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                    ),
                  ),
                )),
                const DataCell(Center(
                  child: Text(
                    '100.0%',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                  ),
                )),
                ...data.columns.map((c) {
                  final compTotal = data.companyTotals[c.idInspeksi.toString()] ?? c.totalTemuan;
                  return DataCell(
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: compTotal > 0 ? const Color(0xFFC7D2FE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          compTotal.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: compTotal > 0 ? const Color(0xFF1E1B4B) : const Color(0xFF64748B),
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

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header Drag Handle & Title
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_chart, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Matriks Rekapitulasi Temuan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Format Tabular Excel • ${data.totalPerusahaan} Perusahaan Diinspeksi • Total ${data.grandTotal} Temuan',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exportMatrixToExcel(data),
                      icon: const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
                      label: const Text(
                        'Export Excel (.xlsx)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Horizontal Category Subtotal Chips
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKategoriChip(
                        label: 'Semua Kategori',
                        count: data.grandTotal,
                        isSelected: selectedKategoriId == null,
                        onTap: () {
                          setSheetState(() {
                            selectedKategoriId = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...data.rekapKategori.map((k) {
                        final isSel = selectedKategoriId == k.idKategori;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildKategoriChip(
                            label: k.namaKategori,
                            count: k.totalTemuan,
                            isSelected: isSel,
                            onTap: () {
                              setSheetState(() {
                                selectedKategoriId = isSel ? null : k.idKategori;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Scrollable Two-Way Table
              Expanded(
                child: data.columns.isEmpty
                    ? const Center(
                        child: Text('Belum ada data inspeksi untuk periode ini.',
                            style: TextStyle(color: Color(0xFF94A3B8))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            columnSpacing: 16,
                            horizontalMargin: 12,
                            headingTextStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            dataTextStyle: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
                            columns: [
                              const DataColumn(label: Text('Kategori')),
                              const DataColumn(label: Text('Objek Konservasi')),
                              const DataColumn(label: Text('Deskripsi Temuan')),
                              const DataColumn(label: Text('Jml', style: TextStyle(color: Color(0xFFD97706)))),
                              const DataColumn(label: Text('%', style: TextStyle(color: Color(0xFFD97706)))),
                              ...data.columns.map(
                                (c) => DataColumn(
                                  label: SizedBox(
                                    width: 110,
                                    child: Text(
                                      c.namaPerusahaan,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: tableRows,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKategoriChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x4DD97706), blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0x40FFFFFF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (count > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MODAL DETAIL INSPEKSI =================
  Future<void> _openDetailModal(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );

    try {
      final record = await BinwasService.fetchDetail(id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _BinwasDetailModal(
          initialRecord: record,
          onRecordUpdated: () => _loadHistory(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ================= FORM SUBMISSION =================
  Future<void> _submitForm() async {
    if (_selectedCompany == null || (_selectedCompany!['nama_perusahaan'] ?? '').toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perusahaan wajib dipilih terlebih dahulu sebelum menyimpan inspeksi!'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedPetugas == null || _selectedPetugas!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama petugas wajib dipilih!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validasi Objek Konservasi (Wajib minimal 1 jika toggle ON)
    for (final item in _formInputs.values) {
      if (item.adaTemuan && item.selectedObjekKonservasi.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mohon pilih minimal 1 Objek Konservasi untuk temuan:\n"${item.deskripsiTemuan}"'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final itemsData = _formInputs.values.expand((item) => item.toEntriesJson()).toList();

      final payload = {
        'tipe_komoditas': _formTipeKomoditas,
        'id_perusahaan': _selectedCompany!['id'],
        'nama_perusahaan': _selectedCompany!['nama_perusahaan'],
        'nama_provinsi': _selectedCompany!['nama_provinsi'],
        'jenis_izin': _selectedCompany!['jenis_izin'],
        'nama_petugas': _selectedPetugas!,
        'tanggal_inspeksi': DateFormat('yyyy-MM-dd').format(_tanggalInspeksi),
        'triwulan': _formTriwulan,
        'tahun': _formTahun,
        'catatan_umum': _catatanUmumController.text.trim(),
        'items': itemsData,
        'asal_input': 'pusat',
      };

      final res = await BinwasService.submitInspeksi(payload);

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Inspeksi berhasil disimpan!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );

        // Reset Form & pindah ke riwayat
        _selectedCompany = null;
        _catatanUmumController.clear();
        _selectedPetugas = 'Aryanti';
        _loadMasterTemuan();
        _tabController.animateTo(2);
        _loadDashboard();
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(),

            // Filter Global Bar
            _buildFilterBar(),

            // Segment Tabs
            _buildTabSelector(),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildFormInspeksiTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFFDE68A), width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fact_check, color: Color(0xFFFBBF24), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Binwas Konservasi Minerba',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Pembinaan & Pengawasan Kaidah Konservasi',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFBEB),
                          foregroundColor: const Color(0xFFD97706),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.table_view, size: 15),
                        label: const Text('Matriks', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: _openMatrixModal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.table_chart, size: 15),
                        label: const Text('Laporan Khusus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const LaporanKhususPage(isCentral: true),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fact_check, color: Color(0xFFFBBF24), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Binwas Konservasi Minerba',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pembinaan & Pengawasan Kaidah Konservasi',
                      style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFBEB),
                  foregroundColor: const Color(0xFFD97706),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.table_view, size: 16),
                label: const Text('Matriks', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: _openMatrixModal,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.assignment, size: 16),
                label: const Text('Evaluasi Dokumen', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const EvaluasiDokumenPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
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
                      builder: (c) => const LaporanKhususPage(isCentral: true),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFFBEB),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filter Wilayah Provinsi
            _buildFilterChip(
              'Wilayah',
              _selectedProvinsi == 'semua' ? 'Semua Provinsi' : _selectedProvinsi,
              () {
                _showFilterDialog(
                  title: 'Pilih Wilayah Provinsi',
                  options: ['semua', ..._provinsiList],
                  selected: _selectedProvinsi,
                  onSelect: (v) {
                    setState(() => _selectedProvinsi = v);
                    _loadDashboard();
                    _loadHistory();
                  },
                );
              },
            ),
            const SizedBox(width: 8),

            // Filter Komoditas
            _buildFilterChip('Komoditas', _selectedTipe.toUpperCase(), () {
              _showFilterDialog(
                title: 'Pilih Sektor',
                options: ['semua', 'batubara', 'mineral'],
                selected: _selectedTipe,
                onSelect: (v) {
                  setState(() => _selectedTipe = v);
                  _loadProvinsiList();
                  _loadDashboard();
                  _loadHistory();
                },
              );
            }),
            const SizedBox(width: 8),

            // Filter Triwulan
            _buildFilterChip('Triwulan', _selectedTriwulan == 'semua' ? 'Semua TW' : _selectedTriwulan, () {
              _showFilterDialog(
                title: 'Pilih Triwulan',
                options: ['semua', 'Triwulan 1', 'Triwulan 2', 'Triwulan 3', 'Triwulan 4'],
                selected: _selectedTriwulan,
                onSelect: (v) {
                  setState(() => _selectedTriwulan = v);
                  _loadDashboard();
                  _loadHistory();
                },
              );
            }),
            const SizedBox(width: 8),

            // Filter Tahun
            _buildFilterChip('Tahun', _selectedTahun, () {
              _showFilterDialog(
                title: 'Pilih Tahun',
                options: ['semua', '2026', '2025', '2024'],
                selected: _selectedTahun,
                onSelect: (v) {
                  setState(() => _selectedTahun = v);
                  _loadDashboard();
                  _loadHistory();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 10.5, color: Color(0xFF78350F))),
            Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF18181B))),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF78350F)),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog({
    required String title,
    required List<String> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final opt = options[i];
                    final isSel = opt == selected;
                    final label = opt == 'semua' ? 'SEMUA (NASIONAL)' : opt.toUpperCase();
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? const Color(0xFFB45309) : const Color(0xFF1E293B),
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFFF59E0B), size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelect(opt);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: const Color(0xFFFBBF24),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Rekap & KPI'),
          Tab(text: 'Form Inspeksi'),
          Tab(text: 'Riwayat'),
        ],
      ),
    );
  }

  // ================= TAB 1: DASHBOARD REKAP =================
  Widget _buildDashboardTab() {
    if (_isLoadingDashboard) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }

    if (_errorDashboard != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat rekapitulasi: $_errorDashboard', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _loadDashboard, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    final d = _dashboardData;
    if (d == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFFF59E0B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        children: [
          // 4 Grid KPI Cards
          Row(
            children: [
              Expanded(child: _buildKPICard('Total Inspeksi', '${d.totalInspeksi}', Icons.assignment, const Color(0xFF0284C7))),
              const SizedBox(width: 8),
              Expanded(child: _buildKPICard('Perusahaan', '${d.totalPerusahaan}', Icons.business, const Color(0xFF16A34A))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildKPICard('Total Temuan', '${d.totalTemuan}', Icons.warning_amber, const Color(0xFFDC2626))),
              const SizedBox(width: 8),
              Expanded(child: _buildKPICard('Rata-rata/PT', '${d.rataRataTemuan}', Icons.analytics, const Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 16),

          if (d.totalInspeksi == 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insights, color: Color(0xFFD97706), size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Data Pengawasan Masih Kosong',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Belum ada laporan inspeksi lapangan yang tersimpan di server. Anda dapat mengisi form inspeksi secara manual melalui tab Form Inspeksi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                  ),
                ],
              ),
            ),
          ],

          // Banner Shortcut Matriks
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF18181B), Color(0xFF27272A)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_on, color: Color(0xFFFBBF24), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Tabel Matriks Perusahaan vs Temuan',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Tampilan spreadsheet cross-tabulation persis Excel',
                          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 10.5)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openMatrixModal,
                  child: const Text('Buka', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // =========================================================================
          // SEKSI GRAFIK REKAPITULASI TEMUAN (Kategori, Komoditas & Objek Konservasi)
          // =========================================================================
          _buildChartSection(d),
          const SizedBox(height: 18),

          // Rekap 8 Objek Konservasi (Sesuai Excel)
          _buildCardContainer(
            title: 'Rekapitulasi 8 Objek Konservasi',
            subtitle: 'Proporsi temuan berdasarkan sasaran kaidah konservasi',
            icon: Icons.shield_outlined,
            children: d.rekapObjekKonservasi.map((obj) {
              return _buildProgressRow(
                label: obj.objekKonservasi,
                count: obj.jumlahTemuan,
                percentage: obj.persentase,
                color: const Color(0xFFD97706),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Rekap 10 Kategori Temuan
          _buildCardContainer(
            title: 'Distribusi per Area / Kategori',
            subtitle: 'Pemetaan temuan pada fase & fasilitas operasional tambang',
            icon: Icons.category_outlined,
            children: d.rekapKategori.map((kat) {
              return _buildProgressRow(
                label: kat.namaKategori,
                count: kat.jumlahTemuan,
                percentage: kat.persentase,
                color: const Color(0xFF2563EB),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Top 5 Temuan Terbanyak
          if (d.topTemuan.isNotEmpty)
            _buildCardContainer(
              title: 'Top Temuan Paling Sering Terjadi',
              subtitle: 'Isu kritis yang memerlukan pembinaan prioritas',
              icon: Icons.error_outline,
              children: d.topTemuan.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${t.totalPelanggaran}x',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.deskripsiTemuan,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            Text('${t.namaKategori} • ${t.objekKonservasi}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A))),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18181B))),
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
        // Judul Seksi Grafik
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pie_chart_rounded, color: Color(0xFFD97706), size: 18),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grafik Rekapitulasi Temuan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Text(
                  'Visualisasi sebaran temuan berbasis kaidah konservasi',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Segmented Control Switcher (Kategori, Komoditas, Objek Konservasi, Semua)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
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
        const SizedBox(height: 14),

        // Konten Grafik Berdasarkan Tab Terpilih
        if (_chartTabIndex == 0)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Kategori Temuan',
            subtitle: 'Proporsi temuan berdasarkan area fasilitas operasional tambang',
            icon: Icons.category_outlined,
            items: kategoriItems,
            isDonut: true, // Donut Chart sesuai gambar kiri
            centerLabel: 'Kategori',
          )
        else if (_chartTabIndex == 1)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Komoditas Tambang',
            subtitle: 'Proporsi temuan berdasarkan jenis komoditas bahan galian',
            icon: Icons.pie_chart,
            items: komoditasItems,
            isDonut: false, // Solid Pie Chart sesuai gambar kanan
            centerLabel: 'Komoditas',
          )
        else if (_chartTabIndex == 2)
          BinwasPieDonutCard(
            title: 'Rekapitulasi 9 Objek Konservasi',
            subtitle: 'Proporsi temuan berdasarkan sasaran kaidah teknis konservasi',
            icon: Icons.shield_outlined,
            items: objekItems,
            isDonut: true, // Donut Chart
            centerLabel: 'Objek Konservasi',
          )
        else ...[
          // Tampilkan Ketiga Grafik Bersamaan (Side-by-side / Stacked)
          BinwasPieDonutCard(
            title: 'Rekapitulasi Kategori Temuan',
            subtitle: 'Proporsi temuan berdasarkan area fasilitas operasional tambang',
            icon: Icons.category_outlined,
            items: kategoriItems,
            isDonut: true,
            centerLabel: 'Kategori',
          ),
          const SizedBox(height: 14),
          BinwasPieDonutCard(
            title: 'Rekapitulasi Komoditas Tambang',
            subtitle: 'Proporsi temuan berdasarkan jenis komoditas bahan galian',
            icon: Icons.pie_chart,
            items: komoditasItems,
            isDonut: false,
            centerLabel: 'Komoditas',
          ),
          const SizedBox(height: 14),
          BinwasPieDonutCard(
            title: 'Rekapitulasi 9 Objek Konservasi',
            subtitle: 'Proporsi temuan berdasarkan sasaran kaidah teknis konservasi',
            icon: Icons.shield_outlined,
            items: objekItems,
            isDonut: true,
            centerLabel: 'Objek Konservasi',
          ),
        ],
      ],
    );
  }

  Widget _buildChartTabItem(int index, String label, IconData icon) {
    final isSelected = _chartTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _chartTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...children,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
              ),
              Text('$count ($percentage%)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage > 0 ? (percentage / 100).clamp(0.0, 1.0) : 0.0,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: FORM INSPEKSI BARU =================
  Widget _buildFormInspeksiTab() {
    if (_isLoadingMaster) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      children: [
        // 1. Pilih Perusahaan Target
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('1. Perusahaan yang Diinspeksi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  // Toggle Sektor
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'batubara', label: Text('Batubara', style: TextStyle(fontSize: 10))),
                      ButtonSegment(value: 'mineral', label: Text('Mineral', style: TextStyle(fontSize: 10))),
                    ],
                    selected: {_formTipeKomoditas},
                    onSelectionChanged: (val) {
                      setState(() {
                        _formTipeKomoditas = val.first;
                        _selectedCompany = null;
                      });
                    },
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_selectedCompany == null) ...[
                TextField(
                  controller: _searchCompanyController,
                  decoration: InputDecoration(
                    hintText: 'Ketik nama PT atau No IUP...',
                    hintStyle: const TextStyle(fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (query) => _searchAndSelectCompany(query),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _searchAndSelectCompany(_searchCompanyController.text),
                    icon: const Icon(Icons.search, size: 14),
                    label: const Text('Cari Perusahaan', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedCompany!['nama_perusahaan'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            Text(
                              '${_selectedCompany!['nama_provinsi']} • ${_selectedCompany!['komoditas']} • ${_selectedCompany!['jenis_izin']}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFF15803D)),
                        onPressed: () => setState(() => _selectedCompany = null),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Data Pelaksanaan Inspeksi
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('2. Data Pelaksanaan Inspeksi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedPetugas,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Nama Petugas Inspeksi',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFFF59E0B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFF59E0B), size: 22),
                items: kDaftarPetugas.map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPetugas = val);
                  }
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tanggalInspeksi,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _tanggalInspeksi = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF71717A)),
                      const SizedBox(width: 10),
                      Text(
                        'Tanggal Inspeksi: ${DateFormat('dd MMMM yyyy').format(_tanggalInspeksi)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _formTriwulan,
                      decoration: InputDecoration(
                        labelText: 'Triwulan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: ['Triwulan 1', 'Triwulan 2', 'Triwulan 3', 'Triwulan 4'].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11.5)));
                      }).toList(),
                      onChanged: (v) => setState(() => _formTriwulan = v ?? 'Triwulan 2'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _formTahun,
                      decoration: InputDecoration(
                        labelText: 'Tahun',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [2026, 2025, 2024].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.toString(), style: const TextStyle(fontSize: 11.5)));
                      }).toList(),
                      onChanged: (v) => setState(() => _formTahun = v ?? 2026),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Checklist Butir Temuan Lapangan
        const Text('3. Checklist Butir Temuan Lapangan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),

        // Accordion per Kategori
        ..._masterCategories.map((cat) {
          final itemsInCat = _formInputs.values.where((i) => i.idKategori == cat.id).toList();
          final countTemuan = itemsInCat.where((i) => i.adaTemuan).length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: countTemuan > 0 ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              title: Row(
                children: [
                  Text(cat.namaKategori, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (countTemuan > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10)),
                      child: Text('$countTemuan temuan',
                          style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              children: itemsInCat.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.deskripsiTemuan,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                Text('Objek: ${item.objekKonservasi}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Switch(
                            value: item.adaTemuan,
                            activeThumbColor: const Color(0xFFDC2626),
                            activeTrackColor: const Color(0xFFFECDD3),
                            onChanged: (val) {
                              setState(() {
                                item.adaTemuan = val;
                                if (!val) {
                                  item.entries = [BinwasFindingEntry()];
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (item.adaTemuan) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.selectedObjekKonservasi.isEmpty
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFFDE68A),
                              width: item.selectedObjekKonservasi.isEmpty ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 16,
                                    color: item.selectedObjekKonservasi.isEmpty
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Pilih Objek Konservasi (Wajib minimal 1):',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  if (item.selectedObjekKonservasi.isEmpty) ...[
                                    const SizedBox(width: 4),
                                    const Text('*', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: BinwasInspeksiItemInput.kDaftarObjekKonservasi.map((obj) {
                                  final isChecked = item.selectedObjekKonservasi.contains(obj);
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isChecked) {
                                          item.selectedObjekKonservasi.remove(obj);
                                        } else {
                                          item.selectedObjekKonservasi.add(obj);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isChecked ? const Color(0xFFD97706) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isChecked ? const Color(0xFFB45309) : const Color(0xFFCBD5E1),
                                        ),
                                        boxShadow: isChecked
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFD97706).withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                            size: 14,
                                            color: isChecked ? Colors.white : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            obj,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                              color: isChecked ? Colors.white : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (item.selectedObjekKonservasi.isEmpty) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Wajib memilih minimal 1 objek konservasi di atas.',
                                  style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ...item.entries.asMap().entries.map((e) {
                          final idx = e.key;
                          final entry = e.value;

                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: idx > 0 ? const EdgeInsets.all(10) : EdgeInsets.zero,
                            decoration: idx > 0
                                ? BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  )
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (idx > 0) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Isian Temuan #${idx + 1}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Hapus isian ini',
                                        onPressed: () {
                                          setState(() {
                                            item.entries.removeAt(idx);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                TextFormField(
                                  initialValue: entry.keteranganLapangan,
                                  onChanged: (val) => entry.keteranganLapangan = val,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: idx == 0
                                        ? 'Keterangan kondisi temuan di lapangan...'
                                        : 'Keterangan kondisi temuan #${idx + 1}...',
                                    hintStyle: const TextStyle(fontSize: 10.5),
                                    isDense: true,
                                    filled: idx > 0,
                                    fillColor: Colors.white,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: entry.rekomendasi,
                                  onChanged: (val) => entry.rekomendasi = val,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: idx == 0
                                        ? 'Saran rekomendasi tindak lanjut...'
                                        : 'Saran rekomendasi tindak lanjut #${idx + 1}...',
                                    hintStyle: const TextStyle(fontSize: 10.5),
                                    isDense: true,
                                    filled: idx > 0,
                                    fillColor: Colors.white,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB45309),
                              backgroundColor: const Color(0xFFFEF3C7),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text(
                              '+ Tambah Inputan Baru',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              setState(() {
                                item.entries.add(BinwasFindingEntry());
                              });
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),

        const SizedBox(height: 14),

        // Catatan Umum
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catatan Umum Inspeksi (Opsional)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanUmumController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Catatan tambahan atau kesimpulan inspeksi...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tombol Submit
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18181B),
              foregroundColor: const Color(0xFFFBBF24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submitForm,
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Color(0xFFFBBF24))
                : const Text('Simpan & Terbitkan Laporan Inspeksi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _searchAndSelectCompany(String query) async {
    if (query.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
    );

    try {
      final results = await BinwasService.searchCompanies(
        tipe: _formTipeKomoditas,
        q: query.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context); // pop loading

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perusahaan tidak ditemukan!')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Perusahaan Target', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (ctx, idx) {
                    final c = results[idx];
                    return ListTile(
                      title: Text(c['nama_perusahaan'], style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: Text('${c['nama_provinsi']} • ${c['komoditas']} • ${c['jenis_izin']}',
                          style: const TextStyle(fontSize: 10.5)),
                      onTap: () {
                        setState(() => _selectedCompany = c);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ================= TAB 3: RIWAYAT INSPEKSI =================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
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

    if (_historyRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            const Text('Belum ada riwayat inspeksi untuk filter ini',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Buat Inspeksi Baru', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFFF59E0B),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        itemCount: _historyRecords.length,
        itemBuilder: (ctx, idx) {
          final r = _historyRecords[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            color: r.tipeKomoditas == 'batubara' ? const Color(0xFF18181B) : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.tipeKomoditas.toUpperCase(),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        Text(
                          '${r.triwulan} ${r.tahun}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.namaPerusahaan,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.namaProvinsi} • Izin: ${r.jenisIzin}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Petugas: ${r.namaPetugas}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: r.totalTemuan > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.totalTemuan > 0 ? '${r.totalTemuan} Temuan' : 'Nol Temuan (Patuh)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: r.totalTemuan > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          tooltip: 'Hapus Data Inspeksi',
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
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// MODAL DETAIL INSPEKSI BESERTA LANGKAH TEMUAN & BERKAS SURAT
// =========================================================================
class _BinwasDetailModal extends StatefulWidget {
  final BinwasInspeksiRecord initialRecord;
  final VoidCallback? onRecordUpdated;

  const _BinwasDetailModal({
    required this.initialRecord,
    this.onRecordUpdated,
  });

  @override
  State<_BinwasDetailModal> createState() => _BinwasDetailModalState();
}

class _BinwasDetailModalState extends State<_BinwasDetailModal> {
  late BinwasInspeksiRecord _record;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
  }

  Future<void> _refreshRecord() async {
    setState(() => _isRefreshing = true);
    try {
      final updated = await BinwasService.fetchDetail(_record.id);
      if (mounted) {
        setState(() {
          _record = updated;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openEditDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditInspeksiDialog(
        record: _record,
        onUpdated: () {
          _refreshRecord();
          widget.onRecordUpdated?.call();
        },
      ),
    );
    if (updated == true) {
      _refreshRecord();
      widget.onRecordUpdated?.call();
    }
  }

  Future<void> _openDeleteDialog() async {
    await DeleteInspeksiDialog.show(
      context,
      idInspeksi: _record.id,
      namaPerusahaan: _record.namaPerusahaan,
      onDeleted: () {
        widget.onRecordUpdated?.call();
        Navigator.of(context).pop();
      },
    );
  }

  void _showUpdateDialog(BinwasItemDetail item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UpdateTindakLanjutSheet(
        idInspeksi: _record.id,
        item: item,
        petugasInspeksi: _record.namaPetugas,
        onSuccess: () {
          _refreshRecord();
          widget.onRecordUpdated?.call();
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    switch (status.trim().toLowerCase()) {
      case 'sudah':
        bg = const Color(0xFFDCFCE7);
        border = const Color(0xFF86EFAC);
        text = const Color(0xFF15803D);
        icon = Icons.check_circle_rounded;
        label = 'Sudah';
        break;
      case 'sedang dilakukan':
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        icon = Icons.pending_actions_rounded;
        label = 'Sedang Dilakukan';
        break;
      case 'belum':
      default:
        bg = const Color(0xFFFEE2E2);
        border = const Color(0xFFFECACA);
        text = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        label = 'Belum';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF92400E))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final temuanList = r.items.where((i) => i.adaTemuan).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.tipeKomoditas == 'batubara' ? const Color(0xFF18181B) : const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.tipeKomoditas.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${r.triwulan} ${r.tahun}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          if (_isRefreshing) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.namaPerusahaan,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit / Koreksi Data Inspeksi',
                  icon: const Icon(Icons.edit_note, color: Color(0xFFD97706), size: 24),
                  onPressed: _openEditDialog,
                ),
                IconButton(
                  tooltip: 'Hapus Data Inspeksi',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                  onPressed: _openDeleteDialog,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Detail Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniInfo('Provinsi', r.namaProvinsi),
                          _buildMiniInfo('Jenis Izin', r.jenisIzin),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFFDE68A)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniInfo('Petugas', r.namaPetugas),
                          _buildMiniInfo('Tgl Inspeksi', r.tanggalInspeksi),
                          _buildMiniInfo('Temuan', '${r.totalTemuan} Butir', isAlert: r.totalTemuan > 0),
                        ],
                      ),
                      if (r.catatanUmum != null && r.catatanUmum!.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFFDE68A)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Catatan Umum: ${r.catatanUmum}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF451A03), fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: OutlinedButton.icon(
                              onPressed: _openEditDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Edit / Koreksi',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: _openDeleteDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Hapus',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Daftar Temuan
                Text(
                  'Daftar Butir Temuan Lapangan (${temuanList.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),

                if (temuanList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 42),
                        SizedBox(height: 8),
                        Text(
                          'Tidak ada temuan / Telah mematuhi kaidah konservasi',
                          style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else
                  ...temuanList.map((item) {
                    final hasLangkah = item.langkahTemuan.isNotEmpty;
                    final hasBukti = item.nomorSurat != null && item.nomorSurat!.trim().isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.namaKategori,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (item.objekKonservasi.isNotEmpty) ...[
                                ...item.objekKonservasi
                                    .split(',')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .map((obj) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_outline, size: 11, color: Color(0xFF991B1B)),
                                              const SizedBox(width: 3.5),
                                              Text(
                                                obj,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF991B1B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.deskripsiTemuan,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          if (item.keteranganLapangan.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Kondisi: ${item.keteranganLapangan}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                          ],
                          if (item.rekomendasi.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Rekomendasi: ${item.rekomendasi}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), fontWeight: FontWeight.w500)),
                          ],

                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFFECDD3)),
                          const SizedBox(height: 10),

                          // ================= BAGIAN LANGKAH TEMUAN / TINDAKAN =================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'LANGKAH TEMUAN / TINDAKAN',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              _buildStatusBadge(item.statusTindakan),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (hasLangkah)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                item.langkahTemuan,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.35),
                              ),
                            )
                          else
                            const Text(
                              'Belum ada uraian langkah tindakan yang diinput.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            ),

                          const SizedBox(height: 8),

                          // Baris Bukti / Dasar Tindakan & Tombol Input Tindakan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: hasBukti ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: hasBukti ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 14,
                                        color: hasBukti ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          hasBukti ? 'Bukti: ${item.nomorSurat}' : 'Bukti dasar: Belum diisi',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: hasBukti ? FontWeight.w600 : FontWeight.normal,
                                            color: hasBukti ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showUpdateDialog(item),
                                icon: const Icon(Icons.edit_note, size: 16, color: Color(0xFFB45309)),
                                label: Text(
                                  hasLangkah ? 'Ubah Tindakan' : 'Input Tindakan',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_pin, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Petugas Tindak Lanjut: ${r.namaPetugas}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// SHEET UPDATE LANGKAH TEMUAN, STATUS TINDAKAN & UPLOAD SURAT DASAR
// =========================================================================
class _UpdateTindakLanjutSheet extends StatefulWidget {
  final int idInspeksi;
  final BinwasItemDetail item;
  final String petugasInspeksi;
  final VoidCallback onSuccess;

  const _UpdateTindakLanjutSheet({
    required this.idInspeksi,
    required this.item,
    required this.petugasInspeksi,
    required this.onSuccess,
  });

  @override
  State<_UpdateTindakLanjutSheet> createState() => _UpdateTindakLanjutSheetState();
}

class _UpdateTindakLanjutSheetState extends State<_UpdateTindakLanjutSheet> {
  late String _statusTindakan;
  late TextEditingController _langkahController;
  late TextEditingController _buktiController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _statusTindakan = widget.item.statusTindakan;
    if (_statusTindakan.isEmpty) _statusTindakan = 'Belum';
    _langkahController = TextEditingController(text: widget.item.langkahTemuan);
    _buktiController = TextEditingController(text: widget.item.nomorSurat ?? '');
  }

  @override
  void dispose() {
    _langkahController.dispose();
    _buktiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final success = await BinwasService.updateTindakLanjut(
        idInspeksi: widget.idInspeksi,
        idTemuanDetail: widget.item.id,
        statusTindakan: _statusTindakan,
        langkahTemuan: _langkahController.text.trim(),
        nomorSurat: _buktiController.text.trim(),
        fileSurat: '',
        petugas: widget.petugasInspeksi,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else {
        throw Exception('Server tidak dapat menyimpan data.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusOption({
    required String value,
    required String label,
    required Color color,
    required Color activeBg,
    required IconData icon,
  }) {
    final isSelected = _statusTindakan.toLowerCase() == value.toLowerCase();

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusTindakan = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                isSelected ? Icons.check_circle : icon,
                size: 20,
                color: isSelected ? color : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D4D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Dialog
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFFB45309), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tindak Lanjut & Dasar Surat',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        widget.item.deskripsiTemuan,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Divider(height: 20),

            // 1. Pilihan Status Tindakan (Dengan Warna)
            const Text(
              'Status Tindakan:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusOption(
                  value: 'Belum',
                  label: 'Belum',
                  color: const Color(0xFFDC2626),
                  activeBg: const Color(0xFFFEE2E2),
                  icon: Icons.cancel_outlined,
                ),
                const SizedBox(width: 8),
                _buildStatusOption(
                  value: 'Sedang Dilakukan',
                  label: 'Sedang\nDilakukan',
                  color: const Color(0xFFD97706),
                  activeBg: const Color(0xFFFEF3C7),
                  icon: Icons.access_time_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatusOption(
                  value: 'Sudah',
                  label: 'Sudah',
                  color: const Color(0xFF16A34A),
                  activeBg: const Color(0xFFDCFCE7),
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Input Uraian Langkah Temuan / Tindakan
            const Text(
              'Langkah Temuan / Tindakan yang Dilakukan:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _langkahController,
              maxLines: 3,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Tuliskan tindakan atau tindak lanjut yang telah / sedang diambil oleh perusahaan...',
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Input Bukti / Dasar Tindakan (FREETEXT)
            const Text(
              'Bukti / Dasar Tindakan (Freetext):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _buktiController,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Tuliskan bukti, nomor surat dasar, atau keterangan dokumen perbaikan...',
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Petugas Tindak Lanjut (Otomatis sama dengan Petugas Inspeksi)
            const Text(
              'Petugas Tindak Lanjut:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.petugasInspeksi.isNotEmpty ? widget.petugasInspeksi : 'Petugas Binwas',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Text(
                      'Sama dengan Petugas Inspeksi',
                      style: TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: const Color(0xFFFBBF24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Tindak Lanjut',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


