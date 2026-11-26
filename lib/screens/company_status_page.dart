import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/company_status_service.dart';
import '../widgets/security_pin_dialog.dart';

class CompanyStatusPage extends StatefulWidget {
  final ReportType initialType;

  const CompanyStatusPage({
    super.key,
    this.initialType = ReportType.batubara,
  });

  @override
  State<CompanyStatusPage> createState() => _CompanyStatusPageState();
}

class _CompanyStatusPageState extends State<CompanyStatusPage> {
  late ReportType _selectedType;
  String _selectedStatus = 'semua'; // semua | aktif | nonaktif
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<CompanyStatusItem> _items = [];
  int _totalCount = 0;
  int _aktifCount = 0;
  int _nonaktifCount = 0;
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _updatingKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await CompanyStatusService.fetchCompanies(
        type: _selectedType,
        query: _searchController.text,
        status: _selectedStatus,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _totalCount = res.total;
        _aktifCount = res.aktif;
        _nonaktifCount = res.nonaktif;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadData);
  }

  Future<void> _handleToggle(CompanyStatusItem item, bool targetActive) async {
    final pinOk = await SecurityPinDialog.verify(
      context,
      title: targetActive ? 'Aktifkan Perusahaan?' : 'Non-Aktifkan Perusahaan?',
      subtitle: targetActive
          ? 'Masukkan PIN untuk mengaktifkan kembali ${item.namaPerusahaan} ke perhitungan persentase kepatuhan.'
          : 'Masukkan PIN untuk menonaktifkan ${item.namaPerusahaan}. Perusahaan non-aktif tidak dihitung pada persentase laporan.',
      confirmLabel: targetActive ? 'Aktifkan' : 'Non-Aktifkan',
      confirmColor: targetActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      icon: targetActive ? Icons.check_circle_outline : Icons.block_outlined,
    );
    if (pinOk != true || !mounted) return;

    final key = '${item.id}_${item.skIup}';
    setState(() => _updatingKeys.add(key));

    try {
      final newState = await CompanyStatusService.toggleStatus(
        type: item.type,
        id: item.id,
        skIup: item.skIup,
        namaPerusahaan: item.namaPerusahaan,
        isActive: targetActive,
      );
      if (!mounted) return;
      setState(() {
        _updatingKeys.remove(key);
        final idx = _items.indexWhere((e) => e.id == item.id && e.skIup == item.skIup);
        if (idx != -1) {
          if (_selectedStatus != 'semua') {
            _items.removeAt(idx);
          } else {
            _items[idx] = item.copyWith(isActive: newState);
          }
        }
        if (newState && !item.isActive) {
          _aktifCount++;
          _nonaktifCount = (_nonaktifCount - 1).clamp(0, _totalCount);
        } else if (!newState && item.isActive) {
          _nonaktifCount++;
          _aktifCount = (_aktifCount - 1).clamp(0, _totalCount);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? '${item.namaPerusahaan} diaktifkan. Persentase laporan diperbarui.'
                : '${item.namaPerusahaan} dinonaktifkan. Persentase laporan diperbarui.',
          ),
          backgroundColor: newState ? const Color(0xFF16A34A) : const Color(0xFF52525B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingKeys.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBatubara = _selectedType == ReportType.batubara;
    final accentColor = isBatubara ? const Color(0xFFB45309) : const Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STATUS PERUSAHAAN',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Color(0xFF18181B),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Kelola Perusahaan Aktif / Non-Aktif (Persentase Kepatuhan)',
              style: TextStyle(fontSize: 10, color: Color(0xFF71717A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh, color: Color(0xFF18181B)),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Controls
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Sector Switcher
                Row(
                  children: [
                    Expanded(
                      child: _buildSectorTab(
                        label: 'Batubara',
                        icon: Icons.terrain,
                        selected: isBatubara,
                        color: const Color(0xFF18181B),
                        onTap: () {
                          if (!isBatubara) {
                            setState(() => _selectedType = ReportType.batubara);
                            _loadData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSectorTab(
                        label: 'Mineral',
                        icon: Icons.diamond_outlined,
                        selected: !isBatubara,
                        color: const Color(0xFF0F766E),
                        onTap: () {
                          if (isBatubara) {
                            setState(() => _selectedType = ReportType.mineral);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // KPI Summary Strip
                Row(
                  children: [
                    _buildMiniKpi('Total', '$_totalCount', const Color(0xFF18181B), const Color(0xFFF4F4F5)),
                    const SizedBox(width: 8),
                    _buildMiniKpi('Aktif', '$_aktifCount', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
                    const SizedBox(width: 8),
                    _buildMiniKpi('Non-Aktif', '$_nonaktifCount', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama perusahaan, SK IUP, atau provinsi...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
                    prefixIcon: Icon(Icons.search, size: 19, color: accentColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF4F4F5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter Chips
                Row(
                  children: [
                    _buildFilterChip('Semua', 'semua', accentColor),
                    const SizedBox(width: 8),
                    _buildFilterChip('Aktif', 'aktif', const Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    _buildFilterChip('Non-Aktif', 'nonaktif', const Color(0xFFDC2626)),
                  ],
                ),
              ],
            ),
          ),

          // Body List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 42, color: Color(0xFFEF4444)),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadData, child: const Text('Coba Lagi')),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada perusahaan yang sesuai filter.',
                              style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final key = '${item.id}_${item.skIup}';
                              final isUpdating = _updatingKeys.contains(key);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: item.isActive ? Colors.white : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: item.isActive ? const Color(0xFFE4E4E7) : const Color(0xFFFECACA),
                                  ),
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
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: item.isActive
                                                      ? const Color(0xFFDCFCE7)
                                                      : const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.isActive ? 'AKTIF' : 'NON-AKTIF',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: item.isActive
                                                        ? const Color(0xFF15803D)
                                                        : const Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (item.jenisIzin.isNotEmpty && item.jenisIzin != '-')
                                                Text(
                                                  item.jenisIzin,
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF71717A),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.namaPerusahaan,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: item.isActive
                                                  ? const Color(0xFF18181B)
                                                  : const Color(0xFF71717A),
                                              decoration: item.isActive ? null : TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'SK IUP: ${item.skIup} • ${item.provinsi}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    isUpdating
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Switch(
                                            value: item.isActive,
                                            activeThumbColor: const Color(0xFF16A34A),
                                            onChanged: (val) => _handleToggle(item, val),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorTab({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : const Color(0xFF71717A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : const Color(0xFF52525B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKpi(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        if (_selectedStatus != value) {
          setState(() => _selectedStatus = value);
          _loadData();
        }
      },
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: selected ? Colors.white : const Color(0xFF52525B),
      ),
      backgroundColor: const Color(0xFFF4F4F5),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

