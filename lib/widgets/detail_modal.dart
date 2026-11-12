import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/report_item.dart';
import '../services/api_service.dart';

class DetailModal extends StatelessWidget {
  final ReportItem item;
  final ReportType type;

  const DetailModal({
    super.key,
    required this.item,
    required this.type,
  });

  static void show(BuildContext context, ReportItem item, ReportType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetailModal(item: item, type: type),
    );
  }

  Future<void> _openFile(BuildContext context, String fileOrUrl, {String fileKind = 'laporan'}) async {
    final fileUrl = ApiService.getFileUrl(type, fileOrUrl, fileKind: fileKind);
    final fileUri = Uri.parse(fileUrl);
    try {
      final launched = await launchUrl(
        fileUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(fileUri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka tautan file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProd = item.statusProduksiCode == 'P';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 20),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaPerusahaan,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SK IUP: ${item.skIup}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProd ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isProd ? Colors.green.shade300 : Colors.amber.shade400,
                    ),
                  ),
                  child: Text(
                    item.statusProduksi,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isProd ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Informasi Perizinan & Wilayah'),
                  _buildInfoGrid([
                    {'label': 'Provinsi', 'value': item.provinsi},
                    {'label': 'Jenis Perizinan', 'value': item.jenisPerizinan},
                    {'label': 'Periode Laporan', 'value': '${item.triwulan} - ${item.tahun}'},
                    {'label': 'Sistem Tambang', 'value': item.sistemPenambangan},
                    if (item.komoditas != null)
                      {'label': 'Komoditas', 'value': item.komoditas!},
                    {'label': 'Waktu Input', 'value': _formatIndonesianDateTime(item.waktuInput)},
                  ]),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Data Teknis & Konservasi Minerba'),
                  _buildMetricsTable(),
                  const SizedBox(height: 16),

                  if (item.laporanFile != null || item.petaFile != null) ...[
                    _buildSectionTitle('Dokumen & Lampiran'),
                    if (item.laporanFile != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: item.laporanFile!.startsWith('http') ? Colors.blue.shade700 : Colors.redAccent,
                          child: Icon(
                            item.laporanFile!.startsWith('http') ? Icons.link : Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.laporanFile!.startsWith('http') ? 'Link Google Drive (Laporan)' : 'Laporan Resmi (PDF)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(item.laporanFile!, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _openFile(context, item.laporanFile!, fileKind: 'laporan'),
                          icon: Icon(item.laporanFile!.startsWith('http') ? Icons.open_in_new : Icons.download, size: 14),
                          label: Text(item.laporanFile!.startsWith('http') ? 'Buka' : 'Unduh', style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ),
                    if (item.petaFile != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: item.petaFile!.startsWith('http') ? Colors.blue.shade700 : Colors.blueAccent,
                          child: Icon(
                            item.petaFile!.startsWith('http') ? Icons.link : Icons.map,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.petaFile!.startsWith('http') ? 'Link Google Drive (Peta)' : 'Peta Konservasi (PDF/Img)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(item.petaFile!, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _openFile(context, item.petaFile!, fileKind: 'peta'),
                          icon: Icon(item.petaFile!.startsWith('http') ? Icons.open_in_new : Icons.download, size: 14),
                          label: Text(item.petaFile!.startsWith('http') ? 'Buka' : 'Unduh', style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIndonesianDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '-';
    final trimmed = raw.trim();

    // Cek format YYYY-MM-DD atau YYYY-MM-DD HH:MM:SS
    final parts = trimmed.split(' ');
    final datePieces = parts[0].split('-');

    if (datePieces.length == 3 && datePieces[0].length == 4) {
      final yyyy = datePieces[0];
      final mm = datePieces[1].padLeft(2, '0');
      final dd = datePieces[2].padLeft(2, '0');
      final formattedDate = '$dd-$mm-$yyyy';
      return parts.length > 1 && parts[1].isNotEmpty
          ? '$formattedDate ${parts[1]}'
          : formattedDate;
    }

    // Fallback parsing DateTime
    final dt = DateTime.tryParse(trimmed);
    if (dt != null) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString().padLeft(4, '0');
      if (trimmed.contains(':')) {
        final hh = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        final ss = dt.second.toString().padLeft(2, '0');
        return '$dd-$mm-$yyyy $hh:$min:$ss';
      }
      return '$dd-$mm-$yyyy';
    }

    return trimmed;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: items.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    row['label']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                const Text(': ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    row['value']!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Mapping label resmi sesuai form_input_laporan.php (Batubara) & form_pelaporan_mineral.php (Mineral)
  static final Map<String, String> _labelMap = {
    // === BATUBARA ===
    'rencana_recovery_penambangan': 'Rencana Recovery Penambangan (FS)',
    'rkab_2_1': 'Rencana Recovery Penambangan (RKAB)',
    'studi_kelayakan_2_1': 'Studi Kelayakan Recovery Penambangan',
    'recovery_penambangan_truck_2_1': 'Recovery Penambangan (Truck Factor)',
    'recovery_penambangan_survey_2_2': 'Recovery Penambangan (Survey Factor)',
    'recovery_penambangan_truck_2_2': 'Recovery Penambangan (Truck Factor)',
    'recovery_penambangan_survey_2_3': 'Recovery Penambangan (Survey Factor)',
    'rencana_recovery_pengolahan': 'Rencana Recovery Pengolahan (FS)',
    'rkab_2_4': 'Rencana Recovery Pengolahan (RKAB)',
    'studi_kelayakan_2_4': 'Studi Kelayakan Recovery Pengolahan',
    'recovery_pengolahan_2_3': 'Recovery Pengolahan',
    'recovery_pengolahan_2_5': 'Recovery Pengolahan',
    'bkr_komulatif_awal_tahun': 'BKR Kumulatif Awal Tahun',
    'bkr_lokasi': 'BKR Lokasi',
    'bkr_kuantitas': 'BKR Kuantitas',
    'bkr_calorie_values_3_1': 'BKR Nilai Kalori',
    'bkr_ash_3_1': 'BKR Kandungan Abu',
    'bkr_sulfur_3_1': 'BKR Kandungan Sulfur',
    'bkr_total_moisture_3_1': 'BKR Total Moisture',
    'bkr_pemanfaatan_sudah_belum_3_2': 'BKR Status Pemanfaatan',
    'bkr_jenis_pemanfaatan': 'BKR Jenis Pemanfaatan',
    'pbkr_volume': 'PBKR Volume',
    'cm_ada_tidak': 'Cadangan Marginal (Status)',
    'cm_komulatif_awal_tahun': 'CM Kumulatif Awal Tahun',
    'cm_lokasi': 'CM Lokasi',
    'cm_kuantitas': 'CM Kuantitas',
    'cm_calorie_values_4_1': 'CM Nilai Kalori',
    'cm_ash_4_1': 'CM Kandungan Abu',
    'cm_sulfur_4_1': 'CM Kandungan Sulfur',
    'cm_total_moisture_4_1': 'CM Total Moisture',
    'cm_penyebab_4_2': 'CM Penyebab',
    'cm_optimalisasi_sudah_belum_4_3': 'CM Status Optimalisasi',
    'cm_yang_sudah_ditambang_': 'CM Yang Sudah Ditambang',
    'shp_komulatif_awal_tahun': 'SHP Kumulatif Awal Tahun',
    'shp_lokasi': 'SHP Lokasi',
    'shp_kuantitas': 'SHP Kuantitas',
    'shp_calorie_values_5_1': 'SHP Nilai Kalori',
    'shp_ash_5_1': 'SHP Kandungan Abu',
    'shp_sulfur_5_1': 'SHP Kandungan Sulfur',
    'shp_total_moisture_5_1': 'SHP Total Moisture',
    'pshp_volume': 'PSHP Volume',
    'ctt_komulatif_awal_tahun': 'CTT Kumulatif Awal Tahun',
    'ctt_lokasi': 'CTT Lokasi',
    'ctt_kuantitas': 'CTT Kuantitas',
    'ctt_kedalaman': 'CTT Kedalaman',
    'ctt_calorie_values_6_1': 'CTT Nilai Kalori',
    'ctt_ash_6_1': 'CTT Kandungan Abu',
    'ctt_sulfur_6_1': 'CTT Kandungan Sulfur',
    'ctt_total_moisture_6_1': 'CTT Total Moisture',
    'ctt_alasan_6_2': 'CTT Alasan',

    // === MINERAL ===
    'recovery_persentase': 'Rencana Recovery Penambangan (FS)',
    'rencana_recovery_2_1': 'Rencana Recovery Penambangan (FS)',
    'recovery_truck': 'Rencana Recovery Penambangan (RKAB)',
    'recovery_survey_factor': 'Recovery Penambangan (Survey Factor)',
    'rencana_recovery': 'Recovery Penambangan (Truck Factor)',
    'rencana_recovery_2_4': 'Recovery Penambangan (Truck Factor)',
    'rencana_recovery_pengolahan_fs': 'Recovery Pengolahan (FS)',
    'rencana_recovery_pengolahan_rkab': 'Recovery Pengolahan (RKAB)',
    'recovery_pengolahan': 'Recovery Pengolahan/Pemulihan',
    'recovery_pemulihan_2_6': 'Recovery Pengolahan/Pemulihan',
    'jenis_mineral_ikutan': 'Mineral Ikutan (Jenis)',
    'mi_jenis': 'Mineral Ikutan (Jenis)',
    'kumulatif_awal_tahun': 'MI Kumulatif Awal Tahun',
    'mi_stok_awal_tahun': 'MI Kumulatif Awal Tahun',
    'kuantitas_mineral_ikutan': 'MI Kuantitas',
    'mi_kuantitias': 'MI Kuantitas',
    'kadar_mineral_ikutan': 'MI Kadar',
    'mi_kadar_gram_ton': 'MI Kadar (g/t)',
    'persentase_mineral_ikutan': 'MI Kadar Persentase',
    'mi_kadar_persentase': 'MI Kadar Persentase',
    'lokasi_mineral_ikutan': 'MI Lokasi',
    'mi_lokasi': 'MI Lokasi',
    'volume_kuantitas_pemanfaatan': 'PMI Volume/Kuantitas',
    'pmi_volume': 'PMI Volume/Kuantitas',
    'kadar_pemanfaatan': 'PMI Kadar',
    'pmi_kadar': 'PMI Kadar',
    'persentase_pemanfaatan': 'PMI Persentase',
    'pmi_persentase': 'PMI Persentase',
    'kumulatif_awal_tahun_kr': 'MKR Kumulatif Awal Tahun',
    'mkr_stok_awal_tahun': 'MKR Kumulatif Awal Tahun',
    'kuantitas_kr': 'MKR Kuantitas',
    'mkr_kuantitas': 'MKR Kuantitas',
    'kadar_gram_ton_kr': 'MKR Kadar (g/t)',
    'mkr_kadar_gram_ton': 'MKR Kadar (g/t)',
    'kadar_persentase_kr': 'MKR Kadar Persentase',
    'mkr_kadar_persentase': 'MKR Kadar Persentase',
    'lokasi_kr': 'MKR Lokasi',
    'mkr_lokasi': 'MKR Lokasi',
    'pemanfaatan_mineral_kr': 'Pemanfaatan MKR',
    'pmkr_volume': 'PMKR Volume/Kuantitas',
    'pmkr_kadar': 'PMKR Kadar',
    'pmkr_persentase': 'PMKR Persentase',
    'kumulatif_awal_tahun_cm': 'CM Kumulatif Awal Tahun',
    'cm_stok_awal_tahun': 'CM Kumulatif Awal Tahun',
    'kuantitas_cm': 'CM Kuantitas',
    'kadar_gram_ton_cm': 'CM Kadar (g/t)',
    'cm_kadar_gram_ton': 'CM Kadar (g/t)',
    'kadar_persentase_cm': 'CM Kadar Persentase',
    'cm_kadar_persentase': 'CM Kadar Persentase',
    'lokasi_cm': 'CM Lokasi',
    'volume_kuantitas_cm': 'PCM Volume/Kuantitas',
    'pcm_volume': 'PCM Volume/Kuantitas',
    'pcm_kadar': 'PCM Kadar',
    'pcm_persentase': 'PCM Persentase',
    'kumulatif_awal_tahun_shp': 'SHP Kumulatif Awal Tahun',
    'kuantitas_shp': 'SHP Kuantitas',
    'jenis_shp': 'SHP Jenis',
    'shp_jenis': 'SHP Jenis',
    'unsur_shp': 'SHP Unsur',
    'shp_unsur': 'SHP Unsur',
    'kadar_gram_ton_shp': 'SHP Kadar (g/t)',
    'shp_kadar_gram_ton': 'SHP Kadar (g/t)',
    'kadar_persentase_shp': 'SHP Kadar Persentase',
    'shp_kadar_persentase': 'SHP Kadar Persentase',
    'calorin_valius_shpp': 'SHPP Nilai Kalori',
    'pemanfaatan_shpp': 'SHPP Pemanfaatan',
    'lokasi_shp': 'SHP Lokasi',
    'volume_kuantitas_pemanfaatan_shp': 'PSHPP Volume/Kuantitas',
    'pshpp_volume': 'PSHPP Volume/Kuantitas',
    'kadar_pemanfaatan_shp': 'PSHPP Kadar',
    'pshpp_kadar': 'PSHPP Kadar',
    'persentase_pemanfaatan_shp': 'PSHPP Persentase',
    'pshpp_persentase': 'PSHPP Persentase',
    'volume_kuantitas_shpp': 'SHPP Volume/Kuantitas',
    'kumulatif_awal_tahun_ctt': 'CMTT Kumulatif Awal Tahun',
    'kuantitas_cadangan_ctt': 'CMTT Kuantitas Cadangan',
    'cmtt_mineral': 'CMTT Mineral',
    'cmtt_kuantitas_cadangan': 'CMTT Kuantitas Cadangan',
    'cmtt_kuantitas': 'CMTT Kuantitas',
    'kedalaman_ctt': 'CMTT Kedalaman',
    'cmtt_kedalaman': 'CMTT Kedalaman',
    'kadar_gram_ton_ctt': 'CMTT Kadar (g/t)',
    'cmtt_kadar_gram_ton': 'CMTT Kadar (g/t)',
    'kadar_persentase_ctt': 'CMTT Kadar Persentase',
    'cmtt_kadar_persentase': 'CMTT Kadar Persentase',
    'lokasi_ctt': 'CMTT Lokasi',
    'cmtt_lokasi': 'CMTT Lokasi',
  };

  /// Format label field agar mudah dibaca dan mempertahankan akronim industri
  static String formatLabel(String key) {
    if (_labelMap.containsKey(key)) {
      return _labelMap[key]!;
    }
    // Bersihkan penomoran section form seperti _1_1, _1_4, _2_1, dll
    String clean = key.replaceAll(RegExp(r'_\d+_\d+$'), '');
    clean = clean.replaceAll(RegExp(r'_\d+$'), '');
    clean = clean.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return key;

    const acronyms = {
      'bkr', 'pbkr', 'cm', 'shp', 'pshp', 'ctt', 'mkr', 'pmkr',
      'mi', 'pmi', 'cmtt', 'shpp', 'pshpp', 'rkab', 'fs', 'iup', 'sk', 'op'
    };

    return clean.split(' ').map((w) {
      if (w.isEmpty) return '';
      final lower = w.toLowerCase();
      if (acronyms.contains(lower)) {
        return lower.toUpperCase();
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Mendapatkan satuan resmi (% atau tonase/ton, kcal/kg, g/t, m³, m)
  /// berdasarkan form_input_laporan.php (Batubara) & form_pelaporan_mineral.php (Mineral)
  static String getFieldUnit(String key, ReportType type) {
    final k = key.toLowerCase();

    // 1. Satuan Persentase (%)
    if (k.contains('recovery') ||
        k.contains('_ash') ||
        k.contains('_sulfur') ||
        k.contains('_moisture') ||
        k.contains('persen') ||
        k.contains('persentase')) {
      return '%';
    }

    // 2. Satuan Nilai Kalori (kcal/kg)
    if (k.contains('calorie') || k.contains('calorin')) {
      return 'kcal/kg';
    }

    // 3. Satuan Kadar gram per ton (g/t)
    if (k.contains('gram_ton') || k.contains('g_t')) {
      return 'g/t';
    }

    // 4. Satuan Kedalaman (m)
    if (k.contains('kedalaman')) {
      return 'm';
    }

    // 5. Satuan Volume Batubara (m³)
    if (type == ReportType.batubara && (k == 'pbkr_volume' || k == 'pshp_volume')) {
      return 'm³';
    }

    // 6. Satuan Tonase / Ton (Kuantitas, Kumulatif, Cadangan, Stok Awal)
    if (k.contains('kuantitas') ||
        k.contains('kuantitias') ||
        k.contains('kumulatif') ||
        k.contains('komulatif') ||
        k.contains('stok_awal') ||
        k.contains('ditambang') ||
        k.contains('cadangan') ||
        k == 'cmtt_mineral' ||
        (type == ReportType.mineral && (k.contains('volume') || k.contains('pemanfaatan_mineral')))) {
      // Batubara di form menggunakan 'ton', Mineral di form menggunakan 'tonase'
      return type == ReportType.batubara ? 'ton' : 'tonase';
    }

    return '';
  }

  /// Mengubah angka (termasuk desimal & ribuan) ke format Indonesia
  /// Contoh: 1080.77 -> 1.080,77 ; 1727998.27 -> 1.727.998,27
  static String formatIndonesianNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-' || trimmed == 'null') return '-';

    String normalized = trimmed;

    // Normalisasi format US: ribuan koma, desimal titik (1,080.77 -> 1080.77)
    if (RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(normalized)) {
      normalized = normalized.replaceAll(',', '');
    }
    // Normalisasi format Indo: ribuan titik, desimal koma (1.080,77 -> 1080.77)
    else if (RegExp(r'^-?\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(normalized)) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    // Normalisasi desimal koma tanpa ribuan (1080,77 atau 98,38 -> 1080.77)
    else if (RegExp(r'^-?\d+,\d+$').hasMatch(normalized)) {
      normalized = normalized.replaceAll(',', '.');
    }

    // Cek apakah murni numerik
    final numVal = double.tryParse(normalized);
    if (numVal == null) {
      // Bukan angka (misal: "Blok A", "Ada", "Tambang Terbuka"), return apa adanya
      return trimmed;
    }

    // Pisahkan integer dan desimal
    final parts = normalized.split('.');
    String intPart = parts[0];
    String? decPart = parts.length > 1 ? parts[1] : null;

    final isNegative = intPart.startsWith('-');
    if (isNegative) intPart = intPart.substring(1);

    // Format ribuan dengan tanda titik (.)
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(intPart[i]);
    }
    final formattedInt = (isNegative ? '-' : '') + buffer.toString();

    // Gabungkan bagian desimal dengan tanda koma (,) jika ada
    if (decPart != null && decPart.isNotEmpty) {
      // Jika semua desimal nol (misal 1000.00), tampilkan bilangan bulat saja
      if (RegExp(r'^0+$').hasMatch(decPart)) {
        return formattedInt;
      }
      // Hapus trailing nol berlebih di akhir desimal
      String trimmedDec = decPart.replaceAll(RegExp(r'0+$'), '');
      return '$formattedInt,$trimmedDec';
    }

    return formattedInt;
  }

  /// Menghasilkan string tampilan lengkap: Angka format Indo + Satuan
  /// Contoh: 1080.77 untuk kuantitas batubara -> "1.080,77 ton"
  /// Contoh: 98.38 untuk recovery -> "98,38 %"
  static String formatDisplayValue(String key, dynamic rawVal, ReportType type) {
    if (rawVal == null) return '-';
    final str = rawVal.toString().trim();
    if (str.isEmpty || str == '-' || str == 'null') return '-';

    // Cek apakah bernilai numerik
    final cleaned = str.replaceAll('.', '').replaceAll(',', '');
    final isNum = double.tryParse(cleaned) != null;

    if (!isNum) {
      return str;
    }

    final formattedNumber = formatIndonesianNumber(str);
    final unit = getFieldUnit(key, type);

    if (unit.isEmpty) {
      return formattedNumber;
    }

    if (unit == '%') {
      return '$formattedNumber %';
    }

    return '$formattedNumber $unit';
  }

  Widget _buildMetricsTable() {
    final raw = item.rawDetails;

    // Filter relevant non-empty keys
    final rows = <Map<String, String>>[];
    raw.forEach((key, val) {
      if (val != null) {
        final strVal = val.toString().trim();
        // Skip nilai kosong, strip, atau angka nol
        if (strVal.isNotEmpty &&
            strVal != '-' &&
            strVal != 'null' &&
            strVal != '0' &&
            strVal != '0.00' &&
            strVal != '0,00' &&
            strVal != '0.0') {
          final skipKeys = {
            'id', 'sk_iup', 'nama_perusahaan', 'nama_provinsi', 'provinsi',
            'tahun', 'tahun_1_7', 'triwulan', 'waktu_pelaporan', 'waktu_perlaporan_laporan_1_6',
            'laporan', 'laporan_7_1', 'laporan_dokumen', 'peta', 'peta_file',
            'peta_konservasi', 'peta_konservasi_7_2', 'waktu_input', 'waktu_input_8',
            'email', 'alamat_email_1_4', 'email_gmail_cadangan', 'komoditas_mineral',
            'jenis_perizinan', 'jenis_perizinan_1_1', 'sistem_penambangan', 'sistem_penambangan_1_5'
          };

          if (!skipKeys.contains(key.toLowerCase())) {
            final label = formatLabel(key);
            final displayValue = formatDisplayValue(key, val, type);
            rows.add({'label': label, 'value': displayValue});
          }
        }
      }
    });

    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'Tidak ada data rincian teknis tambahan.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: rows.map((r) {
          final isLong = r['value']!.length > 32 || r['value']!.contains('\n');
          if (isLong) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r['value']!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF18181B),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    r['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Text(
                    r['value']!,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18181B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
