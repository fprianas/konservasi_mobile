class UserSession {
  final int id;
  final String username;
  final String namaProvinsi;
  final String tipeSektor; // 'batubara' or 'mineral'

  const UserSession({
    required this.id,
    required this.username,
    required this.namaProvinsi,
    required this.tipeSektor,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      username: (json['username'] ?? '').toString().trim(),
      namaProvinsi: (json['nama_provinsi'] ?? '').toString().trim(),
      tipeSektor: (json['tipe_sektor'] ?? 'batubara').toString().trim().toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nama_provinsi': namaProvinsi,
    'tipe_sektor': tipeSektor,
  };

  bool get isBatubara => tipeSektor == 'batubara';
  bool get isMineral => tipeSektor == 'mineral';
  String get sektorLabel => isBatubara ? 'Batubara' : 'Mineral';
}

