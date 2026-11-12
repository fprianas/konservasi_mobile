import '../services/api_service.dart';

class ProvinceAnalysisTrend {
  final String namaProvinsi;
  final double kepatuhanCurrent;
  final double kepatuhanPrev;
  final double delta;
  final int totalPerusahaanCurrent;
  final int sudahLaporCurrent;
  final int sudahLaporPrev;

  ProvinceAnalysisTrend({
    required this.namaProvinsi,
    required this.kepatuhanCurrent,
    required this.kepatuhanPrev,
    required this.delta,
    required this.totalPerusahaanCurrent,
    required this.sudahLaporCurrent,
    required this.sudahLaporPrev,
  });

  bool get isMeningkat => delta > 0.05;
  bool get isMenurun => delta < -0.05;
  bool get isStabil => !isMeningkat && !isMenurun;
}

class SpecialAnalysisData {
  final int totalProduksi;
  final int totalBelumProduksi;
  final double persentaseProduksi;
  final int totalDenganDokumen;
  final int totalDenganPeta;
  final double persentaseKelengkapanDokumen;
  final Map<String, int> perizinanBreakdown;

  SpecialAnalysisData({
    required this.totalProduksi,
    required this.totalBelumProduksi,
    required this.persentaseProduksi,
    required this.totalDenganDokumen,
    required this.totalDenganPeta,
    required this.persentaseKelengkapanDokumen,
    required this.perizinanBreakdown,
  });
}

class AnalysisData {
  final ReportType type;
  final String tahunCurrent;
  final String triwulanCurrent;
  final String tahunPrev;
  final String triwulanPrev;
  final String? selectedProvinsi;

  final double kepatuhanCurrent;
  final double kepatuhanPrev;
  final double deltaKepatuhan;

  final int totalPerusahaan;
  final int sudahLaporCurrent;
  final int sudahLaporPrev;
  final int totalLaporanCurrent;
  final int totalLaporanPrev;

  final List<ProvinceAnalysisTrend> provinceTrends;
  final SpecialAnalysisData specialAnalysis;

  AnalysisData({
    required this.type,
    required this.tahunCurrent,
    required this.triwulanCurrent,
    required this.tahunPrev,
    required this.triwulanPrev,
    this.selectedProvinsi,
    required this.kepatuhanCurrent,
    required this.kepatuhanPrev,
    required this.deltaKepatuhan,
    required this.totalPerusahaan,
    required this.sudahLaporCurrent,
    required this.sudahLaporPrev,
    required this.totalLaporanCurrent,
    required this.totalLaporanPrev,
    required this.provinceTrends,
    required this.specialAnalysis,
  });

  bool get isMeningkat => deltaKepatuhan > 0.05;
  bool get isMenurun => deltaKepatuhan < -0.05;
  bool get isStabil => !isMeningkat && !isMenurun;

  List<ProvinceAnalysisTrend> get topClimbers {
    final list = provinceTrends.where((p) => p.delta > 0).toList();
    list.sort((a, b) => b.delta.compareTo(a.delta));
    return list.take(5).toList();
  }

  List<ProvinceAnalysisTrend> get topDecliners {
    final list = provinceTrends.where((p) => p.delta < 0).toList();
    list.sort((a, b) => a.delta.compareTo(b.delta)); // most negative first
    return list.take(5).toList();
  }
}
