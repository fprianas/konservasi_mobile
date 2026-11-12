import 'package:flutter/material.dart';
import '../models/evaluasi_dokumen_model.dart';
import '../services/evaluasi_dokumen_service.dart';
import 'form_fs_dialog.dart';
import 'delete_evaluasi_dialog.dart';

class DetailFsModal extends StatelessWidget {
  final EvaluasiFsItem item;
  final VoidCallback onDataChanged;

  const DetailFsModal({
    super.key,
    required this.item,
    required this.onDataChanged,
  });

  static void show(BuildContext context, EvaluasiFsItem item, {required VoidCallback onDataChanged}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetailFsModal(item: item, onDataChanged: onDataChanged),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Memadai':
        return const Color(0xFF15803D);
      case 'Belum Memadai':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.latestStatus);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    item.latestStatus.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaPerusahaan,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Komoditas: ${item.komoditas.isNotEmpty ? item.komoditas : "-"} • Evaluator: ${item.evaluator.isNotEmpty ? item.evaluator : "-"}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Disposisi Masuk
                  _buildSectionCard(
                    title: 'Permohonan Masuk',
                    icon: Icons.inbox_outlined,
                    children: [
                      _buildInfoRow('ND DBM/DBB ke DBT', item.ndPermohonanNomor),
                      _buildInfoRow('Tanggal Permohonan', item.ndPermohonanTanggal ?? '-'),
                    ],
                  ),

                  const SizedBox(height: 16),
                  // Tahapan Evaluasi
                  _buildSectionCard(
                    title: 'Riwayat Evaluasi Bertahap (ND DBT)',
                    icon: Icons.timeline,
                    children: [
                      _buildEvalStage('Tahap 1', item.eval1Nomor, item.eval1Tanggal, item.eval1Status),
                      const Divider(height: 16),
                      _buildEvalStage('Tahap 2', item.eval2Nomor, item.eval2Tanggal, item.eval2Status),
                      if (item.eval3Nomor.isNotEmpty || (item.eval3Status != null && item.eval3Status!.isNotEmpty) || (item.eval3Tanggal != null && item.eval3Tanggal!.isNotEmpty)) ...[
                        const Divider(height: 16),
                        _buildEvalStage('Tahap 3', item.eval3Nomor, item.eval3Tanggal, item.eval3Status),
                      ],
                      if (item.eval4Nomor.isNotEmpty || (item.eval4Status != null && item.eval4Status!.isNotEmpty) || (item.eval4Tanggal != null && item.eval4Tanggal!.isNotEmpty)) ...[
                        const Divider(height: 16),
                        _buildEvalStage('Tahap 4', item.eval4Nomor, item.eval4Tanggal, item.eval4Status),
                      ],
                    ],
                  ),

                  if (item.catatan.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Catatan Evaluasi',
                      icon: Icons.notes,
                      children: [
                        Text(item.catatan, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 0),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  tooltip: 'Hapus Evaluasi FS',
                  onPressed: () => _confirmDelete(context),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Data'),
                  onPressed: () {
                    Navigator.pop(context);
                    FormFsDialog.show(context, item: item, onSaved: onDataChanged);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvalStage(String label, String no, String? tgl, String? status) {
    final hasData = no.isNotEmpty || tgl != null || status != null;
    final color = status != null ? _getStatusColor(status) : const Color(0xFF64748B);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: hasData
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(no.isNotEmpty ? no : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    Text('Tanggal: ${tgl ?? "-"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                )
              : const Text('Belum ada evaluasi', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
        ),
        if (status != null && status.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
            ),
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) async {
    final deleted = await DeleteEvaluasiDialog.show(
      context,
      title: 'Hapus Evaluasi FS?',
      namaPerusahaan: item.namaPerusahaan,
      itemType: 'FS',
      onDelete: (pin) async {
        await EvaluasiDokumenService.deleteFs(item.id, pin: pin);
      },
    );
    if (deleted == true && context.mounted) {
      Navigator.pop(context);
      onDataChanged();
    }
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ),
          const Text(' :  ', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}

