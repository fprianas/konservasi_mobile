import 'package:flutter/material.dart';
import '../models/evaluasi_perusahaan_model.dart';
import '../models/report_item.dart';
import '../services/api_service.dart';
import 'detail_modal.dart';
import 'evaluasi_perusahaan_dialog.dart';
import 'security_pin_dialog.dart';

class ReportCard extends StatefulWidget {
  final ReportItem item;
  final ReportType type;
  final Set<String> selectedColumns;
  final EvaluasiPerusahaanItem? initialEvaluasi;
  final ValueChanged<EvaluasiPerusahaanItem?>? onEvaluasiChanged;

  const ReportCard({
    super.key,
    required this.item,
    required this.type,
    required this.selectedColumns,
    this.initialEvaluasi,
    this.onEvaluasiChanged,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  EvaluasiPerusahaanItem? _evaluasi;

  @override
  void initState() {
    super.initState();
    _evaluasi = widget.initialEvaluasi;
  }

  @override
  void didUpdateWidget(covariant ReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEvaluasi != oldWidget.initialEvaluasi) {
      _evaluasi = widget.initialEvaluasi;
    }
  }

  String _formatMetricLabel(String key) {
    switch (key) {
      case 'bkr_kuantitas':
        return 'BKR Kuantitas';
      case 'pbkr_volume':
        return 'PBKR Volume';
      case 'cm_kuantitas':
        return 'Cad. Marginal';
      case 'shp_kuantitas':
        return 'SHP Kuantitas';
      case 'ctt_kuantitas':
        return 'Cad. Tdk Tertambang';
      case 'mkr_kuantitas':
        return 'MKR Kuantitas';
      case 'pmkr_volume':
        return 'PMKR Volume';
      case 'cmtt_kuantitas':
        return 'Cad. Mineral TT';
      case 'rec_penambangan':
        return 'Rec. Tambang';
      case 'rec_pengolahan':
        return 'Rec. Pengolahan';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  Future<void> _openEvaluasiModal(BuildContext context, bool isProd) async {
    if (_evaluasi != null) {
      final verified = await SecurityPinDialog.verify(
        context,
        title: 'Ubah Data Evaluasi',
        subtitle: widget.item.namaPerusahaan,
        confirmLabel: 'Buka Form Ubah',
        confirmColor: const Color(0xFF0F766E),
        icon: Icons.edit_note,
      );
      if (verified != true || !mounted) return;
    }

    if (!context.mounted) return;
    final lapFile = widget.item.laporanFile?.trim();
    final petaFile = widget.item.petaFile?.trim();
    final laporanUrl = (lapFile != null && lapFile.isNotEmpty && lapFile != '-')
        ? ApiService.getFileUrl(widget.type, lapFile, fileKind: 'laporan')
        : null;
    final petaUrl = (petaFile != null && petaFile.isNotEmpty && petaFile != '-')
        ? ApiService.getFileUrl(widget.type, petaFile, fileKind: 'peta')
        : null;

    final result = await EvaluasiPerusahaanDialog.show(
      context,
      namaPerusahaan: widget.item.namaPerusahaan,
      tipe: widget.type == ReportType.batubara ? 'batubara' : 'mineral',
      komoditas: widget.item.komoditas,
      skIup: widget.item.skIup,
      provinsi: widget.item.provinsi,
      triwulan: widget.item.triwulan,
      tahun: int.tryParse(widget.item.tahun) ?? 0,
      statusProduksi: isProd ? 'Produksi' : 'Belum Produksi',
      initialData: _evaluasi,
      laporanUrl: laporanUrl,
      petaUrl: petaUrl,
    );

    if (result != null && mounted) {
      setState(() {
        if (result.id == -1) {
          _evaluasi = null; // Terhapus
        } else {
          _evaluasi = result; // Disimpan / diupdate
        }
      });
      widget.onEvaluasiChanged?.call(_evaluasi);
    }
  }

  Widget _buildEvaluasiButton(BuildContext context, bool isProd) {
    if (_evaluasi == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEvaluasiModal(context, isProd),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Light Warm Amber
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.rate_review_outlined, size: 12, color: Color(0xFFB45309)),
                SizedBox(width: 4),
                Text(
                  'Evaluasi',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMemadai = _evaluasi!.isMemadai;
    final badgeBg = isMemadai ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final badgeBorder = isMemadai ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final badgeText = isMemadai ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final iconData = isMemadai ? Icons.check_circle : Icons.error_outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEvaluasiModal(context, isProd),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeBorder.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 12, color: badgeBorder),
                  const SizedBox(width: 4),
                  Text(
                    _evaluasi!.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 11, color: badgeText),
                ],
              ),
              if (_evaluasi!.formatLaporan.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Format: ${_evaluasi!.formatLaporan}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: _evaluasi!.isFormatSesuai ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final type = widget.type;
    final selectedColumns = widget.selectedColumns;
    final isProd = item.statusProduksiCode == 'P';

    // Filter which optional metrics to display
    final activeMetrics = <String, String>{};
    for (final col in selectedColumns) {
      final val = item.metrics[col]?.toString();
      if (val != null &&
          val.trim().isNotEmpty &&
          val != '-' &&
          val != 'null' &&
          val != '0' &&
          val != '0.00' &&
          val != '0,00') {
        activeMetrics[col] = DetailModal.formatDisplayValue(col, val, type);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFDF5), // Soft pastel yellow/cream
            Colors.white,       // Clean white
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => DetailModal.show(context, item, type),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Nama Perusahaan & Right Column (Produksi Badge + Tombol Evaluasi)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.namaPerusahaan,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18181B), // Solid black
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Badge Produksi / Belum Produksi
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B), // Sleek Black Accent
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isProd ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isProd ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isProd ? 'Produksi' : 'Belum Prod.',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isProd ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Tombol 'Evaluasi'
                        _buildEvaluasiButton(context, isProd),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // SK IUP & Provinsi
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF71717A)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.skIup,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF3F3F46)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF71717A)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.provinsi,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF3F3F46)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Tags Row: Periode Laporan & Izin
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Triwulan + Tahun
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7), // Light Warm Amber
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '${item.triwulan} ${item.tahun}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    // Jenis Izin
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                      ),
                      child: Text(
                        item.jenisPerizinan,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF18181B),
                        ),
                      ),
                    ),
                    if (item.komoditas != null && item.komoditas!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B), // Black chip
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.komoditas!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                  ],
                ),

                // Dynamic Optional Columns
                if (activeMetrics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // Soft yellow container
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: activeMetrics.entries.map((entry) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_formatMetricLabel(entry.key)}: ',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                            ),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF18181B), // Bold Black
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Bottom footer hint
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text(
                      'Ketuk untuk detail lengkap',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309), // Amber brown
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 14, color: Color(0xFFB45309)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
