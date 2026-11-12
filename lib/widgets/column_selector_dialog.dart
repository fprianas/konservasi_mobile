import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ColumnOption {
  final String key;
  final String label;
  final String description;

  const ColumnOption({
    required this.key,
    required this.label,
    required this.description,
  });
}

class ColumnSelectorDialog extends StatefulWidget {
  final ReportType type;
  final Set<String> selectedColumns;
  final Function(Set<String>) onSave;

  const ColumnSelectorDialog({
    super.key,
    required this.type,
    required this.selectedColumns,
    required this.onSave,
  });

  @override
  State<ColumnSelectorDialog> createState() => _ColumnSelectorDialogState();
}

class _ColumnSelectorDialogState extends State<ColumnSelectorDialog> {
  late Set<String> _tempSelected;

  List<ColumnOption> get _options {
    if (widget.type == ReportType.batubara) {
      return const [
        ColumnOption(
          key: 'bkr_kuantitas',
          label: 'Kuantitas BKR',
          description: 'Batubara Kualitas Rendah (Ton)',
        ),
        ColumnOption(
          key: 'pbkr_volume',
          label: 'Volume PBKR',
          description: 'Penimbunan Batubara Kualitas Rendah (Ton/m³)',
        ),
        ColumnOption(
          key: 'cm_kuantitas',
          label: 'Cadangan Marginal (CM)',
          description: 'Kuantitas Cadangan Marginal (Ton)',
        ),
        ColumnOption(
          key: 'shp_kuantitas',
          label: 'Kuantitas SHP',
          description: 'Sisa Hasil Pengolahan (Ton)',
        ),
        ColumnOption(
          key: 'ctt_kuantitas',
          label: 'Cadangan Tidak Tertambang',
          description: 'Kuantitas Cadangan Tidak Tertambang (Ton)',
        ),
        ColumnOption(
          key: 'rec_penambangan',
          label: 'Recovery Tambang',
          description: 'Persentase Recovery Penambangan (%)',
        ),
        ColumnOption(
          key: 'rec_pengolahan',
          label: 'Recovery Pengolahan',
          description: 'Persentase Recovery Pengolahan (%)',
        ),
      ];
    } else {
      return const [
        ColumnOption(
          key: 'mkr_kuantitas',
          label: 'Kuantitas MKR',
          description: 'Mineral Kadar Rendah',
        ),
        ColumnOption(
          key: 'pmkr_volume',
          label: 'Volume PMKR',
          description: 'Penimbunan Mineral Kadar Rendah',
        ),
        ColumnOption(
          key: 'cm_kuantitas',
          label: 'Cadangan Marginal (CM)',
          description: 'Kuantitas Cadangan Marginal',
        ),
        ColumnOption(
          key: 'shp_kuantitas',
          label: 'Kuantitas SHP',
          description: 'Sisa Hasil Pengolahan Mineral',
        ),
        ColumnOption(
          key: 'cmtt_kuantitas',
          label: 'Cadangan Mineral CTT',
          description: 'Cadangan Mineral Tidak Tertambang',
        ),
        ColumnOption(
          key: 'rec_penambangan',
          label: 'Recovery Penambangan',
          description: 'Recovery Penambangan (%)',
        ),
        ColumnOption(
          key: 'rec_pengolahan',
          label: 'Recovery Pemulihan',
          description: 'Recovery Pengolahan / Pemulihan (%)',
        ),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _tempSelected = Set<String>.from(widget.selectedColumns);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Pilih Kolom Tampilan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centang metrik tambahan yang ingin ditampilkan pada kartu laporan:',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              ..._options.map((opt) {
                final isChecked = _tempSelected.contains(opt.key);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    opt.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    opt.description,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  value: isChecked,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _tempSelected.add(opt.key);
                      } else {
                        _tempSelected.remove(opt.key);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _tempSelected.clear();
            });
          },
          child: const Text('Reset', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_tempSelected);
            Navigator.pop(context);
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
