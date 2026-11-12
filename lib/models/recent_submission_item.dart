class RecentSubmissionItem {
  final int id;
  final String namaPerusahaan;
  final String provinsi;
  final String triwulan;
  final String tahun;
  final String waktuInput;

  const RecentSubmissionItem({
    required this.id,
    required this.namaPerusahaan,
    required this.provinsi,
    required this.triwulan,
    required this.tahun,
    required this.waktuInput,
  });

  factory RecentSubmissionItem.fromJson(Map<String, dynamic> json) {
    return RecentSubmissionItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      namaPerusahaan: json['nama_perusahaan']?.toString() ?? '-',
      provinsi: json['provinsi']?.toString() ?? '-',
      triwulan: json['triwulan']?.toString() ?? '-',
      tahun: json['tahun']?.toString() ?? '-',
      waktuInput: json['waktu_input']?.toString() ?? '-',
    );
  }
}

class RecentSubmissionsData {
  final bool success;
  final String period; // 'today', 'week', 'month', 'empty'
  final String label;  // 'Hari Ini', 'Minggu Ini', 'Bulan Ini'
  final String title;  // 'Perusahaan yang mengisi data hari ini'
  final int total;
  final List<RecentSubmissionItem> items;

  const RecentSubmissionsData({
    required this.success,
    required this.period,
    required this.label,
    required this.title,
    required this.total,
    required this.items,
  });

  factory RecentSubmissionsData.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return RecentSubmissionsData(
      success: json['success'] == true,
      period: json['period']?.toString() ?? 'empty',
      label: json['label']?.toString() ?? 'Bulan Ini',
      title: json['title']?.toString() ?? 'Belum ada input bulan ini',
      total: json['total'] is int ? json['total'] : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      items: list.map((e) => RecentSubmissionItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory RecentSubmissionsData.empty() {
    return const RecentSubmissionsData(
      success: true,
      period: 'empty',
      label: 'Bulan Ini',
      title: 'Belum ada input bulan ini',
      total: 0,
      items: [],
    );
  }
}