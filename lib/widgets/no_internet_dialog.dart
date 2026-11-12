import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_service.dart';

class NoInternetDialog extends StatefulWidget {
  final VoidCallback onConnected;
  final bool canDismiss;

  const NoInternetDialog({
    super.key,
    required this.onConnected,
    this.canDismiss = false,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onConnected}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: NoInternetDialog(onConnected: onConnected),
      ),
    );
  }

  @override
  State<NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<NoInternetDialog> {
  bool _isChecking = false;
  String? _errorMessage;

  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    final hasInternet = await NetworkService.hasInternetConnection();

    if (!mounted) return;

    if (hasInternet) {
      Navigator.of(context).pop();
      widget.onConnected();
    } else {
      setState(() {
        _isChecking = false;
        _errorMessage = 'Koneksi internet masih belum terdeteksi.\nMohon periksa kembali sambungan Wi-Fi atau kuota data seluler Anda.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Disconnected
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 2),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 38,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Tidak Ada Koneksi Internet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              const Text(
                'Aplikasi membutuhkan sambungan internet aktif untuk sinkronisasi data dengan server Ditjen Minerba.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Tips Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text(
                          'Petunjuk Pemeriksaan:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Pastikan Wi-Fi telah tersambung dan memiliki akses internet.\n2. Jika menggunakan data seluler, pastikan kuota internet masih aktif dan sinyal operator stabil.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF78350F),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      child: const Text(
                        'Keluar',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isChecking ? null : _checkConnection,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _isChecking ? 'Memeriksa...' : 'Periksa Ulang',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

