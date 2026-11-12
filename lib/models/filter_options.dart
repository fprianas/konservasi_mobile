class FilterOptions {
  final List<String> provinsi;
  final List<String> tahun;
  final List<String> triwulan;
  final List<String> komoditas;
  final List<String> jenisPerizinan;

  FilterOptions({
    required this.provinsi,
    required this.tahun,
    required this.triwulan,
    required this.komoditas,
    required this.jenisPerizinan,
  });

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      provinsi: (json['provinsi'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tahun: (json['tahun'] as List?)?.map((e) => e.toString()).toList() ?? [],
      triwulan: (json['triwulan'] as List?)?.map((e) => e.toString()).toList() ?? [],
      komoditas: (json['komoditas'] as List?)?.map((e) => e.toString()).toList() ?? [],
      jenisPerizinan: (json['jenis_perizinan'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
