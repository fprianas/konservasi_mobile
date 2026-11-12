import 'package:flutter/material.dart';
import '../models/rekap_provinsi_item.dart';
import '../services/api_service.dart';
import 'info_page.dart';

class RekapPage extends StatefulWidget {
  const RekapPage({super.key});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  ReportType _selectedType = ReportType.batubara;
  String _selectedTahun = '';
  String _selectedTriwulan = '';

  String _selectedJenisPerizinan = 'semua';
  List<String> _availablePerizinan = [];
  List<String> _availableTahun = [];
  final List<String> _availableTriwulan = [
    'Triwulan I',
    'Triwulan II',
    'Triwulan III',
    'Triwulan IV',
  ];

  List<RekapProvinsiItem> _allRekap = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final defaultQuarter = ApiService.getDefaultQuarter();
    _selectedTahun = defaultQuarter.tahun;
    _selectedTriwulan = defaultQuarter.triwulan;

    _availableTahun = [
      defaultQuarter.tahun,
      (int.parse(defaultQuarter.tahun) - 1).toString(),
      (int.parse(defaultQuarter.tahun) - 2).toString(),
    ];

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      ApiService.fetchFilters(_selectedType).then((filters) {
        if (mounted && filters.tahun.isNotEmpty) {
          setState(() {
            final yearsSet = {..._availableTahun, ...filters.tahun}.toList();
            yearsSet.sort((a, b) => b.compareTo(a));
            _availableTahun = yearsSet;
            _availablePerizinan = filters.jenisPerizinan;
          });
        }
      }).catchError((_) {});

      final list = await ApiService.fetchRekapProvinsi(
        _selectedType,
        tahun: _selectedTahun,
        triwulan: _selectedTriwulan,
        jenisPerizinan: _selectedJenisPerizinan,
      );

      if (mounted) {
        setState(() {
          _allRekap = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<RekapProvinsiItem> get _filteredRekap {
    if (_searchQuery.trim().isEmpty) return _allRekap;
    final q = _searchQuery.toLowerCase();
    return _allRekap.where((item) => item.namaProvinsi.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isBatubara = _selectedType == ReportType.batubara;
    final filtered = _filteredRekap;

    final totalPerusahaan = _allRekap.fold<int>(0, (sum, i) => sum + i.totalPerusahaan);
    final sudahLapor = _allRekap.fold<int>(0, (sum, i) => sum + i.sudahLapor);
    final belumLapor = _allRekap.fold<int>(0, (sum, i) => sum + i.belumLapor);
    final totalLaporan = _allRekap.fold<int>(0, (sum, i) => sum + i.totalLaporan);
    final persentaseNasional = totalPerusahaan > 0
        ? ((sudahLapor * 100.0) / totalPerusahaan).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFF59E0B),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header Bar
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics, size: 20, color: Color(0xFFFBBF24)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REKAPITULASI PROVINSI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF18181B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Kepatuhan Pelaporan $_selectedTriwulan $_selectedTahun',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tentang Aplikasi',
                        icon: const Icon(Icons.info_outline, color: Color(0xFF18181B)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const InfoPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sektor Switcher (Batubara vs Mineral)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedType != ReportType.batubara) {
                              setState(() { _selectedType = ReportType.batubara; _selectedJenisPerizinan = 'semua'; });
                              _loadData();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isBatubara ? const Color(0xFF18181B) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.terrain,
                                  size: 15,
                                  color: isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Batubara',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isBatubara ? FontWeight.bold : FontWeight.w500,
                                    color: isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedType != ReportType.mineral) {
                              setState(() { _selectedType = ReportType.mineral; _selectedJenisPerizinan = 'semua'; });
                              _loadData();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !isBatubara ? const Color(0xFF18181B) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.diamond_outlined,
                                  size: 15,
                                  color: !isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Mineral',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !isBatubara ? FontWeight.bold : FontWeight.w500,
                                    color: !isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dropdown Tahun & Triwulan Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    // Dropdown Triwulan
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTriwulan,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB45309)),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181B),
                            ),
                            items: _availableTriwulan.map((tw) {
                              return DropdownMenuItem(
                                value: tw,
                                child: Text(tw),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedTriwulan) {
                                setState(() => _selectedTriwulan = val);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Dropdown Tahun
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _availableTahun.contains(_selectedTahun) ? _selectedTahun : null,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB45309)),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181B),
                            ),
                            items: _availableTahun.map((th) {
                              return DropdownMenuItem(
                                value: th,
                                child: Text('Tahun $th'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedTahun) {
                                setState(() => _selectedTahun = val);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

                        // Dropdown Jenis Perizinan di Halaman Rekap
            if (_availablePerizinan.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _availablePerizinan.contains(_selectedJenisPerizinan) ? _selectedJenisPerizinan : 'semua',
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB45309)),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18181B),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'semua', child: Text('Semua Jenis Perizinan')),
                          ..._availablePerizinan.map((izin) {
                            return DropdownMenuItem(
                              value: izin,
                              child: Text('Izin: $izin', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _selectedJenisPerizinan) {
                            setState(() => _selectedJenisPerizinan = val);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),

            // Card Ringkasan Nasional
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                isBatubara ? 'TOTAL BATUBARA' : 'TOTAL MINERAL',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFBBF24),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_allRekap.length} Provinsi',
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$persentaseNasional% Patuh',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat('Total Perusahaan', '$totalPerusahaan', Colors.white),
                          ),
                          Expanded(
                            child: _buildMiniStat('Sudah Lapor', '$sudahLapor', const Color(0xFF34D399)),
                          ),
                          Expanded(
                            child: _buildMiniStat('Belum Lapor', '$belumLapor', const Color(0xFFF87171)),
                          ),
                          Expanded(
                            child: _buildMiniStat('Berkas Laporan', '$totalLaporan', const Color(0xFFFBBF24)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar Provinsi
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama provinsi...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFB45309)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // State Loading, Error, or List Content
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _loadData,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF18181B)),
                        child: const Text('Coba Lagi', style: TextStyle(color: Color(0xFFFBBF24))),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Tidak ada data provinsi untuk filter ini.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      return _buildProvinsiCard(item, index + 1);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.white60),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProvinsiCard(RekapProvinsiItem item, int rank) {
    Color badgeColor;
    if (item.persentaseKepatuhan >= 75) {
      badgeColor = const Color(0xFF059669); // Hijau
    } else if (item.persentaseKepatuhan >= 50) {
      badgeColor = const Color(0xFFD97706); // Kuning/Amber
    } else {
      badgeColor = const Color(0xFFDC2626); // Merah
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.namaProvinsi,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18181B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.persentaseKepatuhan.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear Progress Bar Kepatuhan
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item.persentaseKepatuhan / 100.0).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),

          // 4 Kolom Metrik
          Row(
            children: [
              _buildCardMetric('Total Perusahaan', '${item.totalPerusahaan}', const Color(0xFF18181B)),
              _buildCardMetric('Sudah Lapor', '${item.sudahLapor}', const Color(0xFF059669)),
              _buildCardMetric('Belum Lapor', '${item.belumLapor}', const Color(0xFFDC2626)),
              _buildCardMetric('Total Berkas', '${item.totalLaporan}', const Color(0xFFB45309)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}