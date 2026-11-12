import 'dart:io';
import 'package:http/http.dart' as http;

class NetworkService {
  /// Memeriksa apakah perangkat terhubung ke internet aktif
  static Future<bool> hasInternetConnection() async {
    try {
      final addresses = await InternetAddress.lookup('laporan-minerba.my.id')
          .timeout(const Duration(seconds: 4));
      if (addresses.isNotEmpty && addresses[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final addresses = await InternetAddress.lookup('1.1.1.1')
          .timeout(const Duration(seconds: 4));
      if (addresses.isNotEmpty && addresses[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('https://laporan-minerba.my.id/v2/api_binwas.php?action=check'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode >= 200 && res.statusCode < 500) {
        return true;
      }
    } catch (_) {}

    return false;
  }
}

