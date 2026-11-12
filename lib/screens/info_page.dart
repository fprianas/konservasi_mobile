import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'TENTANG & INFORMASI',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Color(0xFF18181B),
                letterSpacing: 0.6,
              ),
            ),
            Text(
              'Aplikasi Konservasi Mobile v2.0',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          children: [
            // App Banner Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF18181B), Color(0xFF27272A)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.engineering,
                          size: 54,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'KONSERVASI MOBILE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sistem Pelaporan & Monitoring Konservasi\nMineral dan Batubara',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Versi 2.0.0 (Flutter Mobile Edition)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18181B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),



            // Panduan Penggunaan Mobile
            _buildCard(
              title: 'Panduan Penggunaan Mobile',
              icon: Icons.lightbulb_outline,
              children: [
                _buildGuideItem(
                  icon: Icons.touch_app_outlined,
                  title: 'Ketuk Kartu untuk Detail',
                  desc: 'Sentuh kartu perusahaan untuk membuka lembar rincian teknis lengkap.',
                ),
                _buildGuideItem(
                  icon: Icons.view_column_outlined,
                  title: 'Pilih Kolom Opsional',
                  desc: 'Tekan ikon kolom di pojok kanan atas untuk memilih metrik yang tampil di depan.',
                ),
                _buildGuideItem(
                  icon: Icons.calculate_outlined,
                  title: 'Footer Rekapitulasi Jumlah',
                  desc: 'Ketuk bar rekapitulasi di bawah untuk melihat rincian total tonase/kuantitas.',
                ),
                _buildGuideItem(
                  icon: Icons.filter_alt_outlined,
                  title: 'Filter Presisi',
                  desc: 'Gunakan ikon filter untuk menyaring data per tahun, triwulan, atau provinsi.',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Copyright
            const Text(
              '© 2026 Ditjen Mineral dan Batubara\nKementerian ESDM Republik Indonesia',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFB45309)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18181B),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }



  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFB45309)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18181B),
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF71717A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
