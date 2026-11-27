<?php
/**
 * REST API Pelaporan Batubara untuk Aplikasi Flutter Mobile
 * Endpoint: /public_html/v2/api_batubara.php
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

        case 'companies_status':
            handleGetCompaniesStatus();
            break;

        case 'toggle_company_status':
            handleToggleCompanyStatus();
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
 * Mendapatkan opsi filter (Provinsi, Tahun, Triwulan, Jenis Izin)
 */
function handleGetFilters() {
    $provinsi_list = [];
    $sql_prov = "SELECT DISTINCT nama_provinsi FROM provinsi WHERE nama_provinsi IS NOT NULL AND nama_provinsi != '' ORDER BY nama_provinsi ASC";
    $res_prov = executeQuery($sql_prov);
    if ($res_prov) {
        while ($row = $res_prov->fetch_assoc()) {
            $provinsi_list[] = $row['nama_provinsi'];
        }
    }

    $tahun_list = [];
    $sql_tahun = "SELECT DISTINCT tahun_1_7 as tahun FROM vlaporan_batubara2 WHERE tahun_1_7 IS NOT NULL AND tahun_1_7 != '' ORDER BY tahun_1_7 DESC";
    $res_tahun = executeQuery($sql_tahun);
    if ($res_tahun) {
        while ($row = $res_tahun->fetch_assoc()) {
            $tahun_list[] = $row['tahun'];
        }
    }

    $perizinan_list = [];
    $sql_izin = "SELECT DISTINCT jenis_perizinan_1_1 as jenis_perizinan FROM vlaporan_batubara2 WHERE jenis_perizinan_1_1 IS NOT NULL AND jenis_perizinan_1_1 != '' AND jenis_perizinan_1_1 != '-' ORDER BY jenis_perizinan_1_1 ASC";
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
            'jenis_perizinan' => $perizinan_list,
            'status_produksi' => [
                ['label' => 'Sudah Produksi', 'value' => 'P'],
                ['label' => 'Belum Produksi', 'value' => 'BP']
            ]
        ]
    ]);
}

/**
 * Mendapatkan ringkasan statistik KPI
 */
function handleGetSummary() {
    $provinsi = escapeString($_GET['provinsi'] ?? '');
    $tahun = escapeString($_GET['tahun'] ?? '');
    $triwulan = escapeString($_GET['triwulan'] ?? '');
    $jenis_perizinan = escapeString($_GET['jenis_perizinan'] ?? '');

    // 1. Total Perusahaan Terdaftar (hanya yang aktif)
    $sql_total = "SELECT COUNT(DISTINCT pb.sk_iup) as total 
                  FROM perusahaan_batubara pb 
                  LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi 
                  WHERE pb.sk_iup IS NOT NULL AND pb.sk_iup != '' AND COALESCE(pb.is_active, 1) = 1";
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $sql_total .= " AND prov.nama_provinsi = '$provinsi'";
    }
    $res_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($res_total && $row = $res_total->fetch_assoc()) {
        $total_perusahaan = (int)$row['total'];
    }

    // 2. Total Laporan & Perusahaan Sudah Lapor (kecualikan perusahaan non-aktif)
    $where_lap = [
        "nama_provinsi IS NOT NULL",
        "nama_perusahaan IS NOT NULL",
        "sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')"
    ];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_lap[] = "nama_provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun_1_7 = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_perlaporan_laporan_1_6 = '$tw_val'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where_lap[] = "jenis_perizinan_1_1 = '$jenis_perizinan'";
    }

    $where_lap_sql = implode(' AND ', $where_lap);
    $sql_lap = "SELECT 
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_sudah_lapor
                FROM vlaporan_batubara2
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
 * Mendapatkan daftar laporan terpaginasi & terfilter
 */
function handleGetList() {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $limit = max(5, min(100, (int)($_GET['limit'] ?? 15)));
    $offset = ($page - 1) * $limit;

    $search = escapeString($_GET['search'] ?? '');
    $provinsi = escapeString($_GET['provinsi'] ?? '');
    $tahun = escapeString($_GET['tahun'] ?? '');
    $triwulan = escapeString($_GET['triwulan'] ?? '');
    $jenis_perizinan = escapeString($_GET['jenis_perizinan'] ?? '');
    $status_produksi = escapeString($_GET['status_produksi'] ?? '');

    $where = ["nama_provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];

    if (!empty($search)) {
        $where[] = "(nama_perusahaan LIKE '%$search%' OR sk_iup LIKE '%$search%')";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "nama_provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "tahun_1_7 = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where[] = "waktu_perlaporan_laporan_1_6 = '$tw_val'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where[] = "jenis_perizinan_1_1 = '$jenis_perizinan'";
    }
    if (!empty($status_produksi)) {
        if ($status_produksi === 'P') {
            $where[] = "(LOWER(COALESCE(sistem_penambangan_1_5, '')) NOT LIKE '%belum produksi%')";
        } elseif ($status_produksi === 'BP') {
            $where[] = "LOWER(sistem_penambangan_1_5) LIKE '%belum produksi%'";
        }
    }

    $where_sql = implode(' AND ', $where);

    // Hitung total data
    $sql_count = "SELECT COUNT(*) as total FROM vlaporan_batubara2 WHERE $where_sql";
    $res_count = executeQuery($sql_count);
    $total_records = 0;
    if ($res_count && $row = $res_count->fetch_assoc()) {
        $total_records = (int)$row['total'];
    }

    $total_pages = ceil($total_records / $limit);

    // Ambil data halaman ini
    $sql_data = "SELECT * FROM vlaporan_batubara2 
                 WHERE $where_sql 
                 ORDER BY id DESC 
                 LIMIT $offset, $limit";
    $res_data = executeQuery($sql_data);

    $items = [];
    if ($res_data) {
        while ($row = $res_data->fetch_assoc()) {
            // Tentukan status produksi
            $sistem = strtolower($row['sistem_penambangan_1_5'] ?? '');
            $is_produksi = strpos($sistem, 'belum produksi') === false;

            // Bentuk data ringkas untuk mobile + data lengkap untuk detail
            $items[] = [
                'id' => (int)($row['id'] ?? 0),
                'nama_perusahaan' => $row['nama_perusahaan'] ?? '-',
                'sk_iup' => $row['sk_iup'] ?? '-',
                'provinsi' => $row['nama_provinsi'] ?? '-',
                'tahun' => $row['tahun_1_7'] ?? '-',
                'triwulan' => $row['waktu_perlaporan_laporan_1_6'] ?? '-',
                'jenis_perizinan' => $row['jenis_perizinan_1_1'] ?? '-',
                'sistem_penambangan' => $row['sistem_penambangan_1_5'] ?? '-',
                'status_produksi' => $is_produksi ? 'Sudah Produksi' : 'Belum Produksi',
                'status_produksi_code' => $is_produksi ? 'P' : 'BP',
                'waktu_input' => $row['waktu_input_8'] ?? '-',
                
                // Ringkasan metrik utama untuk kartu HP
                'metrics' => [
                    'bkr_kuantitas' => $row['bkr_kuantitas'] ?? '-',
                    'pbkr_volume' => $row['pbkr_volume'] ?? '-',
                    'cm_kuantitas' => $row['cm_kuantitas'] ?? '-',
                    'shp_kuantitas' => $row['shp_kuantitas'] ?? '-',
                    'ctt_kuantitas' => $row['ctt_kuantitas'] ?? '-',
                    'rec_penambangan' => $row['recovery_penambangan_survey_2_3'] ?? $row['recovery_penambangan_truck_2_2'] ?? '-',
                    'rec_pengolahan' => $row['recovery_pengolahan_2_5'] ?? '-',
                ],

                // File lampiran (jika ada)
                'laporan_file' => !empty($row['laporan_7_1']) && $row['laporan_7_1'] !== '-' ? $row['laporan_7_1'] : (!empty($row['laporan']) && $row['laporan'] !== '-' ? $row['laporan'] : null),
                'peta_file' => !empty($row['peta_konservasi_7_2']) && $row['peta_konservasi_7_2'] !== '-' ? $row['peta_konservasi_7_2'] : (!empty($row['peta_konservasi']) && $row['peta_konservasi'] !== '-' ? $row['peta_konservasi'] : null),

                // Data lengkap untuk modal detail tap-to-expand
                'raw_details' => $row
            ];
        }
    }

    // Grand Total untuk seluruh data terfilter
    $sql_totals = "SELECT 
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(bkr_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_bkr_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(pbkr_volume, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_pbkr_volume,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cm_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_cm_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(shp_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_shp_kuantitas,
        ROUND(SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(ctt_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)), 2) as total_ctt_kuantitas
    FROM vlaporan_batubara2 WHERE $where_sql";

    $res_totals = executeQuery($sql_totals);
    $totals = [
        'bkr_kuantitas' => 0.0,
        'pbkr_volume' => 0.0,
        'cm_kuantitas' => 0.0,
        'shp_kuantitas' => 0.0,
        'ctt_kuantitas' => 0.0,
    ];
    if ($res_totals && $row_tot = $res_totals->fetch_assoc()) {
        $totals['bkr_kuantitas'] = (float)($row_tot['total_bkr_kuantitas'] ?? 0);
        $totals['pbkr_volume'] = (float)($row_tot['total_pbkr_volume'] ?? 0);
        $totals['cm_kuantitas'] = (float)($row_tot['total_cm_kuantitas'] ?? 0);
        $totals['shp_kuantitas'] = (float)($row_tot['total_shp_kuantitas'] ?? 0);
        $totals['ctt_kuantitas'] = (float)($row_tot['total_ctt_kuantitas'] ?? 0);
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
 * Mendapatkan detail lengkap 1 laporan
 */
function handleGetDetail() {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        echo json_encode(['success' => false, 'message' => 'ID laporan tidak valid']);
        return;
    }

    $sql = "SELECT * FROM vlaporan_batubara2 WHERE id = $id LIMIT 1";
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

    $where_lap = [
        "nama_provinsi IS NOT NULL",
        "nama_perusahaan IS NOT NULL",
        "sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')"
    ];
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun_1_7 = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_perlaporan_laporan_1_6 = '$tw_val'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $where_lap[] = "jenis_perizinan_1_1 = '$jenis_perizinan'";
    }
    $where_lap_sql = implode(' AND ', $where_lap);

    $sql = "SELECT 
                TRIM(p.nama_provinsi) as nama_provinsi,
                COUNT(DISTINCT pb.sk_iup) as total_perusahaan,
                COALESCE(lap.total_laporan, 0) as total_laporan,
                COALESCE(lap.perusahaan_unik, 0) as sudah_lapor,
                GREATEST(0, COUNT(DISTINCT pb.sk_iup) - COALESCE(lap.perusahaan_unik, 0)) as belum_lapor,
                ROUND(
                    (COALESCE(lap.perusahaan_unik, 0) * 100.0) / 
                    NULLIF(COUNT(DISTINCT pb.sk_iup), 0), 2
                ) as persentase_kepatuhan
            FROM provinsi p
            LEFT JOIN perusahaan_batubara pb ON p.id_provinsi = pb.id_provinsi AND pb.sk_iup IS NOT NULL AND pb.sk_iup != '' AND COALESCE(pb.is_active, 1) = 1
            LEFT JOIN (
                SELECT 
                    TRIM(nama_provinsi) as nama_provinsi,
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_unik
                FROM vlaporan_batubara2
                WHERE $where_lap_sql
                GROUP BY TRIM(nama_provinsi)
            ) as lap ON TRIM(p.nama_provinsi) = lap.nama_provinsi
            WHERE p.nama_provinsi IS NOT NULL AND p.nama_provinsi != ''
            GROUP BY TRIM(p.nama_provinsi)
            HAVING total_perusahaan > 0 OR sudah_lapor > 0
            ORDER BY persentase_kepatuhan DESC, total_perusahaan DESC";

    $res = executeQuery($sql);
    $data = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $data[] = [
                'nama_provinsi' => $row['nama_provinsi'],
                'total_perusahaan' => (int)$row['total_perusahaan'],
                'total_laporan' => (int)$row['total_laporan'],
                'sudah_lapor' => (int)$row['sudah_lapor'],
                'belum_lapor' => (int)$row['belum_lapor'],
                'persentase_kepatuhan' => $row['persentase_kepatuhan'] !== null ? (float)$row['persentase_kepatuhan'] : 0.0,
            ];
        }
    }

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
        $sql = "SELECT id, nama_perusahaan, nama_provinsi, waktu_perlaporan_laporan_1_6, tahun_1_7, waktu_input_8 
                FROM vlaporan_batubara2 
                WHERE waktu_input_8 IS NOT NULL 
                  AND waktu_input_8 != '' 
                  AND waktu_input_8 != '-'
                  AND DATE(waktu_input_8) >= '$startDate' 
                  AND DATE(waktu_input_8) <= '$endDate'
                ORDER BY waktu_input_8 DESC, id DESC 
                LIMIT 40";
        $res = executeQuery($sql);
        $items = [];
        if ($res) {
            while ($row = $res->fetch_assoc()) {
                $items[] = [
                    'id' => (int)($row['id'] ?? 0),
                    'nama_perusahaan' => trim($row['nama_perusahaan'] ?? ''),
                    'provinsi' => trim($row['nama_provinsi'] ?? '-'),
                    'triwulan' => trim($row['waktu_perlaporan_laporan_1_6'] ?? '-'),
                    'tahun' => trim($row['tahun_1_7'] ?? '-'),
                    'waktu_input' => trim($row['waktu_input_8'] ?? '-'),
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
 * Mendapatkan ringkasan internal summary untuk kalkulasi trend
 */
function getSummaryInternalBatubara($tahun = '', $triwulan = '', $provinsi = '') {
    $where_lap = [
        "nama_provinsi IS NOT NULL",
        "nama_perusahaan IS NOT NULL",
        "sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')"
    ];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_lap[] = "nama_provinsi = '$provinsi'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_lap[] = "tahun_1_7 = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $tw_val = formatTriwulan($triwulan);
        $where_lap[] = "waktu_perlaporan_laporan_1_6 = '$tw_val'";
    }

    $where_lap_sql = implode(' AND ', $where_lap);
    $sql_lap = "SELECT 
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_sudah_lapor
                FROM vlaporan_batubara2
                WHERE $where_lap_sql";
    $res_lap = executeQuery($sql_lap);
    $total_laporan = 0;
    $perusahaan_sudah_lapor = 0;
    if ($res_lap && $row = $res_lap->fetch_assoc()) {
        $total_laporan = (int)$row['total_laporan'];
        $perusahaan_sudah_lapor = (int)$row['perusahaan_sudah_lapor'];
    }

    $sql_total = "SELECT COUNT(DISTINCT pb.sk_iup) as total 
                  FROM perusahaan_batubara pb 
                  LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi 
                  WHERE pb.sk_iup IS NOT NULL AND pb.sk_iup != '' AND COALESCE(pb.is_active, 1) = 1";
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $sql_total .= " AND prov.nama_provinsi = '$provinsi'";
    }
    $res_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($res_total && $row_tot = $res_total->fetch_assoc()) {
        $total_perusahaan = (int)$row_tot['total'];
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
 * Mencari daftar perusahaan batubara unik beserta ringkasan status & total laporan
 */
function handleSearchCompanies() {
    $q = escapeString($_GET['q'] ?? $_GET['query'] ?? $_GET['search'] ?? '');
    $tahun = escapeString($_GET['tahun'] ?? '');
    $limit = max(5, min(100, (int)($_GET['limit'] ?? 40)));

    $where = ["nama_provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL", "nama_perusahaan != ''"];
    if (!empty($q)) {
        $where[] = "(nama_perusahaan LIKE '%$q%' OR sk_iup LIKE '%$q%' OR nama_provinsi LIKE '%$q%')";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "tahun_1_7 = '$tahun'";
    }
    $where_sql = implode(' AND ', $where);

    $sql = "SELECT 
                sk_iup,
                nama_perusahaan,
                MAX(nama_provinsi) as nama_provinsi,
                MAX(jenis_perizinan_1_1) as jenis_perizinan,
                MAX(sistem_penambangan_1_5) as sistem_penambangan,
                MAX(id) as latest_id,
                MAX(tahun_1_7) as latest_tahun,
                MAX(waktu_perlaporan_laporan_1_6) as latest_triwulan,
                MAX(waktu_input_8) as latest_waktu_input,
                COUNT(*) as total_reports
            FROM vlaporan_batubara2
            WHERE $where_sql
            GROUP BY nama_perusahaan, sk_iup
            ORDER BY nama_perusahaan ASC
            LIMIT $limit";

    $res = executeQuery($sql);
    // Ambil peta status is_active dari perusahaan_batubara
    $active_map = [];
    $res_active = executeQuery("SELECT sk_iup, nama_perusahaan, COALESCE(is_active, 1) as is_active FROM perusahaan_batubara");
    if ($res_active) {
        while ($ra = $res_active->fetch_assoc()) {
            $sk_k = strtolower(trim($ra['sk_iup'] ?? ''));
            $nm_k = strtolower(trim($ra['nama_perusahaan'] ?? ''));
            $act = ((int)$ra['is_active']) === 1;
            if ($sk_k !== '') $active_map['sk:' . $sk_k] = $act;
            if ($nm_k !== '') $active_map['nm:' . $nm_k] = $act;
        }
    }

    $data = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $sistem = strtolower($row['sistem_penambangan'] ?? '');
            $is_produksi = strpos($sistem, 'belum produksi') === false;
            $sk_k = strtolower(trim($row['sk_iup'] ?? ''));
            $nm_k = strtolower(trim($row['nama_perusahaan'] ?? ''));
            $is_active = true;
            if (isset($active_map['sk:' . $sk_k])) {
                $is_active = $active_map['sk:' . $sk_k];
            } elseif (isset($active_map['nm:' . $nm_k])) {
                $is_active = $active_map['nm:' . $nm_k];
            }

            $data[] = [
                'nama_perusahaan' => $row['nama_perusahaan'],
                'sk_iup' => $row['sk_iup'],
                'provinsi' => $row['nama_provinsi'],
                'jenis_perizinan' => $row['jenis_perizinan'] ?? '-',
                'komoditas' => 'Batubara',
                'sektor' => 'batubara',
                'is_active' => $is_active,
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
 * Mendapatkan histori pelaporan lengkap untuk 1 perusahaan batubara
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

    $sql = "SELECT * FROM vlaporan_batubara2 WHERE $where_sql ORDER BY tahun_1_7 DESC, id DESC";
    $res = executeQuery($sql);
    $items = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $sistem = strtolower($row['sistem_penambangan_1_5'] ?? '');
            $is_produksi = strpos($sistem, 'belum produksi') === false;

            $items[] = [
                'id' => (int)($row['id'] ?? 0),
                'nama_perusahaan' => $row['nama_perusahaan'] ?? '-',
                'sk_iup' => $row['sk_iup'] ?? '-',
                'provinsi' => $row['nama_provinsi'] ?? '-',
                'tahun' => $row['tahun_1_7'] ?? '-',
                'triwulan' => $row['waktu_perlaporan_laporan_1_6'] ?? '-',
                'jenis_perizinan' => $row['jenis_perizinan_1_1'] ?? '-',
                'sistem_penambangan' => $row['sistem_penambangan_1_5'] ?? '-',
                'status_produksi' => $is_produksi ? 'Sudah Produksi' : 'Belum Produksi',
                'status_produksi_code' => $is_produksi ? 'P' : 'BP',
                'waktu_input' => $row['waktu_input_8'] ?? $row['waktu_input'] ?? '-',
                'komoditas' => 'Batubara',
                'metrics' => [
                    'bkr_kuantitas' => $row['bkr_kuantitas_2_1'] ?? '-',
                    'pbkr_volume' => $row['pbkr_volume_2_1'] ?? '-',
                    'cm_kuantitas' => $row['cm_kuantitas_cadangan_2_1'] ?? '-',
                    'shp_kuantitas' => $row['shp_kuantitas_2_1'] ?? '-',
                    'ctt_kuantitas' => $row['ctt_kuantitas_cadangan_2_1'] ?? '-',
                    'stripping_ratio' => $row['stripping_ratio_truck_2_2'] ?? '-',
                    'rec_penambangan' => $row['recovery_penambangan_survey_2_3'] ?? '-',
                    'rec_pengolahan' => $row['recovery_pengolahan_2_6'] ?? '-',
                ],
                'laporan_file' => !empty($row['laporan_7_1']) && $row['laporan_7_1'] !== '-' ? $row['laporan_7_1'] : (!empty($row['laporan']) && $row['laporan'] !== '-' ? $row['laporan'] : null),
                'peta_file' => !empty($row['peta_konservasi_7_2']) && $row['peta_konservasi_7_2'] !== '-' ? $row['peta_konservasi_7_2'] : (!empty($row['peta_konservasi']) && $row['peta_konservasi'] !== '-' ? $row['peta_konservasi'] : (!empty($row['peta']) && $row['peta'] !== '-' ? $row['peta'] : null)),
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
 * Analisis trend kepatuhan (kenaikan/penurunan) & analisis khusus batubara
 */
function handleGetAnalysis() {
    $tahun_curr = escapeString($_GET['tahun_current'] ?? $_GET['tahun'] ?? '');
    $triwulan_curr = escapeString($_GET['triwulan_current'] ?? $_GET['triwulan'] ?? '');
    $tahun_prev = escapeString($_GET['tahun_prev'] ?? '');
    $triwulan_prev = escapeString($_GET['triwulan_prev'] ?? '');
    $provinsi = escapeString($_GET['provinsi'] ?? '');

    $s_curr = getSummaryInternalBatubara($tahun_curr, $triwulan_curr, $provinsi);
    $s_prev = getSummaryInternalBatubara($tahun_prev, $triwulan_prev, $provinsi);
    $delta_kepatuhan = round($s_curr['persentase_kepatuhan'] - $s_prev['persentase_kepatuhan'], 2);

    // Rekap Provinsi Current & Prev
    $sql_prov = "SELECT 
                    TRIM(p.nama_provinsi) as nama_provinsi,
                    COUNT(DISTINCT pb.sk_iup) as total_perusahaan,
                    COALESCE(lap.perusahaan_unik, 0) as sudah_lapor,
                    ROUND((COALESCE(lap.perusahaan_unik, 0) * 100.0) / NULLIF(COUNT(DISTINCT pb.sk_iup), 0), 2) as kepatuhan
                 FROM provinsi p
                 LEFT JOIN perusahaan_batubara pb ON p.id_provinsi = pb.id_provinsi AND pb.sk_iup IS NOT NULL AND pb.sk_iup != '' AND COALESCE(pb.is_active, 1) = 1
                 LEFT JOIN (
                     SELECT TRIM(nama_provinsi) as nama_provinsi, COUNT(DISTINCT sk_iup) as perusahaan_unik
                     FROM vlaporan_batubara2
                     WHERE tahun_1_7 = '$tahun_curr' AND waktu_perlaporan_laporan_1_6 = '".formatTriwulan($triwulan_curr)."'
                       AND sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')
                     GROUP BY TRIM(nama_provinsi)
                 ) as lap ON TRIM(p.nama_provinsi) = lap.nama_provinsi
                 GROUP BY TRIM(p.nama_provinsi)
                 HAVING total_perusahaan > 0 OR sudah_lapor > 0";
    $res_p_curr = executeQuery($sql_prov);
    $prov_curr = [];
    if ($res_p_curr) {
        while ($r = $res_p_curr->fetch_assoc()) {
            $prov_curr[strtolower(trim($r['nama_provinsi']))] = [
                'nama' => $r['nama_provinsi'],
                'total' => (int)$r['total_perusahaan'],
                'sudah' => (int)$r['sudah_lapor'],
                'kep' => (float)($r['kepatuhan'] ?? 0.0)
            ];
        }
    }

    $sql_prov_prev = "SELECT TRIM(nama_provinsi) as nama_provinsi, COUNT(DISTINCT sk_iup) as perusahaan_unik
                      FROM vlaporan_batubara2
                      WHERE tahun_1_7 = '$tahun_prev' AND waktu_perlaporan_laporan_1_6 = '".formatTriwulan($triwulan_prev)."'
                        AND sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')
                      GROUP BY TRIM(nama_provinsi)";
    $res_p_prev = executeQuery($sql_prov_prev);
    $prev_sudah_map = [];
    if ($res_p_prev) {
        while ($r = $res_p_prev->fetch_assoc()) {
            $prev_sudah_map[strtolower(trim($r['nama_provinsi']))] = (int)$r['perusahaan_unik'];
        }
    }

    $province_trends = [];
    foreach ($prov_curr as $k => $c) {
        $prev_sudah = $prev_sudah_map[$k] ?? 0;
        $prev_kep = $c['total'] > 0 ? round(($prev_sudah * 100.0) / $c['total'], 2) : 0.0;
        $delta = round($c['kep'] - $prev_kep, 2);

        $province_trends[] = [
            'nama_provinsi' => $c['nama'],
            'kepatuhan_current' => (float)$c['kep'],
            'kepatuhan_prev' => (float)$prev_kep,
            'delta' => (float)$delta,
            'total_perusahaan' => (int)$c['total'],
            'sudah_lapor_current' => (int)$c['sudah'],
            'sudah_lapor_prev' => (int)$prev_sudah
        ];
    }

    usort($province_trends, function($a, $b) {
        return $b['delta'] <=> $a['delta'];
    });

    // Analisis Khusus
    $where_spec = ["nama_provinsi IS NOT NULL", "nama_perusahaan IS NOT NULL"];
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_spec[] = "nama_provinsi = '$provinsi'";
    }
    if (!empty($tahun_curr) && $tahun_curr !== 'semua') {
        $where_spec[] = "tahun_1_7 = '$tahun_curr'";
    }
    if (!empty($triwulan_curr) && $triwulan_curr !== 'semua') {
        $where_spec[] = "waktu_perlaporan_laporan_1_6 = '".formatTriwulan($triwulan_curr)."'";
    }
    $where_spec_sql = implode(' AND ', $where_spec);

    $sql_spec = "SELECT 
                    COUNT(*) as total_laporan,
                    SUM(CASE WHEN LOWER(COALESCE(sistem_penambangan_1_5, '')) NOT LIKE '%belum produksi%' THEN 1 ELSE 0 END) as total_produksi,
                    SUM(CASE WHEN LOWER(COALESCE(sistem_penambangan_1_5, '')) LIKE '%belum produksi%' THEN 1 ELSE 0 END) as total_belum_produksi,
                    SUM(CASE WHEN laporan IS NOT NULL AND laporan != '' AND laporan != '-' THEN 1 ELSE 0 END) as total_dokumen,
                    SUM(CASE WHEN peta IS NOT NULL AND peta != '' AND peta != '-' THEN 1 ELSE 0 END) as total_peta
                 FROM vlaporan_batubara2
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

/**
 * Mengambil daftar perusahaan beserta status aktif/non-aktif
 */
function handleGetCompaniesStatus() {
    $q = escapeString($_GET['q'] ?? '');
    $status = escapeString($_GET['status'] ?? 'semua'); // semua | aktif | nonaktif
    $provinsi = escapeString($_GET['provinsi'] ?? 'semua');
    $limit = max(10, min(1000, (int)($_GET['limit'] ?? 500)));

    $where = ["pb.sk_iup IS NOT NULL", "pb.sk_iup != ''"];
    if (!empty($q)) {
        $where[] = "(pb.nama_perusahaan LIKE '%$q%' OR pb.sk_iup LIKE '%$q%' OR COALESCE(prov.nama_provinsi, '') LIKE '%$q%')";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "prov.nama_provinsi = '$provinsi'";
    }
    if ($status === 'aktif') {
        $where[] = "COALESCE(pb.is_active, 1) = 1";
    } elseif ($status === 'nonaktif') {
        $where[] = "COALESCE(pb.is_active, 1) = 0";
    }

    $where_sql = implode(' AND ', $where);
    $sql = "SELECT
                pb.id,
                pb.nama_perusahaan,
                pb.sk_iup,
                COALESCE(prov.nama_provinsi, '-') as provinsi,
                COALESCE(pb.jenis_izin, '-') as jenis_izin,
                COALESCE(pb.komoditas, 'Batubara') as komoditas,
                COALESCE(pb.is_active, 1) as is_active
            FROM perusahaan_batubara pb
            LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi
            WHERE $where_sql
            ORDER BY pb.nama_perusahaan ASC
            LIMIT $limit";

    $res = executeQuery($sql);
    $data = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $data[] = [
                'id' => (int)$row['id'],
                'nama_perusahaan' => $row['nama_perusahaan'],
                'sk_iup' => $row['sk_iup'],
                'provinsi' => $row['provinsi'],
                'jenis_izin' => $row['jenis_izin'],
                'komoditas' => $row['komoditas'],
                'is_active' => ((int)$row['is_active']) === 1,
                'sektor' => 'batubara',
            ];
        }
    }

    // Ringkasan total keseluruhan perusahaan batubara
    $sum_sql = "SELECT
                    COUNT(DISTINCT sk_iup) as total,
                    COUNT(DISTINCT CASE WHEN COALESCE(is_active, 1) = 1 THEN sk_iup END) as aktif,
                    COUNT(DISTINCT CASE WHEN COALESCE(is_active, 1) = 0 THEN sk_iup END) as nonaktif
                FROM perusahaan_batubara
                WHERE sk_iup IS NOT NULL AND sk_iup != ''";
    $res_sum = executeQuery($sum_sql);
    $summary = ['total' => 0, 'aktif' => 0, 'nonaktif' => 0];
    if ($res_sum && $rs = $res_sum->fetch_assoc()) {
        $summary = [
            'total' => (int)$rs['total'],
            'aktif' => (int)$rs['aktif'],
            'nonaktif' => (int)$rs['nonaktif'],
        ];
    }

    echo json_encode([
        'success' => true,
        'summary' => $summary,
        'total' => count($data),
        'data' => $data,
    ]);
}

/**
 * Mengubah status aktif/non-aktif perusahaan batubara (dilindungi PIN)
 */
function handleToggleCompanyStatus() {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (!is_array($body)) $body = [];

    $pin = trim((string)($body['pin'] ?? $_POST['pin'] ?? ''));
    if ($pin !== '3636') {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Kode keamanan (PIN) tidak valid']);
        return;
    }

    $id = (int)($body['id'] ?? $_POST['id'] ?? 0);
    $sk_iup = escapeString($body['sk_iup'] ?? $_POST['sk_iup'] ?? '');
    $nama = escapeString($body['nama_perusahaan'] ?? $_POST['nama_perusahaan'] ?? '');
    $is_active_raw = $body['is_active'] ?? $_POST['is_active'] ?? null;

    if ($is_active_raw === null) {
        echo json_encode(['success' => false, 'message' => 'Parameter is_active diperlukan']);
        return;
    }
    $is_active = ($is_active_raw === true || $is_active_raw === 1 || $is_active_raw === '1' || $is_active_raw === 'true') ? 1 : 0;

    if ($id > 0) {
        $sql = "UPDATE perusahaan_batubara SET is_active = $is_active WHERE id = $id";
    } elseif (!empty($sk_iup) && $sk_iup !== '-') {
        $sql = "UPDATE perusahaan_batubara SET is_active = $is_active WHERE sk_iup = '$sk_iup'";
    } elseif (!empty($nama)) {
        $sql = "UPDATE perusahaan_batubara SET is_active = $is_active WHERE nama_perusahaan = '$nama'";
    } else {
        echo json_encode(['success' => false, 'message' => 'Identifier perusahaan (id / sk_iup / nama_perusahaan) diperlukan']);
        return;
    }

    $ok = executeQuery($sql);
    if ($ok) {
        echo json_encode([
            'success' => true,
            'is_active' => $is_active === 1,
            'message' => $is_active === 1 ? 'Perusahaan berhasil diaktifkan kembali' : 'Perusahaan berhasil dinonaktifkan'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Gagal memperbarui status perusahaan'
        ]);
    }
}




