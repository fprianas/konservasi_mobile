<?php
/**
 * AJAX Server-Side Data Processor for Laporan Batubara
 * File: get_laporan_data.php
 * Sumber Data: view vlaporan_batubara2
 */

// Bersihkan output buffer & cegah warning PHP merusak format JSON
ob_start();
error_reporting(E_ALL & ~E_NOTICE & ~E_WARNING & ~E_DEPRECATED);
ini_set('display_errors', 0);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

header('Content-Type: application/json; charset=utf-8');

try {
    // Cek otentikasi login
    if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
        ob_clean();
        echo json_encode(array(
            'draw' => intval($_REQUEST['draw'] ?? 1),
            'recordsTotal' => 0,
            'recordsFiltered' => 0,
            'data' => array(),
            'error' => 'Sesi telah berakhir, silakan login kembali'
        ));
        exit();
    }

    require_once 'koneksi.php';

    // Ambil parameter DataTables
    $draw = isset($_REQUEST['draw']) ? intval($_REQUEST['draw']) : 1;
    $start = isset($_REQUEST['start']) ? intval($_REQUEST['start']) : 0;
    $length = isset($_REQUEST['length']) ? intval($_REQUEST['length']) : 10;
    if ($length <= 0) {
        $length = 10;
    }

    // Parameter filter
    $nama_perusahaan = isset($_REQUEST['nama_perusahaan']) ? trim($_REQUEST['nama_perusahaan']) : '';
    $provinsi = isset($_REQUEST['provinsi']) ? trim($_REQUEST['provinsi']) : 'semua';
    $triwulan = isset($_REQUEST['triwulan']) ? trim($_REQUEST['triwulan']) : 'semua';
    $tahun = isset($_REQUEST['tahun']) ? trim($_REQUEST['tahun']) : 'semua';
    $jenis_perizinan = isset($_REQUEST['jenis_perizinan']) ? trim($_REQUEST['jenis_perizinan']) : 'semua';

    $search_value = '';
    if (isset($_REQUEST['search']) && is_array($_REQUEST['search']) && isset($_REQUEST['search']['value'])) {
        $search_value = trim($_REQUEST['search']['value']);
    }

    // Mapping kolom database
    $columns = array(
        0 => 'id',
        1 => 'id',
        2 => 'jenis_perizinan_1_1',
        3 => 'nama_provinsi',
        4 => 'nama_perusahaan',
        5 => 'sk_iup',
        6 => 'alamat_email_1_4',
        7 => 'sistem_penambangan_1_5',
        8 => 'waktu_perlaporan_laporan_1_6',
        9 => 'tahun_1_7',
        10 => 'rencana_recovery_penambangan',
        11 => 'rkab_2_1',
        12 => 'studi_kelayakan_2_1',
        13 => 'recovery_penambangan_truck_2_1',
        14 => 'recovery_penambangan_survey_2_2',
        15 => 'rencana_recovery_pengolahan',
        16 => 'rkab_2_4',
        17 => 'studi_kelayakan_2_4',
        18 => 'recovery_pengolahan_2_3',
        19 => 'bkr_komulatif_awal_tahun',
        20 => 'bkr_lokasi',
        21 => 'bkr_kuantitas',
        22 => 'bkr_calorie_values_3_1',
        23 => 'bkr_ash_3_1',
        24 => 'bkr_sulfur_3_1',
        25 => 'bkr_total_moisture_3_1',
        26 => 'bkr_pemanfaatan_sudah_belum_3_2',
        27 => 'bkr_jenis_pemanfaatan',
        28 => 'pbkr_volume',
        29 => 'cm_ada_tidak',
        30 => 'cm_komulatif_awal_tahun',
        31 => 'cm_lokasi',
        32 => 'cm_kuantitas',
        33 => 'cm_calorie_values_4_1',
        34 => 'cm_ash_4_1',
        35 => 'cm_sulfur_4_1',
        36 => 'cm_total_moisture_4_1',
        37 => 'cm_penyebab_4_2',
        38 => 'cm_optimalisasi_sudah_belum_4_3',
        39 => 'cm_yang_sudah_ditambang_',
        40 => 'shp_komulatif_awal_tahun',
        41 => 'shp_lokasi',
        42 => 'shp_kuantitas',
        43 => 'shp_calorie_values_5_1',
        44 => 'shp_ash_5_1',
        45 => 'shp_sulfur_5_1',
        46 => 'shp_total_moisture_5_1',
        47 => 'pshp_volume',
        48 => 'ctt_komulatif_awal_tahun',
        49 => 'ctt_lokasi',
        50 => 'ctt_kuantitas',
        51 => 'ctt_kedalaman',
        52 => 'ctt_calorie_values_6_1',
        53 => 'ctt_ash_6_1',
        54 => 'ctt_sulfur_6_1',
        55 => 'ctt_total_moisture_6_1',
        56 => 'ctt_alasan_6_2',
        57 => 'laporan_7_1',
        58 => 'peta_konservasi_7_2',
        59 => 'waktu_input_8',
        60 => 'id'
    );

    // Sorting
    $order_column_idx = isset($_REQUEST['order'][0]['column']) ? intval($_REQUEST['order'][0]['column']) : 9;
    $order_dir = (isset($_REQUEST['order'][0]['dir']) && strtolower($_REQUEST['order'][0]['dir']) === 'asc') ? 'ASC' : 'DESC';
    $order_column = isset($columns[$order_column_idx]) ? $columns[$order_column_idx] : 'tahun_1_7';

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

    // Safe escape helper
    function safeEscape($str)
    {
        if (function_exists('escapeString')) {
            return escapeString($str);
        }
        global $koneksi, $conn, $db;
        $link = $koneksi ?? $conn ?? $db ?? null;
        if ($link && is_object($link)) {
            return mysqli_real_escape_string($link, $str);
        }
        return addslashes($str);
    }

    $where_conditions = array();
    $where_conditions[] = "nama_provinsi IS NOT NULL";
    $where_conditions[] = "nama_perusahaan IS NOT NULL";

    if (!empty($nama_perusahaan)) {
        $escaped_perusahaan = safeEscape($nama_perusahaan);
        $where_conditions[] = "nama_perusahaan LIKE '%$escaped_perusahaan%'";
    }

    if (!empty($provinsi) && $provinsi !== 'semua') {
        $escaped_provinsi = safeEscape($provinsi);
        $where_conditions[] = "nama_provinsi = '$escaped_provinsi'";
    }

    if (!empty($tahun) && $tahun !== 'semua') {
        $escaped_tahun = safeEscape($tahun);
        $where_conditions[] = "tahun_1_7 = '$escaped_tahun'";
    }

    if (!empty($triwulan) && $triwulan !== 'semua') {
        switch ($triwulan) {
            case '1':
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                break;
            case '2':
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                break;
            case '3':
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                break;
            case '4':
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                break;
        }
    }

    if (!empty($jenis_perizinan) && $jenis_perizinan !== 'semua') {
        $escaped_perizinan = safeEscape($jenis_perizinan);
        $where_conditions[] = "jenis_perizinan_1_1 = '$escaped_perizinan'";
    }

    // Filter Status Produksi (P = Sudah Produksi, BP = Belum Produksi)
    $status_produksi = isset($_REQUEST['status_produksi']) ? $_REQUEST['status_produksi'] : array();
    if (!is_array($status_produksi)) {
        $status_produksi = array($status_produksi);
    }
    if (!empty($status_produksi)) {
        $hasP = in_array('P', $status_produksi) || in_array('sudah', $status_produksi);
        $hasBP = in_array('BP', $status_produksi) || in_array('belum', $status_produksi);

        if ($hasP && !$hasBP) {
            // Hanya yang Sudah Produksi: tidak ada kata 'Belum produksi' di Sistem Penambangan
            $where_conditions[] = "(LOWER(COALESCE(sistem_penambangan_1_5, '')) NOT LIKE '%belum produksi%')";
        } elseif ($hasBP && !$hasP) {
            // Hanya yang Belum Produksi: ada kata 'Belum produksi' di Sistem Penambangan
            $where_conditions[] = "LOWER(sistem_penambangan_1_5) LIKE '%belum produksi%'";
        }
    }

    if (!empty($search_value)) {
        $escaped_search = safeEscape($search_value);
        $search_clause = "(
            nama_perusahaan LIKE '%$escaped_search%' OR 
            nama_provinsi LIKE '%$escaped_search%' OR 
            sk_iup LIKE '%$escaped_search%' OR 
            jenis_perizinan_1_1 LIKE '%$escaped_search%' OR 
            sistem_penambangan_1_5 LIKE '%$escaped_search%' OR
            tahun_1_7 LIKE '%$escaped_search%'
        )";
        $where_conditions[] = $search_clause;
    }

    $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);

    // Hitung total tanpa filter
    $sql_total = "SELECT COUNT(*) as total FROM vlaporan_batubara2 WHERE nama_provinsi IS NOT NULL AND nama_perusahaan IS NOT NULL";
    $res_total = executeQuery($sql_total);
    $recordsTotal = 0;
    if ($res_total && $row_tot = $res_total->fetch_assoc()) {
        $recordsTotal = intval($row_tot['total']);
    }

    // Hitung total dengan filter
    $sql_filtered = "SELECT COUNT(*) as total FROM vlaporan_batubara2 $where_clause";
    $res_filtered = executeQuery($sql_filtered);
    $recordsFiltered = 0;
    if ($res_filtered && $row_filt = $res_filtered->fetch_assoc()) {
        $recordsFiltered = intval($row_filt['total']);
    }

    // Query data dengan LIMIT & OFFSET (MySQL syntax)
    $sql_data = "SELECT * FROM vlaporan_batubara2 $where_clause ORDER BY `$order_column` $order_dir LIMIT $start, $length";
    $res_data = executeQuery($sql_data);

    $data = array();
    if ($res_data && $res_data->num_rows > 0) {
        $upload_dir = '../pelaporan-v3.2.3/Batu Bara/uploads/';
        while ($row = $res_data->fetch_assoc()) {
            $laporan_file = $row['laporan_7_1'] ?? '';
            $laporan_exists = !empty($laporan_file) && @file_exists($upload_dir . $laporan_file);

            $peta_file = $row['peta_konservasi_7_2'] ?? '';
            $peta_exists = !empty($peta_file) && @file_exists($upload_dir . $peta_file);

            $row['laporan_exists'] = $laporan_exists;
            $row['peta_exists'] = $peta_exists;

            $data[] = $row;
        }
    }

    // Hitung Grand Total keseluruhan untuk kolom tonase/kuantitas yang diminta:
    // BKR (col 19, 21, 28), CM (col 29 ada/tidak, 30, 32, 39), SHP (col 40, 42, 47), CTT (col 48, 50)
    $sql_grand_total = "SELECT 
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(bkr_komulatif_awal_tahun, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_19,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(bkr_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_21,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(pbkr_volume, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_28,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cm_komulatif_awal_tahun, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_30,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cm_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_32,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(cm_yang_sudah_ditambang_, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_39,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(shp_komulatif_awal_tahun, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_40,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(shp_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_42,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(pshp_volume, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_47,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(ctt_komulatif_awal_tahun, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_48,
        SUM(COALESCE(CAST(NULLIF(REPLACE(REPLACE(ctt_kuantitas, ',', '.'), ' ', ''), '') AS DECIMAL(18,2)), 0)) as col_50,
        SUM(CASE WHEN LOWER(TRIM(cm_ada_tidak)) LIKE '%ada%' AND LOWER(TRIM(cm_ada_tidak)) NOT LIKE '%tidak%' THEN 1 ELSE 0 END) as cm_ada_count,
        SUM(CASE WHEN LOWER(TRIM(cm_ada_tidak)) LIKE '%tidak%' THEN 1 ELSE 0 END) as cm_tidak_count
    FROM vlaporan_batubara2 $where_clause";

    $res_gt = executeQuery($sql_grand_total);
    $grandTotals = array();
    if ($res_gt && $row_gt = $res_gt->fetch_assoc()) {
        foreach ($row_gt as $k => $v) {
            if ($k === 'cm_ada_count' || $k === 'cm_tidak_count') {
                continue;
            }
            $colIdx = (int) str_replace('col_', '', $k);
            $grandTotals[$colIdx] = (float) $v;
        }
        $grandTotals[29] = array(
            'ada' => (int) ($row_gt['cm_ada_count'] ?? 0),
            'tidak' => (int) ($row_gt['cm_tidak_count'] ?? 0)
        );
    }

    ob_clean();
    echo json_encode(array(
        'draw' => $draw,
        'recordsTotal' => $recordsTotal,
        'recordsFiltered' => $recordsFiltered,
        'grandTotals' => $grandTotals,
        'data' => $data
    ));
    exit();

} catch (Exception $e) {
    ob_clean();
    echo json_encode(array(
        'draw' => intval($_REQUEST['draw'] ?? 1),
        'recordsTotal' => 0,
        'recordsFiltered' => 0,
        'data' => array(),
        'error' => $e->getMessage()
    ));
    exit();
}
