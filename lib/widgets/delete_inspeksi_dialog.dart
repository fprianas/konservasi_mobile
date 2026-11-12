import 'package:flutter/material.dart';
import '../services/binwas_service.dart';

class DeleteInspeksiDialog extends StatefulWidget {
  final int idInspeksi;
  final String namaPerusahaan;
  final VoidCallback onDeleted;

  const DeleteInspeksiDialog({
    super.key,
    required this.idInspeksi,
    required this.namaPerusahaan,
    required this.onDeleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int idInspeksi,
    required String namaPerusahaan,
    required VoidCallback onDeleted,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteInspeksiDialog(
        idInspeksi: idInspeksi,
        namaPerusahaan: namaPerusahaan,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<DeleteInspeksiDialog> createState() => _DeleteInspeksiDialogState();
}

class _DeleteInspeksiDialogState extends State<DeleteInspeksiDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isObscure = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Masukkan kode rahasia terlebih dahulu.');
      return;
    }

    if (pin != '3636') {
      setState(() => _errorMessage = 'Kode salah');
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final res = await BinwasService.deleteInspeksi(widget.idInspeksi, pin);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Data inspeksi berhasil dihapus.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      widget.onDeleted();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Header Danger
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hapus Data Inspeksi?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.namaPerusahaan,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Warning Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Text(
                  'Perhatian: Tindakan ini akan menghapus data inspeksi dan seluruh rincian temuan lapangan secara permanen dari server database.\nData yang dihapus tidak dapat dipulihkan kembali.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF991B1B),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Input Kode Rahasia
              const Text(
                'Masukkan Kode Rahasia:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: _isObscure,
                autofocus: true,
                onSubmitted: (_) => _handleDelete(),
                decoration: InputDecoration(
                  hintText: 'Ketik kode rahasia...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.password, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _handleDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever, size: 18),
                    label: Text(
                      _isDeleting ? 'Menghapus...' : 'Hapus Permanen',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

