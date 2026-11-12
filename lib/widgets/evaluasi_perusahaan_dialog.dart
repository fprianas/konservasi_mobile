import 'package:flutter/material.dart';
import '../models/evaluasi_perusahaan_model.dart';
import '../services/evaluasi_perusahaan_service.dart';
import 'delete_evaluasi_dialog.dart';

class ObjekEvaluasiConfig {
  final String key;
  final String label;
  final String hint;

  const ObjekEvaluasiConfig({
    required this.key,
    required this.label,
    required this.hint,
  });
}

class EvaluasiPerusahaanDialog extends StatefulWidget {
  final String namaPerusahaan;
  final String tipe; // 'batubara' | 'mineral'
  final String? komoditas;
  final String skIup;
  final String provinsi;
  final String triwulan;
  final int tahun;
  final String statusProduksi;
  final EvaluasiPerusahaanItem? initialData;

  const EvaluasiPerusahaanDialog({
    super.key,
    required this.namaPerusahaan,
    required this.tipe,
    this.komoditas,
    this.skIup = '',
    this.provinsi = '',
    this.triwulan = '',
    this.tahun = 0,
    this.statusProduksi = '',
    this.initialData,
  });

  /// Helper untuk membuka dialog modal evaluasi
  static Future<EvaluasiPerusahaanItem?> show(
    BuildContext context, {
    required String namaPerusahaan,
    required String tipe,
    String? komoditas,
    String skIup = '',
    String provinsi = '',
    String triwulan = '',
    int tahun = 0,
    String statusProduksi = '',
    EvaluasiPerusahaanItem? initialData,
  }) {
    return showDialog<EvaluasiPerusahaanItem?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EvaluasiPerusahaanDialog(
        namaPerusahaan: namaPerusahaan,
        tipe: tipe,
        komoditas: komoditas,
        skIup: skIup,
        provinsi: provinsi,
        triwulan: triwulan,
        tahun: tahun,
        statusProduksi: statusProduksi,
        initialData: initialData,
      ),
    );
  }

  @override
  State<EvaluasiPerusahaanDialog> createState() => _EvaluasiPerusahaanDialogState();
}

class _EvaluasiPerusahaanDialogState extends State<EvaluasiPerusahaanDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _catatanCtrl = TextEditingController();

  List<String> _petugasList = EvaluasiPerusahaanService.kDefaultPetugas;
  String? _selectedPetugas;
  EvaluasiPerusahaanItem? _existingItem;

  // State untuk 7 Objek Evaluasi: status & controller tanggapan
  final Map<String, String> _itemStatus = {};
  final Map<String, TextEditingController> _itemTanggapanCtrls = {};

  bool _isLoadingInitial = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<ObjekEvaluasiConfig> _getObjekList() {
    final isBatubaraOrAspal = widget.tipe.toLowerCase() == 'batubara' ||
        (widget.komoditas != null &&
            (widget.komoditas!.toLowerCase().contains('batubara') ||
                widget.komoditas!.toLowerCase().contains('aspal')));

    return [
      const ObjekEvaluasiConfig(
        key: 'format_laporan',
        label: '1. Format Laporan',
        hint: 'Tuliskan tanggapan ketidaksesuaian format laporan...',
      ),
      const ObjekEvaluasiConfig(
        key: 'recovery_penambangan',
        label: '2. Recovery Penambangan',
        hint: 'Tuliskan tanggapan terkait recovery penambangan...',
      ),
      const ObjekEvaluasiConfig(
        key: 'recovery_pengolahan',
        label: '3. Recovery Pengolahan',
        hint: 'Tuliskan tanggapan terkait recovery pengolahan...',
      ),
      const ObjekEvaluasiConfig(
        key: 'cadangan_marginal',
        label: '4. Cadangan Marginal',
        hint: 'Tuliskan tanggapan terkait cadangan marginal...',
      ),
      ObjekEvaluasiConfig(
        key: 'kualitas_kadar_rendah',
        label: isBatubaraOrAspal
            ? '5. Batubara Kualitas Rendah (BKR)'
            : '5. Mineral Kadar Rendah (MKR)',
        hint: isBatubaraOrAspal
            ? 'Tuliskan tanggapan batubara kualitas rendah...'
            : 'Tuliskan tanggapan mineral kadar rendah...',
      ),
      const ObjekEvaluasiConfig(
        key: 'sisa_hasil_pengolahan',
        label: '6. Sisa Hasil Pengolahan (SHP)',
        hint: 'Tuliskan tanggapan terkait sisa hasil pengolahan...',
      ),
      const ObjekEvaluasiConfig(
        key: 'cadangan_tidak_tertambang',
        label: '7. Cadangan Tidak Tertambang',
        hint: 'Tuliskan tanggapan terkait cadangan tidak tertambang...',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _existingItem = widget.initialData;

    final list = _getObjekList();
    for (final cfg in list) {
      _itemTanggapanCtrls[cfg.key] = TextEditingController();
    }

    _applyItemData(_existingItem);
    _loadData();
  }

  void _applyItemData(EvaluasiPerusahaanItem? item) {
    final list = _getObjekList();
    if (item == null) {
      _selectedPetugas = _petugasList.first;
      for (final cfg in list) {
        _itemStatus[cfg.key] = 'Memadai';
        _itemTanggapanCtrls[cfg.key]?.text = '';
      }
      _catatanCtrl.text = '';
      return;
    }

    _selectedPetugas = item.namaPetugas.isNotEmpty ? item.namaPetugas : _petugasList.first;
    _catatanCtrl.text = item.catatan;

    for (final cfg in list) {
      if (item.detailEvaluasi.containsKey(cfg.key)) {
        final val = item.detailEvaluasi[cfg.key];
        if (val is Map) {
          final st = val['status']?.toString() == 'Belum Memadai' ? 'Belum Memadai' : 'Memadai';
          _itemStatus[cfg.key] = st;
          _itemTanggapanCtrls[cfg.key]?.text = val['tanggapan']?.toString() ?? '';
        } else {
          _itemStatus[cfg.key] = 'Memadai';
        }
      } else if (cfg.key == 'format_laporan') {
        _itemStatus[cfg.key] = item.isFormatMemadai ? 'Memadai' : 'Belum Memadai';
      } else {
        _itemStatus[cfg.key] = 'Memadai';
      }
    }
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    for (final ctrl in _itemTanggapanCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  bool get _isAllMemadai => _itemStatus.values.every((st) => st != 'Belum Memadai');
  String get _overallStatus => _isAllMemadai ? 'Memadai' : 'Belum Memadai';
  int get _belumMemadaiCount => _itemStatus.values.where((st) => st == 'Belum Memadai').length;

  Future<void> _loadData() async {
    // 1. Ambil daftar petugas server
    try {
      final list = await EvaluasiPerusahaanService.fetchPetugasList();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _petugasList = list;
          if (_selectedPetugas == null || !_petugasList.contains(_selectedPetugas)) {
            _selectedPetugas = _petugasList.first;
          }
        });
      }
    } catch (_) {}

    // 2. Jika initialData belum ada, coba fetch evaluasi yang sudah terekam di DB untuk periode ini
    if (_existingItem == null) {
      setState(() => _isLoadingInitial = true);
      try {
        final item = await EvaluasiPerusahaanService.fetchEvaluasiByPerusahaan(
          widget.namaPerusahaan,
          tahun: widget.tahun > 0 ? widget.tahun : null,
          triwulan: widget.triwulan.isNotEmpty ? widget.triwulan : null,
        );
        if (mounted && item != null) {
          setState(() {
            _existingItem = item;
            _applyItemData(item);
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _saveEvaluasi() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPetugas == null || _selectedPetugas!.isEmpty) {
      setState(() => _errorMessage = 'Silakan pilih nama petugas.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final list = _getObjekList();
    final Map<String, dynamic> detailMap = {};
    for (final cfg in list) {
      final st = _itemStatus[cfg.key] ?? 'Memadai';
      final tanggapan = st == 'Belum Memadai' ? (_itemTanggapanCtrls[cfg.key]?.text.trim() ?? '') : '';
      detailMap[cfg.key] = {
        'label': cfg.label,
        'status': st,
        'tanggapan': tanggapan,
      };
    }

    final formatLaporanStatus = _itemStatus['format_laporan'] ?? 'Memadai';

    try {
      final payload = {
        if (_existingItem != null && _existingItem!.id > 0) 'id': _existingItem!.id,
        'nama_perusahaan': widget.namaPerusahaan,
        'tipe': widget.tipe,
        if (widget.komoditas != null) 'komoditas': widget.komoditas,
        'sk_iup': widget.skIup,
        'provinsi': widget.provinsi,
        'triwulan': widget.triwulan,
        'tahun': widget.tahun,
        'status_produksi': widget.statusProduksi,
        'nama_petugas': _selectedPetugas,
        'status': _overallStatus,
        'format_laporan': formatLaporanStatus,
        'catatan': _catatanCtrl.text.trim(),
        'detail_evaluasi': detailMap,
      };

      final saved = await EvaluasiPerusahaanService.saveEvaluasi(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_existingItem != null
              ? 'Evaluasi perusahaan berhasil diperbarui'
              : 'Evaluasi perusahaan berhasil disimpan'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _confirmDelete() async {
    final deleted = await DeleteEvaluasiDialog.show(
      context,
      title: 'Hapus Evaluasi Perusahaan',
      namaPerusahaan: widget.namaPerusahaan,
      itemType: 'Evaluasi',
      onDelete: (pin) async {
        await EvaluasiPerusahaanService.deleteEvaluasi(
          id: _existingItem?.id,
          namaPerusahaan: widget.namaPerusahaan,
          pin: pin,
        );
      },
    );

    if (deleted == true && mounted) {
      final deletedMarker = EvaluasiPerusahaanItem(
        id: -1,
        namaPerusahaan: widget.namaPerusahaan,
        namaPetugas: '',
        status: '',
        formatLaporan: '',
      );
      Navigator.of(context).pop(deletedMarker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _existingItem != null && _existingItem!.id > 0;
    final isBatubara = widget.tipe.toLowerCase() == 'batubara';
    final accentColor = isBatubara ? const Color(0xFFF59E0B) : const Color(0xFF0284C7);
    final objekList = _getObjekList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 850),
        child: Column(
          children: [
            // Header modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fact_check_outlined, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Evaluasi Perusahaan' : 'Form Evaluasi Perusahaan',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.namaPerusahaan,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body (Scrollable)
            Expanded(
              child: _isLoadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Metadata Card Singkat
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isBatubara ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.tipe.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isBatubara ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                  if (widget.triwulan.isNotEmpty || widget.tahun > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF18181B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${widget.triwulan.isNotEmpty ? widget.triwulan : ''}${widget.tahun > 0 ? ' ${widget.tahun}' : ''}'.trim(),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget.statusProduksi.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: widget.statusProduksi.toLowerCase().contains('belum')
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.statusProduksi,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: widget.statusProduksi.toLowerCase().contains('belum')
                                              ? const Color(0xFF475569)
                                              : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget.provinsi.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.provinsi,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Field 1: Nama Petugas Evaluator (Dropdown)
                            const Text(
                              'Nama Petugas Evaluator *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _petugasList.contains(_selectedPetugas)
                                  ? _selectedPetugas
                                  : (_petugasList.isNotEmpty ? _petugasList.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: accentColor, width: 1.5),
                                ),
                                prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                              ),
                              items: _petugasList.map((name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedPetugas = val);
                              },
                              validator: (val) => val == null || val.trim().isEmpty ? 'Nama petugas wajib dipilih' : null,
                            ),

                            const SizedBox(height: 20),

                            // Header Seksi Objek Evaluasi
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Objek Evaluasi Konservasi',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isAllMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _isAllMemadai ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isAllMemadai ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 13,
                                        color: _isAllMemadai ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isAllMemadai ? 'Semua Memadai (7/7)' : '$_belumMemadaiCount Belum Memadai',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _isAllMemadai ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pilih status untuk setiap aspek. Jika dipilih "Belum Memadai", isikan tanggapan evaluasi.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),

                            // Render 7 Objek Evaluasi
                            ...objekList.map((cfg) => _buildObjekCard(cfg, accentColor)),

                            const SizedBox(height: 8),

                            // Catatan Umum / Ringkasan Evaluasi
                            const Text(
                              'Catatan Umum / Rekomendasi Tambahan (Opsional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _catatanCtrl,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Tuliskan catatan umum atau kesimpulan evaluasi di sini...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: accentColor, width: 1.5),
                                ),
                              ),
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                      tooltip: 'Hapus Evaluasi Perusahaan',
                      onPressed: _isSaving ? null : _confirmDelete,
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveEvaluasi,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _isSaving
                          ? 'Menyimpan...'
                          : (isEdit ? 'Simpan Perubahan' : 'Simpan Evaluasi'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAllMemadai ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjekCard(ObjekEvaluasiConfig cfg, Color accentColor) {
    final status = _itemStatus[cfg.key] ?? 'Memadai';
    final isBelumMemadai = status == 'Belum Memadai';
    final ctrl = _itemTanggapanCtrls[cfg.key];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBelumMemadai ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBelumMemadai ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isBelumMemadai ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  cfg.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isBelumMemadai ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Pills Memadai / Belum Memadai
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChoicePill(
                    label: 'Memadai',
                    isSelected: !isBelumMemadai,
                    activeColor: const Color(0xFF16A34A),
                    activeBg: const Color(0xFFDCFCE7),
                    icon: Icons.check_circle_rounded,
                    onTap: () {
                      setState(() {
                        _itemStatus[cfg.key] = 'Memadai';
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildChoicePill(
                    label: 'Belum Memadai',
                    isSelected: isBelumMemadai,
                    activeColor: const Color(0xFFDC2626),
                    activeBg: const Color(0xFFFEE2E2),
                    icon: Icons.error_rounded,
                    onTap: () {
                      setState(() {
                        _itemStatus[cfg.key] = 'Belum Memadai';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tanggapan field HANYA jika Belum Memadai
          if (isBelumMemadai) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: ctrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: cfg.hint,
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                labelText: 'Tanggapan (${cfg.label}) *',
                labelStyle: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.5),
                ),
              ),
              validator: (v) {
                if (isBelumMemadai && (v == null || v.trim().isEmpty)) {
                  return 'Tanggapan wajib diisi untuk status Belum Memadai';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoicePill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? activeColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
