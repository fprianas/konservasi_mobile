import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluasi_dokumen_model.dart';
import '../services/evaluasi_dokumen_service.dart';
import '../services/wilayah_service.dart';
import 'company_search_picker_modal.dart';

class FormRkpwDialog extends StatefulWidget {
  final EvaluasiRkpwItem? initialItem;
  final VoidCallback onSaved;

  const FormRkpwDialog({
    super.key,
    this.initialItem,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {EvaluasiRkpwItem? item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FormRkpwDialog(initialItem: item, onSaved: onSaved),
    );
  }

  @override
  State<FormRkpwDialog> createState() => _FormRkpwDialogState();
}

class _FormRkpwDialogState extends State<FormRkpwDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  late TextEditingController _evaluatorCtrl;
  late TextEditingController _perusahaanCtrl;
  late TextEditingController _noSkIupCtrl;
  late TextEditingController _masaBerlakuCtrl;
  late TextEditingController _luasWiupCtrl;
  late TextEditingController _komoditasCtrl;
  late TextEditingController _luasDimohonCtrl;
  late TextEditingController _suratPerusahaanNoCtrl;
  late TextEditingController _suratPerusahaanTglCtrl;
  late TextEditingController _tglMasukDjmbCtrl;
  late TextEditingController _tglMasukDbtCtrl;
  late TextEditingController _tglMasukSdkmCtrl;
  late TextEditingController _ndDbtPermohonanNoCtrl;
  late TextEditingController _ndDbtPermohonanTglCtrl;
  late TextEditingController _ndDbtKmNoCtrl;
  late TextEditingController _ndDbtKmTglCtrl;
  late TextEditingController _ndDbpPwNoCtrl;
  late TextEditingController _ndDbpPwTglCtrl;
  late TextEditingController _ndDbmPeNoCtrl;
  late TextEditingController _ndDbmPeTglCtrl;
  late TextEditingController _suratDjbNoCtrl;
  late TextEditingController _suratDjbTglCtrl;
  late TextEditingController _catatanCtrl;
  late TextEditingController _suratMemNoCtrl;
  late TextEditingController _suratMemTglCtrl;
  late TextEditingController _skPerluasanNoCtrl;
  late TextEditingController _skPerluasanTglCtrl;
  late TextEditingController _luasDisetujuiCtrl;
  late TextEditingController _kdiNilaiCtrl;
  late TextEditingController _totalLuasSekarangCtrl;

  String _jenisKomoditas = 'Mineral';
  String _status = 'Proses';
  String _kdiStatusBayar = 'Belum';

  // Cascading Location (Provinsi -> Kabupaten -> Kecamatan)
  List<WilayahItem> _provinces = [];
  List<WilayahItem> _regencies = [];
  List<WilayahItem> _districts = [];

  WilayahItem? _selectedProvince;
  WilayahItem? _selectedRegency;
  WilayahItem? _selectedDistrict;

  bool _isLoadingProvinces = false;
  bool _isLoadingRegencies = false;
  bool _isLoadingDistricts = false;

  // Manual fallback flag
  bool _manualLocation = false;
  late TextEditingController _provinsiManualCtrl;
  late TextEditingController _kabupatenManualCtrl;
  late TextEditingController _kecamatanManualCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _evaluatorCtrl = TextEditingController(text: item?.evaluator ?? '');
    _perusahaanCtrl = TextEditingController(text: item?.namaPerusahaan ?? '');
    _noSkIupCtrl = TextEditingController(text: item?.noSkIup ?? '');
    _masaBerlakuCtrl = TextEditingController(text: item?.masaBerlaku ?? '');
    _luasWiupCtrl = TextEditingController(text: item != null && item.luasWiup > 0 ? item.luasWiup.toString() : '');
    _komoditasCtrl = TextEditingController(text: item?.komoditas ?? '');
    _luasDimohonCtrl = TextEditingController(text: item != null && item.luasPerluasanDimohon > 0 ? item.luasPerluasanDimohon.toString() : '');
    _suratPerusahaanNoCtrl = TextEditingController(text: item?.suratPermohonanNomor ?? '');
    _suratPerusahaanTglCtrl = TextEditingController(text: item?.suratPermohonanTanggal ?? '');
    _tglMasukDjmbCtrl = TextEditingController(text: item?.tglMasukDjmb ?? '');
    _tglMasukDbtCtrl = TextEditingController(text: item?.tglMasukDbt ?? '');
    _tglMasukSdkmCtrl = TextEditingController(text: item?.tglMasukSdkm ?? '');
    _ndDbtPermohonanNoCtrl = TextEditingController(text: item?.ndDbtPermohonanNomor ?? '');
    _ndDbtPermohonanTglCtrl = TextEditingController(text: item?.ndDbtPermohonanTanggal ?? '');
    _ndDbtKmNoCtrl = TextEditingController(text: item?.ndDbtKmNomor ?? '');
    _ndDbtKmTglCtrl = TextEditingController(text: item?.ndDbtKmTanggal ?? '');
    _ndDbpPwNoCtrl = TextEditingController(text: item?.ndDbpPwNomor ?? '');
    _ndDbpPwTglCtrl = TextEditingController(text: item?.ndDbpPwTanggal ?? '');
    _ndDbmPeNoCtrl = TextEditingController(text: item?.ndDbmPeNomor ?? '');
    _ndDbmPeTglCtrl = TextEditingController(text: item?.ndDbmPeTanggal ?? '');
    _suratDjbNoCtrl = TextEditingController(text: item?.suratDjbNomor ?? '');
    _suratDjbTglCtrl = TextEditingController(text: item?.suratDjbTanggal ?? '');
    _catatanCtrl = TextEditingController(text: item?.catatanEvaluasi ?? '');
    _suratMemNoCtrl = TextEditingController(text: item?.suratMemNomor ?? '');
    _suratMemTglCtrl = TextEditingController(text: item?.suratMemTanggal ?? '');
    _skPerluasanNoCtrl = TextEditingController(text: item?.skPerluasanNomor ?? '');
    _skPerluasanTglCtrl = TextEditingController(text: item?.skPerluasanTanggal ?? '');
    _luasDisetujuiCtrl = TextEditingController(text: item != null && item.luasDisetujui > 0 ? item.luasDisetujui.toString() : '');
    _kdiNilaiCtrl = TextEditingController(text: item != null && item.kdiNilaiRp > 0 ? item.kdiNilaiRp.toString() : '');
    _totalLuasSekarangCtrl = TextEditingController(text: item != null && item.totalLuasSekarang > 0 ? item.totalLuasSekarang.toString() : '');

    _provinsiManualCtrl = TextEditingController(text: item?.provinsi ?? '');
    _kabupatenManualCtrl = TextEditingController(text: item?.kabupaten ?? '');
    _kecamatanManualCtrl = TextEditingController(text: item?.kecamatan ?? '');

    if (item != null) {
      _jenisKomoditas = item.jenisKomoditas.isNotEmpty ? item.jenisKomoditas : 'Mineral';
      _status = item.status.isNotEmpty ? item.status : 'Proses';
      _kdiStatusBayar = item.kdiStatusBayar.isNotEmpty ? item.kdiStatusBayar : 'Belum';
    }

    _initWilayahData();
  }

  Future<void> _initWilayahData() async {
    setState(() => _isLoadingProvinces = true);
    final provs = await WilayahService.getProvinces();
    if (!mounted) return;

    setState(() {
      _provinces = provs;
      _isLoadingProvinces = false;
    });

    // Auto-select initial location if editing
    final initialProv = widget.initialItem?.provinsi;
    final initialKab = widget.initialItem?.kabupaten;
    final initialKec = widget.initialItem?.kecamatan;

    if (initialProv != null && initialProv.isNotEmpty) {
      final pMatch = _provinces.firstWhere(
        (p) => p.name.toUpperCase().contains(initialProv.toUpperCase()) || initialProv.toUpperCase().contains(p.name.toUpperCase()),
        orElse: () => WilayahItem(id: '', name: initialProv),
      );

      if (pMatch.id.isNotEmpty) {
        _selectedProvince = pMatch;
        setState(() => _isLoadingRegencies = true);
        final regList = await WilayahService.getRegencies(pMatch.id);
        if (!mounted) return;

        setState(() {
          _regencies = regList;
          _isLoadingRegencies = false;
        });

        if (initialKab != null && initialKab.isNotEmpty) {
          final kClean = initialKab.toUpperCase().replaceAll('KABUPATEN ', '').replaceAll('KOTA ', '');
          final rMatch = _regencies.firstWhere(
            (r) => r.name.toUpperCase().contains(kClean),
            orElse: () => WilayahItem(id: '', name: initialKab),
          );

          if (rMatch.id.isNotEmpty) {
            _selectedRegency = rMatch;
            setState(() => _isLoadingDistricts = true);
            final distList = await WilayahService.getDistricts(rMatch.id);
            if (!mounted) return;

            setState(() {
              _districts = distList;
              _isLoadingDistricts = false;
            });

            if (initialKec != null && initialKec.isNotEmpty) {
              final dMatch = _districts.firstWhere(
                (d) => d.name.toUpperCase() == initialKec.toUpperCase(),
                orElse: () => WilayahItem(id: '', name: initialKec),
              );
              if (dMatch.id.isNotEmpty) {
                _selectedDistrict = dMatch;
              }
            }
          }
        }
      } else {
        // Fallback manual jika nama provinsi tidak cocok di master
        setState(() => _manualLocation = true);
      }
    }
  }

  void _onProvinceChanged(WilayahItem? prov) async {
    if (prov == null || prov == _selectedProvince) return;
    setState(() {
      _selectedProvince = prov;
      _selectedRegency = null;
      _selectedDistrict = null;
      _regencies = [];
      _districts = [];
      _isLoadingRegencies = true;
    });

    final regList = await WilayahService.getRegencies(prov.id);
    if (!mounted) return;
    setState(() {
      _regencies = regList;
      _isLoadingRegencies = false;
    });
  }

  void _onRegencyChanged(WilayahItem? reg) async {
    if (reg == null || reg == _selectedRegency) return;
    setState(() {
      _selectedRegency = reg;
      _selectedDistrict = null;
      _districts = [];
      _isLoadingDistricts = true;
    });

    final distList = await WilayahService.getDistricts(reg.id);
    if (!mounted) return;
    setState(() {
      _districts = distList;
      _isLoadingDistricts = false;
    });
  }

  Future<void> _openCompanyPicker() async {
    final selected = await CompanySearchPickerModal.show(
      context,
      initialTipe: _jenisKomoditas.toLowerCase(),
      initialQuery: _perusahaanCtrl.text.trim(),
    );

    if (selected != null) {
      setState(() {
        _perusahaanCtrl.text = selected['nama_perusahaan'] ?? _perusahaanCtrl.text;

        final tipe = (selected['tipe_komoditas'] ?? '').toString().toLowerCase();
        if (tipe == 'batubara') {
          _jenisKomoditas = 'Batubara';
        } else if (tipe == 'mineral') {
          _jenisKomoditas = 'Mineral';
        }

        final komoditas = (selected['komoditas'] ?? '').toString().trim();
        if (komoditas.isNotEmpty) {
          _komoditasCtrl.text = komoditas;
        }

        final skIup = (selected['sk_iup'] ?? '').toString().trim();
        if (skIup.isNotEmpty && skIup != '-') {
          _noSkIupCtrl.text = skIup;
        }

        final provName = (selected['nama_provinsi'] ?? '').toString().trim();
        if (provName.isNotEmpty && _provinces.isNotEmpty) {
          for (final p in _provinces) {
            if (p.name.toUpperCase().contains(provName.toUpperCase()) ||
                provName.toUpperCase().contains(p.name.toUpperCase())) {
              _onProvinceChanged(p);
              break;
            }
          }
        }
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateFormat('yyyy-MM-dd').parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Tentukan nilai lokasi (dari dropdown otomatis atau input manual)
    String provinsi = _manualLocation ? _provinsiManualCtrl.text.trim() : (_selectedProvince?.formattedName ?? '');
    String kabupaten = _manualLocation ? _kabupatenManualCtrl.text.trim() : (_selectedRegency?.formattedName ?? '');
    String kecamatan = _manualLocation ? _kecamatanManualCtrl.text.trim() : (_selectedDistrict?.formattedName ?? '');

    // Bersihkan prefix Kabupaten/Kota agar serasi
    if (kabupaten.toUpperCase().startsWith('KABUPATEN ')) {
      kabupaten = kabupaten.substring(10).trim();
    } else if (kabupaten.toUpperCase().startsWith('KOTA ')) {
      kabupaten = kabupaten.substring(5).trim();
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        if (widget.initialItem != null) 'id': widget.initialItem!.id,
        'evaluator': _evaluatorCtrl.text.trim(),
        'nama_perusahaan': _perusahaanCtrl.text.trim(),
        'jenis_komoditas': _jenisKomoditas,
        'no_sk_iup': _noSkIupCtrl.text.trim(),
        'masa_berlaku': _masaBerlakuCtrl.text.trim(),
        'luas_wiup': double.tryParse(_luasWiupCtrl.text) ?? 0.0,
        'komoditas': _komoditasCtrl.text.trim(),
        'kecamatan': kecamatan,
        'kabupaten': kabupaten,
        'provinsi': provinsi,
        'luas_perluasan_dimohon': double.tryParse(_luasDimohonCtrl.text) ?? 0.0,
        'surat_permohonan_nomor': _suratPerusahaanNoCtrl.text.trim(),
        'surat_permohonan_tanggal': _suratPerusahaanTglCtrl.text.trim().isEmpty ? null : _suratPerusahaanTglCtrl.text.trim(),
        'tgl_masuk_djmb': _tglMasukDjmbCtrl.text.trim().isEmpty ? null : _tglMasukDjmbCtrl.text.trim(),
        'tgl_masuk_dbt': _tglMasukDbtCtrl.text.trim().isEmpty ? null : _tglMasukDbtCtrl.text.trim(),
        'tgl_masuk_sdkm': _tglMasukSdkmCtrl.text.trim().isEmpty ? null : _tglMasukSdkmCtrl.text.trim(),
        'nd_dbt_permohonan_nomor': _ndDbtPermohonanNoCtrl.text.trim(),
        'nd_dbt_permohonan_tanggal': _ndDbtPermohonanTglCtrl.text.trim(),
        'nd_dbt_km_nomor': _ndDbtKmNoCtrl.text.trim(),
        'nd_dbt_km_tanggal': _ndDbtKmTglCtrl.text.trim().isEmpty ? null : _ndDbtKmTglCtrl.text.trim(),
        'nd_dbp_pw_nomor': _ndDbpPwNoCtrl.text.trim(),
        'nd_dbp_pw_tanggal': _ndDbpPwTglCtrl.text.trim().isEmpty ? null : _ndDbpPwTglCtrl.text.trim(),
        'nd_dbm_pe_nomor': _ndDbmPeNoCtrl.text.trim(),
        'nd_dbm_pe_tanggal': _ndDbmPeTglCtrl.text.trim().isEmpty ? null : _ndDbmPeTglCtrl.text.trim(),
        'surat_djb_nomor': _suratDjbNoCtrl.text.trim(),
        'surat_djb_tanggal': _suratDjbTglCtrl.text.trim().isEmpty ? null : _suratDjbTglCtrl.text.trim(),
        'catatan_evaluasi': _catatanCtrl.text.trim(),
        'status': _status,
        'surat_mem_nomor': _suratMemNoCtrl.text.trim(),
        'surat_mem_tanggal': _suratMemTglCtrl.text.trim().isEmpty ? null : _suratMemTglCtrl.text.trim(),
        'sk_perluasan_nomor': _skPerluasanNoCtrl.text.trim(),
        'sk_perluasan_tanggal': _skPerluasanTglCtrl.text.trim().isEmpty ? null : _skPerluasanTglCtrl.text.trim(),
        'luas_disetujui': double.tryParse(_luasDisetujuiCtrl.text) ?? 0.0,
        'kdi_nilai_rp': double.tryParse(_kdiNilaiCtrl.text) ?? 0.0,
        'kdi_status_bayar': _kdiStatusBayar,
        'total_luas_sekarang': double.tryParse(_totalLuasSekarangCtrl.text) ?? 0.0,
      };

      await EvaluasiDokumenService.saveRkpw(payload, isEdit: widget.initialItem != null);
      if (!mounted) return;

      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialItem != null ? 'Data RKPW berhasil diperbarui' : 'Data permohonan RKPW berhasil ditambahkan'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialItem != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description, color: Color(0xFFFBBF24), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Dokumen Perluasan WIUP/WIUPK (RKPW)' : 'Tambah Permohonan Dokumen RKPW',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SEKSI 1: IDENTITAS UTAMA
                      _buildSectionHeader(Icons.business, '1. Identitas Perusahaan & Evaluator'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _perusahaanCtrl,
                                  label: 'Nama Perusahaan *',
                                  hint: 'Ketik nama atau pilih dari database',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.manage_search, color: Color(0xFF1E3A8A)),
                                    tooltip: 'Pilih dari Database Mineral / Batubara',
                                    onPressed: _openCompanyPicker,
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: _openCompanyPicker,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search, size: 13, color: Color(0xFF1E3A8A)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Pilih dari Database Mineral & Batubara',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _evaluatorCtrl,
                              label: 'Nama Evaluator',
                              hint: 'Nama petugas evaluator',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'Jenis Komoditas',
                              value: _jenisKomoditas,
                              items: const ['Mineral', 'Batubara'],
                              onChanged: (v) => setState(() => _jenisKomoditas = v ?? 'Mineral'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _komoditasCtrl,
                              label: 'Komoditas Spesifik',
                              hint: 'Contoh: Nikel, Emas, Batubara',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _noSkIupCtrl,
                              label: 'Nomor SK IUP',
                              hint: 'Contoh: 41/1/IUP/PMA/2020',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _masaBerlakuCtrl,
                              label: 'Masa Berlaku',
                              hint: 'Contoh: 8/2/2010 - 8/2/2030',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _luasWiupCtrl,
                              label: 'Luas WIUP Awal (Ha)',
                              hint: 'Contoh: 4247',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // SEKSI 2: LOKASI TAMBANG (DROPDOWN OTOMATIS)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(Icons.place, '2. Lokasi Tambang (Dropdown Otomatis)'),
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: Icon(_manualLocation ? Icons.touch_app : Icons.edit, size: 14),
                            label: Text(_manualLocation ? 'Gunakan Dropdown API' : 'Ketik Manual', style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() => _manualLocation = !_manualLocation),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (!_manualLocation) ...[
                        Row(
                          children: [
                            // 1. Dropdown Provinsi
                            Expanded(
                              child: _buildWilayahDropdown(
                                label: 'Provinsi',
                                hint: 'Pilih Provinsi...',
                                isLoading: _isLoadingProvinces,
                                items: _provinces,
                                selectedItem: _selectedProvince,
                                onChanged: _onProvinceChanged,
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 2. Dropdown Kabupaten
                            Expanded(
                              child: _buildWilayahDropdown(
                                label: 'Kabupaten/Kota',
                                hint: _selectedProvince == null ? 'Pilih Provinsi dulu' : 'Pilih Kabupaten/Kota...',
                                isLoading: _isLoadingRegencies,
                                items: _regencies,
                                selectedItem: _selectedRegency,
                                onChanged: _onRegencyChanged,
                                enabled: _selectedProvince != null,
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 3. Dropdown Kecamatan
                            Expanded(
                              child: _buildWilayahDropdown(
                                label: 'Kecamatan',
                                hint: _selectedRegency == null ? 'Pilih Kabupaten dulu' : 'Pilih Kecamatan...',
                                isLoading: _isLoadingDistricts,
                                items: _districts,
                                selectedItem: _selectedDistrict,
                                onChanged: (dist) => setState(() => _selectedDistrict = dist),
                                enabled: _selectedRegency != null,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _provinsiManualCtrl, label: 'Provinsi', hint: 'Provinsi')),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTextField(controller: _kabupatenManualCtrl, label: 'Kabupaten', hint: 'Kabupaten')),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTextField(controller: _kecamatanManualCtrl, label: 'Kecamatan', hint: 'Kecamatan')),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      // SEKSI 3: PERMOHONAN & TRACKING SURAT MASUK
                      _buildSectionHeader(Icons.mark_email_read, '3. Permohonan Perluasan & Surat Masuk'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _luasDimohonCtrl,
                              label: 'Luas Perluasan Dimohon (Ha)',
                              hint: 'Contoh: 957',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _suratPerusahaanNoCtrl,
                              label: 'Nomor Surat Perusahaan',
                              hint: 'Contoh: 475/TBP/XII/2022',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              controller: _suratPerusahaanTglCtrl,
                              label: 'Tgl Surat Perusahaan',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDateField(controller: _tglMasukDjmbCtrl, label: 'Tgl Masuk DJMB')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDateField(controller: _tglMasukDbtCtrl, label: 'Tgl Masuk DBT')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDateField(controller: _tglMasukSdkmCtrl, label: 'Tgl Masuk SDKM')),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // SEKSI 4: NOTA DINAS INTERNAL & EVALUASI
                      _buildSectionHeader(Icons.folder_shared, '4. Disposisi Nota Dinas & Evaluasi Internal'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _ndDbtPermohonanNoCtrl,
                              label: 'ND DBT Permohonan Evaluasi',
                              hint: 'Nomor ND ke DBP & DBM/DBB',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _ndDbtPermohonanTglCtrl,
                              label: 'Tgl ND Permohonan',
                              hint: 'e.g. 2023-01-06',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _ndDbtKmNoCtrl, label: 'ND DBT (Hasil Evaluasi KM)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateField(controller: _ndDbtKmTglCtrl, label: 'Tgl ND KM')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _ndDbpPwNoCtrl, label: 'ND DBP (Hasil Evaluasi PW)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateField(controller: _ndDbpPwTglCtrl, label: 'Tgl ND PW')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _ndDbmPeNoCtrl, label: 'ND DBM/DBB (Hasil Evaluasi PE)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateField(controller: _ndDbmPeTglCtrl, label: 'Tgl ND PE')),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // SEKSI 5: KEPUTUSAN & STATUS
                      _buildSectionHeader(Icons.assignment_turned_in, '5. Keputusan, SK Perluasan & KDI'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _suratDjbNoCtrl, label: 'Surat DJB (Kompilasi KM PE PW)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateField(controller: _suratDjbTglCtrl, label: 'Tgl Surat DJB')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Status Pengajuan',
                              value: _status,
                              items: const ['Proses', 'Disetujui', 'Ditolak'],
                              onChanged: (v) => setState(() => _status = v ?? 'Proses'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _catatanCtrl,
                        label: 'Catatan Hasil Evaluasi',
                        hint: 'Tuliskan catatan teknis atau alasan jika permohonan ditolak...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _suratMemNoCtrl, label: 'Surat Menteri ESDM (MEM)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateField(controller: _suratMemTglCtrl, label: 'Tgl Surat MEM')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _skPerluasanNoCtrl, label: 'Nomor SK Perluasan')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDateField(controller: _skPerluasanTglCtrl, label: 'Tgl SK Perluasan')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildTextField(controller: _luasDisetujuiCtrl, label: 'Luas Disetujui (Ha)', keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _kdiNilaiCtrl, label: 'Nilai KDI (Rp)', keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Status KDI',
                              value: _kdiStatusBayar,
                              items: const ['Lunas', 'Belum'],
                              onChanged: (v) => setState(() => _kdiStatusBayar = v ?? 'Belum'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildTextField(controller: _totalLuasSekarangCtrl, label: 'Total Luas Sekarang (Ha)', keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Menyimpan...' : (isEdit ? 'Simpan Perubahan' : 'Simpan Data RKPW')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.contains(value) ? value : null,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildWilayahDropdown({
    required String label,
    required String hint,
    required bool isLoading,
    required List<WilayahItem> items,
    required WilayahItem? selectedItem,
    required ValueChanged<WilayahItem?> onChanged,
    bool enabled = true,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        hintText: isLoading ? 'Memuat data...' : hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        suffixIcon: isLoading
            ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WilayahItem>(
          isExpanded: true,
          value: items.contains(selectedItem) ? selectedItem : null,
          hint: Text(isLoading ? 'Memuat data...' : hint, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item.formattedName, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: enabled && !isLoading ? onChanged : null,
        ),
      ),
    );
  }
}

