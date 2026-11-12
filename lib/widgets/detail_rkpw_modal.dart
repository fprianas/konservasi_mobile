import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluasi_dokumen_model.dart';
import '../services/evaluasi_dokumen_service.dart';
import 'form_rkpw_dialog.dart';
import 'delete_evaluasi_dialog.dart';

class DetailRkpwModal extends StatelessWidget {
  final EvaluasiRkpwItem item;
  final VoidCallback onDataChanged;

  const DetailRkpwModal({
    super.key,
    required this.item,
    required this.onDataChanged,
  });

  static void show(BuildContext context, EvaluasiRkpwItem item, {required VoidCallback onDataChanged}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetailRkpwModal(item: item, onDataChanged: onDataChanged),
    );
  }

  String _formatNumber(double val) {
    if (val == 0) return '0';
    return NumberFormat('#,##0.##', 'id_ID').format(val);
  }

  String _formatRupiah(double val) {
    if (val == 0) return 'Rp 0';
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
        return const Color(0xFF15803D);
      case 'Ditolak':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.status);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                    item.status.toUpperCase(),
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
                        'Komoditas: ${item.komoditas.isNotEmpty ? item.komoditas : item.jenisKomoditas} • Evaluator: ${item.evaluator.isNotEmpty ? item.evaluator : "-"}',
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
                  // KPI Luas & KDI Ringkasan
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Luas Dimohon',
                          '${_formatNumber(item.luasPerluasanDimohon)} Ha',
                          Icons.crop_landscape,
                          const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          'Luas Disetujui',
                          '${_formatNumber(item.luasDisetujui)} Ha',
                          Icons.verified,
                          const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          'Total Luas Akhir',
                          '${_formatNumber(item.totalLuasSekarang)} Ha',
                          Icons.map,
                          const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  // Informasi IUP & Lokasi
                  _buildSectionCard(
                    title: 'Informasi IUP & Lokasi Tambang',
                    icon: Icons.layers_outlined,
                    children: [
                      _buildInfoRow('Nomor SK IUP', item.noSkIup),
                      _buildInfoRow('Masa Berlaku', item.masaBerlaku),
                      _buildInfoRow('Luas WIUP Awal', '${_formatNumber(item.luasWiup)} Ha'),
                      _buildInfoRow('Provinsi', item.provinsi),
                      _buildInfoRow('Kabupaten/Kota', item.kabupaten),
                      _buildInfoRow('Kecamatan', item.kecamatan),
                    ],
                  ),

                  const SizedBox(height: 16),
                  // Surat Permohonan & Tanggal Masuk
                  _buildSectionCard(
                    title: 'Surat Permohonan & Tracking Masuk',
                    icon: Icons.email_outlined,
                    children: [
                      _buildInfoRow('Nomor Surat Perusahaan', item.suratPermohonanNomor),
                      _buildInfoRow('Tanggal Surat Perusahaan', item.suratPermohonanTanggal ?? '-'),
                      _buildInfoRow('Masuk Ditjen Minerba (DJMB)', item.tglMasukDjmb ?? '-'),
                      _buildInfoRow('Masuk Direktorat (DBT)', item.tglMasukDbt ?? '-'),
                      _buildInfoRow('Masuk Subdit (SDKM)', item.tglMasukSdkm ?? '-'),
                    ],
                  ),

                  const SizedBox(height: 16),
                  // Disposisi Nota Dinas
                  _buildSectionCard(
                    title: 'Disposisi Nota Dinas & Evaluasi Internal',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildInfoRow('ND DBT Permohonan Evaluasi', item.ndDbtPermohonanNomor),
                      _buildInfoRow('Tgl ND Permohonan', item.ndDbtPermohonanTanggal),
                      _buildInfoRow('ND DBT (Hasil Evaluasi KM)', '${item.ndDbtKmNomor} (${item.ndDbtKmTanggal ?? "-"})'),
                      _buildInfoRow('ND DBP (Hasil Evaluasi PW)', '${item.ndDbpPwNomor} (${item.ndDbpPwTanggal ?? "-"})'),
                      _buildInfoRow('ND DBM/DBB (Hasil Evaluasi PE)', '${item.ndDbmPeNomor} (${item.ndDbmPeTanggal ?? "-"})'),
                      _buildInfoRow('Surat DJB Kompilasi KM PE PW', '${item.suratDjbNomor} (${item.suratDjbTanggal ?? "-"})'),
                    ],
                  ),

                  const SizedBox(height: 16),
                  // Keputusan, SK Perluasan & KDI
                  _buildSectionCard(
                    title: 'Keputusan, SK Perluasan & Pembayaran KDI',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _buildInfoRow('Surat Menteri ESDM (MEM)', '${item.suratMemNomor} (${item.suratMemTanggal ?? "-"})'),
                      _buildInfoRow('Nomor SK Perluasan', item.skPerluasanNomor),
                      _buildInfoRow('Tanggal SK Perluasan', item.skPerluasanTanggal ?? '-'),
                      _buildInfoRow('Luas Disetujui', '${_formatNumber(item.luasDisetujui)} Ha'),
                      _buildInfoRow('Nilai Pembayaran KDI', _formatRupiah(item.kdiNilaiRp)),
                      _buildInfoRow('Status KDI', item.kdiStatusBayar, valueColor: item.kdiStatusBayar == 'Lunas' ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                      _buildInfoRow('Catatan Evaluasi', item.catatanEvaluasi.isNotEmpty ? item.catatanEvaluasi : '-'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
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
                  tooltip: 'Hapus Permohonan',
                  onPressed: () => _confirmDelete(context),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Data'),
                  onPressed: () {
                    Navigator.pop(context);
                    FormRkpwDialog.show(context, item: item, onSaved: onDataChanged);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final deleted = await DeleteEvaluasiDialog.show(
      context,
      title: 'Hapus Permohonan RKPW?',
      namaPerusahaan: item.namaPerusahaan,
      itemType: 'RKPW',
      onDelete: (pin) async {
        await EvaluasiDokumenService.deleteRkpw(item.id, pin: pin);
      },
    );
    if (deleted == true && context.mounted) {
      Navigator.pop(context);
      onDataChanged();
    }
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), maxLines: 1),
        ],
      ),
    );
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
              Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

