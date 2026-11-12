import 'package:flutter/material.dart';
import '../models/analysis_data.dart';
import '../services/api_service.dart';
import 'info_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  ReportType _selectedType = ReportType.batubara;
  bool _isNasional = true;
  String? _selectedProvinsi;

  String _tahunCurrent = '';
  String _triwulanCurrent = '';
  String _tahunPrev = '';
  String _triwulanPrev = '';

  List<String> _availableTahun = [];
  final List<String> _availableTriwulan = [
    'Triwulan I',
    'Triwulan II',
    'Triwulan III',
    'Triwulan IV',
  ];
  List<String> _availableProvinsi = [];

  AnalysisData? _analysisData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPeriods();
    _loadFiltersAndData();
  }

  void _initPeriods() {
    final defaultQuarter = ApiService.getDefaultQuarter();
    _tahunCurrent = defaultQuarter.tahun;
    _triwulanCurrent = defaultQuarter.triwulan;

    final curYearInt = int.tryParse(_tahunCurrent) ?? DateTime.now().year;
    _availableTahun = [
      curYearInt.toString(),
      (curYearInt - 1).toString(),
      (curYearInt - 2).toString(),
    ];

    // Tentukan periode pembanding default (1 triwulan sebelumnya)
    final twIndex = _availableTriwulan.indexOf(_triwulanCurrent);
    if (twIndex > 0) {
      _triwulanPrev = _availableTriwulan[twIndex - 1];
      _tahunPrev = _tahunCurrent;
    } else {
      _triwulanPrev = 'Triwulan IV';
      _tahunPrev = (curYearInt - 1).toString();
    }
  }

  Future<void> _loadFiltersAndData() async {
    try {
      final filters = await ApiService.fetchFilters(_selectedType);
      if (mounted) {
        setState(() {
          _availableProvinsi = filters.provinsi;
        });
      }
    } catch (_) {}

    await _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.fetchAnalysisData(
        type: _selectedType,
        tahunCurrent: _tahunCurrent,
        triwulanCurrent: _triwulanCurrent,
        tahunPrev: _tahunPrev,
        triwulanPrev: _triwulanPrev,
        provinsi: _isNasional ? null : _selectedProvinsi,
      );

      if (mounted) {
        setState(() {
          _analysisData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat analisis: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBatubara = _selectedType == ReportType.batubara;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ANALISIS KEPATUHAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF18181B),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const Text(
              'Trend Perubahan & Evaluasi Konservasi',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tentang Aplikasi',
            icon: const Icon(Icons.info_outline, color: Color(0xFF18181B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InfoPage()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalysis,
        color: const Color(0xFFF59E0B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sektor Tab Switcher (Batubara vs Mineral)
              _buildSektorSwitcher(isBatubara),
              const SizedBox(height: 12),

              // Filter Controls Card (Cakupan & Periode Komparasi)
              _buildFilterControlCard(),
              const SizedBox(height: 14),

              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else if (_analysisData != null) ...[
                // Hero Tren Card
                _buildHeroTrendCard(_analysisData!),
                const SizedBox(height: 14),

                // Top Climbers vs Needs Attention (Jika Nasional)
                if (_isNasional && _analysisData!.provinceTrends.isNotEmpty) ...[
                  _buildProvinceDynamicsSection(_analysisData!),
                  const SizedBox(height: 14),
                ],

                // Analisis Khusus
                _buildSpecialAnalysisSection(_analysisData!),
                const SizedBox(height: 14),

                // Executive Summary / AI Insight Box
                _buildExecutiveInsightBox(_analysisData!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSektorSwitcher(bool isBatubara) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
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
                  setState(() => _selectedType = ReportType.batubara);
                  _loadFiltersAndData();
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
                      size: 16,
                      color: isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Batubara',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isBatubara ? FontWeight.bold : FontWeight.w500,
                        color: isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF71717A),
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
                  setState(() => _selectedType = ReportType.mineral);
                  _loadFiltersAndData();
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
                      size: 16,
                      color: !isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mineral',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: !isBatubara ? FontWeight.bold : FontWeight.w500,
                        color: !isBatubara ? const Color(0xFFFBBF24) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControlCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cakupan Segmented Switch: Nasional vs Per Provinsi
          Row(
            children: [
              const Text(
                'Cakupan Analisis:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
              ),
              const Spacer(),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_isNasional) {
                          setState(() {
                            _isNasional = true;
                            _selectedProvinsi = null;
                          });
                          _loadAnalysis();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isNasional ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Nasional',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _isNasional ? FontWeight.bold : FontWeight.w500,
                            color: _isNasional ? const Color(0xFF18181B) : const Color(0xFF71717A),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_isNasional) {
                          setState(() {
                            _isNasional = false;
                            if (_availableProvinsi.isNotEmpty && _selectedProvinsi == null) {
                              _selectedProvinsi = _availableProvinsi.first;
                            }
                          });
                          _loadAnalysis();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isNasional ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Per Provinsi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: !_isNasional ? FontWeight.bold : FontWeight.w500,
                            color: !_isNasional ? const Color(0xFF18181B) : const Color(0xFF71717A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Jika Per Provinsi, tampilkan dropdown pilihan provinsi
          if (!_isNasional) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProvinsi,
                  hint: const Text('Pilih Provinsi', style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB45309)),
                  isExpanded: true,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
                  items: _availableProvinsi.map((prov) {
                    return DropdownMenuItem(value: prov, child: Text(prov));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedProvinsi = val);
                      _loadAnalysis();
                    }
                  },
                ),
              ),
            ),
          ],

          const Divider(height: 18),

          // Komparasi Periode Baris
          Row(
            children: [
              // Periode Utama (Berjalan)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Periode Berjalan',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildSmallDropdown(
                            value: _triwulanCurrent,
                            items: _availableTriwulan,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _triwulanCurrent = val);
                                _loadAnalysis();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 2,
                          child: _buildSmallDropdown(
                            value: _tahunCurrent,
                            items: _availableTahun,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _tahunCurrent = val);
                                _loadAnalysis();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.compare_arrows, size: 18, color: Color(0xFF71717A)),
              ),
              // Periode Pembanding (Sebelumnya)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF6B7280), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Periode Pembanding',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildSmallDropdown(
                            value: _triwulanPrev,
                            items: _availableTriwulan,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _triwulanPrev = val);
                                _loadAnalysis();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 2,
                          child: _buildSmallDropdown(
                            value: _tahunPrev,
                            items: _availableTahun,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _tahunPrev = val);
                                _loadAnalysis();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFFB45309)),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
          items: items.map((it) => DropdownMenuItem(value: it, child: Text(it, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHeroTrendCard(AnalysisData data) {
    final delta = data.deltaKepatuhan;
    final isUp = delta > 0.05;
    final isDown = delta < -0.05;

    Color deltaColor;
    IconData deltaIcon;
    String deltaText;
    if (isUp) {
      deltaColor = const Color(0xFF10B981); // Emerald Green
      deltaIcon = Icons.trending_up;
      deltaText = '+${delta.toStringAsFixed(1)}% Meningkat';
    } else if (isDown) {
      deltaColor = const Color(0xFFEF4444); // Red
      deltaIcon = Icons.trending_down;
      deltaText = '${delta.toStringAsFixed(1)}% Menurun';
    } else {
      deltaColor = const Color(0xFF71717A); // Gray
      deltaIcon = Icons.trending_flat;
      deltaText = '0.0% Stabil';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF18181B), Color(0xFF27272A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, size: 20, color: Color(0xFFFBBF24)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNasional ? 'TREN KEPATUHAN NASIONAL' : 'TREN KEPATUHAN ${_selectedProvinsi?.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${data.triwulanCurrent} ${data.tahunCurrent} vs ${data.triwulanPrev} ${data.tahunPrev}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: deltaColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(deltaIcon, size: 14, color: deltaColor),
                    const SizedBox(width: 4),
                    Text(
                      deltaText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Main Comparison Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tingkat Kepatuhan Sekarang', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        data.kepatuhanCurrent.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      const Text(
                        '%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Periode Sebelumnya', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
                  const SizedBox(height: 2),
                  Text(
                    '${data.kepatuhanPrev.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar Komparasi
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (data.kepatuhanCurrent / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF3F3F46),
              color: const Color(0xFFF59E0B),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF3F3F46), height: 1),
          const SizedBox(height: 14),

          // Statistik Tambahan (Total Laporan, Sudah Lapor)
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  label: 'Total Perusahaan',
                  val: data.totalPerusahaan.toString(),
                  icon: Icons.business,
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFF3F3F46)),
              Expanded(
                child: _buildMetricMini(
                  label: 'Sudah Lapor',
                  val: '${data.sudahLaporCurrent} (${data.sudahLaporCurrent - data.sudahLaporPrev >= 0 ? '+' : ''}${data.sudahLaporCurrent - data.sudahLaporPrev})',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFF3F3F46)),
              Expanded(
                child: _buildMetricMini(
                  label: 'Laporan Masuk',
                  val: '${data.totalLaporanCurrent}',
                  icon: Icons.description_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String label,
    required String val,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProvinceDynamicsSection(AnalysisData data) {
    final climbers = data.topClimbers;
    final decliners = data.topDecliners;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.leaderboard, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Text(
                'Dinamika Kepatuhan Antar Provinsi',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Peningkatan Tertinggi
          if (climbers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.arrow_upward, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        'Peningkatan Kepatuhan Tertinggi (Top Climbers)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...climbers.map((p) => _buildProvinceDeltaRow(p, isPositive: true)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Penurunan / Perlu Perhatian
          if (decliners.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Text(
                        'Perlu Perhatian Khusus (Penurunan Kepatuhan)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...decliners.map((p) => _buildProvinceDeltaRow(p, isPositive: false)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProvinceDeltaRow(ProvinceAnalysisTrend p, {required bool isPositive}) {
    final color = isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.namaProvinsi,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF18181B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${p.kepatuhanPrev.toStringAsFixed(0)}% → ${p.kepatuhanCurrent.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isPositive ? '+' : ''}${p.delta.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialAnalysisSection(AnalysisData data) {
    final sp = data.specialAnalysis;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Text(
                'Analisis Khusus & Profil Operasional',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Rasio Aktivitas: Sudah Produksi vs Belum Produksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rasio Aktivitas Tambang (Produksi vs Eksplorasi):', style: TextStyle(fontSize: 11.5, color: Color(0xFF3F3F46))),
              Text(
                '${sp.persentaseProduksi}% Aktif',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: sp.totalProduksi > 0 ? sp.totalProduksi : 1,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  Expanded(
                    flex: sp.totalBelumProduksi > 0 ? sp.totalBelumProduksi : 1,
                    child: Container(color: const Color(0xFFE4E4E7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sudah Produksi: ${sp.totalProduksi} perush.', style: const TextStyle(fontSize: 10, color: Color(0xFF059669))),
              Text('Belum Produksi: ${sp.totalBelumProduksi} perush.', style: const TextStyle(fontSize: 10, color: Color(0xFF71717A))),
            ],
          ),

          const Divider(height: 22),

          // 2. Kelengkapan Lampiran Dokumen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kepatuhan Lampiran Laporan Teknis:', style: TextStyle(fontSize: 11.5, color: Color(0xFF3F3F46))),
              Text(
                '${sp.persentaseKelengkapanDokumen}% Lengkap',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (sp.persentaseKelengkapanDokumen / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFF4F4F5),
              color: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dokumen PDF: ${sp.totalDenganDokumen} file', style: const TextStyle(fontSize: 10, color: Color(0xFF71717A))),
              Text('Peta Kemajuan: ${sp.totalDenganPeta} file', style: const TextStyle(fontSize: 10, color: Color(0xFF71717A))),
            ],
          ),

          if (sp.perizinanBreakdown.isNotEmpty) ...[
            const Divider(height: 22),
            const Text('Sebaran Jenis Perizinan Pelapor:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF18181B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sp.perizinanBreakdown.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExecutiveInsightBox(AnalysisData data) {
    final isUp = data.deltaKepatuhan >= 0;
    final statusWord = isUp ? 'meningkat' : 'mengalami penurunan';
    final topClimber = data.topClimbers.isNotEmpty ? data.topClimbers.first.namaProvinsi : 'sebagian wilayah';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 6),
              Text(
                'Kesimpulan & Rekomendasi Konservasi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Berdasarkan data komparasi ${_selectedType == ReportType.batubara ? "Batubara" : "Mineral"} antara ${data.triwulanCurrent} ${data.tahunCurrent} terhadap ${data.triwulanPrev} ${data.tahunPrev}, tingkat kepatuhan pelaporan $statusWord sebesar ${data.deltaKepatuhan.abs().toStringAsFixed(1)}% menjadi ${data.kepatuhanCurrent.toStringAsFixed(1)}%.\n\n'
            'Daerah dengan akselerasi kepatuhan terbaik dicatatkan oleh $topClimber. '
            'Rekomendasi konservasi: lakukan supervisi langsung ke perusahaan berstatus belum lapor untuk menjamin pemantauan kaidah konservasi pertambangan berkelanjutan.',
            style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF78350F)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 260,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: Color(0xFFF59E0B)),
          SizedBox(height: 14),
          Text(
            'Menganalisis data kepatuhan & tren...',
            style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Terjadi kesalahan',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18181B),
              foregroundColor: const Color(0xFFFBBF24),
            ),
            onPressed: _loadAnalysis,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
