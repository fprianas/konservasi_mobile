import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class TotalsFooter extends StatefulWidget {
  final ReportType type;
  final Map<String, double> grandTotals;
  final int totalRecords;
  final Set<String> selectedColumns;
  final ValueChanged<bool>? onExpandedChanged;

  const TotalsFooter({
    super.key,
    required this.type,
    required this.grandTotals,
    required this.totalRecords,
    required this.selectedColumns,
    this.onExpandedChanged,
  });

  @override
  State<TotalsFooter> createState() => TotalsFooterState();
}

class TotalsFooterState extends State<TotalsFooter> {
  bool _isExpanded = false;

  void collapse() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      widget.onExpandedChanged?.call(false);
    }
  }

  void toggle() {
    setState(() => _isExpanded = !_isExpanded);
    widget.onExpandedChanged?.call(_isExpanded);
  }

  String _formatNumber(double val) {
    if (val == 0) return '0';
    final formatter = NumberFormat('#,##0.##', 'id_ID');
    return formatter.format(val);
  }

  List<({String key, String label, String unit, double value})> _getMetricItems() {
    if (widget.type == ReportType.batubara) {
      return [
        (
          key: 'bkr_kuantitas',
          label: 'Kuantitas BKR',
          unit: 'Ton',
          value: widget.grandTotals['bkr_kuantitas'] ?? 0.0,
        ),
        (
          key: 'pbkr_volume',
          label: 'Volume PBKR',
          unit: 'm³',
          value: widget.grandTotals['pbkr_volume'] ?? 0.0,
        ),
        (
          key: 'cm_kuantitas',
          label: 'Cad. Marginal',
          unit: 'Ton',
          value: widget.grandTotals['cm_kuantitas'] ?? 0.0,
        ),
        (
          key: 'shp_kuantitas',
          label: 'Kuantitas SHP',
          unit: 'Ton',
          value: widget.grandTotals['shp_kuantitas'] ?? 0.0,
        ),
        (
          key: 'ctt_kuantitas',
          label: 'Cad. Tdk Tertambang',
          unit: 'Ton',
          value: widget.grandTotals['ctt_kuantitas'] ?? 0.0,
        ),
      ];
    } else {
      return [
        (
          key: 'mkr_kuantitas',
          label: 'Kuantitas MKR',
          unit: 'Ton',
          value: widget.grandTotals['mkr_kuantitas'] ?? 0.0,
        ),
        (
          key: 'pmkr_volume',
          label: 'Volume PMKR',
          unit: 'm³',
          value: widget.grandTotals['pmkr_volume'] ?? 0.0,
        ),
        (
          key: 'cm_kuantitas',
          label: 'Cad. Marginal',
          unit: 'Ton',
          value: widget.grandTotals['cm_kuantitas'] ?? 0.0,
        ),
        (
          key: 'shp_kuantitas',
          label: 'Kuantitas SHP',
          unit: 'Ton',
          value: widget.grandTotals['shp_kuantitas'] ?? 0.0,
        ),
        (
          key: 'cmtt_kuantitas',
          label: 'Cad. Mineral TT',
          unit: 'Ton',
          value: widget.grandTotals['cmtt_kuantitas'] ?? 0.0,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMetrics = _getMetricItems();

    // Prioritize metrics that are in selectedColumns, or take all if none selected
    final displayMetrics = allMetrics.where((m) {
      if (widget.selectedColumns.isEmpty) return true;
      return widget.selectedColumns.contains(m.key);
    }).toList();

    final activeMetrics = displayMetrics.isNotEmpty ? displayMetrics : allMetrics;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Deep Obsidian Black
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF59E0B), width: 2), // Warm Amber Border
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar (Clickable to toggle expand)
            InkWell(
              onTap: toggle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calculate_outlined,
                        size: 16,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'TOTAL REKAPITULASI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFBBF24), // Warm Gold
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${widget.totalRecords} Data',
                                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Grand total seluruh laporan sesuai filter aktif',
                            style: TextStyle(fontSize: 10, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    // Tombol Tutup / Lihat Semua yang sangat jelas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isExpanded
                            ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isExpanded
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isExpanded ? 'Tutup' : 'Lihat Semua',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isExpanded
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFFBBF24),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isExpanded ? Icons.close : Icons.keyboard_arrow_up,
                            color: _isExpanded
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFFBBF24),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal compact metrics row (when collapsed)
            if (!_isExpanded)
              Container(
                height: 62,
                padding: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeMetrics.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final m = activeMetrics[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.label,
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                          Text(
                            '${_formatNumber(m.value)} ${m.unit}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Expanded Full Grid (when expanded)
            if (_isExpanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth >= 900) {
                            crossAxisCount = allMetrics.length.clamp(1, 5);
                          } else if (constraints.maxWidth >= 600) {
                            crossAxisCount = 3;
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              mainAxisExtent: 68,
                            ),
                            itemCount: allMetrics.length,
                            itemBuilder: (context, idx) {
                              final m = allMetrics[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      m.label,
                                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_formatNumber(m.value)} ${m.unit}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFBBF24),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
