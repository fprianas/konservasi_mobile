import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/binwas_model.dart';

/// Model item data untuk grafik Pie / Donut
class BinwasChartItem {
  final String label;
  final int value;
  final double percentage;
  final Color color;

  const BinwasChartItem({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });
}

/// Widget Grafik Pie / Donut Interaktif untuk Binwas
class BinwasPieDonutCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<BinwasChartItem> items;
  final bool isDonut; // true = Donut dengan lubang tengah, false = Solid Pie Chart
  final String? centerLabel;

  const BinwasPieDonutCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.isDonut = true,
    this.centerLabel,
  });

  @override
  State<BinwasPieDonutCard> createState() => _BinwasPieDonutCardState();
}

class _BinwasPieDonutCardState extends State<BinwasPieDonutCard>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant BinwasPieDonutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _selectedIndex = null;
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validItems = widget.items.where((i) => i.value > 0).toList();
    final totalValue = validItems.fold<int>(0, (sum, i) => sum + i.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Icon(widget.icon, color: const Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDonut ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isDonut ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Text(
                  widget.isDonut ? 'Donut Chart' : 'Pie Chart',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: widget.isDonut ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (totalValue == 0)
            Container(
              height: 190,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          'DATA MASIH NIHIL',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada temuan inspeksi lapangan (Nihil)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Seluruh butir kriteria pengawasan saat ini belum mencatat pelanggaran.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else ...[
            // Grafik Visual Area
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _PieDonutPainter(
                        items: validItems,
                        totalValue: totalValue,
                        isDonut: widget.isDonut,
                        selectedIndex: _selectedIndex,
                        animationProgress: _animation.value,
                      ),
                      child: widget.isDonut
                          ? Center(
                              child: _buildCenterLabel(validItems, totalValue),
                            )
                          : const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hint interaktif
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  _selectedIndex != null
                      ? 'Ketuk kembali pada legenda untuk melepas fokus'
                      : 'Ketuk salah satu item legenda di bawah untuk menyorot grafik',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Legenda Daftar Rincian
            ...validItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == idx;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = (_selectedIndex == idx) ? null : idx;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? item.color.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: item.color, width: 1.2)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? item.color : const Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.value} temuan',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${item.percentage.toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? item.color : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterLabel(List<BinwasChartItem> items, int totalValue) {
    if (_selectedIndex != null && _selectedIndex! < items.length) {
      final selected = items[_selectedIndex!];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selected.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: selected.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${selected.value} Temuan',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          SizedBox(
            width: 86,
            child: Text(
              selected.label,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$totalValue',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          widget.centerLabel ?? 'Total Temuan',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// CustomPainter untuk menggambar Pie / Donut Chart dengan tingkat kepresisian tinggi
class _PieDonutPainter extends CustomPainter {
  final List<BinwasChartItem> items;
  final int totalValue;
  final bool isDonut;
  final int? selectedIndex;
  final double animationProgress;

  _PieDonutPainter({
    required this.items,
    required this.totalValue,
    required this.isDonut,
    this.selectedIndex,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || totalValue <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2) - 10;
    final strokeWidth = isDonut ? maxRadius * 0.44 : maxRadius;
    final donutRadius = isDonut ? maxRadius - (strokeWidth / 2) : maxRadius;

    double currentAngle = -math.pi / 2; // Mulai dari jam 12 (posisi atas)

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final sweepAngle = (item.value / totalValue) * 2 * math.pi * animationProgress;
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..color = item.color
        ..isAntiAlias = true;

      if (isDonut) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth;

        // Efek bayangan glow untuk item yang dipilih
        if (isSelected) {
          final glowPaint = Paint()
            ..color = item.color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 14
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

          canvas.drawArc(
            Rect.fromCircle(center: center, radius: donutRadius),
            currentAngle,
            sweepAngle,
            false,
            glowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: donutRadius),
          currentAngle,
          sweepAngle,
          false,
          paint,
        );

        // Garis batas antar segmen agar terlihat rapi dan elegan
        if (items.length > 1) {
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: donutRadius),
            currentAngle,
            0.02,
            false,
            borderPaint,
          );
        }
      } else {
        // Solid Pie Chart (lingkaran utuh tanpa lubang, persis seperti di gambar)
        paint.style = PaintingStyle.fill;
        final currentRadius = isSelected ? maxRadius + 6 : maxRadius;

        if (isSelected) {
          final shadowPaint = Paint()
            ..color = item.color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: currentRadius + 4),
            currentAngle,
            sweepAngle,
            true,
            shadowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: currentRadius),
          currentAngle,
          sweepAngle,
          true,
          paint,
        );

        // Garis putih pemisah antar irisan pie
        if (items.length > 1) {
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: currentRadius),
            currentAngle,
            sweepAngle,
            true,
            borderPaint,
          );
        }
      }

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieDonutPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.items != items ||
        oldDelegate.totalValue != totalValue;
  }
}

/// Helper pembuat daftar BinwasChartItem dengan palet warna kontras tinggi dan saling berbeda
class BinwasChartPalette {
  // Palet 20 warna kurasi dengan kontras maksimal (tidak ada warna bertubrukan)
  static const List<Color> distinctPalette20 = [
    Color(0xFF2563EB), // 1. Biru Elektrik (Blue)
    Color(0xFFDC2626), // 2. Merah Cerah (Red)
    Color(0xFF0D9488), // 3. Toska / Teal
    Color(0xFFEA580C), // 4. Oranye Pekat (Orange)
    Color(0xFF16A34A), // 5. Hijau Zamrud (Green)
    Color(0xFF8B5CF6), // 6. Ungu Lavender (Purple)
    Color(0xFFEAB308), // 7. Kuning Emas (Yellow)
    Color(0xFFEC4899), // 8. Merah Muda / Pink
    Color(0xFF06B6D4), // 9. Cyan Terang (Cyan)
    Color(0xFF92400E), // 10. Cokelat Tambang (Brown)
    Color(0xFF4338CA), // 11. Indigo Gelap
    Color(0xFF059669), // 12. Hijau Mint Tua
    Color(0xFFBE185D), // 13. Magenta Rose
    Color(0xFFD97706), // 14. Amber Emas
    Color(0xFF6366F1), // 15. Violet Indigo
    Color(0xFF65A30D), // 16. Hijau Limau (Lime)
    Color(0xFF0284C7), // 17. Biru Langit (Sky Blue)
    Color(0xFFB91C1C), // 18. Merah Marun (Maroon)
    Color(0xFF64748B), // 19. Abu Slate (Slate)
    Color(0xFFF43F5E), // 20. Rose Coral
  ];

  // Palet Warna Kategori Temuan (10 Kategori dengan rona warna unik)
  static final Map<String, Color> kategoriColors = {
    'Administrasi': const Color(0xFF2563EB), // Biru (Dominan 59.1%)
    'Front Loading': const Color(0xFFDC2626), // Merah (14.3%)
    'Stockpile': const Color(0xFFEA580C), // Oranye
    'ROM': const Color(0xFF06B6D4), // Cyan
    'Jalan Tambang': const Color(0xFF16A34A), // Hijau Zamrud
    'Jalan Hauling': const Color(0xFF8B5CF6), // Ungu
    'Conveyor': const Color(0xFF8B5CF6),
    'Jetty': const Color(0xFFEAB308), // Kuning Emas
    'Area Peledakan': const Color(0xFFEC4899), // Pink
    'Peledakan': const Color(0xFFEC4899),
    'Tunnel': const Color(0xFF92400E), // Cokelat
    'Underground': const Color(0xFF92400E),
    'Disposal': const Color(0xFF475569), // Slate
    'Pengolahan': const Color(0xFF0D9488), // Toska
    'Lainnya': const Color(0xFF64748B), // Abu
  };

  // Palet Warna Komoditas (Warna berbeda tegas untuk setiap bahan galian)
  static final Map<String, Color> komoditasColors = {
    'Batubara': const Color(0xFF0D9488), // Toska / Teal (Dominan 63.6%)
    'Nikel': const Color(0xFF2563EB), // Biru (18.7%)
    'Emas': const Color(0xFFEAB308), // Kuning Emas (8.3%)
    'Tembaga': const Color(0xFF16A34A), // Hijau (5.6%)
    'Batu Gamping': const Color(0xFF8B5CF6), // Ungu Lavender (5.6%)
    'Gamping': const Color(0xFF8B5CF6),
    'Bauksit': const Color(0xFFEA580C), // Oranye
    'Besi': const Color(0xFFDC2626), // Merah
    'Pasir Besi': const Color(0xFFB91C1C),
    'Timah': const Color(0xFF06B6D4), // Cyan
    'Perak': const Color(0xFF64748B), // Slate Grey
    'Granit': const Color(0xFF92400E), // Cokelat
    'Andesit': const Color(0xFF4B5563), // Abu Tua
    'Tanah Urug': const Color(0xFFA16207), // Kuning Tanah
    'Lempung': const Color(0xFFD97706), // Amber
    'Mineral': const Color(0xFF4338CA), // Indigo
  };

  // Palet Warna 9 Objek Konservasi (9 Rona Warna Sangat Berbeda)
  static final Map<String, Color> objekColors = {
    'Recovery Penambangan': const Color(0xFFDC2626), // 1. Merah
    'Recovery Pengolahan': const Color(0xFFEA580C), // 2. Oranye
    'Dilusi dan Losses': const Color(0xFFEAB308), // 3. Kuning Emas
    'Batubara Kualitas Rendah': const Color(0xFF0D9488), // 4. Toska
    'Mineral Kadar Rendah': const Color(0xFF2563EB), // 5. Biru Elektrik
    'Mineral Ikutan': const Color(0xFF16A34A), // 6. Hijau Segar
    'Cadangan Marginal': const Color(0xFF8B5CF6), // 7. Ungu
    'Cadangan Tidak Tertambang': const Color(0xFFEC4899), // 8. Pink
    'Sisa Hasil Pengolahan': const Color(0xFF92400E), // 9. Cokelat
  };

  static Color _findPreferredColor(String label, Map<String, Color> map) {
    for (final entry in map.entries) {
      if (label.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return Colors.transparent;
  }

  /// Menjamin seluruh item grafik memiliki warna yang 100% berbeda satu sama lain
  static Color _getDistinctColor({
    required String label,
    required Map<String, Color> preferredMap,
    required Set<Color> usedColors,
    required int index,
  }) {
    final pref = _findPreferredColor(label, preferredMap);
    if (pref != Colors.transparent && !usedColors.contains(pref)) {
      usedColors.add(pref);
      return pref;
    }

    // Jika warna preferred sudah terpakai variabel lain, pilih warna kontras berikutnya yang belum terpakai
    for (final candidate in distinctPalette20) {
      if (!usedColors.contains(candidate)) {
        usedColors.add(candidate);
        return candidate;
      }
    }

    // Fallback jika item melebihi 20
    final fallback = distinctPalette20[index % distinctPalette20.length];
    usedColors.add(fallback);
    return fallback;
  }

  static Color getKategoriColor(String label, int index) {
    return _getDistinctColor(
      label: label,
      preferredMap: kategoriColors,
      usedColors: {},
      index: index,
    );
  }

  static Color getKomoditasColor(String label, int index) {
    return _getDistinctColor(
      label: label,
      preferredMap: komoditasColors,
      usedColors: {},
      index: index,
    );
  }

  static Color getObjekColor(String label, int index) {
    return _getDistinctColor(
      label: label,
      preferredMap: objekColors,
      usedColors: {},
      index: index,
    );
  }

  /// Konversi data rekap kategori ke BinwasChartItem dengan warna saling berbeda
  static List<BinwasChartItem> fromKategori(List<BinwasRekapKategori> list) {
    final usedColors = <Color>{};
    return list.asMap().entries.map((entry) {
      final kat = entry.value;
      final color = _getDistinctColor(
        label: kat.namaKategori,
        preferredMap: kategoriColors,
        usedColors: usedColors,
        index: entry.key,
      );
      return BinwasChartItem(
        label: kat.namaKategori,
        value: kat.jumlahTemuan,
        percentage: kat.persentase,
        color: color,
      );
    }).toList();
  }

  /// Konversi data rekap komoditas ke BinwasChartItem dengan warna saling berbeda
  static List<BinwasChartItem> fromKomoditas(List<BinwasRekapKomoditas> list) {
    final usedColors = <Color>{};
    return list.asMap().entries.map((entry) {
      final kom = entry.value;
      final color = _getDistinctColor(
        label: kom.namaKomoditas,
        preferredMap: komoditasColors,
        usedColors: usedColors,
        index: entry.key,
      );
      return BinwasChartItem(
        label: kom.namaKomoditas,
        value: kom.jumlahTemuan,
        percentage: kom.persentase,
        color: color,
      );
    }).toList();
  }

  /// Konversi data rekap objek konservasi ke BinwasChartItem dengan warna saling berbeda
  static List<BinwasChartItem> fromObjek(List<BinwasRekapObjek> list) {
    final usedColors = <Color>{};
    return list.asMap().entries.map((entry) {
      final obj = entry.value;
      final color = _getDistinctColor(
        label: obj.objekKonservasi,
        preferredMap: objekColors,
        usedColors: usedColors,
        index: entry.key,
      );
      return BinwasChartItem(
        label: obj.objekKonservasi,
        value: obj.jumlahTemuan,
        percentage: obj.persentase,
        color: color,
      );
    }).toList();
  }
}

