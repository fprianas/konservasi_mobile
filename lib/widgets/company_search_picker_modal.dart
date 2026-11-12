import 'dart:async';
import 'package:flutter/material.dart';
import '../services/binwas_service.dart';

class CompanySearchPickerModal extends StatefulWidget {
  final String initialTipe; // 'semua', 'mineral', 'batubara'
  final String? initialQuery;

  const CompanySearchPickerModal({
    super.key,
    this.initialTipe = 'semua',
    this.initialQuery,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String initialTipe = 'semua',
    String? initialQuery,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompanySearchPickerModal(
        initialTipe: initialTipe,
        initialQuery: initialQuery,
      ),
    );
  }

  @override
  State<CompanySearchPickerModal> createState() => _CompanySearchPickerModalState();
}

class _CompanySearchPickerModalState extends State<CompanySearchPickerModal> {
  late String _selectedTipe;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  List<Map<String, dynamic>> _companies = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTipe = widget.initialTipe;
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    _doSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _doSearch();
    });
  }

  Future<void> _doSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final q = _searchController.text.trim();

    try {
      List<Map<String, dynamic>> results = [];
      if (_selectedTipe == 'semua') {
        // Gabungkan hasil dari mineral dan batubara
        final resMineral = await BinwasService.searchCompanies(tipe: 'mineral', q: q);
        final resBatubara = await BinwasService.searchCompanies(tipe: 'batubara', q: q);
        results = [...resMineral, ...resBatubara];
        // Sortir alfabet nama perusahaan
        results.sort((a, b) => (a['nama_perusahaan'] ?? '').toString().compareTo((b['nama_perusahaan'] ?? '').toString()));
      } else {
        results = await BinwasService.searchCompanies(tipe: _selectedTipe, q: q);
      }

      if (!mounted) return;
      setState(() {
        _companies = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryText = _searchController.text.trim();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.domain_verification, color: Color(0xFF1E3A8A), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Perusahaan dari Database',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Database Master Konservasi Mineral & Batubara',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tipe Filter Tabs & Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Filter Segment (Semua, Mineral, Batubara)
                Row(
                  children: [
                    _buildSegmentButton('semua', 'Semua Database', Icons.layers_outlined),
                    const SizedBox(width: 8),
                    _buildSegmentButton('mineral', 'Mineral', Icons.diamond_outlined),
                    const SizedBox(width: 8),
                    _buildSegmentButton('batubara', 'Batubara', Icons.terrain_outlined),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari nama PT / CV / No SK IUP / Komoditas...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: queryText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              _doSearch();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
                  ),
                ),
              ],
            ),
          ),

          // Search Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  _isLoading
                      ? 'Sedang mencari data perusahaan...'
                      : 'Ditemukan ${_companies.length} perusahaan',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 10),

          // Company List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 36),
                              const SizedBox(height: 8),
                              Text('Gagal memuat: $_errorMessage', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _doSearch, child: const Text('Coba Lagi')),
                            ],
                          ),
                        ),
                      )
                    : _companies.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 10),
                                  const Text('Perusahaan tidak ditemukan di database.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  if (queryText.isNotEmpty) ...[
                                    const Text('Anda tetap dapat menggunakan nama yang diketik:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.check, size: 16),
                                      label: Text('Gunakan "$queryText"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        Navigator.pop(context, {
                                          'nama_perusahaan': queryText,
                                          'tipe_komoditas': _selectedTipe == 'semua' ? 'mineral' : _selectedTipe,
                                          'komoditas': '',
                                          'sk_iup': '',
                                          'nama_provinsi': '',
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: _companies.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final c = _companies[idx];
                              final isMineral = (c['tipe_komoditas'] ?? '').toString().toLowerCase() == 'mineral';
                              final badgeBg = isMineral ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7);
                              final badgeBorder = isMineral ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A);
                              final badgeFg = isMineral ? const Color(0xFF1D4ED8) : const Color(0xFFD97706);

                              final String nama = c['nama_perusahaan'] ?? '';
                              final String komoditas = c['komoditas'] ?? '';
                              final String izin = c['jenis_izin'] ?? '';
                              final String skIup = c['sk_iup'] ?? '';
                              final String prov = c['nama_provinsi'] ?? '';

                              return Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Navigator.pop(context, c);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Nama Perusahaan & Badge Tipe
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nama,
                                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: badgeBorder),
                                              ),
                                              child: Text(
                                                isMineral ? 'MINERAL' : 'BATUBARA',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeFg),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Subtitle Info Row (Komoditas, Izin, Provinsi)
                                        Row(
                                          children: [
                                            if (komoditas.isNotEmpty) ...[
                                              const Icon(Icons.category_outlined, size: 13, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(komoditas, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (izin.isNotEmpty && izin != '-') ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(izin, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            if (prov.isNotEmpty) ...[
                                              const Icon(Icons.place_outlined, size: 13, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(prov, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ],
                                        ),

                                        if (skIup.isNotEmpty && skIup != '-') ...[
                                          const SizedBox(height: 4),
                                          Text('SK IUP: $skIup', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String tipe, String label, IconData icon) {
    final isSelected = _selectedTipe == tipe;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedTipe = tipe);
          _doSearch();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

