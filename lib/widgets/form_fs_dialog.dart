import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluasi_dokumen_model.dart';
import '../services/evaluasi_dokumen_service.dart';
import '../services/evaluasi_perusahaan_service.dart';
import 'company_search_picker_modal.dart';

class FormFsDialog extends StatefulWidget {
  final EvaluasiFsItem? initialItem;
  final VoidCallback onSaved;

  const FormFsDialog({
    super.key,
    this.initialItem,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {EvaluasiFsItem? item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FormFsDialog(initialItem: item, onSaved: onSaved),
    );
  }

  @override
  State<FormFsDialog> createState() => _FormFsDialogState();
}

class _FormFsDialogState extends State<FormFsDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _perusahaanCtrl;
  late TextEditingController _evaluatorCtrl;
  late TextEditingController _komoditasCtrl;
  late TextEditingController _ndPermohonanNoCtrl;
  late TextEditingController _ndPermohonanTglCtrl;

  late TextEditingController _eval1NoCtrl;
  late TextEditingController _eval1TglCtrl;
  String? _eval1Status;

  late TextEditingController _eval2NoCtrl;
  late TextEditingController _eval2TglCtrl;
  String? _eval2Status;

  late TextEditingController _eval3NoCtrl;
  late TextEditingController _eval3TglCtrl;
  String? _eval3Status;

  late TextEditingController _eval4NoCtrl;
  late TextEditingController _eval4TglCtrl;
  String? _eval4Status;

  late TextEditingController _catatanCtrl;

  List<String> _evaluatorList = [];
  String? _selectedEvaluator;
  bool _isManualEvaluator = false;

  /// Jumlah tahap evaluasi yang ditampilkan (default: 2, maks: 4)
  int _visibleEvalCount = 2;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _perusahaanCtrl = TextEditingController(text: item?.namaPerusahaan ?? '');
    _evaluatorCtrl = TextEditingController(text: item?.evaluator ?? '');
    _komoditasCtrl = TextEditingController(text: item?.komoditas ?? '');
    _ndPermohonanNoCtrl = TextEditingController(text: item?.ndPermohonanNomor ?? '');
    _ndPermohonanTglCtrl = TextEditingController(text: item?.ndPermohonanTanggal ?? '');

    _eval1NoCtrl = TextEditingController(text: item?.eval1Nomor ?? '');
    _eval1TglCtrl = TextEditingController(text: item?.eval1Tanggal ?? '');
    _eval1Status = item?.eval1Status;

    _eval2NoCtrl = TextEditingController(text: item?.eval2Nomor ?? '');
    _eval2TglCtrl = TextEditingController(text: item?.eval2Tanggal ?? '');
    _eval2Status = item?.eval2Status;

    _eval3NoCtrl = TextEditingController(text: item?.eval3Nomor ?? '');
    _eval3TglCtrl = TextEditingController(text: item?.eval3Tanggal ?? '');
    _eval3Status = item?.eval3Status;

    _eval4NoCtrl = TextEditingController(text: item?.eval4Nomor ?? '');
    _eval4TglCtrl = TextEditingController(text: item?.eval4Tanggal ?? '');
    _eval4Status = item?.eval4Status;

    _catatanCtrl = TextEditingController(text: item?.catatan ?? '');

    // Setup daftar evaluator
    _evaluatorList = List<String>.from(EvaluasiPerusahaanService.kDefaultPetugas);
    if (item != null && item.evaluator.trim().isNotEmpty) {
      final curEval = item.evaluator.trim();
      if (!_evaluatorList.contains(curEval)) {
        _evaluatorList.add(curEval);
      }
      _selectedEvaluator = curEval;
    } else {
      _selectedEvaluator = null;
    }

    // Tentukan jumlah evaluasi bertahap yang ditampilkan awal (minimal 2)
    int count = 2;
    if (item != null) {
      final hasEval4 = item.eval4Nomor.isNotEmpty ||
          (item.eval4Tanggal != null && item.eval4Tanggal!.isNotEmpty) ||
          (item.eval4Status != null && item.eval4Status!.isNotEmpty);
      final hasEval3 = item.eval3Nomor.isNotEmpty ||
          (item.eval3Tanggal != null && item.eval3Tanggal!.isNotEmpty) ||
          (item.eval3Status != null && item.eval3Status!.isNotEmpty);

      if (hasEval4) {
        count = 4;
      } else if (hasEval3) {
        count = 3;
      }
    }
    _visibleEvalCount = count;

    _loadServerEvaluators();
  }

  @override
  void dispose() {
    _perusahaanCtrl.dispose();
    _evaluatorCtrl.dispose();
    _komoditasCtrl.dispose();
    _ndPermohonanNoCtrl.dispose();
    _ndPermohonanTglCtrl.dispose();
    _eval1NoCtrl.dispose();
    _eval1TglCtrl.dispose();
    _eval2NoCtrl.dispose();
    _eval2TglCtrl.dispose();
    _eval3NoCtrl.dispose();
    _eval3TglCtrl.dispose();
    _eval4NoCtrl.dispose();
    _eval4TglCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServerEvaluators() async {
    try {
      final filters = await EvaluasiDokumenService.fetchFsFilters();
      if (filters['evaluator'] is List) {
        final serverList = (filters['evaluator'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e.toLowerCase() != 'semua')
            .toList();
        if (serverList.isNotEmpty && mounted) {
          setState(() {
            final set = {..._evaluatorList, ...serverList};
            _evaluatorList = set.toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openCompanyPicker() async {
    final selected = await CompanySearchPickerModal.show(
      context,
      initialTipe: 'semua',
      initialQuery: _perusahaanCtrl.text.trim(),
    );

    if (selected != null) {
      setState(() {
        _perusahaanCtrl.text = selected['nama_perusahaan'] ?? _perusahaanCtrl.text;
        final komoditas = (selected['komoditas'] ?? '').toString().trim();
        if (komoditas.isNotEmpty) {
          _komoditasCtrl.text = komoditas;
        }
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateFormat('yyyy-MM-dd').parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final evaluatorVal = _isManualEvaluator
        ? _evaluatorCtrl.text.trim()
        : (_selectedEvaluator ?? _evaluatorCtrl.text.trim());

    try {
      final payload = {
        if (widget.initialItem != null) 'id': widget.initialItem!.id,
        'nama_perusahaan': _perusahaanCtrl.text.trim(),
        'evaluator': evaluatorVal,
        'komoditas': _komoditasCtrl.text.trim(),
        'nd_permohonan_nomor': _ndPermohonanNoCtrl.text.trim(),
        'nd_permohonan_tanggal': _ndPermohonanTglCtrl.text.trim().isEmpty ? null : _ndPermohonanTglCtrl.text.trim(),
        'eval_1_nomor': _eval1NoCtrl.text.trim(),
        'eval_1_tanggal': _eval1TglCtrl.text.trim().isEmpty ? null : _eval1TglCtrl.text.trim(),
        'eval_1_status': _eval1Status,
        'eval_2_nomor': _eval2NoCtrl.text.trim(),
        'eval_2_tanggal': _eval2TglCtrl.text.trim().isEmpty ? null : _eval2TglCtrl.text.trim(),
        'eval_2_status': _eval2Status,
        'eval_3_nomor': _visibleEvalCount >= 3 ? _eval3NoCtrl.text.trim() : '',
        'eval_3_tanggal': (_visibleEvalCount >= 3 && _eval3TglCtrl.text.trim().isNotEmpty) ? _eval3TglCtrl.text.trim() : null,
        'eval_3_status': _visibleEvalCount >= 3 ? _eval3Status : null,
        'eval_4_nomor': _visibleEvalCount >= 4 ? _eval4NoCtrl.text.trim() : '',
        'eval_4_tanggal': (_visibleEvalCount >= 4 && _eval4TglCtrl.text.trim().isNotEmpty) ? _eval4TglCtrl.text.trim() : null,
        'eval_4_status': _visibleEvalCount >= 4 ? _eval4Status : null,
        'catatan': _catatanCtrl.text.trim(),
      };

      await EvaluasiDokumenService.saveFs(payload, isEdit: widget.initialItem != null);
      if (!mounted) return;

      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialItem != null ? 'Data FS berhasil diperbarui' : 'Data evaluasi FS berhasil ditambahkan'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialItem != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: Color(0xFF34D399), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Dokumen Studi Kelayakan (FS)' : 'Tambah Evaluasi Studi Kelayakan (FS)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subjek
                      const Text(
                        '1. Identitas Permohonan Evaluasi',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _perusahaanCtrl,
                                  label: 'Nama Perusahaan *',
                                  hint: 'Ketik nama atau pilih dari database',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.manage_search, color: Color(0xFF0F766E)),
                                    tooltip: 'Pilih dari Database Mineral / Batubara',
                                    onPressed: _openCompanyPicker,
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: _openCompanyPicker,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search, size: 13, color: Color(0xFF0F766E)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Pilih dari Database Mineral & Batubara',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Dropdown / Input Evaluator
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isManualEvaluator)
                                  _buildTextField(
                                    controller: _evaluatorCtrl,
                                    label: 'Nama Evaluator (Manual)',
                                    hint: 'Ketik nama evaluator...',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.list, color: Color(0xFF0F766E), size: 20),
                                      tooltip: 'Pilih dari daftar dropdown',
                                      onPressed: () {
                                        setState(() {
                                          _isManualEvaluator = false;
                                          final txt = _evaluatorCtrl.text.trim();
                                          if (txt.isNotEmpty) {
                                            if (!_evaluatorList.contains(txt)) _evaluatorList.add(txt);
                                            _selectedEvaluator = txt;
                                          }
                                        });
                                      },
                                    ),
                                  )
                                else
                                  InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Nama Evaluator',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                        borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.5),
                                      ),
                                      prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.edit_note, color: Color(0xFF0F766E), size: 20),
                                        tooltip: 'Ketik manual nama baru',
                                        onPressed: () {
                                          setState(() {
                                            _isManualEvaluator = true;
                                          });
                                        },
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _evaluatorList.contains(_selectedEvaluator) ? _selectedEvaluator : null,
                                        isExpanded: true,
                                        hint: const Text('- Pilih Evaluator -', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: null,
                                            child: Text('- Belum Dipilih -', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                          ),
                                          ..._evaluatorList.map((name) => DropdownMenuItem<String>(
                                            value: name,
                                            child: Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                                          )),
                                        ],
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedEvaluator = val;
                                            _evaluatorCtrl.text = val ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    setState(() {
                                      _isManualEvaluator = !_isManualEvaluator;
                                      if (!_isManualEvaluator) {
                                        final txt = _evaluatorCtrl.text.trim();
                                        if (txt.isNotEmpty) {
                                          if (!_evaluatorList.contains(txt)) _evaluatorList.add(txt);
                                          _selectedEvaluator = txt;
                                        }
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_isManualEvaluator ? Icons.list : Icons.edit, size: 12, color: const Color(0xFF0F766E)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isManualEvaluator ? 'Pilih dari daftar dropdown' : 'Ketik nama evaluator baru',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _komoditasCtrl,
                              label: 'Komoditas',
                              hint: 'Contoh: Nikel, Batubara, Emas',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _ndPermohonanNoCtrl,
                              label: 'ND DBM/DBB ke DBT (Permohonan)',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              controller: _ndPermohonanTglCtrl,
                              label: 'Tgl ND Permohonan',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. Riwayat Penilaian / Evaluasi Bertahap (ND DBT)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tahap aktif: $_visibleEvalCount dari 4',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Evaluasi Ke-1 (selalu tampil)
                      _buildEvalRow(
                        'Evaluasi Ke-1',
                        _eval1NoCtrl,
                        _eval1TglCtrl,
                        _eval1Status,
                        (v) => setState(() => _eval1Status = v),
                      ),
                      const SizedBox(height: 12),

                      // Evaluasi Ke-2 (selalu tampil)
                      _buildEvalRow(
                        'Evaluasi Ke-2',
                        _eval2NoCtrl,
                        _eval2TglCtrl,
                        _eval2Status,
                        (v) => setState(() => _eval2Status = v),
                      ),

                      // Evaluasi Ke-3 (tampil jika _visibleEvalCount >= 3)
                      if (_visibleEvalCount >= 3) ...[
                        const SizedBox(height: 12),
                        _buildEvalRow(
                          'Evaluasi Ke-3',
                          _eval3NoCtrl,
                          _eval3TglCtrl,
                          _eval3Status,
                          (v) => setState(() => _eval3Status = v),
                          onDelete: _visibleEvalCount == 3
                              ? () {
                                  setState(() {
                                    _eval3NoCtrl.clear();
                                    _eval3TglCtrl.clear();
                                    _eval3Status = null;
                                    _visibleEvalCount = 2;
                                  });
                                }
                              : null,
                        ),
                      ],

                      // Evaluasi Ke-4 (tampil jika _visibleEvalCount >= 4)
                      if (_visibleEvalCount >= 4) ...[
                        const SizedBox(height: 12),
                        _buildEvalRow(
                          'Evaluasi Ke-4',
                          _eval4NoCtrl,
                          _eval4TglCtrl,
                          _eval4Status,
                          (v) => setState(() => _eval4Status = v),
                          onDelete: () {
                            setState(() {
                              _eval4NoCtrl.clear();
                              _eval4TglCtrl.clear();
                              _eval4Status = null;
                              _visibleEvalCount = 3;
                            });
                          },
                        ),
                      ],

                      // Tombol Add (Tambah Tahap Evaluasi Bertahap berikutnya)
                      if (_visibleEvalCount < 4) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _visibleEvalCount++;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Text(
                                  '+ Tambah Evaluasi Bertahap (Evaluasi Ke-${_visibleEvalCount + 1})',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _catatanCtrl,
                        label: 'Catatan / Ringkasan Hasil Evaluasi FS',
                        hint: 'Tuliskan catatan teknis...',
                        maxLines: 3,
                      ),
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
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Menyimpan...' : (isEdit ? 'Simpan Perubahan' : 'Simpan Data FS')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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

  Widget _buildEvalRow(
    String label,
    TextEditingController noCtrl,
    TextEditingController tglCtrl,
    String? statusVal,
    ValueChanged<String?> onStatusChanged, {
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 3),
                        Text(
                          'Hapus Tahap',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(controller: noCtrl, label: 'Nomor ND DBT', hint: 'Nomor ND'),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildDateField(controller: tglCtrl, label: 'Tanggal ND'),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hasil Penilaian',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: statusVal,
                      hint: const Text('Pilih Status', style: TextStyle(fontSize: 11.5)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('- Belum Ada -', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Memadai', child: Text('Memadai', style: TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Belum Memadai', child: Text('Belum Memadai', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Proses', child: Text('Proses', style: TextStyle(fontSize: 12, color: Color(0xFFD97706)))),
                      ],
                      onChanged: onStatusChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
