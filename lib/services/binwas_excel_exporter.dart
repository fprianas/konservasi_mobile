import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/binwas_model.dart';

class BinwasExcelExportResult {
  final bool success;
  final String? filePath;
  final String message;

  const BinwasExcelExportResult({
    required this.success,
    this.filePath,
    required this.message,
  });
}

class BinwasExcelExporter {
  /// Ekspor Matriks Rekapitulasi Temuan ke format Excel (.xlsx) resmi
  static Future<BinwasExcelExportResult> exportMatrix({
    required BinwasMatrixData matrixData,
    String tipe = 'semua',
    String tahun = '2026',
    String triwulan = 'semua',
    BinwasDashboardData? dashboardData,
  }) async {
    try {
      final excel = Excel.createExcel();

      // ==========================================
      // SHEET 1: Matriks Rekapitulasi Temuan
      // ==========================================
      const sheetName = 'Matriks Rekapitulasi';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // Styles
      final titleMainStyle = CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final titleSubStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final infoFilterStyle = CellStyle(
        italic: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#475569'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final colHeaderStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final companyHeaderStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final itemTextStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final itemCenterStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final itemRedBoldCenterStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#DC2626'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final subtotalHeaderStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#92400E'),
        backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final subtotalScoreStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#78350F'),
        backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final grandTotalHeaderStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#312E81'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final grandTotalScoreStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#4338CA'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // 1. Title Block
      int rowIdx = 0;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue('KEMENTERIAN ENERGI DAN SUMBER DAYA MINERAL REPUBLIK INDONESIA')
        ..cellStyle = titleMainStyle;
      rowIdx++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue('DIREKTORAT JENDERAL MINERAL DAN BATUBARA - PEMBINAAN & PENGAWASAN KONSERVASI')
        ..cellStyle = titleSubStyle;
      rowIdx++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue('MATRIKS REKAPITULASI BUTIR TEMUAN LAPANGAN (PERSIS FORMAT TABULAR EXCEL)')
        ..cellStyle = titleSubStyle;
      rowIdx++;

      final now = DateTime.now();
      const namaBulan = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final nowFormatted =
          '${now.day} ${namaBulan[now.month - 1]} ${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue(
            'Periode: Triwulan ${triwulan.toUpperCase()} Tahun $tahun | Komoditas: ${tipe.toUpperCase()} | Diinspeksi: ${matrixData.totalPerusahaan} Perusahaan | Total Temuan: ${matrixData.grandTotal} | Diekspor: $nowFormatted WIB')
        ..cellStyle = infoFilterStyle;
      rowIdx += 2; // Spasi sebelum tabel

      // 2. Column Headers (Row 5)
      final headerTitles = [
        'No',
        'Kategori',
        'Objek Konservasi',
        'Deskripsi Butir Temuan Lapangan',
        'Jml',
        '%',
      ];

      for (int c = 0; c < headerTitles.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx))
          ..value = TextCellValue(headerTitles[c])
          ..cellStyle = colHeaderStyle;
      }

      for (int i = 0; i < matrixData.columns.length; i++) {
        final col = matrixData.columns[i];
        final colIndex = headerTitles.length + i;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIdx))
          ..value = TextCellValue('${col.namaPerusahaan}\n(${col.tipeKomoditas.toUpperCase()})')
          ..cellStyle = companyHeaderStyle;
      }
      rowIdx++;

      // 3. Data Rows (Grouped by Category + Category Subtotal Rows)
      int itemCounter = 1;

      for (var kat in matrixData.rekapKategori) {
        final katRows = matrixData.rows.where((r) => r.idKategori == kat.idKategori).toList();

        for (var r in katRows) {
          // Col 0: No
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
            ..value = IntCellValue(itemCounter++)
            ..cellStyle = itemCenterStyle;

          // Col 1: Kategori
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
            ..value = TextCellValue(r.namaKategori)
            ..cellStyle = itemTextStyle;

          // Col 2: Objek Konservasi
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
            ..value = TextCellValue(r.objekKonservasi)
            ..cellStyle = itemCenterStyle;

          // Col 3: Deskripsi Temuan
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx))
            ..value = TextCellValue(r.deskripsiTemuan)
            ..cellStyle = itemTextStyle;

          // Col 4: Jml
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx))
            ..value = IntCellValue(r.jumlah)
            ..cellStyle = r.jumlah > 0 ? itemRedBoldCenterStyle : itemCenterStyle;

          // Col 5: %
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx))
            ..value = TextCellValue('${r.persentase.toStringAsFixed(1)}%')
            ..cellStyle = itemCenterStyle;

          // Col 6..N: Perusahaan Scores (1 / 0)
          for (int i = 0; i < matrixData.columns.length; i++) {
            final comp = matrixData.columns[i];
            final val = r.scores[comp.idInspeksi.toString()] ?? 0;
            final colIdx = headerTitles.length + i;

            sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx))
              ..value = IntCellValue(val)
              ..cellStyle = val == 1 ? itemRedBoldCenterStyle : itemCenterStyle;
          }

          rowIdx++;
        }

        // --- BARIS SUB-TOTAL KATEGORI ---
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          ..value = TextCellValue('')
          ..cellStyle = subtotalHeaderStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
          ..value = TextCellValue('SUBTOTAL ${kat.namaKategori.toUpperCase()}')
          ..cellStyle = subtotalHeaderStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
          ..value = TextCellValue('-')
          ..cellStyle = subtotalScoreStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx))
          ..value = TextCellValue('Subtotal temuan ${kat.namaKategori} (${kat.jumlahButir} butir)')
          ..cellStyle = subtotalHeaderStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx))
          ..value = IntCellValue(kat.totalTemuan)
          ..cellStyle = subtotalScoreStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx))
          ..value = TextCellValue('${kat.persentase.toStringAsFixed(1)}%')
          ..cellStyle = subtotalScoreStyle;

        // Subtotal Perusahaan untuk Kategori Ini
        for (int i = 0; i < matrixData.columns.length; i++) {
          final comp = matrixData.columns[i];
          final katScore = kat.scores[comp.idInspeksi.toString()] ?? 0;
          final colIdx = headerTitles.length + i;

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx))
            ..value = IntCellValue(katScore)
            ..cellStyle = subtotalScoreStyle;
        }

        rowIdx++;
      }

      // --- BARIS TOTAL KESELURUHAN (GRAND TOTAL) ---
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue('')
        ..cellStyle = grandTotalHeaderStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
        ..value = TextCellValue('TOTAL KESELURUHAN')
        ..cellStyle = grandTotalHeaderStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
        ..value = TextCellValue('-')
        ..cellStyle = grandTotalScoreStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx))
        ..value = TextCellValue('Grand Total Seluruh Kategori Temuan Lapangan')
        ..cellStyle = grandTotalHeaderStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx))
        ..value = IntCellValue(matrixData.grandTotal)
        ..cellStyle = grandTotalScoreStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx))
        ..value = TextCellValue('100.0%')
        ..cellStyle = grandTotalScoreStyle;

      for (int i = 0; i < matrixData.columns.length; i++) {
        final comp = matrixData.columns[i];
        final compGrandTotal = matrixData.companyTotals[comp.idInspeksi.toString()] ?? comp.totalTemuan;
        final colIdx = headerTitles.length + i;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx))
          ..value = IntCellValue(compGrandTotal)
          ..cellStyle = grandTotalScoreStyle;
      }
      rowIdx++;

      // ==========================================
      // SHEET 2: Ringkasan Rekapitulasi (Executive Summary)
      // ==========================================
      const summarySheetName = 'Ringkasan & KPI';
      final Sheet sumSheet = excel[summarySheetName];

      int sumRow = 0;
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
        ..value = TextCellValue('RINGKASAN EKSEKUTIF PENGAWASAN KONSERVASI MINERBA')
        ..cellStyle = titleMainStyle;
      sumRow += 2;

      // Table A: Rekap Kategori
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
        ..value = TextCellValue('REKAPITULASI SUB-TOTAL PER KATEGORI TEMUAN')
        ..cellStyle = titleSubStyle;
      sumRow++;

      final katTableHeaders = ['No', 'Nama Kategori Temuan', 'Jumlah Temuan', 'Kontribusi (%)', 'Jumlah Butir'];
      for (int c = 0; c < katTableHeaders.length; c++) {
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sumRow))
          ..value = TextCellValue(katTableHeaders[c])
          ..cellStyle = colHeaderStyle;
      }
      sumRow++;

      int katNum = 1;
      for (var k in matrixData.rekapKategori) {
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
          ..value = IntCellValue(katNum++)
          ..cellStyle = itemCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sumRow))
          ..value = TextCellValue(k.namaKategori)
          ..cellStyle = itemTextStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow))
          ..value = IntCellValue(k.totalTemuan)
          ..cellStyle = itemRedBoldCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sumRow))
          ..value = TextCellValue('${k.persentase.toStringAsFixed(1)}%')
          ..cellStyle = itemCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: sumRow))
          ..value = IntCellValue(k.jumlahButir)
          ..cellStyle = itemCenterStyle;
        sumRow++;
      }

      // Total Kategori Row
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
        ..value = TextCellValue('')
        ..cellStyle = subtotalHeaderStyle;
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sumRow))
        ..value = TextCellValue('TOTAL TEMUAN')
        ..cellStyle = subtotalHeaderStyle;
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow))
        ..value = IntCellValue(matrixData.grandTotal)
        ..cellStyle = subtotalScoreStyle;
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sumRow))
        ..value = TextCellValue('100.0%')
        ..cellStyle = subtotalScoreStyle;
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: sumRow))
        ..value = IntCellValue(matrixData.rows.length)
        ..cellStyle = subtotalScoreStyle;
      sumRow += 3;

      // Table B: Daftar Perusahaan Diinspeksi
      sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
        ..value = TextCellValue('DAFTAR PERUSAHAAN DIINSPEKSI')
        ..cellStyle = titleSubStyle;
      sumRow++;

      final compHeaders = ['No', 'Nama Perusahaan', 'Komoditas', 'Tanggal Inspeksi', 'Total Temuan'];
      for (int c = 0; c < compHeaders.length; c++) {
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sumRow))
          ..value = TextCellValue(compHeaders[c])
          ..cellStyle = colHeaderStyle;
      }
      sumRow++;

      int compNum = 1;
      for (var c in matrixData.columns) {
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow))
          ..value = IntCellValue(compNum++)
          ..cellStyle = itemCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sumRow))
          ..value = TextCellValue(c.namaPerusahaan)
          ..cellStyle = itemTextStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow))
          ..value = TextCellValue(c.tipeKomoditas.toUpperCase())
          ..cellStyle = itemCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sumRow))
          ..value = TextCellValue(c.tanggalInspeksi)
          ..cellStyle = itemCenterStyle;
        sumSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: sumRow))
          ..value = IntCellValue(c.totalTemuan)
          ..cellStyle = itemRedBoldCenterStyle;
        sumRow++;
      }

      // 4. Encode & Save File
      final List<int>? fileBytes = excel.save();
      if (fileBytes == null || fileBytes.isEmpty) {
        return const BinwasExcelExportResult(
          success: false,
          message: 'Gagal membuat byte data berkas Excel.',
        );
      }

      final timeSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final defaultFileName = 'Matriks_Rekapitulasi_Temuan_${tahun}_$timeSlug.xlsx';

      String? targetPath;

      // Coba tawarkan dialog pemilihan lokasi simpan jika di Desktop Windows
      if (Platform.isWindows) {
        try {
          final uri = await FilePicker.saveFile(
            dialogTitle: 'Simpan Matriks Rekapitulasi Excel',
            fileName: defaultFileName,
            bytes: Uint8List.fromList(fileBytes),
          );
          if (uri != null) {
            targetPath = uri.isScheme('file') ? uri.toFilePath() : uri.path;
            if (targetPath.isEmpty) {
              targetPath = uri.toString();
            }
          } else {
            // Pengguna membatalkan dialog penyimpanan
            return const BinwasExcelExportResult(
              success: false,
              message: 'Penyimpanan berkas Excel dibatalkan.',
            );
          }
        } catch (_) {
          targetPath = null;
        }
      }

      // Pastikan berkas tersimpan ke targetPath atau direktori penyimpanan perangkat
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
          try {
            dir = Directory.systemTemp;
          } catch (_) {
            dir = Directory.current;
          }
        }
        targetPath = '${dir.path}${Platform.pathSeparator}$defaultFileName';
        final file = File(targetPath);
        await file.writeAsBytes(fileBytes, flush: true);
      }

      // Coba buka berkas secara otomatis dengan aplikasi Excel bawaan
      try {
        await OpenFilex.open(targetPath);
      } catch (_) {}

      return BinwasExcelExportResult(
        success: true,
        filePath: targetPath,
        message: 'Berkas Excel berhasil diekspor:\n$targetPath',
      );
    } catch (e) {
      return BinwasExcelExportResult(
        success: false,
        message: 'Terjadi kesalahan saat mengekspor ke Excel: $e',
      );
    }
  }

  /// Ekspor Laporan Khusus Evaluasi Pembinaan & Pengawasan sesuai format resmi
  static Future<BinwasExcelExportResult> exportLaporanKhusus({
    required BinwasLaporanKhusus laporan,
  }) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Laporan Khusus';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // Styles
      final borderThin = Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#334155'),
      );

      final headerLabelStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final headerValueStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final colHeaderStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final colSubHeaderStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final cellTextStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        verticalAlign: VerticalAlign.Top,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final cellCenterStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Top,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final cellStatusMemadaiStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#15803D'),
        backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final cellStatusBelumStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#DC2626'),
        backgroundColorHex: ExcelColor.fromHexString('#FEE2E2'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final cellStatusProgressStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#D97706'),
        backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderThin,
        bottomBorder: borderThin,
        leftBorder: borderThin,
        rightBorder: borderThin,
      );

      final legendTitleStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
      );

      final legendCodeStyle = CellStyle(
        bold: true,
        fontSize: 9,
        horizontalAlign: HorizontalAlign.Center,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
      );

      final legendDescStyle = CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#334155'),
      );

      // 1. Header Box (Persis Format Spreadsheet)
      // Row 0: Nama Petugas Binwas | [laporan.namaPetugas]
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Nama Petugas Binwas')
        ..cellStyle = headerLabelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        ..value = TextCellValue(laporan.namaPetugas)
        ..cellStyle = headerValueStyle;

      // Row 1: Perusahaan | [laporan.perusahaan]
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Perusahaan')
        ..cellStyle = headerLabelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
        ..value = TextCellValue(laporan.perusahaan)
        ..cellStyle = headerValueStyle;

      // Row 2: Komoditas | [laporan.komoditas]
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Komoditas')
        ..cellStyle = headerLabelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
        ..value = TextCellValue(laporan.komoditas)
        ..cellStyle = headerValueStyle;

      // Row 3: Tanggal Binwas | [laporan.tanggalBinwas]
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
        ..value = TextCellValue('Tanggal Binwas')
        ..cellStyle = headerLabelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
        ..value = TextCellValue(laporan.tanggalBinwas)
        ..cellStyle = headerValueStyle;

      // Spasi di Row 4 (blank)

      // 2. Table Headers (Row 5 & Row 6)
      final colTitles = [
        'Temuan',
        'Rekomendasi',
        'Objek/Kategori',
        'Status',
        'Catatan evaluasi',
      ];
      final colCodes = ['a', 'b', 'c', 'd', 'e'];

      for (int c = 0; c < 5; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 5))
          ..value = TextCellValue(colTitles[c])
          ..cellStyle = colHeaderStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 6))
          ..value = TextCellValue(colCodes[c])
          ..cellStyle = colSubHeaderStyle;
      }

      // 3. Data Rows (Row 7...)
      int rowIdx = 7;
      if (laporan.items.isEmpty) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          ..value = TextCellValue('Tidak ada temuan lapangan (Patuh / Nihil).')
          ..cellStyle = cellTextStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
          ..value = TextCellValue('-')
          ..cellStyle = cellTextStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
          ..value = TextCellValue('-')
          ..cellStyle = cellCenterStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx))
          ..value = TextCellValue('Memadai')
          ..cellStyle = cellStatusMemadaiStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx))
          ..value = TextCellValue('Kondisi lapangan sesuai dengan norma konservasi.')
          ..cellStyle = cellTextStyle;
        rowIdx++;
      } else {
        for (final item in laporan.items) {
          // Col 0: Temuan (a)
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
            ..value = TextCellValue(item.temuan)
            ..cellStyle = cellTextStyle;

          // Col 1: Rekomendasi (b)
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
            ..value = TextCellValue(item.rekomendasi)
            ..cellStyle = cellTextStyle;

          // Col 2: Objek/Kategori (c)
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
            ..value = TextCellValue(item.objekKategori)
            ..cellStyle = cellCenterStyle;

          // Col 3: Status (d)
          CellStyle stStyle = cellStatusProgressStyle;
          final normStatus = item.status.trim().toLowerCase();
          if (normStatus == 'memadai') {
            stStyle = cellStatusMemadaiStyle;
          } else if (normStatus.contains('belum')) {
            stStyle = cellStatusBelumStyle;
          }
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx))
            ..value = TextCellValue(item.status)
            ..cellStyle = stStyle;

          // Col 4: Catatan evaluasi (e)
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx))
            ..value = TextCellValue(item.catatanEvaluasi.isNotEmpty ? item.catatanEvaluasi : '-')
            ..cellStyle = cellTextStyle;

          rowIdx++;
        }
      }

      // Spasi sebelum keterangan
      rowIdx++;

      // 4. Keterangan Section
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue('Keterangan')
        ..cellStyle = legendTitleStyle;
      rowIdx++;

      final legends = [
        ('a', 'Temuan sesuai hasil inputan aplikasi'),
        ('b', 'Rekomendasi sesuai hasil inputan aplikasi'),
        ('c', 'sesuai dengan objek/kategori'),
        ('d', '(Memadai, Belum Memadai, On Progress)'),
        ('e', 'berisi paragraf'),
      ];

      for (final lg in legends) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          ..value = TextCellValue(lg.$1)
          ..cellStyle = legendCodeStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
          ..value = TextCellValue(lg.$2)
          ..cellStyle = legendDescStyle;
        rowIdx++;
      }

      // Set column widths
      sheet.setColumnWidth(0, 38.0);
      sheet.setColumnWidth(1, 38.0);
      sheet.setColumnWidth(2, 28.0);
      sheet.setColumnWidth(3, 18.0);
      sheet.setColumnWidth(4, 45.0);

      // Simpan Berkas
      final List<int>? fileBytes = excel.save();
      if (fileBytes == null || fileBytes.isEmpty) {
        return const BinwasExcelExportResult(
          success: false,
          message: 'Gagal membuat byte data berkas Excel.',
        );
      }

      final safeCompName = laporan.perusahaan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final timeSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final defaultFileName = 'Laporan_Khusus_${safeCompName}_$timeSlug.xlsx';

      String? targetPath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        try {
          final uri = await FilePicker.saveFile(
            dialogTitle: 'Simpan Laporan Khusus Excel',
            fileName: defaultFileName,
            bytes: Uint8List.fromList(fileBytes),
          );
          if (uri != null) {
            targetPath = uri.isScheme('file') ? uri.toFilePath() : uri.path;
            if (targetPath.isEmpty) targetPath = uri.toString();
          } else {
            return const BinwasExcelExportResult(
              success: false,
              message: 'Penyimpanan berkas Excel dibatalkan.',
            );
          }
        } catch (_) {
          targetPath = null;
        }
      }

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
          try {
            dir = Directory.systemTemp;
          } catch (_) {
            dir = Directory.current;
          }
        }
        targetPath = '${dir.path}${Platform.pathSeparator}$defaultFileName';
        final file = File(targetPath);
        await file.writeAsBytes(fileBytes, flush: true);
      }

      try {
        await OpenFilex.open(targetPath);
      } catch (_) {}

      return BinwasExcelExportResult(
        success: true,
        filePath: targetPath,
        message: 'Laporan Khusus berhasil diekspor:\n$targetPath',
      );
    } catch (e) {
      return BinwasExcelExportResult(
        success: false,
        message: 'Terjadi kesalahan saat mengekspor Laporan Khusus: $e',
      );
    }
  }
}

