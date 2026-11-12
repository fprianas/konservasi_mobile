import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/evaluasi_dokumen_model.dart';
import '../models/evaluasi_perusahaan_model.dart';

class EvaluasiExportResult {
  final bool success;
  final String? filePath;
  final String message;

  const EvaluasiExportResult({
    required this.success,
    this.filePath,
    required this.message,
  });
}

class EvaluasiExporterService {
  static final _numFormat = NumberFormat('#,##0.00', 'id_ID');
  static final _dateFormat = DateFormat('dd-MM-yyyy HH:mm', 'id_ID');

  // =========================================================================
  // 1. EXPORT SHEET RKPW KE EXCEL (.XLSX)
  // =========================================================================
  static Future<EvaluasiExportResult> exportRkpwExcel({
    required List<EvaluasiRkpwItem> items,
    required EvaluasiRkpwStats stats,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Sheet RKPW';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // Styles
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final rowStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final centerStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final numberStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      // Title rows
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('DAFTAR PERMOHONAN PERSETUJUAN DOKUMEN PERLUASAN WIUP DAN WIUPK (RKPW)')
        ..cellStyle = CellStyle(bold: true, fontSize: 13, fontColorHex: ExcelColor.fromHexString('#0F172A'));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Direktorat Pembinaan Program Mineral dan Batubara - Ditjen Minerba')
        ..cellStyle = CellStyle(fontSize: 10, fontColorHex: ExcelColor.fromHexString('#64748B'));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Tanggal Ekspor: ${_dateFormat.format(DateTime.now())} | Total Data: ${items.length}')
        ..cellStyle = CellStyle(fontSize: 9, italic: true, fontColorHex: ExcelColor.fromHexString('#94A3B8'));

      // Headers
      final headers = [
        'No',
        'Evaluator',
        'Nama Perusahaan',
        'Jenis Komoditas',
        'Komoditas',
        'No SK IUP',
        'Masa Berlaku',
        'Luas WIUP (Ha)',
        'Provinsi',
        'Kabupaten',
        'Kecamatan',
        'Luas Permohonan (Ha)',
        'No Surat Permohonan',
        'Tgl Surat Permohonan',
        'Tgl Masuk DJMB',
        'Tgl Masuk DBT',
        'Tgl Masuk SDKM',
        'ND DBT Permohonan No',
        'ND DBT Permohonan Tgl',
        'ND DBT KM No',
        'ND DBT KM Tgl',
        'ND DBP PW No',
        'ND DBP PW Tgl',
        'ND DBM PE No',
        'ND DBM PE Tgl',
        'Surat DJB No',
        'Surat DJB Tgl',
        'Status',
        'Catatan Evaluasi',
        'Surat MEM No',
        'Surat MEM Tgl',
        'SK Perluasan No',
        'SK Perluasan Tgl',
        'Luas Disetujui (Ha)',
        'Nilai KDI (Rp)',
        'Status Bayar KDI',
        'Total Luas Akhir (Ha)',
      ];

      final headerRowIndex = 4;
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIndex));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      // Data Rows
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final r = headerRowIndex + 1 + i;

        final rowValues = [
          (i + 1).toString(),
          item.evaluator,
          item.namaPerusahaan,
          item.jenisKomoditas,
          item.komoditas,
          item.noSkIup,
          item.masaBerlaku,
          item.luasWiup,
          item.provinsi,
          item.kabupaten,
          item.kecamatan,
          item.luasPerluasanDimohon,
          item.suratPermohonanNomor,
          item.suratPermohonanTanggal ?? '',
          item.tglMasukDjmb ?? '',
          item.tglMasukDbt ?? '',
          item.tglMasukSdkm ?? '',
          item.ndDbtPermohonanNomor,
          item.ndDbtPermohonanTanggal,
          item.ndDbtKmNomor,
          item.ndDbtKmTanggal ?? '',
          item.ndDbpPwNomor,
          item.ndDbpPwTanggal ?? '',
          item.ndDbmPeNomor,
          item.ndDbmPeTanggal ?? '',
          item.suratDjbNomor,
          item.suratDjbTanggal ?? '',
          item.status,
          item.catatanEvaluasi,
          item.suratMemNomor,
          item.suratMemTanggal ?? '',
          item.skPerluasanNomor,
          item.skPerluasanTanggal ?? '',
          item.luasDisetujui,
          item.kdiNilaiRp,
          item.kdiStatusBayar,
          item.totalLuasSekarang,
        ];

        for (int c = 0; c < rowValues.length; c++) {
          final val = rowValues[c];
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          if (val is double) {
            cell.value = DoubleCellValue(val);
            cell.cellStyle = numberStyle;
          } else {
            cell.value = TextCellValue(val.toString());
            cell.cellStyle = (c == 0 || c == 7 || c == 27 || c == 35) ? centerStyle : rowStyle;
          }
        }
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        return const EvaluasiExportResult(success: false, message: 'Gagal membuat berkas Excel');
      }

      final fileName = 'Evaluasi_RKPW_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      return await _saveAndOpenFile(fileBytes, fileName, 'Excel (.xlsx)');
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Gagal ekspor Excel RKPW: $e');
    }
  }

  // =========================================================================
  // 2. EXPORT SHEET FS KE EXCEL (.XLSX)
  // =========================================================================
  static Future<EvaluasiExportResult> exportFsExcel({
    required List<EvaluasiFsItem> items,
    required EvaluasiFsStats stats,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Sheet FS';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // Styles
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final rowStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final centerStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Title rows
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('EVALUASI DOKUMEN STUDI KELAYAKAN BERTAHAP (FS)')
        ..cellStyle = CellStyle(bold: true, fontSize: 13, fontColorHex: ExcelColor.fromHexString('#0F172A'));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Direktorat Pembinaan Program Mineral dan Batubara - Ditjen Minerba')
        ..cellStyle = CellStyle(fontSize: 10, fontColorHex: ExcelColor.fromHexString('#64748B'));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Tanggal Ekspor: ${_dateFormat.format(DateTime.now())} | Total Data: ${items.length}')
        ..cellStyle = CellStyle(fontSize: 9, italic: true, fontColorHex: ExcelColor.fromHexString('#94A3B8'));

      // Headers
      final headers = [
        'No',
        'Evaluator',
        'Nama Perusahaan',
        'Komoditas',
        'ND Permohonan Nomor',
        'ND Permohonan Tanggal',
        'Tahap 1 - No ND DBT',
        'Tahap 1 - Tanggal ND',
        'Tahap 1 - Hasil Penilaian',
        'Tahap 2 - No ND DBT',
        'Tahap 2 - Tanggal ND',
        'Tahap 2 - Hasil Penilaian',
        'Tahap 3 - No ND DBT',
        'Tahap 3 - Tanggal ND',
        'Tahap 3 - Hasil Penilaian',
        'Tahap 4 - No ND DBT',
        'Tahap 4 - Tanggal ND',
        'Tahap 4 - Hasil Penilaian',
        'Status Akhir',
        'Catatan',
      ];

      final headerRowIndex = 4;
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIndex));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      // Data Rows
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final r = headerRowIndex + 1 + i;

        final rowValues = [
          (i + 1).toString(),
          item.evaluator,
          item.namaPerusahaan,
          item.komoditas,
          item.ndPermohonanNomor,
          item.ndPermohonanTanggal ?? '',
          item.eval1Nomor,
          item.eval1Tanggal ?? '',
          item.eval1Status ?? '-',
          item.eval2Nomor,
          item.eval2Tanggal ?? '',
          item.eval2Status ?? '-',
          item.eval3Nomor,
          item.eval3Tanggal ?? '',
          item.eval3Status ?? '-',
          item.eval4Nomor,
          item.eval4Tanggal ?? '',
          item.eval4Status ?? '-',
          item.latestStatus,
          item.catatan,
        ];

        for (int c = 0; c < rowValues.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          cell.value = TextCellValue(rowValues[c]);
          cell.cellStyle = (c == 0 || c == 8 || c == 11 || c == 14 || c == 17 || c == 18) ? centerStyle : rowStyle;
        }
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        return const EvaluasiExportResult(success: false, message: 'Gagal membuat berkas Excel');
      }

      final fileName = 'Evaluasi_FS_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      return await _saveAndOpenFile(fileBytes, fileName, 'Excel (.xlsx)');
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Gagal ekspor Excel FS: $e');
    }
  }

  // =========================================================================
  // 3. EXPORT SHEET RKPW KE PDF (.PDF)
  // =========================================================================
  static Future<EvaluasiExportResult> exportRkpwPdf({
    required List<EvaluasiRkpwItem> items,
    required EvaluasiRkpwStats stats,
  }) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KEMENTERIAN ENERGI DAN SUMBER DAYA MINERAL REPUBLIK INDONESIA',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'DAFTAR PERMOHONAN PERSETUJUAN PERLUASAN WIUP DAN WIUPK (RKPW)',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(
                        'Direktorat Pembinaan Program Mineral dan Batubara',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Tgl Ekspor: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Total Data: ${items.length} Permohonan', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            // KPI Summary Cards
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiItem('Total Dokumen', '${stats.total}', PdfColors.blue900),
                  _buildPdfKpiItem('Disetujui', '${stats.totalDisetujui}', PdfColors.green800),
                  _buildPdfKpiItem('Ditolak', '${stats.totalDitolak}', PdfColors.red800),
                  _buildPdfKpiItem('Proses', '${stats.totalProses}', PdfColors.orange800),
                  _buildPdfKpiItem('Luas Dimohon', '${_numFormat.format(stats.sumLuasDimohon)} Ha', PdfColors.blue800),
                  _buildPdfKpiItem('Luas Disetujui', '${_numFormat.format(stats.sumLuasDisetujui)} Ha', PdfColors.green900),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Perusahaan',
                'Komoditas',
                'Lokasi (Kec, Kab, Prov)',
                'Luas WIUP (Ha)',
                'Luas Dimohon (Ha)',
                'Disetujui (Ha)',
                'Status',
                'Evaluator',
                'Catatan',
              ],
              data: List.generate(items.length, (idx) {
                final item = items[idx];
                final lokasi = [item.kecamatan, item.kabupaten, item.provinsi].where((e) => e.isNotEmpty).join(', ');
                return [
                  (idx + 1).toString(),
                  item.namaPerusahaan,
                  item.komoditas.isNotEmpty ? item.komoditas : item.jenisKomoditas,
                  lokasi.isNotEmpty ? lokasi : '-',
                  _numFormat.format(item.luasWiup),
                  _numFormat.format(item.luasPerluasanDimohon),
                  _numFormat.format(item.luasDisetujui),
                  item.status,
                  item.evaluator.isNotEmpty ? item.evaluator : '-',
                  item.catatanEvaluasi.isNotEmpty ? item.catatanEvaluasi : '-',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.center,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ],
        ),
      );

      final fileBytes = await doc.save();
      final fileName = 'Evaluasi_RKPW_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      return await _saveAndOpenFile(fileBytes, fileName, 'PDF (.pdf)');
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Gagal ekspor PDF RKPW: $e');
    }
  }

  // =========================================================================
  // 4. EXPORT SHEET FS KE PDF (.PDF)
  // =========================================================================
  static Future<EvaluasiExportResult> exportFsPdf({
    required List<EvaluasiFsItem> items,
    required EvaluasiFsStats stats,
  }) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KEMENTERIAN ENERGI DAN SUMBER DAYA MINERAL REPUBLIK INDONESIA',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'EVALUASI DOKUMEN STUDI KELAYAKAN BERTAHAP (FS)',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                      ),
                      pw.Text(
                        'Direktorat Pembinaan Program Mineral dan Batubara',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Tgl Ekspor: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Total Data: ${items.length} Dokumen', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            // KPI Summary Cards
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiItem('Total FS', '${stats.total}', PdfColors.teal900),
                  _buildPdfKpiItem('Memadai', '${stats.totalMemadai}', PdfColors.green800),
                  _buildPdfKpiItem('Belum Memadai', '${stats.totalBelumMemadai}', PdfColors.red800),
                  _buildPdfKpiItem('Sedang Proses', '${stats.totalProses}', PdfColors.orange800),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Perusahaan',
                'Komoditas',
                'ND Permohonan',
                'Tahap 1',
                'Tahap 2',
                'Tahap 3',
                'Tahap 4',
                'Status Akhir',
                'Evaluator',
                'Catatan',
              ],
              data: List.generate(items.length, (idx) {
                final item = items[idx];
                return [
                  (idx + 1).toString(),
                  item.namaPerusahaan,
                  item.komoditas,
                  '${item.ndPermohonanNomor}\n${item.ndPermohonanTanggal ?? ""}',
                  item.eval1Status != null ? '${item.eval1Status}\n${item.eval1Nomor}' : '-',
                  item.eval2Status != null ? '${item.eval2Status}\n${item.eval2Nomor}' : '-',
                  item.eval3Status != null ? '${item.eval3Status}\n${item.eval3Nomor}' : '-',
                  item.eval4Status != null ? '${item.eval4Status}\n${item.eval4Nomor}' : '-',
                  item.latestStatus,
                  item.evaluator.isNotEmpty ? item.evaluator : '-',
                  item.catatan.isNotEmpty ? item.catatan : '-',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.center,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ],
        ),
      );

      final fileBytes = await doc.save();
      final fileName = 'Evaluasi_FS_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      return await _saveAndOpenFile(fileBytes, fileName, 'PDF (.pdf)');
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Gagal ekspor PDF FS: $e');
    }
  }

  // =========================================================================
  // HELPER PDF KPI
  // =========================================================================
  static pw.Widget _buildPdfKpiItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  // =========================================================================
  // 5. EXPORT REKAP EVALUASI PERUSAHAAN (7 OBJEK KONSERVASI) KE EXCEL
  // =========================================================================
  static Future<EvaluasiExportResult> exportEvaluasiPerusahaanExcel({
    required List<EvaluasiPerusahaanItem> items,
    String tipe = 'SEMUA',
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Rekap Evaluasi Konservasi';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // Styles
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final rowStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final centerStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final memadaiStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#166534'),
        backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final belumMemadaiStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#991B1B'),
        backgroundColorHex: ExcelColor.fromHexString('#FEE2E2'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Title rows
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('REKAPITULASI HASIL EVALUASI KONSERVASI PERUSAHAAN PERTAMBANGAN')
        ..cellStyle = CellStyle(bold: true, fontSize: 13, fontColorHex: ExcelColor.fromHexString('#0F172A'));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Direktorat Pembinaan Program Mineral dan Batubara - Ditjen Minerba')
        ..cellStyle = CellStyle(fontSize: 10, fontColorHex: ExcelColor.fromHexString('#64748B'));

      final totalMemadai = items.where((e) => e.isMemadai).length;
      final totalBelum = items.length - totalMemadai;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Tanggal Ekspor: ${_dateFormat.format(DateTime.now())} | Total: ${items.length} Perusahaan | Memadai: $totalMemadai | Belum Memadai: $totalBelum | Kategori: $tipe')
        ..cellStyle = CellStyle(fontSize: 9, italic: true, fontColorHex: ExcelColor.fromHexString('#0F766E'));

      // Headers
      final headers = [
        'No',
        'Nama Perusahaan',
        'Komoditas / Tipe',
        'No SK IUP',
        'Provinsi',
        'Status Produksi',
        'Petugas Evaluator',
        'Status Keseluruhan',
        'Format Laporan',
        'Tanggapan Format Laporan',
        'Recovery Penambangan',
        'Tanggapan Recovery Penambangan',
        'Recovery Pengolahan',
        'Tanggapan Recovery Pengolahan',
        'Cadangan Marginal',
        'Tanggapan Cadangan Marginal',
        'Kualitas / Kadar Rendah',
        'Tanggapan Kualitas / Kadar Rendah',
        'Sisa Hasil Pengolahan (SHP)',
        'Tanggapan SHP',
        'Cadangan Tidak Tertambang',
        'Tanggapan Cadangan Tdk Tertambang',
        'Catatan Umum',
        'Tanggal Evaluasi',
      ];

      const headerRow = 4;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow))
          ..value = TextCellValue(headers[c])
          ..cellStyle = headerStyle;
      }

      int rowIndex = 5;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final isMemadai = item.isMemadai;
        final detail = item.detailEvaluasi;

        String getObjStatus(String key, String fallback) {
          if (detail.containsKey(key) && detail[key] is Map) {
            return detail[key]['status']?.toString() ?? 'Memadai';
          }
          return fallback;
        }

        String getObjTanggapan(String key) {
          if (detail.containsKey(key) && detail[key] is Map) {
            return detail[key]['tanggapan']?.toString() ?? '';
          }
          return '';
        }

        final stFormat = getObjStatus('format_laporan', item.formatLaporan);
        final tgFormat = getObjTanggapan('format_laporan');

        final stRecTambang = getObjStatus('recovery_penambangan', 'Memadai');
        final tgRecTambang = getObjTanggapan('recovery_penambangan');

        final stRecOlah = getObjStatus('recovery_pengolahan', 'Memadai');
        final tgRecOlah = getObjTanggapan('recovery_pengolahan');

        final stCadMarginal = getObjStatus('cadangan_marginal', 'Memadai');
        final tgCadMarginal = getObjTanggapan('cadangan_marginal');

        final stKualitasRendah = getObjStatus('kualitas_kadar_rendah', 'Memadai');
        final tgKualitasRendah = getObjTanggapan('kualitas_kadar_rendah');

        final stShp = getObjStatus('sisa_hasil_pengolahan', 'Memadai');
        final tgShp = getObjTanggapan('sisa_hasil_pengolahan');

        final stCadTt = getObjStatus('cadangan_tidak_tertambang', 'Memadai');
        final tgCadTt = getObjTanggapan('cadangan_tidak_tertambang');

        final komoditasVal = item.komoditas != null && item.komoditas!.isNotEmpty
            ? item.komoditas!
            : item.tipe.toUpperCase();

        final dateVal = item.updatedAt != null ? _dateFormat.format(item.updatedAt!) : '-';

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          ..value = IntCellValue(i + 1)
          ..cellStyle = centerStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          ..value = TextCellValue(item.namaPerusahaan)
          ..cellStyle = rowStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          ..value = TextCellValue(komoditasVal)
          ..cellStyle = centerStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          ..value = TextCellValue(item.skIup)
          ..cellStyle = rowStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          ..value = TextCellValue(item.provinsi)
          ..cellStyle = rowStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          ..value = TextCellValue(item.statusProduksi)
          ..cellStyle = centerStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          ..value = TextCellValue(item.namaPetugas)
          ..cellStyle = rowStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          ..value = TextCellValue(item.status)
          ..cellStyle = isMemadai ? memadaiStyle : belumMemadaiStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          ..value = TextCellValue(stFormat)
          ..cellStyle = stFormat == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex))
          ..value = TextCellValue(tgFormat)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex))
          ..value = TextCellValue(stRecTambang)
          ..cellStyle = stRecTambang == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex))
          ..value = TextCellValue(tgRecTambang)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex))
          ..value = TextCellValue(stRecOlah)
          ..cellStyle = stRecOlah == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex))
          ..value = TextCellValue(tgRecOlah)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex))
          ..value = TextCellValue(stCadMarginal)
          ..cellStyle = stCadMarginal == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex))
          ..value = TextCellValue(tgCadMarginal)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: rowIndex))
          ..value = TextCellValue(stKualitasRendah)
          ..cellStyle = stKualitasRendah == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: rowIndex))
          ..value = TextCellValue(tgKualitasRendah)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: rowIndex))
          ..value = TextCellValue(stShp)
          ..cellStyle = stShp == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: rowIndex))
          ..value = TextCellValue(tgShp)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 20, rowIndex: rowIndex))
          ..value = TextCellValue(stCadTt)
          ..cellStyle = stCadTt == 'Memadai' ? memadaiStyle : belumMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: rowIndex))
          ..value = TextCellValue(tgCadTt)
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 22, rowIndex: rowIndex))
          ..value = TextCellValue(item.catatan)
          ..cellStyle = rowStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 23, rowIndex: rowIndex))
          ..value = TextCellValue(dateVal)
          ..cellStyle = centerStyle;

        rowIndex++;
      }

      final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = excel.save();
      if (bytes == null) {
        return const EvaluasiExportResult(success: false, message: 'Gagal membuat file Excel.');
      }

      return await _saveAndOpenFile(
        bytes,
        'Rekap_Evaluasi_Konservasi_$nowStr.xlsx',
        'Excel Rekap Evaluasi',
      );
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Terjadi kesalahan saat ekspor Excel: $e');
    }
  }

  // =========================================================================
  // 6. EXPORT REKAP EVALUASI PERUSAHAAN (7 OBJEK KONSERVASI) KE PDF (.PDF)
  // =========================================================================
  static Future<EvaluasiExportResult> exportEvaluasiPerusahaanPdf({
    required List<EvaluasiPerusahaanItem> items,
    String tipe = 'SEMUA',
  }) async {
    try {
      final doc = pw.Document();

      final totalItems = items.length;
      final totalMemadai = items.where((i) => i.isMemadai).length;
      final totalBelumMemadai = totalItems - totalMemadai;
      final persentase = totalItems > 0 ? (totalMemadai / totalItems * 100).toStringAsFixed(1) : '0.0';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KEMENTERIAN ENERGI DAN SUMBER DAYA MINERAL REPUBLIK INDONESIA',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'REKAPITULASI HASIL EVALUASI TEKNIS KONSERVASI MINERBA (7 ASPEK OBJEK)',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                      ),
                      pw.Text(
                        'Direktorat Pembinaan Program Mineral dan Batubara • Sektor: $tipe',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Tgl Ekspor: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Total Evaluasi: $totalItems Data', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            // KPI Summary Cards
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiItem('Total Evaluasi', '$totalItems', PdfColors.teal900),
                  _buildPdfKpiItem('Memadai (Lolos 7 Objek)', '$totalMemadai', PdfColors.green800),
                  _buildPdfKpiItem('Belum Memadai', '$totalBelumMemadai', PdfColors.red800),
                  _buildPdfKpiItem('Tingkat Kepatuhan', '$persentase%', PdfColors.blue800),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Table 7 Objek
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Nama Perusahaan',
                'Komoditas',
                'Periode',
                'Status Akhir',
                '1. Format',
                '2. Rec Tambang',
                '3. Rec Olah',
                '4. Cad Marginal',
                '5. BKR / MKR',
                '6. SHP',
                '7. CTT',
                'Petugas Evaluator',
              ],
              data: List.generate(items.length, (idx) {
                final item = items[idx];
                final details = item.detailEvaluasi;

                String getStatus(String key) {
                  final d = details[key];
                  if (d is Map) {
                    final st = d['status']?.toString() ?? 'Memadai';
                    return st == 'Memadai' ? 'Memadai' : 'Kurang';
                  }
                  return 'Memadai';
                }

                return [
                  (idx + 1).toString(),
                  item.namaPerusahaan,
                  item.komoditas?.isNotEmpty == true ? item.komoditas! : item.tipe.toUpperCase(),
                  '${item.triwulan}\n${item.tahun}',
                  item.isMemadai ? 'MEMADAI' : 'BELUM MEMADAI',
                  getStatus('format_laporan'),
                  getStatus('recovery_penambangan'),
                  getStatus('recovery_pengolahan'),
                  getStatus('cadangan_marginal'),
                  getStatus('kualitas_kadar_rendah'),
                  getStatus('sisa_hasil_pengolahan'),
                  getStatus('cadangan_tidak_tertambang'),
                  item.namaPetugas.isNotEmpty ? item.namaPetugas : '-',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.center,
                9: pw.Alignment.center,
                10: pw.Alignment.center,
                11: pw.Alignment.center,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            ),
          ],
        ),
      );

      final fileBytes = await doc.save();
      final fileName = 'Rekap_Evaluasi_Konservasi_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      return await _saveAndOpenFile(fileBytes, fileName, 'PDF (.pdf)');
    } catch (e) {
      return EvaluasiExportResult(success: false, message: 'Gagal ekspor PDF Rekap Evaluasi: $e');
    }
  }

  // =========================================================================
  // HELPER SAVE & OPEN
  // =========================================================================
  static Future<EvaluasiExportResult> _saveAndOpenFile(
    List<int> fileBytes,
    String defaultFileName,
    String formatName,
  ) async {
    String? targetPath;

    // Desktop: Dialog Save File
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Simpan Berkas $formatName',
          fileName: defaultFileName,
          bytes: Uint8List.fromList(fileBytes),
        );
        if (uri != null) {
          targetPath = uri.isScheme('file') ? uri.toFilePath() : uri.path;
          if (targetPath.isEmpty) {
            targetPath = uri.toString();
          }
        } else {
          return const EvaluasiExportResult(
            success: false,
            message: 'Penyimpanan berkas dibatalkan.',
          );
        }
      } catch (_) {
        targetPath = null;
      }
    }

    // Mobile / Fallback
    if (targetPath != null && targetPath.isNotEmpty) {
      final file = File(targetPath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        await file.writeAsBytes(fileBytes, flush: true);
      }
    } else {
      Directory dir;
      try {
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        dir = Directory.systemTemp;
      }

      targetPath = '${dir.path}${Platform.pathSeparator}$defaultFileName';
      final file = File(targetPath);
      await file.writeAsBytes(fileBytes, flush: true);
    }

    // Buka berkas otomatis
    try {
      await OpenFilex.open(targetPath);
    } catch (_) {}

    return EvaluasiExportResult(
      success: true,
      filePath: targetPath,
      message: 'Berkas $formatName berhasil diekspor ke $defaultFileName',
    );
  }
}

