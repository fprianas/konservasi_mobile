<?php
/**
 * REST API Pelaporan Mineral untuk Aplikasi Flutter Mobile
 * Endpoint: /public_html/v2/mineral/api_mineral.php
 */

// Header CORS & JSON
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Suppress error display agar tidak merusak format JSON
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_reporting(E_ALL);

// Koneksi Database
require_once __DIR__ . '/koneksi.php';

// Safe helper functions
if (!function_exists('escapeString')) {
    function escapeString($val) {
        global $koneksi, $conn, $db;
        $link = $koneksi ?? $conn ?? $db ?? null;
        if ($link && is_object($link)) {
            return mysqli_real_escape_string($link, trim((string)$val));
        }
        return addslashes(trim((string)$val));
    }
}

if (!function_exists('executeQuery')) {
    function executeQuery($sql) {
        global $koneksi, $conn, $db;
        $link = $koneksi ?? $conn ?? $db ?? null;
        if ($link && is_object($link)) {
            return mysqli_query($link, $sql);
        }
        return false;
    }
}

$action = $_GET['action'] ?? $_POST['action'] ?? 'list';

try {
    switch ($action) {
        case 'filters':
            handleGetFilters();
            break;

        case 'summary':
        case 'stats':
            handleGetSummary();
            break;

        case 'rekap_provinsi':
            handleGetRekapProvinsi();
            break;

        case 'recent_submissions':
        case 'recent_inputs':
            handleGetRecentSubmissions();
            break;

        case 'detail':
            handleGetDetail();
            break;

        case 'search_companies':
            handleSearchCompanies();
            break;

        case 'company_history':
            handleGetCompanyHistory();
            break;

        case 'analysis':
        case 'trend':
            handleGetAnalysis();
            break;

        case 'list':
        default:
            handleGetList();
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server: ' . $e->getMessage()
    ]);
}

/**
 * Mendapatkan opsi filter (Provinsi, Tahun, Triwulan, Komoditas, Jenis Izin)
 */
function handleGetFilters() {
    $provinsi_list = [];
    $sql_prov = "SELECT DISTINCT provinsi as nama_provinsi FROM vlaporan_mineral WHERE provinsi IS NOT NULL AND provinsi != '' ORDER BY provinsi ASC";
    $res_prov = executeQuery($sql_prov);
    if ($res_prov) {
        while ($row = $res_prov->fetch_assoc()) {
            $provinsi_list[] = $row['nama_provinsi'];
        }
    }

    $tahun_list = [];
    $sql_tahun = "SELECT DISTINCT tahun FROM vlaporan_mineral WHERE tahun IS NOT NULL AND tahun != '' ORDER BY tahun DESC";
    $res_tahun = executeQuery($sql_tahun);
    if ($res_tahun) {
        while ($row = $res_tahun->fetch_assoc()) {
            $tahun_list[] = $row['tahun'];
        }
    }

    $komoditas_list = [];
    $sql_komoditas = "SELECT DISTINCT komoditas_mineral FROM vlaporan_mineral WHERE komoditas_mineral IS NOT NULL AND komoditas_mineral != '' ORDER BY komoditas_mineral ASC";
    $res_komoditas = executeQuery($sql_komoditas);
    if ($res_komoditas) {
        while ($row = $res_komoditas->fetch_assoc()) {
            $komoditas_list[] = $row['komoditas_mineral'];
        }
    }

    $perizinan_list = [];
    $sql_izin = "SELECT DISTINCT jenis_perizinan FROM vlaporan_mineral WHERE jenis_perizinan IS NOT NULL AND jenis_perizinan != '' AND jenis_perizinan != '-' ORDER BY jenis_perizinan ASC";
    $res_izin = executeQuery($sql_izin);
    if ($res_izin) {
        while ($row = $res_izin->fetch_assoc()) {
            $perizinan_list[] = $row['jenis_perizinan'];
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'provinsi' => $provinsi_list,
            'tahun' => $tahun_list,
            'triwulan' => ['Triwulan I', 'Triwulan II', 'Triwulan III', 'Triwulan IV'],
            'komoditas' => $komoditas_list,
            'jenis_perizinan' => $perizinan_list,
            'status_produksi' => [
                ['label' => 'Sudah Produksi', 'value' => 'sudah'],
                ['label' => 'Belum Produksi', 'value' => 'belum']
            ]
        ]
    ]);
}

/**
 * Mendapatkan ringkasan statistik KPI Mineral
 */
function handleGetSummary() {
    $provinsi = escapeString($_GET['provinsi'] ?? '');
    $tahun = escapeString($_GET['tahun'] ?? '');
    $triwulan = escapeString($_GET['triwulan'] ?? '');
    $jenis_perizinan = escapeString($_GET['jenis_perizinan'] ?? '');

    // 1. Total Perusahaan Terdaftar
    $sql_total = "SELECT COUNT(DISTINCT pm.sk_iup) as total 
                  FROM perusahaan_mineral pm 
                  LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id 
                  WHERE pm.sk_iup IS NOT NULL AND pm.sk_iup != ''";
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $sql_total .= " AND prov.nama_provinsi = '$provinsi'";
    }
    $res_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($res_total && $row = $res_total->fetch_assoc()) {
        $total_perusahaan = (int)$row['total'];
    }

    // Fallback jika perusahaan_mineral kosong
    if ($total_perusahaan === 0) {
        $sql_fb = "SELECT COUNT(DISTINCT sk_iup) as total FROM vlaporan_mineral";
        if (!empty($provinsi) && $provinsi !== 'semua') {
            $sql_fb .= " WHERE provinsi = '$provinsi'";
        }
        $res_fb = executeQuery($sql_fb);
        if ($res_fb && $row_fb = $res_fb->fetch_assoc()) {
            $total_perusahaan = (int)$row_fb['total'];
        }
    }

    // 2. Total Laporan & Perusahaan Sudah Lapor
    $where_lap = ["provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_lap[] = "provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_pelaporan = '$tw_val'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where_lap[] = "jenis_perizinan = '$jenis_perizinan'";
    }

    $where_lap_sql = implode(' AND ', $where_lap);
    $sql_lap = "SELECT 
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_sudah_lapor
                FROM vlaporan_mineral
                WHERE $where_lap_sql";
    $res_lap = executeQuery($sql_lap);
    $total_laporan = 0;
    $perusahaan_sudah_lapor = 0;
    if ($res_lap && $row = $res_lap->fetch_assoc()) {
        $total_laporan = (int)$row['total_laporan'];
        $perusahaan_sudah_lapor = (int)$row['perusahaan_sudah_lapor'];
    }

    $belum_lapor = max(0, $total_perusahaan - $perusahaan_sudah_lapor);
    $kepatuhan = $total_perusahaan > 0 ? round(($perusahaan_sudah_lapor * 100.0) / $total_perusahaan, 2) : 0;

    echo json_encode([
        'success' => true,
        'data' => [
            'total_perusahaan' => $total_perusahaan,
            'sudah_lapor' => $perusahaan_sudah_lapor,
            'belum_lapor' => $belum_lapor,
            'total_laporan_masuk' => $total_laporan,
            'persentase_kepatuhan' => $kepatuhan
        ]
    ]);
}

/**
 * Mendapatkan daftar laporan mineral terpaginasi & terfilter
 */
function handleGetList() {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $limit = max(5, min(100, (int)($_GET['limit'] ?? 15)));
    $offset = ($page - 1) * $limit;

    $search = escapeString($_GET['search'] ?? '');
    $provinsi = escapeString($_GET['provinsi'] ?? '');
    $tahun = escapeString($_GET['tahun'] ?? '');
    $triwulan = escapeString($_GET['triwulan'] ?? '');
    $komoditas = escapeString($_GET['komoditas'] ?? '');
    $jenis_perizinan = escapeString($_GET['jenis_perizinan'] ?? '');
    $status_produksi = escapeString($_GET['status_produksi'] ?? '');

    $where = ["provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];

    if (!empty($search)) {
        $where[] = "(nama_perusahaan LIKE '%$search%' OR sk_iup LIKE '%$search%')";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where[] = "waktu_pelaporan = '$tw_val'";
    }
    if (!empty($komoditas) && $komoditas !== 'semua') {
        $where[] = "komoditas_mineral = '$komoditas'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where[] = "jenis_perizinan = '$jenis_perizinan'";
    }
    if (!empty($status_produksi)) {
        if ($status_produksi === 'sudah' || $status_produksi === 'P') {
            $where[] = "(sistem_penambangan IS NOT NULL AND LOWER(sistem_penambangan) NOT LIKE '%belum produksi%')";
        } elseif ($status_produksi === 'belum' || $status_produksi === 'BP') {
            $where[] = "LOWER(sistem_penambangan) LIKE '%belum produksi%'";
        }
    }

    $where_sql = implode(' AND ', $where);

    // Hitung total data
    $sql_count = "SELECT COUNT(*) as total FROM vlaporan_mineral WHERE $where_sql";
    $res_count = executeQuery($sql_count);
    $total_records = 0;
    if ($res_count && $row = $res_count->fetch_assoc()) {
        $total_records = (int)$row['total'];
    }

    $total_pages = ceil($total_records / $limit);

    // Ambil data halaman ini
    $sql_data = "SELECT * FROM vlaporan_mineral 
                 WHERE $where_sql 
                 ORDER BY id DESC 
                 LIMIT $offset, $limit";
    $res_data = executeQuery($sql_data);

    $items = [];
    if ($res_data) {
        while ($row = $res_data->fetch_assoc()) {
            $sistem = strtolower($row['sistem_penambangan'] ?? '');
            $is_produksi = !empty($sistem) && strpos($sistem, 'belum produksi') === false;

            $items[] = [
                'id' => (int)($row['id'] ?? 0),
                'nama_perusahaan' => $row['nama_perusahaan'] ?? '-',
                'sk_iup' => $row['sk_iup'] ?? '-',
                'provinsi' => $row['provinsi'] ?? '-',
                'tahun' => $row['tahun'] ?? '-',
                'triwulan' => $row['waktu_pelaporan'] ?? '-',
                'komoditas_mineral' => $row['komoditas_mineral'] ?? '-',
                'jenis_perizinan' => $row['jenis_perizinan'] ?? '-',
                'sistem_penambangan' => $row['sistem_penambangan'] ?? '-',
                'status_produksi' => $is_produksi ? 'Sudah Produksi' : 'Belum Produksi',
                'status_produksi_code' => $is_produksi ? 'P' : 'BP',
                'waktu_input' => $row['waktu_input'] ?? '-',

                // Metrik utama untuk kartu HP
                'metrics' => [
                    'mkr_kuantitas' => $row['mkr_kuantitas'] ?? '-',
                    'pmkr_volume' => $row['pmkr_volume'] ?? '-',
                    'cm_kuantitas' => $row['cm_kuantitas'] ?? '-',
                    'shp_kuantitas' => $row['shp_kuantitas'] ?? '-',
                    'cmtt_kuantitas' => $row['cmtt_kuantitas_cadangan'] ?? '-',
                    'rec_penambangan' => $row['recovery_penambangan_survey_2_3'] ?? $row['recovery_penambangan_truck_2_2'] ?? '-',
                    'rec_pengolahan' => $row['recovery_pemulihan_2_6'] ?? '-',
                ],

                // File lampiran (jika ada)
                'laporan_file' => !empty($row['laporan']) && $row['laporan'] !== '-' ? $row['laporan'] : null,
                'peta_file' => !empty($row['peta_konservasi']) && $row['peta_konservasi'] !== '-' ? $row['peta_konservasi'] : null,

                // Data lengkap untuk modal detail tap-to-expand
                'raw_details' => $row
            ];
        }
    }

    // Grand Total untuk seluruh data mineral terfilter
    $sql_totals = "SELECT 
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(mkr_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_mkr_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(pmkr_volume, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_pmkr_volume,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cm_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_cm_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(shp_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_shp_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cmtt_kuantitas_cadangan, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_cmtt_kuantitas
    FROM vlaporan_mineral WHERE $where_sql";

    $res_totals = executeQuery($sql_totals);
    $totals = [
        'mkr_kuantitas' => 0.0,
        'pmkr_volume' => 0.0,
        'cm_kuantitas' => 0.0,
        'shp_kuantitas' => 0.0,
        'cmtt_kuantitas' => 0.0,
    ];
    if ($res_totals && $row_tot = $res_totals->fetch_assoc()) {
        $totals['mkr_kuantitas'] = (float)($row_tot['total_mkr_kuantitas'] ?? 0);
        $totals['pmkr_volume'] = (float)($row_tot['total_pmkr_volume'] ?? 0);
        $totals['cm_kuantitas'] = (float)($row_tot['total_cm_kuantitas'] ?? 0);
        $totals['shp_kuantitas'] = (float)($row_tot['total_shp_kuantitas'] ?? 0);
        $totals['cmtt_kuantitas'] = (float)($row_tot['total_cmtt_kuantitas'] ?? 0);
    }

    echo json_encode([
        'success' => true,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $limit,
            'total_records' => $total_records,
            'total_pages' => $total_pages,
            'has_more' => $page < $total_pages
        ],
        'totals' => $totals,
        'data' => $items
    ]);
}

/**
 * Mendapatkan detail lengkap 1 laporan mineral
 */
function handleGetDetail() {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        echo json_encode(['success' => false, 'message' => 'ID laporan tidak valid']);
        return;
    }

    $sql = "SELECT * FROM vlaporan_mineral WHERE id = $id LIMIT 1";
    $res = executeQuery($sql);
    if ($res && $row = $res->fetch_assoc()) {
        echo json_encode(['success' => true, 'data' => $row]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Data tidak ditemukan']);
    }
}

/**
 * Normalisasi format Triwulan
 */
function formatTriwulan($val) {
    switch (trim($val)) {
        case '1': return 'Triwulan I';
        case '2': return 'Triwulan II';
        case '3': return 'Triwulan III';
        case '4': return 'Triwulan IV';
        default: return $val;
    }
}

/**
 * Mendapatkan rekapitulasi data per provinsi sesuai tahun dan triwulan
 */
function handleGetRekapProvinsi() {
    $tahun = escapeString($_GET['tahun'] ?? '');
    $triwulan = escapeString($_GET['triwulan'] ?? '');
    $jenis_perizinan = escapeString($_GET['jenis_perizinan'] ?? '');

    // 1. Ambil total perusahaan terdaftar per provinsi
    // Catatan: relasi perusahaan_mineral ke provinsi_mineral adalah pm.id_provinsi = prov.id
    $sql_terdaftar = "SELECT 
                        TRIM(COALESCE(prov.nama_provinsi, 'Tidak Diketahui')) as nama_provinsi, 
                        COUNT(DISTINCT pm.sk_iup) as total 
                      FROM perusahaan_mineral pm 
                      LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id 
                      WHERE pm.sk_iup IS NOT NULL AND pm.sk_iup != ''
                      GROUP BY TRIM(COALESCE(prov.nama_provinsi, 'Tidak Diketahui'))";
    $res_terdaftar = executeQuery($sql_terdaftar);
    $map_provinsi = [];
    if ($res_terdaftar) {
        while ($row = $res_terdaftar->fetch_assoc()) {
            $prov = trim($row['nama_provinsi']);
            if (!empty($prov) && $prov !== 'Tidak Diketahui') {
                $map_provinsi[$prov] = [
                    'nama_provinsi' => $prov,
                    'total_perusahaan' => (int)$row['total'],
                    'total_laporan' => 0,
                    'sudah_lapor' => 0,
                    'belum_lapor' => (int)$row['total'],
                    'persentase_kepatuhan' => 0.0,
                ];
            }
        }
    }

    // 2. Ambil data laporan per provinsi sesuai filter tahun & triwulan
    $where_lap = ["provinsi IS NOT NULL", "provinsi != ''", "nama_perusahaan IS NOT NULL"];
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_pelaporan = '$tw_val'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where_lap[] = "jenis_perizinan = '$jenis_perizinan'";
    }
    $where_lap_sql = implode(' AND ', $where_lap);

    $sql_lap = "SELECT 
                    TRIM(provinsi) as nama_provinsi, 
                    COUNT(*) as total_laporan, 
                    COUNT(DISTINCT sk_iup) as sudah_lapor 
                FROM vlaporan_mineral 
                WHERE $where_lap_sql 
                GROUP BY TRIM(provinsi)";
    $res_lap = executeQuery($sql_lap);
    if ($res_lap) {
        while ($row = $res_lap->fetch_assoc()) {
            $prov = trim($row['nama_provinsi']);
            if (empty($prov)) continue;

            $sudah = (int)$row['sudah_lapor'];
            $laporan = (int)$row['total_laporan'];

            if (!isset($map_provinsi[$prov])) {
                $map_provinsi[$prov] = [
                    'nama_provinsi' => $prov,
                    'total_perusahaan' => $sudah,
                    'total_laporan' => $laporan,
                    'sudah_lapor' => $sudah,
                    'belum_lapor' => 0,
                    'persentase_kepatuhan' => 100.0,
                ];
            } else {
                $total = max($map_provinsi[$prov]['total_perusahaan'], $sudah);
                $map_provinsi[$prov]['total_perusahaan'] = $total;
                $map_provinsi[$prov]['total_laporan'] = $laporan;
                $map_provinsi[$prov]['sudah_lapor'] = $sudah;
                $map_provinsi[$prov]['belum_lapor'] = max(0, $total - $sudah);
            }
        }
    }

    // 3. Hitung persentase kepatuhan akhir
    $data = [];
    foreach ($map_provinsi as $item) {
        $total = $item['total_perusahaan'];
        $sudah = $item['sudah_lapor'];
        $kepatuhan = $total > 0 ? round(($sudah * 100.0) / $total, 2) : 0.0;
        if ($kepatuhan > 100.0) $kepatuhan = 100.0;

        $item['persentase_kepatuhan'] = $kepatuhan;
        $data[] = $item;
    }

    // Urutkan berdasarkan persentase kepatuhan DESC, lalu total perusahaan DESC
    usort($data, function($a, $b) {
        if ($b['persentase_kepatuhan'] != $a['persentase_kepatuhan']) {
            return ($b['persentase_kepatuhan'] > $a['persentase_kepatuhan']) ? 1 : -1;
        }
        return $b['total_perusahaan'] - $a['total_perusahaan'];
    });

    echo json_encode([
        'success' => true,
        'data' => $data
    ]);
}

/**
 * Mendapatkan daftar perusahaan yang baru mengisi data
 * Prioritas: Hari Ini -> Minggu Ini -> Bulan Ini -> Kosong
 */
function handleGetRecentSubmissions() {
    date_default_timezone_set('Asia/Jakarta');
    $today = date('Y-m-d');
    $start_week = date('Y-m-d', strtotime('monday this week'));
    $start_month = date('Y-m-01');

    $fetchItems = function($startDate, $endDate) {
        $sql = "SELECT id, nama_perusahaan, provinsi, waktu_pelaporan, tahun, waktu_input 
                FROM vlaporan_mineral 
                WHERE waktu_input IS NOT NULL 
                  AND waktu_input != '' 
                  AND waktu_input != '-'
                  AND DATE(waktu_input) >= '$startDate' 
                  AND DATE(waktu_input) <= '$endDate'
                ORDER BY waktu_input DESC, id DESC 
                LIMIT 40";
        $res = executeQuery($sql);
        $items = [];
        if ($res) {
            while ($row = $res->fetch_assoc()) {
                $items[] = [
                    'id' => (int)($row['id'] ?? 0),
                    'nama_perusahaan' => trim($row['nama_perusahaan'] ?? ''),
                    'provinsi' => trim($row['provinsi'] ?? '-'),
                    'triwulan' => trim($row['waktu_pelaporan'] ?? '-'),
                    'tahun' => trim($row['tahun'] ?? '-'),
                    'waktu_input' => trim($row['waktu_input'] ?? '-'),
                ];
            }
        }
        return $items;
    };

    // 1. Hari Ini
    $items = $fetchItems($today, $today);
    if (!empty($items)) {
        echo json_encode([
            'success' => true,
            'period' => 'today',
            'label' => 'Hari Ini',
            'title' => 'Perusahaan yang mengisi data hari ini',
            'total' => count($items),
            'items' => $items
        ]);
        return;
    }

    // 2. Minggu Ini
    $items = $fetchItems($start_week, $today);
    if (!empty($items)) {
        echo json_encode([
            'success' => true,
            'period' => 'week',
            'label' => 'Minggu Ini',
            'title' => 'Perusahaan yang mengisi data minggu ini',
            'total' => count($items),
            'items' => $items
        ]);
        return;
    }

    // 3. Bulan Ini
    $items = $fetchItems($start_month, $today);
    if (!empty($items)) {
        echo json_encode([
            'success' => true,
            'period' => 'month',
            'label' => 'Bulan Ini',
            'title' => 'Perusahaan yang mengisi data bulan ini',
            'total' => count($items),
            'items' => $items
        ]);
        return;
    }

    // 4. Belum ada input bulan ini
    echo json_encode([
        'success' => true,
        'period' => 'empty',
        'label' => 'Bulan Ini',
        'title' => 'Belum ada input bulan ini',
        'total' => 0,
        'items' => []
    ]);
}

/**
 * Mendapatkan ringkasan internal summary untuk kalkulasi trend mineral
 */
function getSummaryInternalMineral($tahun = '', $triwulan = '', $provinsi = '') {
    $where_lap = ["provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_lap[] = "provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_pelaporan = '$tw_val'";
    }

    $where_lap_sql = implode(' AND ', $where_lap);
    $sql_lap = "SELECT 
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_sudah_lapor
                FROM vlaporan_mineral
                WHERE $where_lap_sql";
    $res_lap = executeQuery($sql_lap);
    $total_laporan = 0;
    $perusahaan_sudah_lapor = 0;
    if ($res_lap && $row = $res_lap->fetch_assoc()) {
        $total_laporan = (int)$row['total_laporan'];
        $perusahaan_sudah_lapor = (int)$row['perusahaan_sudah_lapor'];
    }

    $sql_total = "SELECT COUNT(DISTINCT pm.sk_iup) as total 
                  FROM perusahaan_mineral pm 
                  LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id 
                  WHERE pm.sk_iup IS NOT NULL AND pm.sk_iup != ''";
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $sql_total .= " AND prov.nama_provinsi = '$provinsi'";
    }
    $res_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($res_total && $row_tot = $res_total->fetch_assoc()) {
        $total_perusahaan = (int)$row_tot['total'];
    }
    if ($total_perusahaan === 0) {
        $sql_fb = "SELECT COUNT(DISTINCT sk_iup) as total FROM vlaporan_mineral";
        if (!empty($provinsi) && $provinsi !== 'semua') {
            $sql_fb .= " WHERE provinsi = '$provinsi'";
        }
        $res_fb = executeQuery($sql_fb);
        if ($res_fb && $row_fb = $res_fb->fetch_assoc()) {
            $total_perusahaan = (int)$row_fb['total'];
        }
    }
    if ($total_perusahaan === 0) {
        $total_perusahaan = max($perusahaan_sudah_lapor, 1);
    }

    $kepatuhan = $total_perusahaan > 0 ? round(($perusahaan_sudah_lapor * 100.0) / $total_perusahaan, 2) : 0.0;

    return [
        'total_perusahaan' => $total_perusahaan,
        'sudah_lapor' => $perusahaan_sudah_lapor,
        'total_laporan_masuk' => $total_laporan,
        'persentase_kepatuhan' => $kepatuhan
    ];
}

/**
 * Mencari daftar perusahaan mineral unik beserta ringkasan status & total laporan
 */
function handleSearchCompanies() {
    $q = escapeString($_GET['q'] ?? $_GET['query'] ?? $_GET['search'] ?? '');
    $limit = max(5, min(100, (int)($_GET['limit'] ?? 40)));

    $where = ["provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL", "nama_perusahaan != ''"];
    if (!empty($q)) {
        $where[] = "(nama_perusahaan LIKE '%$q%' OR sk_iup LIKE '%$q%' OR provinsi LIKE '%$q%')";
    }
    $where_sql = implode(' AND ', $where);

    $sql = "SELECT 
                sk_iup,
                nama_perusahaan,
                provinsi,
                jenis_perizinan,
                komoditas_mineral,
                sistem_penambangan,
                MAX(id) as latest_id,
                MAX(tahun) as latest_tahun,
                MAX(waktu_pelaporan) as latest_triwulan,
                MAX(waktu_input) as latest_waktu_input,
                COUNT(*) as total_reports
            FROM vlaporan_mineral
            WHERE $where_sql
            GROUP BY sk_iup, nama_perusahaan, provinsi, jenis_perizinan, komoditas_mineral, sistem_penambangan
            ORDER BY nama_perusahaan ASC
            LIMIT $limit";

    $res = executeQuery($sql);
    $data = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $sistem = strtolower($row['sistem_penambangan'] ?? '');
            $is_produksi = !empty($sistem) && strpos($sistem, 'belum produksi') === false;

            $data[] = [
                'nama_perusahaan' => $row['nama_perusahaan'],
                'sk_iup' => $row['sk_iup'],
                'provinsi' => $row['provinsi'],
                'jenis_perizinan' => $row['jenis_perizinan'] ?? '-',
                'komoditas' => $row['komoditas_mineral'] ?? 'Mineral',
                'sektor' => 'mineral',
                'latest_status_produksi' => $is_produksi ? 'Sudah Produksi' : 'Belum Produksi',
                'latest_status_produksi_code' => $is_produksi ? 'P' : 'BP',
                'latest_tahun' => $row['latest_tahun'] ?? '-',
                'latest_triwulan' => $row['latest_triwulan'] ?? '-',
                'latest_waktu_input' => $row['latest_waktu_input'] ?? '-',
                'total_reports' => (int)$row['total_reports']
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'total' => count($data),
        'data' => $data
    ]);
}

/**
 * Mendapatkan histori pelaporan lengkap untuk 1 perusahaan mineral
 */
function handleGetCompanyHistory() {
    $sk_iup = escapeString($_GET['sk_iup'] ?? '');
    $nama = escapeString($_GET['nama_perusahaan'] ?? $_GET['nama'] ?? '');

    if (empty($sk_iup) && empty($nama)) {
        echo json_encode(['success' => false, 'message' => 'Parameter sk_iup atau nama_perusahaan diperlukan']);
        return;
    }

    $where = [];
    if (!empty($sk_iup) && $sk_iup !== '-') {
        $where[] = "sk_iup = '$sk_iup'";
    } else {
        $where[] = "nama_perusahaan = '$nama'";
    }
    $where_sql = implode(' AND ', $where);

    $sql = "SELECT * FROM vlaporan_mineral WHERE $where_sql ORDER BY tahun DESC, id DESC";
    $res = executeQuery($sql);
    $items = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $sistem = strtolower($row['sistem_penambangan'] ?? '');
            $is_produksi = !empty($sistem) && strpos($sistem, 'belum produksi') === false;

            $items[] = [
                'id' => (int)($row['id'] ?? 0),
                'nama_perusahaan' => $row['nama_perusahaan'] ?? '-',
                'sk_iup' => $row['sk_iup'] ?? '-',
                'provinsi' => $row['provinsi'] ?? '-',
                'tahun' => $row['tahun'] ?? '-',
                'triwulan' => $row['waktu_pelaporan'] ?? '-',
                'jenis_perizinan' => $row['jenis_perizinan'] ?? '-',
                'sistem_penambangan' => $row['sistem_penambangan'] ?? '-',
                'status_produksi' => $is_produksi ? 'Sudah Produksi' : 'Belum Produksi',
                'status_produksi_code' => $is_produksi ? 'P' : 'BP',
                'waktu_input' => $row['waktu_input'] ?? '-',
                'komoditas' => $row['komoditas_mineral'] ?? 'Mineral',
                'metrics' => [
                    'mkr_kuantitas' => $row['mkr_kuantitas'] ?? '-',
                    'pmkr_volume' => $row['pmkr_volume'] ?? '-',
                    'cm_kuantitas' => $row['cm_kuantitas'] ?? '-',
                    'shp_kuantitas' => $row['shp_kuantitas'] ?? '-',
                    'cmtt_kuantitas' => $row['cmtt_kuantitas_cadangan'] ?? '-',
                    'rec_penambangan' => $row['recovery_penambangan_survey_2_3'] ?? $row['recovery_penambangan_truck_2_2'] ?? '-',
                    'rec_pengolahan' => $row['recovery_pemulihan_2_6'] ?? '-',
                ],
                'laporan_file' => !empty($row['laporan']) && $row['laporan'] !== '-' ? $row['laporan'] : null,
                'peta_file' => !empty($row['peta']) && $row['peta'] !== '-' ? $row['peta'] : null,
                'raw_details' => $row
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'total' => count($items),
        'data' => $items
    ]);
}

/**
 * Analisis trend kepatuhan (kenaikan/penurunan) & analisis khusus mineral
 */
function handleGetAnalysis() {
    $tahun_curr = escapeString($_GET['tahun_current'] ?? $_GET['tahun'] ?? '');
    $triwulan_curr = escapeString($_GET['triwulan_current'] ?? $_GET['triwulan'] ?? '');
    $tahun_prev = escapeString($_GET['tahun_prev'] ?? '');
    $triwulan_prev = escapeString($_GET['triwulan_prev'] ?? '');
    $provinsi = escapeString($_GET['provinsi'] ?? '');

    $s_curr = getSummaryInternalMineral($tahun_curr, $triwulan_curr, $provinsi);
    $s_prev = getSummaryInternalMineral($tahun_prev, $triwulan_prev, $provinsi);
    $delta_kepatuhan = round($s_curr['persentase_kepatuhan'] - $s_prev['persentase_kepatuhan'], 2);

    // Rekap Provinsi Current
    $sql_prov = "SELECT 
                    provinsi as nama_provinsi,
                    COUNT(DISTINCT sk_iup) as sudah_lapor,
                    COUNT(*) as total_laporan
                 FROM vlaporan_mineral
                 WHERE tahun = '$tahun_curr' AND waktu_pelaporan = '".formatTriwulan($triwulan_curr)."'
                 GROUP BY provinsi";
    $res_p_curr = executeQuery($sql_prov);
    $prov_curr = [];
    if ($res_p_curr) {
        while ($r = $res_p_curr->fetch_assoc()) {
            $prov_curr[strtolower(trim($r['nama_provinsi']))] = [
                'nama' => $r['nama_provinsi'],
                'sudah' => (int)$r['sudah_lapor'],
                'laporan' => (int)$r['total_laporan']
            ];
        }
    }

    // Rekap Provinsi Prev
    $sql_prov_prev = "SELECT 
                         provinsi as nama_provinsi,
                         COUNT(DISTINCT sk_iup) as sudah_lapor
                      FROM vlaporan_mineral
                      WHERE tahun = '$tahun_prev' AND waktu_pelaporan = '".formatTriwulan($triwulan_prev)."'
                      GROUP BY provinsi";
    $res_p_prev = executeQuery($sql_prov_prev);
    $prev_sudah_map = [];
    if ($res_p_prev) {
        while ($r = $res_p_prev->fetch_assoc()) {
            $prev_sudah_map[strtolower(trim($r['nama_provinsi']))] = (int)$r['sudah_lapor'];
        }
    }

    $province_trends = [];
    foreach ($prov_curr as $k => $c) {
        $prev_sudah = $prev_sudah_map[$k] ?? 0;
        $total_p = max($c['sudah'], $prev_sudah, 1);
        $curr_kep = round(($c['sudah'] * 100.0) / $total_p, 2);
        $prev_kep = round(($prev_sudah * 100.0) / $total_p, 2);
        $delta = round($curr_kep - $prev_kep, 2);

        $province_trends[] = [
            'nama_provinsi' => $c['nama'],
            'kepatuhan_current' => (float)$curr_kep,
            'kepatuhan_prev' => (float)$prev_kep,
            'delta' => (float)$delta,
            'total_perusahaan' => (int)$total_p,
            'sudah_lapor_current' => (int)$c['sudah'],
            'sudah_lapor_prev' => (int)$prev_sudah
        ];
    }

    usort($province_trends, function($a, $b) {
        return $b['delta'] <=> $a['delta'];
    });

    // Analisis Khusus
    $where_spec = ["provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_spec[] = "provinsi = '$provinsi'";
    }
    if (!empty($tahun_curr) && $tahun_curr !== 'semua') {
        $where_spec[] = "tahun = '$tahun_curr'";
    }
    if (!empty($triwulan_curr) && $triwulan_curr !== 'semua') {
        $where_spec[] = "waktu_pelaporan = '".formatTriwulan($triwulan_curr)."'";
    }
    $where_spec_sql = implode(' AND ', $where_spec);

    $sql_spec = "SELECT 
                    COUNT(*) as total_laporan,
                    SUM(CASE WHEN LOWER(COALESCE(sistem_penambangan, '')) NOT LIKE '%belum produksi%' THEN 1 ELSE 0 END) as total_produksi,
                    SUM(CASE WHEN LOWER(COALESCE(sistem_penambangan, '')) LIKE '%belum produksi%' THEN 1 ELSE 0 END) as total_belum_produksi,
                    SUM(CASE WHEN laporan IS NOT NULL AND laporan != '' AND laporan != '-' THEN 1 ELSE 0 END) as total_dokumen,
                    SUM(CASE WHEN peta IS NOT NULL AND peta != '' AND peta != '-' THEN 1 ELSE 0 END) as total_peta
                 FROM vlaporan_mineral
                 WHERE $where_spec_sql";
    $res_spec = executeQuery($sql_spec);
    $special = [
        'total_produksi' => 0,
        'total_belum_produksi' => 0,
        'persentase_produksi' => 0.0,
        'total_dengan_dokumen' => 0,
        'total_dengan_peta' => 0,
        'persentase_kelengkapan_dokumen' => 0.0,
    ];
    if ($res_spec && $r_sp = $res_spec->fetch_assoc()) {
        $tot = (int)$r_sp['total_laporan'];
        $prod = (int)$r_sp['total_produksi'];
        $dok = (int)$r_sp['total_dokumen'];
        $special['total_produksi'] = $prod;
        $special['total_belum_produksi'] = (int)$r_sp['total_belum_produksi'];
        $special['persentase_produksi'] = $tot > 0 ? round(($prod * 100.0) / $tot, 1) : 0.0;
        $special['total_dengan_dokumen'] = $dok;
        $special['total_dengan_peta'] = (int)$r_sp['total_peta'];
        $special['persentase_kelengkapan_dokumen'] = $tot > 0 ? round(($dok * 100.0) / $tot, 1) : 0.0;
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'tahun_current' => $tahun_curr,
            'triwulan_current' => $triwulan_curr,
            'tahun_prev' => $tahun_prev,
            'triwulan_prev' => $triwulan_prev,
            'selected_provinsi' => $provinsi,
            'kepatuhan_current' => (float)$s_curr['persentase_kepatuhan'],
            'kepatuhan_prev' => (float)$s_prev['persentase_kepatuhan'],
            'delta_kepatuhan' => (float)$delta_kepatuhan,
            'total_perusahaan' => (int)$s_curr['total_perusahaan'],
            'sudah_lapor_current' => (int)$s_curr['sudah_lapor'],
            'sudah_lapor_prev' => (int)$s_prev['sudah_lapor'],
            'total_laporan_current' => (int)$s_curr['total_laporan_masuk'],
            'total_laporan_prev' => (int)$s_prev['total_laporan_masuk'],
            'province_trends' => $province_trends,
            'special_analysis' => $special
        ]
    ]);
}




