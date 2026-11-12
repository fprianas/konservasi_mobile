import 'package:flutter/material.dart';
import '../models/binwas_model.dart';
import '../services/binwas_service.dart';

class EditInspeksiDialog extends StatefulWidget {
  final BinwasInspeksiRecord record;
  final VoidCallback? onUpdated;

  const EditInspeksiDialog({
    super.key,
    required this.record,
    this.onUpdated,
  });

  @override
  State<EditInspeksiDialog> createState() => _EditInspeksiDialogState();
}

class _EditItemState {
  final int id;
  final String namaKategori;
  final String deskripsiTemuan;
  final String objekKonservasi;
  bool adaTemuan;
  final TextEditingController keteranganController;
  final TextEditingController rekomendasiController;

  _EditItemState({
    required this.id,
    required this.namaKategori,
    required this.deskripsiTemuan,
    required this.objekKonservasi,
    required this.adaTemuan,
    required String initialKeterangan,
    required String initialRekomendasi,
  })  : keteranganController = TextEditingController(text: initialKeterangan),
        rekomendasiController = TextEditingController(text: initialRekomendasi);

  void dispose() {
    keteranganController.dispose();
    rekomendasiController.dispose();
  }
}

class _EditInspeksiDialogState extends State<EditInspeksiDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _petugasController;
  late TextEditingController _tanggalController;
  late String _selectedTriwulan;
  late int _selectedTahun;
  late List<_EditItemState> _items;
  bool _isSaving = false;

  final List<String> _triwulanOptions = const ['TW 1', 'TW 2', 'TW 3', 'TW 4'];
  final List<int> _tahunOptions = const [2024, 2025, 2026, 2027, 2028];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _petugasController = TextEditingController(text: r.namaPetugas == '-' ? '' : r.namaPetugas);
    _tanggalController = TextEditingController(text: r.tanggalInspeksi == '-' ? '' : r.tanggalInspeksi);

    // Normalize Triwulan
    final tw = r.triwulan.toUpperCase();
    if (tw.contains('1')) {
      _selectedTriwulan = 'TW 1';
    } else if (tw.contains('2')) {
      _selectedTriwulan = 'TW 2';
    } else if (tw.contains('3')) {
      _selectedTriwulan = 'TW 3';
    } else if (tw.contains('4')) {
      _selectedTriwulan = 'TW 4';
    } else {
      _selectedTriwulan = _triwulanOptions.contains(r.triwulan) ? r.triwulan : 'TW 1';
    }

    _selectedTahun = _tahunOptions.contains(r.tahun) ? r.tahun : 2026;

    _items = r.items.map((item) {
      return _EditItemState(
        id: item.id,
        namaKategori: item.namaKategori,
        deskripsiTemuan: item.deskripsiTemuan,
        objekKonservasi: item.objekKonservasi,
        adaTemuan: item.adaTemuan,
        initialKeterangan: item.keteranganLapangan,
        initialRekomendasi: item.rekomendasi,
      );
    }).toList();
  }

  @override
  void dispose() {
    _petugasController.dispose();
    _tanggalController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(_tanggalController.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Pilih Tanggal Inspeksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _tanggalController.text = '$y-$m-$d';
      });
    }
  }

  Future<void> _submitUpdate() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'id_inspeksi': widget.record.id,
        'nama_petugas': _petugasController.text.trim(),
        'tanggal_inspeksi': _tanggalController.text.trim(),
        'triwulan': _selectedTriwulan,
        'tahun': _selectedTahun,
        'temuan': _items.map((item) {
          return {
            'id_detail': item.id,
            'ada_temuan': item.adaTemuan ? 1 : 0,
            'keterangan_lapangan': item.keteranganController.text.trim(),
            'rekomendasi': item.rekomendasiController.text.trim(),
          };
        }).toList(),
      };

      final res = await BinwasService.updateInspeksi(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Data inspeksi berhasil diperbarui!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      widget.onUpdated?.call();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Koreksi / Edit Data Inspeksi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.namaPerusahaan,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    // Informasi Header Inspeksi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 6),
                              Text(
                                'Data Utama Inspeksi Lapangan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Petugas
                          TextFormField(
                            controller: _petugasController,
                            decoration: InputDecoration(
                              labelText: 'Nama Petugas Lapangan *',
                              hintText: 'Masukkan nama petugas binwas...',
                              isDense: true,
                              prefixIcon: const Icon(Icons.person, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Nama petugas wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Row: Tanggal, Triwulan, Tahun
                          if (screenWidth < 500) ...[
                            TextFormField(
                              controller: _tanggalController,
                              readOnly: true,
                              onTap: _pickDate,
                              decoration: InputDecoration(
                                labelText: 'Tanggal Inspeksi *',
                                hintText: 'YYYY-MM-DD',
                                isDense: true,
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.date_range, size: 18),
                                  onPressed: _pickDate,
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Tanggal wajib diisi' : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedTriwulan,
                                    decoration: InputDecoration(
                                      labelText: 'Triwulan',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _triwulanOptions.map((t) {
                                      return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTriwulan = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedTahun,
                                    decoration: InputDecoration(
                                      labelText: 'Tahun',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _tahunOptions.map((th) {
                                      return DropdownMenuItem(value: th, child: Text('$th', style: const TextStyle(fontSize: 12.5)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTahun = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _tanggalController,
                                    readOnly: true,
                                    onTap: _pickDate,
                                    decoration: InputDecoration(
                                      labelText: 'Tanggal Inspeksi *',
                                      hintText: 'YYYY-MM-DD',
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.date_range, size: 18),
                                        onPressed: _pickDate,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Tanggal wajib diisi' : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedTriwulan,
                                    decoration: InputDecoration(
                                      labelText: 'Triwulan',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _triwulanOptions.map((t) {
                                      return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTriwulan = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedTahun,
                                    decoration: InputDecoration(
                                      labelText: 'Tahun',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _tahunOptions.map((th) {
                                      return DropdownMenuItem(value: th, child: Text('$th', style: const TextStyle(fontSize: 12.5)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTahun = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Section Butir Temuan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daftar Butir Temuan Lapangan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            '${_items.where((i) => i.adaTemuan).length} Temuan Aktif',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Tidak ada rincian butir untuk inspeksi ini.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: item.adaTemuan ? const Color(0xFFFFFBEB) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.adaTemuan ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
                              width: item.adaTemuan ? 1.5 : 1.0,
                            ),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: item.adaTemuan,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            leading: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: item.adaTemuan ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  color: item.adaTemuan ? Colors.white : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            title: Text(
                              item.deskripsiTemuan,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: item.adaTemuan ? const Color(0xFF92400E) : const Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${item.namaKategori} • ${item.objekKonservasi}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: Switch(
                              value: item.adaTemuan,
                              activeThumbColor: const Color(0xFFDC2626),
                              onChanged: (val) {
                                setState(() {
                                  item.adaTemuan = val;
                                });
                              },
                            ),
                            children: [
                              const Divider(height: 10),
                              const SizedBox(height: 4),
                              if (item.adaTemuan) ...[
                                TextFormField(
                                  controller: item.keteranganController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Keterangan Temuan di Lapangan',
                                    hintText: 'Tuliskan deskripsi temuan fakta lapangan...',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: item.rekomendasiController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Rekomendasi / Saran Perbaikan',
                                    hintText: 'Tuliskan rekomendasi teknis perbaikan...',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ] else ...[
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      'Status: Tidak ada temuan (Patuh / Sesuai kaidah konservasi)',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF16A34A), fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
}

