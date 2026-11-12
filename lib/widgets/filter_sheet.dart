import 'package:flutter/material.dart';
import '../models/filter_options.dart';
import '../services/api_service.dart';

class FilterSheet extends StatefulWidget {
  final ReportType type;
  final FilterOptions options;
  final String? currentTahun;
  final String? currentTriwulan;
  final String? currentProvinsi;
  final String? currentStatusProduksi;
  final String? currentKomoditas;
  final String? currentJenisPerizinan;
  final Function({
    String? tahun,
    String? triwulan,
    String? provinsi,
    String? statusProduksi,
    String? komoditas,
    String? jenisPerizinan,
  }) onApply;

  const FilterSheet({
    super.key,
    required this.type,
    required this.options,
    this.currentTahun,
    this.currentTriwulan,
    this.currentProvinsi,
    this.currentStatusProduksi,
    this.currentKomoditas,
    this.currentJenisPerizinan,
    required this.onApply,
  });

  static void show(
    BuildContext context, {
    required ReportType type,
    required FilterOptions options,
    String? currentTahun,
    String? currentTriwulan,
    String? currentProvinsi,
    String? currentStatusProduksi,
    String? currentKomoditas,
    String? currentJenisPerizinan,
    required Function({
      String? tahun,
      String? triwulan,
      String? provinsi,
      String? statusProduksi,
      String? komoditas,
    String? jenisPerizinan,
    }) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterSheet(
        type: type,
        options: options,
        currentTahun: currentTahun,
        currentTriwulan: currentTriwulan,
        currentProvinsi: currentProvinsi,
        currentStatusProduksi: currentStatusProduksi,
        currentKomoditas: currentKomoditas,
        currentJenisPerizinan: currentJenisPerizinan,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _selectedTahun;
  String? _selectedTriwulan;
  String? _selectedProvinsi;
  String? _selectedStatusProduksi;
  String? _selectedKomoditas;
  String? _selectedJenisPerizinan;

  @override
  void initState() {
    super.initState();
    _selectedTahun = widget.currentTahun ?? 'semua';
    _selectedTriwulan = widget.currentTriwulan ?? 'semua';
    _selectedProvinsi = widget.currentProvinsi ?? 'semua';
    _selectedStatusProduksi = widget.currentStatusProduksi ?? 'semua';
    _selectedKomoditas = widget.currentKomoditas ?? 'semua';
    _selectedJenisPerizinan = widget.currentJenisPerizinan ?? 'semua';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 14 : 20),
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Laporan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTahun = 'semua';
                    _selectedTriwulan = 'semua';
                    _selectedProvinsi = 'semua';
                    _selectedStatusProduksi = 'semua';
                    _selectedKomoditas = 'semua';
                    _selectedJenisPerizinan = 'semua';
                  });
                },
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const Divider(),

          // Filters list
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Tahun
                  _buildLabel('Tahun'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTahun,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem(value: 'semua', child: Text('Semua Tahun')),
                      ...widget.options.tahun.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (val) => setState(() => _selectedTahun = val),
                  ),
                  const SizedBox(height: 14),

                  // Filter Triwulan
                  _buildLabel('Triwulan'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTriwulan,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem(value: 'semua', child: Text('Semua Triwulan')),
                      ...widget.options.triwulan.map((tw) => DropdownMenuItem(value: tw, child: Text(tw))),
                    ],
                    onChanged: (val) => setState(() => _selectedTriwulan = val),
                  ),
                  const SizedBox(height: 14),

                  // Filter Provinsi
                  _buildLabel('Provinsi'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvinsi,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem(value: 'semua', child: Text('Semua Provinsi')),
                      ...widget.options.provinsi.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedProvinsi = val),
                  ),
                  const SizedBox(height: 14),

                                    // Filter Jenis Perizinan
                  if (widget.options.jenisPerizinan.isNotEmpty) ...[
                    _buildLabel('Jenis Perizinan'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJenisPerizinan,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        const DropdownMenuItem(value: 'semua', child: Text('Semua Jenis Perizinan')),
                        ...widget.options.jenisPerizinan.map((jp) => DropdownMenuItem(
                              value: jp,
                              child: Text(jp, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedJenisPerizinan = val),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Filter Status Produksi
                  _buildLabel('Status Produksi'),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip('Semua', 'semua', _selectedStatusProduksi, (v) {
                        setState(() => _selectedStatusProduksi = v);
                      }),
                      _buildChoiceChip('Sudah Produksi (P)', widget.type == ReportType.batubara ? 'P' : 'sudah', _selectedStatusProduksi, (v) {
                        setState(() => _selectedStatusProduksi = v);
                      }),
                      _buildChoiceChip('Belum Produksi (BP)', widget.type == ReportType.batubara ? 'BP' : 'belum', _selectedStatusProduksi, (v) {
                        setState(() => _selectedStatusProduksi = v);
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Komoditas (Hanya Mineral)
                  if (widget.type == ReportType.mineral && widget.options.komoditas.isNotEmpty) ...[
                    _buildLabel('Komoditas Mineral'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedKomoditas,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        const DropdownMenuItem(value: 'semua', child: Text('Semua Komoditas')),
                        ...widget.options.komoditas.map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(k, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedKomoditas = val),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),

          // Apply button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                widget.onApply(
                  tahun: _selectedTahun,
                  triwulan: _selectedTriwulan,
                  provinsi: _selectedProvinsi,
                  statusProduksi: _selectedStatusProduksi,
                  komoditas: _selectedKomoditas,
                  jenisPerizinan: _selectedJenisPerizinan,
                );
                Navigator.pop(context);
              },
              child: const Text('Terapkan Filter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildChoiceChip(String label, String value, String? current, Function(String) onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (_) => onSelect(value),
    );
  }
}
