import 'report_item.dart';
import '../services/api_service.dart';

class CompanySearchItem {
  final String namaPerusahaan;
  final String skIup;
  final String provinsi;
  final String jenisPerizinan;
  final String? komoditas;
  final ReportType type;
  final String latestStatusProduksi;
  final String latestStatusProduksiCode;
  final String latestTahun;
  final String latestTriwulan;
  final String latestWaktuInput;
  final int totalReports;
  final List<ReportItem> reports;

  CompanySearchItem({
    required this.namaPerusahaan,
    required this.skIup,
    required this.provinsi,
    required this.jenisPerizinan,
    this.komoditas,
    required this.type,
    required this.latestStatusProduksi,
    required this.latestStatusProduksiCode,
    required this.latestTahun,
    required this.latestTriwulan,
    required this.latestWaktuInput,
    required this.totalReports,
    required this.reports,
  });

  factory CompanySearchItem.fromJson(Map<String, dynamic> json, ReportType defaultType) {
    final sektorStr = json['sektor']?.toString().toLowerCase() ?? '';
    final ReportType t = sektorStr == 'mineral'
        ? ReportType.mineral
        : (sektorStr == 'batubara' ? ReportType.batubara : defaultType);

    final statusProd = json['latest_status_produksi']?.toString() ?? 'Belum Produksi';
    final statusProdCode = json['latest_status_produksi_code']?.toString() ??
        (statusProd.toLowerCase().contains('sudah') ? 'P' : 'BP');

    return CompanySearchItem(
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '-',
      skIup: json['sk_iup']?.toString() ?? '-',
      provinsi: json['provinsi']?.toString() ?? '-',
      jenisPerizinan: json['jenis_perizinan']?.toString() ?? '-',
      komoditas: json['komoditas']?.toString(),
      type: t,
      latestStatusProduksi: statusProd,
      latestStatusProduksiCode: statusProdCode,
      latestTahun: json['latest_tahun']?.toString() ?? '-',
      latestTriwulan: json['latest_triwulan']?.toString() ?? '-',
      latestWaktuInput: json['latest_waktu_input']?.toString() ?? '-',
      totalReports: json['total_reports'] is int
          ? json['total_reports']
          : int.tryParse(json['total_reports'].toString()) ?? 0,
      reports: [],
    );
  }

  bool get isProduksi =>
      latestStatusProduksiCode == 'P' ||
      latestStatusProduksi.toLowerCase().contains('sudah');
}
