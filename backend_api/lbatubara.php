<?php
/**
 * Laporan Batubara - Dashboard Pelaporan Minerba
 * File: lbatubara.php
 * Sumber Data: view vlaporan_batubara2
 */

// Start session dan cek login
session_start();

// Cek apakah user sudah login
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    // Jika belum login, redirect ke login page
    header('Location: loginb.php');
    exit();
}

require_once 'koneksi.php';

// AJAX handler untuk manajemen status aktif/non-aktif perusahaan batubara
if (isset($_POST['action']) && in_array($_POST['action'], ['manage_company_status', 'toggle_company_status'], true)) {
    while (ob_get_level()) { ob_end_clean(); }
    header('Content-Type: application/json; charset=utf-8');
    $act = $_POST['action'];

    if ($act === 'manage_company_status') {
        $filter_status = $_POST['filter_status'] ?? 'nonaktif';
        $q = escapeString(trim($_POST['q'] ?? ''));
        $provinsi = escapeString(trim($_POST['provinsi'] ?? ''));

        $where = ["pb.sk_iup IS NOT NULL", "pb.sk_iup != ''"];
        if ($filter_status === 'nonaktif') {
            $where[] = "COALESCE(pb.is_active, 1) = 0";
        } elseif ($filter_status === 'aktif') {
            $where[] = "COALESCE(pb.is_active, 1) = 1";
        }
        if (!empty($provinsi) && $provinsi !== 'semua') {
            $where[] = "p.nama_provinsi = '$provinsi'";
        }
        if (!empty($q)) {
            $where[] = "(pb.nama_perusahaan LIKE '%$q%' OR pb.sk_iup LIKE '%$q%' OR COALESCE(p.nama_provinsi, '') LIKE '%$q%')";
        }
        $where_sql = implode(' AND ', $where);
        $sql = "SELECT pb.id, pb.nama_perusahaan, pb.sk_iup, COALESCE(p.nama_provinsi, '-') as nama_provinsi,
                       COALESCE(pb.jenis_izin, '-') as jenis_izin, COALESCE(pb.is_active, 1) as is_active
                FROM perusahaan_batubara pb
                LEFT JOIN provinsi p ON pb.id_provinsi = p.id_provinsi
                WHERE $where_sql
                ORDER BY pb.is_active ASC, pb.nama_perusahaan ASC
                LIMIT 500";
        $res = executeQuery($sql);
        $rows = [];
        if ($res) {
            while ($r = $res->fetch_assoc()) {
                $rows[] = [
                    'id' => (int)$r['id'],
                    'nama_perusahaan' => $r['nama_perusahaan'],
                    'sk_iup' => $r['sk_iup'],
                    'nama_provinsi' => $r['nama_provinsi'],
                    'jenis_izin' => $r['jenis_izin'],
                    'is_active' => ((int)$r['is_active']) === 1
                ];
            }
        }
        echo json_encode(['success' => true, 'data' => $rows]);
        exit();
    }

    if ($act === 'toggle_company_status') {
        $pin = trim($_POST['pin'] ?? '');
        if ($pin !== '3636') {
            echo json_encode(['success' => false, 'message' => 'PIN keamanan tidak valid.']);
            exit();
        }
        $id = intval($_POST['id'] ?? 0);
        $is_active = intval($_POST['is_active'] ?? 1) === 1 ? 1 : 0;
        if ($id <= 0) {
            echo json_encode(['success' => false, 'message' => 'ID perusahaan tidak valid.']);
            exit();
        }
        $ok = executeQuery("UPDATE perusahaan_batubara SET is_active = $is_active WHERE id = $id");
        echo json_encode([
            'success' => (bool)$ok,
            'is_active' => $is_active === 1,
            'message' => $ok
                ? ($is_active === 1 ? 'Perusahaan berhasil diaktifkan kembali.' : 'Perusahaan berhasil dinonaktifkan.')
                : 'Gagal memperbarui status perusahaan.'
        ]);
        exit();
    }
}

// Fungsi untuk mendapatkan daftar provinsi
function getProvinsiList()
{
    $sql = "SELECT DISTINCT nama_provinsi 
            FROM provinsi 
            WHERE nama_provinsi IS NOT NULL 
            ORDER BY nama_provinsi ASC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar tahun
function getTahunList()
{
    $sql = "SELECT DISTINCT tahun_1_7 as tahun 
            FROM vlaporan_batubara2 
            WHERE tahun_1_7 IS NOT NULL 
            AND tahun_1_7 != '' 
            ORDER BY tahun_1_7 DESC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar jenis perizinan batubara
function getJenisPerizinanList()
{
    $sql = "SELECT DISTINCT jenis_perizinan_1_1 as jenis_perizinan 
            FROM vlaporan_batubara2 
            WHERE jenis_perizinan_1_1 IS NOT NULL 
            AND jenis_perizinan_1_1 != '' 
            AND jenis_perizinan_1_1 != '-' 
            ORDER BY jenis_perizinan_1_1 ASC";
    return executeQuery($sql);
}

// Fungsi untuk pencarian data dengan filter
// Menampilkan SEMUA record laporan tanpa deduplication
function searchLaporanBatubara($nama_perusahaan = '', $provinsi = '', $triwulan = '', $tahun = '', $jenis_perizinan = '')
{
    $where_conditions = array();

    // Selalu tambahkan kondisi untuk data yang valid
    $where_conditions[] = "nama_provinsi IS NOT NULL";
    $where_conditions[] = "nama_perusahaan IS NOT NULL";

    // Filter nama perusahaan (pencarian LIKE)
    if (!empty($nama_perusahaan) && trim($nama_perusahaan) != '') {
        $nama_perusahaan = escapeString(trim($nama_perusahaan));
        $where_conditions[] = "nama_perusahaan LIKE '%$nama_perusahaan%'";
    }

    // Filter provinsi
    if (!empty($provinsi) && $provinsi != 'semua' && trim($provinsi) != '') {
        $provinsi = escapeString(trim($provinsi));
        $where_conditions[] = "nama_provinsi = '$provinsi'";
    }

    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua' && trim($tahun) != '') {
        $tahun = escapeString(trim($tahun));
        $where_conditions[] = "tahun_1_7 = '$tahun'";
    }

    // Filter triwulan (berdasarkan waktu_perlaporan_laporan_1_6)
    // Menggunakan pencarian exact match karena format data konsisten
    if (!empty($triwulan) && $triwulan != 'semua' && trim($triwulan) != '') {
        $triwulan_escaped = escapeString($triwulan);
        switch ($triwulan) {
            case '1': // Triwulan I
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                break;
            case '2': // Triwulan II
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                break;
            case '3': // Triwulan III
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                break;
            case '4': // Triwulan IV
                $where_conditions[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                break;
        }
    }

    // Filter jenis perizinan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua' && trim($jenis_perizinan) != '') {
        $jp_clean = escapeString(trim($jenis_perizinan));
        $where_conditions[] = "jenis_perizinan_1_1 = '$jp_clean'";
    }

    // Gabungkan kondisi WHERE
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
    }

    // Query langsung dari vlaporan_batubara2 tanpa deduplication
    // Ini akan menampilkan SEMUA record laporan
    $sql = "SELECT * FROM vlaporan_batubara2 
            $where_clause 
            ORDER BY nama_provinsi, nama_perusahaan, tahun_1_7 DESC";

    return executeQuery($sql);
}

/**
 * Fungsi untuk mendapatkan analisis perusahaan yang sudah dan belum melaporkan per provinsi
 * Kolom "Sudah Lapor": Total record laporan
 * Kolom "Belum Lapor": Total perusahaan - Perusahaan unik yang sudah lapor
 */
function getAnalisisPerusahaan($provinsi = '', $tahun = '', $triwulan = '', $jenis_perizinan = '')
{
    // Buat kondisi WHERE untuk laporan
    $where_conditions_laporan = array();
    $where_conditions_laporan[] = "nama_provinsi IS NOT NULL";
    $where_conditions_laporan[] = "nama_perusahaan IS NOT NULL";
    $where_conditions_laporan[] = "sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')";

    // Filter provinsi
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions_laporan[] = "nama_provinsi = '$provinsi'";
    }

    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions_laporan[] = "tahun_1_7 = '$tahun'";
    }

    // Filter triwulan
    if (!empty($triwulan) && $triwulan != 'semua') {
        switch ($triwulan) {
            case '1':
                $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                break;
            case '2':
                $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                break;
            case '3':
                $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                break;
            case '4':
                $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                break;
        }
    }

    // Filter jenis perizinan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        $jp_clean = escapeString(trim($jenis_perizinan));
        $where_conditions_laporan[] = "jenis_perizinan_1_1 = '$jp_clean'";
    }

    $where_clause_laporan = implode(' AND ', $where_conditions_laporan);

    // Buat kondisi WHERE untuk perusahaan
    $where_conditions_perusahaan = array("COALESCE(pb.is_active, 1) = 1");
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions_perusahaan[] = "pb.id_provinsi IN (SELECT id_provinsi FROM provinsi WHERE nama_provinsi = '$provinsi')";
    }

    $where_clause_perusahaan = '';
    if (!empty($where_conditions_perusahaan)) {
        $where_clause_perusahaan = 'WHERE ' . implode(' AND ', $where_conditions_perusahaan);
    }

    // Query untuk analisis per provinsi
    $sql = "SELECT 
                p.nama_provinsi,
                COUNT(DISTINCT pb.sk_iup) as total_perusahaan,
                COALESCE(laporan_summary.total_laporan, 0) as sudah_lapor,
                COALESCE(laporan_summary.perusahaan_unik, 0) as perusahaan_sudah_lapor,
                COUNT(DISTINCT pb.sk_iup) - COALESCE(laporan_summary.perusahaan_unik, 0) as belum_lapor,
                ROUND(
                    (COALESCE(laporan_summary.perusahaan_unik, 0) * 100.0) / 
                    NULLIF(COUNT(DISTINCT pb.sk_iup), 0), 2
                ) as persentase_lapor
            FROM perusahaan_batubara pb
            LEFT JOIN provinsi p ON pb.id_provinsi = p.id_provinsi
            LEFT JOIN (
                SELECT 
                    nama_provinsi,
                    COUNT(*) as total_laporan,
                    COUNT(DISTINCT sk_iup) as perusahaan_unik
                FROM vlaporan_batubara2
                WHERE $where_clause_laporan
                GROUP BY nama_provinsi
            ) as laporan_summary ON p.nama_provinsi = laporan_summary.nama_provinsi
            $where_clause_perusahaan
            GROUP BY p.nama_provinsi
            ORDER BY total_perusahaan DESC";

    return executeQuery($sql);
}

/**
 * Fungsi untuk mendapatkan total statistik perusahaan
 * Menghitung total record laporan yang sesuai filter (sama dengan jumlah baris di tabel)
 */
function getTotalStatistikPerusahaan($provinsi = '', $tahun = '', $triwulan = '', $jenis_perizinan = '')
{
    // Query 1: Total perusahaan dari perusahaan_batubara dengan filter provinsi jika ada
    $where_conditions_total = array("sk_iup IS NOT NULL", "sk_iup != ''");

    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        // Join dengan provinsi untuk filter provinsi
        $sql_total = "SELECT COUNT(DISTINCT pb.sk_iup) as total 
                      FROM perusahaan_batubara pb 
                      LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi 
                      WHERE pb.sk_iup IS NOT NULL AND pb.sk_iup != '' 
                      AND COALESCE(pb.is_active, 1) = 1
                      AND prov.nama_provinsi = '$provinsi'";
    } else {
        $sql_total = "SELECT COUNT(DISTINCT sk_iup) as total FROM perusahaan_batubara WHERE sk_iup IS NOT NULL AND sk_iup != '' AND COALESCE(is_active, 1) = 1";
    }

    $result_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($result_total && $row_total = $result_total->fetch_assoc()) {
        $total_perusahaan = $row_total['total'];
    }

    // Query 2: Perusahaan yang sudah melaporkan dari vlaporan_batubara2 dengan semua filter
    $where_conditions = array("sk_iup NOT IN (SELECT sk_iup FROM perusahaan_batubara WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')");
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "tahun_1_7 = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan != 'semua') {
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
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions[] = "nama_provinsi = '$provinsi'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        $jp_clean = escapeString(trim($jenis_perizinan));
        $where_conditions[] = "jenis_perizinan_1_1 = '$jp_clean'";
    }

    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions) . ' AND ';
    } else {
        $where_clause = 'WHERE ';
    }

    // Query dengan GROUP BY untuk menghitung unique sk_iup (Perusahaan Sudah Lapor)
    $sql_lapor = "SELECT COUNT(*) as sudah_lapor 
                  FROM (
                      SELECT sk_iup 
                      FROM vlaporan_batubara2 
                      {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                      GROUP BY sk_iup
                  ) as unique_reports";
    $result_lapor = executeQuery($sql_lapor);
    $sudah_melaporkan = 0;
    if ($result_lapor && $row_lapor = $result_lapor->fetch_assoc()) {
        $sudah_melaporkan = $row_lapor['sudah_lapor'];
    }

    // Query 3: Hitung perusahaan yang belum melaporkan
    // Menggunakan NOT IN dengan subquery yang konsisten
    $provinsi_filter = '';
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi_filter = " AND prov.nama_provinsi = '" . escapeString($provinsi) . "'";
    }

    $sql_belum_lapor = "SELECT COUNT(DISTINCT pb.sk_iup) as belum_lapor
                        FROM perusahaan_batubara pb
                        LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi
                        WHERE pb.sk_iup IS NOT NULL 
                        AND pb.sk_iup != ''
                        AND COALESCE(pb.is_active, 1) = 1
                        $provinsi_filter
                        AND pb.sk_iup NOT IN (
                            SELECT sk_iup 
                            FROM (
                                SELECT sk_iup
                                FROM vlaporan_batubara2 
                                {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                                GROUP BY sk_iup
                            ) as sudah_lapor_unique
                        )";

    $result_belum = executeQuery($sql_belum_lapor);
    $belum_melaporkan = 0;
    if ($result_belum && $row_belum = $result_belum->fetch_assoc()) {
        $belum_melaporkan = $row_belum['belum_lapor'];
    }

    // Total dokumen (Laporan Masuk)
    $sql_dokumen = "SELECT COUNT(*) as total_dokumen FROM vlaporan_batubara2 {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''";
    $result_dokumen = executeQuery($sql_dokumen);
    $total_dokumen = 0;
    if ($result_dokumen && $row_dokumen = $result_dokumen->fetch_assoc()) {
        $total_dokumen = $row_dokumen['total_dokumen'];
    }

    // Hitung perusahaan non-aktif
    if (!empty($provinsi) && $provinsi != 'semua') {
        $prov_esc = escapeString($provinsi);
        $sql_nonaktif = "SELECT COUNT(DISTINCT pb.sk_iup) as total_nonaktif
                         FROM perusahaan_batubara pb
                         LEFT JOIN provinsi prov ON pb.id_provinsi = prov.id_provinsi
                         WHERE pb.sk_iup IS NOT NULL AND pb.sk_iup != ''
                         AND COALESCE(pb.is_active, 1) = 0
                         AND prov.nama_provinsi = '$prov_esc'";
    } else {
        $sql_nonaktif = "SELECT COUNT(DISTINCT sk_iup) as total_nonaktif FROM perusahaan_batubara WHERE sk_iup IS NOT NULL AND sk_iup != '' AND COALESCE(is_active, 1) = 0";
    }
    $res_nonaktif = executeQuery($sql_nonaktif);
    $total_nonaktif = 0;
    if ($res_nonaktif && $row_na = $res_nonaktif->fetch_assoc()) {
        $total_nonaktif = intval($row_na['total_nonaktif']);
    }

    // Return sebagai object, persis lmineral.php (sebelumnya array/mysqli_result)
    return (object) [
        'total_perusahaan' => $total_perusahaan,
        'perusahaan_sudah_lapor' => $sudah_melaporkan,
        'belum_lapor' => $belum_melaporkan,
        'non_aktif' => $total_nonaktif,
        'sudah_lapor' => $total_dokumen // total laporan masuk
    ];
}

/**
 * Fungsi untuk mendapatkan daftar perusahaan berdasarkan status
 */
function getDaftarPerusahaan($status = 'all', $provinsi = '', $tahun = '', $triwulan = '', $jenis_perizinan = '')
{
    $where_conditions = array();

    // Filter provinsi jika ada
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions[] = "pb.id_provinsi IN (SELECT id_provinsi FROM provinsi WHERE nama_provinsi = '$provinsi')";
    }

    // Buat kondisi untuk laporan yang sudah sesuai filter
    $laporan_condition_parts = array("nama_perusahaan IS NOT NULL");

    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $laporan_condition_parts[] = "tahun_1_7 = '" . escapeString($tahun) . "'";
    }

    // Filter triwulan
    if (!empty($triwulan) && $triwulan != 'semua') {
        switch ($triwulan) {
            case '1':
                $laporan_condition_parts[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                break;
            case '2':
                $laporan_condition_parts[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                break;
            case '3':
                $laporan_condition_parts[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                break;
            case '4':
                $laporan_condition_parts[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                break;
        }
    }

    // Filter jenis perizinan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        $jp_esc = escapeString($jenis_perizinan);
        $laporan_condition_parts[] = "jenis_perizinan_1_1 = '$jp_esc'";
    }

    $laporan_condition = implode(' AND ', $laporan_condition_parts);

    // Query berbeda berdasarkan status
    if ($status == 'belum_lapor') {
        // Untuk yang belum lapor, ambil perusahaan aktif yang tidak ada di laporan sesuai filter
        $where_conditions[] = "COALESCE(pb.is_active, 1) = 1";
        $where_conditions[] = "pb.sk_iup NOT IN (
            SELECT DISTINCT sk_iup 
            FROM vlaporan_batubara2 
            WHERE $laporan_condition
        )";

        // Gabungkan kondisi WHERE
        $where_clause = '';
        if (!empty($where_conditions)) {
            $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
        }

        $sql = "SELECT DISTINCT
                    pb.nama_perusahaan,
                    pb.sk_iup,
                    pb.jenis_izin,
                    pb.komoditas,
                    p.nama_provinsi,
                    'Belum Lapor' as status_laporan,
                    NULL as tahun_1_7,
                    NULL as waktu_input_8
                FROM perusahaan_batubara pb
                LEFT JOIN provinsi p ON pb.id_provinsi = p.id_provinsi
                $where_clause
                ORDER BY p.nama_provinsi, pb.nama_perusahaan";

    } elseif ($status == 'sudah_lapor') {
        // Untuk yang sudah lapor sesuai filter - ambil perusahaan unik (GROUP BY)
        $where_conditions_laporan = array();
        $where_conditions_laporan[] = "nama_provinsi IS NOT NULL";
        $where_conditions_laporan[] = "nama_perusahaan IS NOT NULL";

        // Filter provinsi
        if (!empty($provinsi) && $provinsi != 'semua') {
            $provinsi = escapeString($provinsi);
            $where_conditions_laporan[] = "nama_provinsi = '$provinsi'";
        }

        // Filter tahun
        if (!empty($tahun) && $tahun != 'semua') {
            $where_conditions_laporan[] = "tahun_1_7 = '" . escapeString($tahun) . "'";
        }

        // Filter triwulan
        if (!empty($triwulan) && $triwulan != 'semua') {
            switch ($triwulan) {
                case '1':
                    $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                    break;
                case '2':
                    $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                    break;
                case '3':
                    $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                    break;
                case '4':
                    $where_conditions_laporan[] = "waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                    break;
            }
        }

        // Filter jenis perizinan
        if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
            $jp_esc = escapeString($jenis_perizinan);
            $where_conditions_laporan[] = "jenis_perizinan_1_1 = '$jp_esc'";
        }

        // Gabungkan kondisi WHERE
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions_laporan);

        // Query menggunakan GROUP BY agar unik per perusahaan
        $sql = "SELECT 
                    MAX(nama_perusahaan) as nama_perusahaan,
                    sk_iup,
                    MAX(jenis_perizinan_1_1) as jenis_izin,
                    '' as komoditas,
                    MAX(nama_provinsi) as nama_provinsi,
                    'Sudah Lapor' as status_laporan,
                    MAX(tahun_1_7) as tahun_1_7,
                    MAX(waktu_perlaporan_laporan_1_6) as triwulan,
                    MAX(waktu_input_8) as waktu_input_8
                FROM vlaporan_batubara2
                $where_clause
                GROUP BY sk_iup
                ORDER BY nama_provinsi, nama_perusahaan";

    } else {
        // Untuk total/all - tampilkan semua perusahaan dengan status dinamis
        // Gabungkan kondisi WHERE (hanya filter provinsi)
        $where_clause = '';
        if (!empty($where_conditions)) {
            $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
        }

        // Buat kondisi untuk status laporan dengan semua filter
        $status_condition = "vlb.sk_iup IS NOT NULL";

        // Filter tahun untuk status
        if (!empty($tahun) && $tahun != 'semua') {
            $status_condition .= " AND vlb.tahun_1_7 = '" . escapeString($tahun) . "'";
        }

        // Filter triwulan untuk status
        if (!empty($triwulan) && $triwulan != 'semua') {
            switch ($triwulan) {
                case '1':
                    $status_condition .= " AND vlb.waktu_perlaporan_laporan_1_6 = 'Triwulan I'";
                    break;
                case '2':
                    $status_condition .= " AND vlb.waktu_perlaporan_laporan_1_6 = 'Triwulan II'";
                    break;
                case '3':
                    $status_condition .= " AND vlb.waktu_perlaporan_laporan_1_6 = 'Triwulan III'";
                    break;
                case '4':
                    $status_condition .= " AND vlb.waktu_perlaporan_laporan_1_6 = 'Triwulan IV'";
                    break;
            }
        }

        $sql = "SELECT 
                    MAX(pb.nama_perusahaan) as nama_perusahaan,
                    pb.sk_iup,
                    MAX(pb.jenis_izin) as jenis_izin,
                    MAX(pb.komoditas) as komoditas,
                    MAX(p.nama_provinsi) as nama_provinsi,
                    MAX(CASE 
                        WHEN $status_condition THEN 'Sudah Lapor'
                        ELSE 'Belum Lapor'
                    END) as status_laporan,
                    MAX(vlb.tahun_1_7) as tahun_1_7,
                    MAX(vlb.waktu_input_8) as waktu_input_8
                FROM perusahaan_batubara pb
                LEFT JOIN provinsi p ON pb.id_provinsi = p.id_provinsi
                LEFT JOIN vlaporan_batubara2 vlb ON pb.sk_iup = vlb.sk_iup
                $where_clause
                GROUP BY pb.sk_iup
                ORDER BY nama_provinsi, nama_perusahaan";
    }

    return executeQuery($sql);
}

/**
 * Fungsi untuk mendapatkan Total Keseluruhan (Grand Total) kolom numerik
 * Berdasarkan filter pencarian aktif (untuk semua halaman/paging dari database)
 */
function getGrandTotalLaporanBatubara($nama_perusahaan = '', $provinsi = '', $triwulan = '', $tahun = '', $status_produksi = array(), $jenis_perizinan = '')
{
    $where_conditions = array();
    $where_conditions[] = "nama_provinsi IS NOT NULL";
    $where_conditions[] = "nama_perusahaan IS NOT NULL";

    if (!empty($nama_perusahaan) && trim($nama_perusahaan) != '') {
        $nama_perusahaan_esc = escapeString(trim($nama_perusahaan));
        $where_conditions[] = "nama_perusahaan LIKE '%$nama_perusahaan_esc%'";
    }

    if (!empty($provinsi) && $provinsi != 'semua' && trim($provinsi) != '') {
        $provinsi_esc = escapeString(trim($provinsi));
        $where_conditions[] = "nama_provinsi = '$provinsi_esc'";
    }

    if (!empty($tahun) && $tahun != 'semua' && trim($tahun) != '') {
        $tahun_esc = escapeString(trim($tahun));
        $where_conditions[] = "tahun_1_7 = '$tahun_esc'";
    }

    if (!empty($triwulan) && $triwulan != 'semua' && trim($triwulan) != '') {
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

    // Filter Jenis Perizinan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua' && trim($jenis_perizinan) != '') {
        $jp_esc = escapeString(trim($jenis_perizinan));
        $where_conditions[] = "jenis_perizinan_1_1 = '$jp_esc'";
    }

    // Filter Status Produksi (P = Sudah Produksi, BP = Belum Produksi)
    if (!empty($status_produksi) && is_array($status_produksi)) {
        $hasP = in_array('P', $status_produksi) || in_array('sudah', $status_produksi);
        $hasBP = in_array('BP', $status_produksi) || in_array('belum', $status_produksi);

        if ($hasP && !$hasBP) {
            // Hanya Sudah Produksi: tidak ada kata 'Belum produksi' di Sistem Penambangan
            $where_conditions[] = "(LOWER(COALESCE(sistem_penambangan_1_5, '')) NOT LIKE '%belum produksi%')";
        } elseif ($hasBP && !$hasP) {
            // Hanya Belum Produksi: ada kata 'Belum produksi' di Sistem Penambangan
            $where_conditions[] = "LOWER(sistem_penambangan_1_5) LIKE '%belum produksi%'";
        }
    }

    $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);

    // Hitung Grand Total keseluruhan untuk kolom tonase/kuantitas yang diminta:
    // BKR (col 19, 21, 28), CM (col 29 ada/tidak, 30, 32, 39), SHP (col 40, 42, 47), CTT (col 48, 50)
    $sql = "SELECT 
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
    FROM vlaporan_batubara2
    $where_clause";

    $result = executeQuery($sql);
    $totals = array();
    if ($result && $row = $result->fetch_assoc()) {
        foreach ($row as $k => $v) {
            if ($k === 'cm_ada_count' || $k === 'cm_tidak_count') {
                continue;
            }
            $colIdx = (int) str_replace('col_', '', $k);
            $totals[$colIdx] = (float) $v;
        }
        $totals[29] = array(
            'ada' => (int) ($row['cm_ada_count'] ?? 0),
            'tidak' => (int) ($row['cm_tidak_count'] ?? 0)
        );
    }
    return $totals;
}

// Proses pencarian parameter filter
$nama_perusahaan = isset($_POST['nama_perusahaan']) ? $_POST['nama_perusahaan'] : (isset($_GET['nama_perusahaan']) ? $_GET['nama_perusahaan'] : '');
$provinsi = isset($_POST['provinsi']) ? $_POST['provinsi'] : (isset($_GET['provinsi']) ? $_GET['provinsi'] : 'semua');
$triwulan = isset($_POST['triwulan']) ? $_POST['triwulan'] : (isset($_GET['triwulan']) ? $_GET['triwulan'] : 'semua');
$tahun = isset($_POST['tahun']) ? $_POST['tahun'] : (isset($_GET['tahun']) ? $_GET['tahun'] : 'semua');
$jenis_perizinan = isset($_POST['jenis_perizinan']) ? $_POST['jenis_perizinan'] : (isset($_GET['jenis_perizinan']) ? $_GET['jenis_perizinan'] : 'semua');

// Parameter Filter Objek
$filter_objek = isset($_POST['filter_objek']) ? $_POST['filter_objek'] : (isset($_GET['filter_objek']) ? $_GET['filter_objek'] : ['all']);
if (!is_array($filter_objek)) {
    $filter_objek = [$filter_objek];
}
$sub_filter = isset($_POST['sub_filter']) ? $_POST['sub_filter'] : (isset($_GET['sub_filter']) ? $_GET['sub_filter'] : ['bkr_kum', 'bkr_kuan', 'cm_kum', 'cm_kuan', 'ctt_kum', 'ctt_kuan', 'shp_kum', 'shp_kuan']);
if (!is_array($sub_filter)) {
    $sub_filter = [$sub_filter];
}

// Parameter Status Produksi (P = Sudah Produksi, BP = Belum Produksi)
$status_produksi = isset($_POST['status_produksi']) ? $_POST['status_produksi'] : (isset($_GET['status_produksi']) ? $_GET['status_produksi'] : ['P', 'BP']);
if (!is_array($status_produksi)) {
    $status_produksi = [$status_produksi];
}

$search_performed = true; // Selalu tampilkan data

// Dapatkan analisis perusahaan & statistik (Ringkas & Cepat tanpa fetch semua baris)
$analisis_perusahaan = getAnalisisPerusahaan($provinsi, $tahun, $triwulan, $jenis_perizinan);
$total_statistik = getTotalStatistikPerusahaan($provinsi, $tahun, $triwulan, $jenis_perizinan);

$total_records = 0;
if ($total_statistik) {
    $total_records = intval($total_statistik->sudah_lapor ?? 0);
}

// Hitung Grand Total keseluruhan untuk data yang sesuai filter
$grand_totals = getGrandTotalLaporanBatubara($nama_perusahaan, $provinsi, $triwulan, $tahun, $status_produksi, $jenis_perizinan);

// Get data untuk dropdown
$provinsi_list = getProvinsiList();
$tahun_list = getTahunList();
$jenis_perizinan_list = getJenisPerizinanList();

$jenis_perizinan_options = array();
if ($jenis_perizinan_list && $jenis_perizinan_list->num_rows > 0) {
    while ($row = $jenis_perizinan_list->fetch_assoc()) {
        $jp = trim($row['jenis_perizinan']);
        if (!empty($jp) && $jp != '-' && !in_array($jp, $jenis_perizinan_options)) {
            $jenis_perizinan_options[] = $jp;
        }
    }
}
if (empty($jenis_perizinan_options)) {
    $jenis_perizinan_options = ['IUP', 'IUPK', 'PKP2B', 'IPR'];
}
?>

<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laporan Batubara - Dashboard Minerba</title>

    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Bootstrap Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <!-- DataTables CSS -->
    <link href="https://cdn.datatables.net/1.13.0/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    <!-- DataTables FixedColumns CSS -->
    <link href="https://cdn.datatables.net/fixedcolumns/4.2.2/css/fixedColumns.bootstrap5.min.css" rel="stylesheet">

    <style>
        /* Logo ESDM Background Watermark */
        body {
            position: relative;
        }

        body::before {
            content: '' !important;
            position: fixed !important;
            top: 50% !important;
            left: 50% !important;
            transform: translate(-50%, -50%) !important;
            width: 400px !important;
            height: 400px !important;
            background-size: contain !important;
            background-repeat: no-repeat !important;
            background-position: center !important;
            opacity: 0.05 !important;
            z-index: 0 !important;
            pointer-events: none !important;
        }

        /* Ensure content is above watermark */
        .container,
        .card,
        .row,
        .table-responsive,
        .header-section {
            position: relative;
            z-index: 1;
        }

        /* Card Watermark - sama seperti form_input_laporan dan perusahaan_batubara */
        .card {
            position: relative;
            overflow: hidden;
        }

        .card::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 300px;
            height: 300px;
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            opacity: 0.08;
            z-index: 1;
            pointer-events: none;
        }

        .card>* {
            position: relative;
            z-index: 2;
        }

        /* Card body watermark tambahan */
        .card-body {
            position: relative;
        }

        .card-body::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 200px;
            height: 200px;
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            opacity: 0.03;
            z-index: 0;
            pointer-events: none;
        }

        .card-body>* {
            position: relative;
            z-index: 1;
        }

        /* Table watermark khusus */
        .table-responsive {
            position: relative;
        }

        .table-responsive::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 250px;
            height: 250px;
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            opacity: 0.02;
            z-index: 0;
            pointer-events: none;
        }

        .table-responsive>* {
            position: relative;
            z-index: 1;
        }

        /* Modal watermark */
        .modal-content {
            position: relative;
            overflow: hidden;
        }

        .modal-content::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 150px;
            height: 150px;
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            opacity: 0.04;
            z-index: 0;
            pointer-events: none;
        }

        .modal-content>* {
            position: relative;
            z-index: 1;
        }

        /* DataTables watermark khusus */
        .dataTables_wrapper {
            position: relative;
        }

        .dataTables_wrapper::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 200px;
            height: 200px;
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            opacity: 0.02;
            z-index: 0;
            pointer-events: none;
        }

        .dataTables_wrapper>* {
            position: relative;
            z-index: 1;
        }

        .header-section {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            position: relative;
            z-index: 1;
        }

        /* Watermark khusus untuk search card */
        .search-card::before {
            opacity: 0.06 !important;
        }

        /* Watermark khusus untuk stats card */
        .stats-card::before {
            opacity: 0.05 !important;
        }

        .search-card {
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
            border: 1px solid rgba(0, 0, 0, 0.125);
        }

        .stats-card {
            border-left: 4px solid #007bff;
        }

        .table-responsive {
            border-radius: 0.375rem;
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
        }

        .btn-search {
            background: linear-gradient(45deg, #007bff, #0056b3);
            border: none;
        }

        .btn-search:hover {
            background: linear-gradient(45deg, #0056b3, #004085);
            transform: translateY(-1px);
        }

        /* Fixed Columns Styling */
        .dtfc-fixed-left {
            background-color: #f8f9fa !important;
            border-right: 2px solid #dee2e6 !important;
        }

        .dtfc-fixed-left .table-dark th {
            background-color: #495057 !important;
            color: white !important;
            border-color: #dee2e6 !important;
        }

        .dtfc-fixed-left tbody tr {
            background-color: #ffffff !important;
        }

        .dtfc-fixed-left tbody tr:nth-child(even) {
            background-color: #f8f9fa !important;
        }

        .dtfc-fixed-left tbody tr:hover {
            background-color: #e9ecef !important;
        }

        /* Ensure fixed columns are visible */
        .table th:nth-child(1),
        .table td:nth-child(1),
        .table th:nth-child(2),
        .table td:nth-child(2),
        .table th:nth-child(3),
        .table td:nth-child(3),
        .table th:nth-child(4),
        .table td:nth-child(4),
        .table th:nth-child(5),
        .table td:nth-child(5) {
            background-color: #f8f9fa !important;
            font-weight: 500;
        }

        .table-dark th:nth-child(1),
        .table-dark th:nth-child(2),
        .table-dark th:nth-child(3),
        .table-dark th:nth-child(4),
        .table-dark th:nth-child(5) {
            background-color: #495057 !important;
            color: white !important;
        }

        /* Footer Table Styling */
        tfoot th {
            font-size: 0.85rem;
            vertical-align: middle;
            border-top: 2px solid #adb5bd !important;
        }

        .dtfc-fixed-left tfoot th {
            background-color: #343a40 !important;
            color: white !important;
        }

        /* Loading Animation Styles */
        .loading-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.95);
            z-index: 9999;
            display: none;
            align-items: center;
            justify-content: center;
            transition: all 0.3s ease;
        }

        .loading-content {
            text-align: center;
            background: white;
            padding: 2.5rem;
            border-radius: 20px;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.15);
            border: 1px solid #e9ecef;
            transform: scale(0.9);
            animation: fadeInScale 0.3s ease forwards;
        }

        @keyframes fadeInScale {
            to {
                transform: scale(1);
            }
        }

        .loading-spinner {
            width: 60px;
            height: 60px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid #007bff;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 0 auto 1.5rem;
        }

        .loading-text {
            font-size: 1.1rem;
            font-weight: 600;
            color: #333;
            margin-bottom: 0.5rem;
        }

        .loading-subtext {
            font-size: 0.9rem;
            color: #666;
            margin-bottom: 0;
        }

        @keyframes spin {
            0% {
                transform: rotate(0deg);
            }

            100% {
                transform: rotate(360deg);
            }
        }

        /* Enhanced Button Loading States */
        .btn-loading {
            position: relative;
            pointer-events: none;
            opacity: 0.7;
        }

        .btn-loading::before {
            content: '';
            position: absolute;
            left: 50%;
            top: 50%;
            transform: translate(-50%, -50%);
            width: 16px;
            height: 16px;
            border: 2px solid transparent;
            border-top: 2px solid currentColor;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }

        /* Prevent scrolling when loading */
        body.loading-active {
            overflow: hidden;
        }

        /* Smooth transitions */
        .btn {
            transition: all 0.2s ease;
        }

        .card {
            transition: box-shadow 0.2s ease;
        }

        .card:hover {
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .loading-text {
            color: #495057;
            font-weight: 500;
            margin: 0;
        }

        .loading-subtext {
            color: #6c757d;
            font-size: 0.9rem;
            margin: 0.5rem 0 0;
        }

        /* Table Loading */
        .table-loading {
            position: relative;
        }

        .table-loading::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.8);
            z-index: 10;
        }

        /* Button Loading */
        .btn-loading {
            position: relative;
            pointer-events: none;
        }

        .btn-loading::after {
            content: '';
            position: absolute;
            width: 16px;
            height: 16px;
            margin: auto;
            border: 2px solid transparent;
            border-top-color: #ffffff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            top: 0;
            left: 0;
            bottom: 0;
            right: 0;
        }
    </style>

    <!-- Pre-loading Script -->
    <script>
        // Show loading immediately when page starts loading
        document.addEventListener('DOMContentLoaded', function () {
            const loadingOverlay = document.getElementById('loadingOverlay');
            if (loadingOverlay) {
                loadingOverlay.style.display = 'flex';
            }
        });

        // Show loading on page load start
        window.addEventListener('beforeunload', function () {
            const loadingOverlay = document.getElementById('loadingOverlay');
            if (loadingOverlay) {
                loadingOverlay.style.display = 'flex';
            }
        });
    </script>
</head>

<body class="bg-light">

    <!-- Loading Overlay -->
    <div id="loadingOverlay" class="loading-overlay">
        <div class="loading-content">
            <div class="loading-spinner"></div>
            <p class="loading-text">Memuat Data...</p>
            <p class="loading-subtext">Mohon tunggu sebentar</p>
        </div>
    </div>

    <!-- Header -->
    <div class="header-section">
        <div class="container">
            <div class="row align-items-center">
                <div class="col-md-7">
                    <h1 class="mb-0"><i class="bi bi-file-earmark-bar-graph"></i> Laporan Batubara</h1>
                    <p class="mb-0 mt-2 opacity-75">Sistem Pelaporan Berkala Pertambangan Batubara</p>
                </div>
                <div class="col-md-5 text-md-end">
                    <div class="d-flex flex-column align-items-end gap-2">
                        <span class="badge bg-light text-dark fs-6">
                            <i class="bi bi-calendar3"></i> <?php echo formatTanggal(date('Y-m-d')); ?>
                        </span>
                        <div class="d-flex align-items-center gap-2">
                            <a href="ai_batubara.php"
                                class="btn btn-success btn-sm rounded-pill text-white px-3 fw-bold me-2 shadow-sm"
                                title="Asisten AI SIMINERBA">
                                <i class="bi bi-robot me-1 fs-6"></i> Asisten AI
                            </a>
                            <span class="badge bg-light text-dark fs-6">
                                <i class="bi bi-person-circle"></i>
                                <strong><?php echo htmlspecialchars($_SESSION['username']); ?></strong>
                            </span>
                            <a href="logoutb.php" class="btn btn-outline-light btn-sm">
                                <i class="bi bi-box-arrow-right"></i> Logout
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="container mt-4">

        <!-- Link Asisten AI -->
        <div class="d-flex justify-content-end mb-3">
            <a href="ai_batubara.php"
                class="btn btn-success shadow rounded-pill px-4 text-white d-flex align-items-center gap-2 fw-bold"
                style="background: linear-gradient(135deg, #10a37f 0%, #059669 100%); border: none;">
                <i class="bi bi-robot fs-5"></i>
                <span>Buka Asisten AI Batubara</span>
            </a>
        </div>

        <!-- Form Pencarian -->
        <div class="card search-card mb-4">
            <div class="card-header bg-primary text-white">
                <h5 class="mb-0"><i class="bi bi-search"></i> Filter Pencarian Data</h5>
            </div>
            <div class="card-body">
                <form method="POST" action="" class="row g-3">

                    <!-- Nama Perusahaan -->
                    <div class="col-md-4">
                        <label for="nama_perusahaan" class="form-label">
                            <i class="bi bi-building"></i> Nama Perusahaan
                        </label>
                        <input type="text" class="form-control" id="nama_perusahaan" name="nama_perusahaan"
                            placeholder="Ketik nama perusahaan..."
                            value="<?php echo isset($nama_perusahaan) ? htmlspecialchars($nama_perusahaan) : ''; ?>">
                    </div>

                    <!-- Provinsi -->
                    <div class="col-md-4">
                        <label for="provinsi" class="form-label">
                            <i class="bi bi-geo-alt"></i> Provinsi
                        </label>
                        <select class="form-select" id="provinsi" name="provinsi">
                            <option value="semua" <?php echo (!isset($provinsi) || $provinsi == 'semua') ? 'selected' : ''; ?>>-- Semua Provinsi --</option>
                            <?php
                            if ($provinsi_list && $provinsi_list->num_rows > 0) {
                                while ($row = $provinsi_list->fetch_assoc()) {
                                    $selected = (isset($provinsi) && $provinsi == $row['nama_provinsi']) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($row['nama_provinsi'] ?? '') . "' $selected>" .
                                        htmlspecialchars($row['nama_provinsi'] ?? '') . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>

                    <!-- Jenis Perizinan -->
                    <div class="col-md-4">
                        <label for="jenis_perizinan" class="form-label">
                            <i class="bi bi-card-checklist text-primary"></i> Jenis Perizinan
                        </label>
                        <select class="form-select" id="jenis_perizinan" name="jenis_perizinan">
                            <option value="semua" <?php echo (!isset($jenis_perizinan) || $jenis_perizinan == 'semua') ? 'selected' : ''; ?>>-- Semua Perizinan --</option>
                            <?php
                            if (!empty($jenis_perizinan_options)) {
                                foreach ($jenis_perizinan_options as $jp_opt) {
                                    $selected = (isset($jenis_perizinan) && $jenis_perizinan == $jp_opt) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($jp_opt) . "' $selected>" .
                                        htmlspecialchars($jp_opt) . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>

                    <!-- Triwulan -->
                    <div class="col-md-6">
                        <label for="triwulan" class="form-label">
                            <i class="bi bi-calendar3"></i> Triwulan
                        </label>
                        <select class="form-select" id="triwulan" name="triwulan">
                            <option value="semua" <?php echo (!isset($triwulan) || $triwulan == 'semua') ? 'selected' : ''; ?>>-- Semua Triwulan --</option>
                            <option value="1" <?php echo (isset($triwulan) && $triwulan == '1') ? 'selected' : ''; ?>>
                                Triwulan I
                            </option>
                            <option value="2" <?php echo (isset($triwulan) && $triwulan == '2') ? 'selected' : ''; ?>>
                                Triwulan II
                            </option>
                            <option value="3" <?php echo (isset($triwulan) && $triwulan == '3') ? 'selected' : ''; ?>>
                                Triwulan III
                            </option>
                            <option value="4" <?php echo (isset($triwulan) && $triwulan == '4') ? 'selected' : ''; ?>>
                                Triwulan IV
                            </option>
                        </select>
                    </div>

                    <!-- Tahun -->
                    <div class="col-md-6">
                        <label for="tahun" class="form-label">
                            <i class="bi bi-calendar-year"></i> Tahun
                        </label>
                        <select class="form-select" id="tahun" name="tahun">
                            <option value="semua" <?php echo (!isset($tahun) || $tahun == 'semua') ? 'selected' : ''; ?>>
                                -- Semua Tahun --</option>
                            <?php
                            if ($tahun_list && $tahun_list->num_rows > 0) {
                                while ($row = $tahun_list->fetch_assoc()) {
                                    $selected = (isset($tahun) && $tahun == $row['tahun']) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($row['tahun'] ?? '') . "' $selected>" .
                                        htmlspecialchars($row['tahun'] ?? '') . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>

                    <!-- Filter Objek Section -->
                    <div class="col-12">
                        <div class="card border-primary border-opacity-25 shadow-sm rounded-3 mt-2 bg-light">
                            <div
                                class="card-header bg-white border-bottom py-2 d-flex justify-content-between align-items-center">
                                <span class="fw-bold text-primary d-flex align-items-center gap-2">
                                    <i class="bi bi-funnel-fill"></i> Filter Objek :
                                </span>
                                <div class="d-flex align-items-center gap-2">
                                    <button type="button" class="btn btn-outline-primary btn-sm py-0 px-2"
                                        id="btnSelectAllObjek" style="font-size: 0.8rem;">
                                        <i class="bi bi-check-all"></i> Pilih Semua
                                    </button>
                                    <button type="button" class="btn btn-outline-secondary btn-sm py-0 px-2"
                                        id="btnResetObjek" style="font-size: 0.8rem;">
                                        <i class="bi bi-arrow-counterclockwise"></i> Reset Objek
                                    </button>
                                </div>
                            </div>
                            <div class="card-body p-3">
                                <div class="row g-3">
                                    <!-- Kolom 1: Recovery Penambangan, Recovery Pengolahan, & Status Produksi -->
                                    <div class="col-lg-3 col-md-6">
                                        <div class="p-2 h-100 bg-white rounded border border-light-subtle d-flex flex-column justify-content-between">
                                            <div>
                                                <div class="form-check mb-3">
                                                    <input class="form-check-input filter-objek-checkbox main-objek"
                                                        type="checkbox" name="filter_objek[]" id="objek_rec_tambang"
                                                        value="rec_tambang" <?php echo (in_array('all', $filter_objek) || in_array('rec_tambang', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_rec_tambang">
                                                        Recovery Penambangan
                                                    </label>
                                                </div>
                                                <div class="form-check mb-3">
                                                    <input class="form-check-input filter-objek-checkbox main-objek"
                                                        type="checkbox" name="filter_objek[]" id="objek_rec_olah"
                                                        value="rec_olah" <?php echo (in_array('all', $filter_objek) || in_array('rec_olah', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_rec_olah">
                                                        Recovery Pengolahan
                                                    </label>
                                                </div>
                                            </div>

                                            <!-- Filter Status Produksi (P & BP) sesuai tanda kotak oranye -->
                                            <div class="pt-2 border-top border-2 border-warning rounded p-2 mt-2 bg-light">
                                                <div class="d-flex align-items-center justify-content-between mb-2">
                                                    <span class="small fw-bold text-dark">
                                                        <i class="bi bi-funnel-fill text-warning"></i> Status Produksi:
                                                    </span>
                                                </div>
                                                <div class="form-check mb-2">
                                                    <input class="form-check-input filter-status-produksi"
                                                        type="checkbox" name="status_produksi[]" id="status_prod_p"
                                                        value="P" <?php echo (empty($status_produksi) || in_array('P', $status_produksi)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark small" for="status_prod_p">
                                                        Sudah Produksi <span class="badge bg-success-subtle text-success border border-success-subtle ms-1" style="font-size: 0.72rem;">P</span>
                                                    </label>
                                                </div>
                                                <div class="form-check mb-0">
                                                    <input class="form-check-input filter-status-produksi"
                                                        type="checkbox" name="status_produksi[]" id="status_prod_bp"
                                                        value="BP" <?php echo (empty($status_produksi) || in_array('BP', $status_produksi)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark small" for="status_prod_bp">
                                                        Belum Produksi <span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle ms-1" style="font-size: 0.72rem;">BP</span>
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Kolom 2: Batubara Kualitas Rendah & Cadangan Marginal -->
                                    <div class="col-lg-3 col-md-6">
                                        <div class="p-2 h-100 bg-white rounded border border-light-subtle">
                                            <!-- Batubara Kualitas Rendah -->
                                            <div class="mb-3">
                                                <div class="form-check">
                                                    <input
                                                        class="form-check-input filter-objek-checkbox main-objek has-sub"
                                                        type="checkbox" name="filter_objek[]" id="objek_bkr" value="bkr"
                                                        data-parent="bkr" <?php echo (in_array('all', $filter_objek) || in_array('bkr', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_bkr">
                                                        Batubara Kualitas Rendah
                                                    </label>
                                                </div>
                                                <div class="ms-4 ps-2 border-start border-2 border-primary-subtle mt-1">
                                                    <div class="form-check py-0 mb-1">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_bkr_kum"
                                                            value="bkr_kum" data-child-of="bkr" <?php echo (in_array('all', $filter_objek) || in_array('bkr_kum', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_bkr_kum">
                                                            ▪ Kumulatif (Tonase)
                                                        </label>
                                                    </div>
                                                    <div class="form-check py-0">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_bkr_kuan"
                                                            value="bkr_kuan" data-child-of="bkr" <?php echo (in_array('all', $filter_objek) || in_array('bkr_kuan', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_bkr_kuan">
                                                            ▪ Kuantitatif (Triwulan) (Tonase)
                                                        </label>
                                                    </div>
                                                </div>
                                            </div>

                                            <!-- Cadangan Marginal -->
                                            <div>
                                                <div class="form-check">
                                                    <input
                                                        class="form-check-input filter-objek-checkbox main-objek has-sub"
                                                        type="checkbox" name="filter_objek[]" id="objek_cm" value="cm"
                                                        data-parent="cm" <?php echo (in_array('all', $filter_objek) || in_array('cm', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_cm">
                                                        Cadangan Marginal
                                                    </label>
                                                </div>
                                                <div class="ms-4 ps-2 border-start border-2 border-primary-subtle mt-1">
                                                    <div class="form-check py-0 mb-1">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_cm_kum"
                                                            value="cm_kum" data-child-of="cm" <?php echo (in_array('all', $filter_objek) || in_array('cm_kum', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_cm_kum">
                                                            ▪ Kumulatif (Tonase)
                                                        </label>
                                                    </div>
                                                    <div class="form-check py-0">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_cm_kuan"
                                                            value="cm_kuan" data-child-of="cm" <?php echo (in_array('all', $filter_objek) || in_array('cm_kuan', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_cm_kuan">
                                                            ▪ Kuantitatif (Triwulan) (Tonase)
                                                        </label>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Kolom 3: Cadangan Tidak Tertambang & Sisa Hasil Pengolahan -->
                                    <div class="col-lg-3 col-md-6">
                                        <div class="p-2 h-100 bg-white rounded border border-light-subtle">
                                            <!-- Cadangan Tidak Tertambang -->
                                            <div class="mb-3">
                                                <div class="form-check">
                                                    <input
                                                        class="form-check-input filter-objek-checkbox main-objek has-sub"
                                                        type="checkbox" name="filter_objek[]" id="objek_ctt" value="ctt"
                                                        data-parent="ctt" <?php echo (in_array('all', $filter_objek) || in_array('ctt', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_ctt">
                                                        Cadangan Tidak Tertambang
                                                    </label>
                                                </div>
                                                <div class="ms-4 ps-2 border-start border-2 border-primary-subtle mt-1">
                                                    <div class="form-check py-0 mb-1">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_ctt_kum"
                                                            value="ctt_kum" data-child-of="ctt" <?php echo (in_array('all', $filter_objek) || in_array('ctt_kum', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_ctt_kum">
                                                            ▪ Kumulatif (Tonase)
                                                        </label>
                                                    </div>
                                                    <div class="form-check py-0">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_ctt_kuan"
                                                            value="ctt_kuan" data-child-of="ctt" <?php echo (in_array('all', $filter_objek) || in_array('ctt_kuan', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_ctt_kuan">
                                                            ▪ Kuantitatif (Triwulan) (Tonase)
                                                        </label>
                                                    </div>
                                                </div>
                                            </div>

                                            <!-- Sisa Hasil Pengolahan -->
                                            <div>
                                                <div class="form-check">
                                                    <input
                                                        class="form-check-input filter-objek-checkbox main-objek has-sub"
                                                        type="checkbox" name="filter_objek[]" id="objek_shp" value="shp"
                                                        data-parent="shp" <?php echo (in_array('all', $filter_objek) || in_array('shp', $filter_objek)) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-semibold text-dark"
                                                        for="objek_shp">
                                                        Sisa Hasil Pengolahan
                                                    </label>
                                                </div>
                                                <div class="ms-4 ps-2 border-start border-2 border-primary-subtle mt-1">
                                                    <div class="form-check py-0 mb-1">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_shp_kum"
                                                            value="shp_kum" data-child-of="shp" <?php echo (in_array('all', $filter_objek) || in_array('shp_kum', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_shp_kum">
                                                            ▪ Kumulatif (Tonase)
                                                        </label>
                                                    </div>
                                                    <div class="form-check py-0">
                                                        <input class="form-check-input filter-objek-checkbox sub-item"
                                                            type="checkbox" name="sub_filter[]" id="sub_shp_kuan"
                                                            value="shp_kuan" data-child-of="shp" <?php echo (in_array('all', $filter_objek) || in_array('shp_kuan', $sub_filter)) ? 'checked' : ''; ?>>
                                                        <label class="form-check-label text-primary small"
                                                            for="sub_shp_kuan">
                                                            ▪ Kuantitatif (Triwulan) (Tonase)
                                                        </label>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Kolom 4: Semua Objek & Info Data Dasar -->
                                    <div class="col-lg-3 col-md-6">
                                        <div
                                            class="p-3 h-100 bg-white rounded border border-light-subtle d-flex flex-column justify-content-between">
                                            <div>
                                                <div
                                                    class="form-check p-2 bg-primary-subtle rounded border border-primary-subtle mb-3">
                                                    <input class="form-check-input ms-1 me-2 filter-objek-checkbox"
                                                        type="checkbox" name="filter_objek[]" id="objek_all" value="all"
                                                        <?php echo in_array('all', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label fw-bold text-primary"
                                                        for="objek_all">
                                                        Semua Objek (All Objek)
                                                    </label>
                                                </div>
                                                <div class="alert alert-light border py-2 px-2 mb-0"
                                                    style="font-size: 0.78rem;">
                                                    <i class="bi bi-info-circle text-primary"></i>
                                                    <strong>Data Dasar Tetap Ada:</strong><br>
                                                    <span class="badge bg-secondary">No</span>
                                                    <span class="badge bg-info text-dark">Provinsi</span>
                                                    <span class="badge bg-primary">Nama Perusahaan</span>
                                                    <span class="badge bg-secondary">Triwulan</span>
                                                    <span class="badge bg-dark">Tahun</span>
                                                    <span class="badge bg-success">Jenis Perizinan</span>
                                                </div>
                                            </div>
                                            <div class="mt-2 text-muted" style="font-size: 0.75rem;">
                                                <i class="bi bi-lightbulb"></i> Kolom tabel akan otomatis disesuaikan
                                                berdasarkan filter objek yang dipilih.
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Tombol Aksi -->
                    <div class="col-12">
                        <button type="submit" class="btn btn-search btn-primary btn-lg">
                            <i class="bi bi-search"></i> Cari Data
                        </button>
                        <a href="lbatubara.php" class="btn btn-outline-secondary btn-lg ms-2">
                            <i class="bi bi-arrow-clockwise"></i> Reset
                        </a>
                        <?php if ($search_performed && $total_records > 0): ?>
                            <button type="button" class="btn btn-success btn-lg ms-2"
                                onclick="exportToCSV('laporan_batubara')">
                                <i class="bi bi-file-earmark-excel"></i> Export Excel
                            </button>
                        <?php endif; ?>
                    </div>
                </form>
            </div>
        </div>

        <?php if ($search_performed): ?>
            <!-- Statistik Hasil Pencarian -->
            <div class="row mb-4">
                <div class="col-md-12">
                    <div class="card stats-card">
                        <div class="card-body">
                            <div class="row align-items-center">
                                <div class="col-md-8">
                                    <h5 class="text-primary mb-1">
                                        <i class="bi bi-bar-chart-line"></i> Data Laporan Batubara
                                    </h5>
                                    <p class="mb-0">
                                        <?php
                                        $filter_active = (!empty($nama_perusahaan) && trim($nama_perusahaan) != '') ||
                                            (!empty($provinsi) && $provinsi != 'semua') ||
                                            (!empty($triwulan) && $triwulan != 'semua') ||
                                            (!empty($tahun) && $tahun != 'semua') ||
                                            (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') ||
                                            (!in_array('all', $filter_objek));
                                        $filter_count = 0;
                                        $filter_text = array();

                                        if (!empty($nama_perusahaan) && trim($nama_perusahaan) != '') {
                                            $filter_text[] = "Perusahaan: '" . htmlspecialchars($nama_perusahaan) . "'";
                                            $filter_count++;
                                        }
                                        if (!empty($provinsi) && $provinsi != 'semua') {
                                            $filter_text[] = "Provinsi: " . htmlspecialchars($provinsi);
                                            $filter_count++;
                                        }
                                        if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
                                            $filter_text[] = "Izin: " . htmlspecialchars($jenis_perizinan);
                                            $filter_count++;
                                        }
                                        if (!empty($tahun) && $tahun != 'semua') {
                                            $filter_text[] = "Tahun: " . htmlspecialchars($tahun);
                                            $filter_count++;
                                        }
                                        if (!empty($triwulan) && $triwulan != 'semua') {
                                            $triwulan_text = array('1' => 'Triwulan I', '2' => 'Triwulan II', '3' => 'Triwulan III', '4' => 'Triwulan IV');
                                            $filter_text[] = $triwulan_text[$triwulan];
                                            $filter_count++;
                                        }
                                        if (!in_array('all', $filter_objek)) {
                                            $objek_labels = [];
                                            if (in_array('rec_tambang', $filter_objek))
                                                $objek_labels[] = 'Recovery Penambangan';
                                            if (in_array('rec_olah', $filter_objek))
                                                $objek_labels[] = 'Recovery Pengolahan';
                                            if (in_array('bkr', $filter_objek))
                                                $objek_labels[] = 'Batubara Kualitas Rendah';
                                            if (in_array('cm', $filter_objek))
                                                $objek_labels[] = 'Cadangan Marginal';
                                            if (in_array('ctt', $filter_objek))
                                                $objek_labels[] = 'Cadangan Tidak Tertambang';
                                            if (in_array('shp', $filter_objek))
                                                $objek_labels[] = 'Sisa Hasil Pengolahan';
                                            if (!empty($objek_labels)) {
                                                $filter_text[] = "Objek: " . implode(', ', $objek_labels);
                                                $filter_count++;
                                            }
                                        }

                                        if ($filter_active && $filter_count > 0): ?>
                                            Hasil pencarian dengan filter:
                                            <strong><?php echo implode(' | ', $filter_text); ?></strong><br>
                                            Ditemukan <strong><?php echo formatNumber($total_records); ?></strong> data dari
                                            <?php echo $filter_count; ?> filter aktif
                                        <?php else: ?>
                                            Menampilkan <strong><?php echo formatNumber($total_records); ?></strong> total data
                                            laporan (tanpa filter)
                                        <?php endif; ?>
                                    </p>
                                </div>
                                <div class="col-md-4 text-md-end">
                                    <div class="btn-group">
                                        <button class="btn btn-outline-success" onclick="exportToExcel()">
                                            <i class="bi bi-file-earmark-excel"></i> Export Excel
                                        </button>
                                        <button class="btn btn-outline-primary" onclick="window.print()">
                                            <i class="bi bi-printer"></i> Print
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Analisis Perusahaan Section -->
            <div class="row mb-4">
                <div class="col-md-12">
                    <div class="card">
                        <div class="card-header bg-success text-white">
                            <h5 class="mb-0">
                                <i class="bi bi-building"></i> Analisis Perusahaan - Status Pelaporan
                                <?php
                                $header_filters = array();
                                if (!empty($provinsi) && $provinsi != 'semua') {
                                    $header_filters[] = htmlspecialchars($provinsi);
                                }
                                if (!empty($tahun) && $tahun != 'semua') {
                                    $header_filters[] = "Tahun " . htmlspecialchars($tahun);
                                }
                                if (!empty($triwulan) && $triwulan != 'semua') {
                                    $triwulan_names = array('1' => 'Triwulan I', '2' => 'Triwulan II', '3' => 'Triwulan III', '4' => 'Triwulan IV');
                                    $header_filters[] = $triwulan_names[$triwulan];
                                }
                                if (!empty($header_filters)) {
                                    echo ' - ' . implode(', ', $header_filters);
                                }
                                ?>
                            </h5>
                        </div>
                        <div class="card-body">
                            <?php
                            // Tampilkan statistik total
                            if ($total_statistik):
                                // Perusahaan unik yang sudah lapor
                                $perusahaan_sudah_lapor = intval($total_statistik->perusahaan_sudah_lapor ?? 0);

                                // Hitung belum lapor yang benar:
                                $belum_lapor_sederhana = intval($total_statistik->belum_lapor ?? 0);

                                // Hitung persentase berdasarkan perusahaan unik yang sudah lapor
                                $total_perush = intval($total_statistik->total_perusahaan ?? 0);
                                $non_aktif_count = intval($total_statistik->non_aktif ?? 0);
                                $persentase_total = $total_perush > 0 ?
                                    round(($perusahaan_sudah_lapor * 100) / $total_perush, 2) : 0;
                                ?>
                                <!-- Info Caption untuk Filter -->
                                <div class="alert alert-info alert-dismissible fade show" role="alert">
                                    <i class="bi bi-info-circle-fill"></i>
                                    <strong>Tips:</strong> Gunakan filter <strong>"Cari Data"</strong> di atas (Provinsi,
                                    Triwulan, Tahun) untuk mendapatkan data yang lebih presisi dan spesifik sesuai kebutuhan
                                    Anda.
                                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                                </div>

                                <!-- Summary Cards -->
                                <div class="row row-cols-1 row-cols-md-5 g-3 mb-4">
                                    <div class="col">
                                        <div class="card border-primary h-100" style="cursor: pointer;"
                                            onclick="showModal('total', '<?php echo $provinsi; ?>', '<?php echo $tahun; ?>', '<?php echo $triwulan; ?>', '<?php echo $jenis_perizinan; ?>')">
                                            <div class="card-body text-center">
                                                <h3 class="text-primary"><?php echo formatNumber($total_perush); ?></h3>
                                                <p class="text-muted mb-0">Perusahaan Wajib Lapor (Aktif)</p>
                                                <small class="text-muted"><i class="bi bi-hand-index"></i> Klik untuk
                                                    detail</small>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col">
                                        <div class="card border-success h-100" style="cursor: pointer;"
                                            onclick="showModal('sudah_lapor', '<?php echo $provinsi; ?>', '<?php echo $tahun; ?>', '<?php echo $triwulan; ?>', '<?php echo $jenis_perizinan; ?>')">
                                            <div class="card-body text-center">
                                                <h3 class="text-success"><?php echo formatNumber($perusahaan_sudah_lapor); ?>
                                                </h3>
                                                <p class="text-muted mb-0" style="font-size: 0.95rem;">Perusahaan Sudah Lapor
                                                </p>
                                                <small class="text-success fw-bold d-block mt-1 mb-1"
                                                    style="font-size: 0.75rem;">
                                                    (Total <?php echo formatNumber($total_records); ?> Laporan Masuk)
                                                </small>
                                                <small class="text-muted" style="font-size: 0.75rem;">
                                                    <i class="bi bi-hand-index"></i> Klik untuk detail
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col">
                                        <div class="card border-warning h-100" style="cursor: pointer;"
                                            onclick="showModal('belum_lapor', '<?php echo $provinsi; ?>', '<?php echo $tahun; ?>', '<?php echo $triwulan; ?>', '<?php echo $jenis_perizinan; ?>')">
                                            <div class="card-body text-center">
                                                <h3 class="text-warning"><?php echo formatNumber($belum_lapor_sederhana); ?>
                                                </h3>
                                                <p class="text-muted mb-0">Perusahaan Belum Lapor</p>
                                                <small class="text-muted">
                                                    <i class="bi bi-hand-index"></i> Klik untuk detail
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col">
                                        <div class="card border-danger h-100" style="cursor: pointer;"
                                            onclick="openStatusModal('nonaktif')">
                                            <div class="card-body text-center">
                                                <h3 class="text-danger"><?php echo formatNumber($non_aktif_count); ?></h3>
                                                <p class="text-muted mb-0">Perusahaan Non-Aktif</p>
                                                <small class="text-danger fw-semibold d-block" style="font-size: 0.75rem;">
                                                    (Dikecualikan dari %)
                                                </small>
                                                <small class="text-muted" style="font-size: 0.75rem;">
                                                    <i class="bi bi-sliders"></i> Kelola Aktif/Non-Aktif
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col">
                                        <div class="card border-info h-100">
                                            <div class="card-body text-center">
                                                <h3 class="text-info"><?php echo $persentase_total; ?>%</h3>
                                                <p class="text-muted mb-0">Tingkat Kepatuhan</p>
                                                <small class="text-muted" style="font-size: 0.75rem;">
                                                    Basis: <?php echo formatNumber($total_perush); ?> Aktif
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Progress Bar -->
                                <div class="mb-4">
                                    <div class="d-flex justify-content-between mb-2">
                                        <span><strong>Tingkat Kepatuhan Pelaporan</strong></span>
                                        <span><strong><?php echo $persentase_total; ?>%</strong></span>
                                    </div>
                                    <div class="progress" style="height: 25px;">
                                        <div class="progress-bar bg-success" role="progressbar"
                                            style="width: <?php echo $persentase_total; ?>%"
                                            aria-valuenow="<?php echo $persentase_total; ?>" aria-valuemin="0"
                                            aria-valuemax="100">
                                            <?php echo $persentase_total; ?>% Patuh
                                        </div>
                                    </div>
                                </div>
                            <?php endif; ?>

                            <!-- Tabel Detail per Provinsi -->
                            <?php if ($analisis_perusahaan && $analisis_perusahaan->num_rows > 0): ?>
                                <h6 class="mb-3"><i class="bi bi-table"></i> Detail per Provinsi</h6>
                                <div class="alert alert-info">
                                    <small>
                                        <i class="bi bi-info-circle"></i>
                                        <strong>Keterangan:</strong>
                                        "Sudah Lapor" = Total record laporan masuk |
                                        "Belum Lapor" = Jumlah perusahaan yang belum melaporkan |
                                        "Persentase" = Dihitung dari perusahaan unik yang sudah lapor
                                    </small>
                                </div>
                                <div class="table-responsive">
                                    <table class="table table-striped table-hover" id="tableAnalisis">
                                        <thead class="table-dark">
                                            <tr>
                                                <th>No</th>
                                                <th>Provinsi</th>
                                                <th title="Total perusahaan terdaftar di provinsi">Total Perusahaan</th>
                                                <th title="Total record laporan masuk">Laporan Masuk</th>
                                                <th title="Jumlah perusahaan yang belum melaporkan">Belum Lapor</th>
                                                <th>Persentase Kepatuhan</th>
                                                <th>Status</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php
                                            $no = 1;
                                            while ($row = $analisis_perusahaan->fetch_assoc()):
                                                $persentase = $row['persentase_lapor'] ?? 0;
                                                $perusahaan_sudah_lapor = $row['perusahaan_sudah_lapor'] ?? 0;
                                                $status_class = $persentase >= 80 ? 'success' : ($persentase >= 60 ? 'warning' : 'danger');
                                                $status_text = $persentase >= 80 ? 'Baik' : ($persentase >= 60 ? 'Cukup' : 'Kurang');
                                                ?>
                                                <tr>
                                                    <td><?php echo $no++; ?></td>
                                                    <td><strong><?php echo htmlspecialchars($row['nama_provinsi'] ?? '(Tidak Ada Data)'); ?></strong>
                                                    </td>
                                                    <td>
                                                        <span class="badge bg-primary fs-6">
                                                            <?php echo formatNumber($row['total_perusahaan']); ?>
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <span class="badge bg-success fs-6">
                                                            <?php echo formatNumber($row['sudah_lapor']); ?>
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <span class="badge bg-warning fs-6">
                                                            <?php echo formatNumber($row['belum_lapor']); ?>
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <div class="d-flex align-items-center">
                                                            <div class="progress me-2" style="width: 100px; height: 20px;">
                                                                <div class="progress-bar bg-<?php echo $status_class; ?>"
                                                                    style="width: <?php echo $persentase; ?>%"></div>
                                                            </div>
                                                            <strong><?php echo $persentase; ?>%</strong>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <span class="badge bg-<?php echo $status_class; ?>">
                                                            <?php echo $status_text; ?>
                                                        </span>
                                                    </td>
                                                </tr>
                                            <?php endwhile; ?>
                                        </tbody>
                                    </table>
                                </div>
                            <?php else: ?>
                                <div class="alert alert-info">
                                    <i class="bi bi-info-circle"></i> Tidak ada data analisis perusahaan untuk kriteria yang
                                    dipilih.
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tabel Hasil -->
            <?php if ($search_performed): ?>
                <div class="card">
                    <div class="card-header bg-light">
                        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                            <div class="d-flex align-items-center gap-2 flex-wrap">
                                <h6 class="mb-0"><i class="bi bi-table"></i> Data Laporan Batubara</h6>
                                <span class="badge bg-dark border border-secondary text-light py-1 px-2" style="font-size: 0.75rem;">
                                    <span class="text-warning fw-bold">■</span> Total Keseluruhan (Semua Data) &nbsp;|&nbsp; 
                                    <span class="text-info fw-bold">■</span> Subtotal Halaman Ini
                                </span>
                            </div>
                            <button type="button" class="btn btn-success btn-sm" onclick="exportToExcel()">
                                <i class="bi bi-file-earmark-excel"></i> Export Excel
                            </button>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-striped table-hover mb-0" id="dataTable">
                                <thead class="table-dark">
                                    <tr>
                                        <th width="3%">No</th>
                                        <th>ID</th>
                                        <th>Jenis Perizinan</th>
                                        <th>Provinsi</th>
                                        <th>Nama Perusahaan</th>
                                        <th>SK IUP</th>
                                        <th>Email</th>
                                        <th>Sistem Penambangan</th>
                                        <th>Waktu Pelaporan</th>
                                        <th>Tahun</th>
                                        <th>Rencana Recovery Penambangan</th>
                                        <th>RKAB 2.1</th>
                                        <th>Studi Kelayakan 2.1</th>
                                        <th>Recovery Penambangan Truck</th>
                                        <th>Recovery Penambangan Survey</th>
                                        <th>Rencana Recovery Pengolahan</th>
                                        <th>RKAB 2.4</th>
                                        <th>Studi Kelayakan 2.4</th>
                                        <th>Recovery Pengolahan</th>
                                        <th>BKR Kumulatif Awal Tahun</th>
                                        <th>BKR Lokasi</th>
                                        <th>BKR Kuantitas</th>
                                        <th>Kualitas Batubara Kualitas Rendah</th>
                                        <th>BKR Abu</th>
                                        <th>BKR Sulfur</th>
                                        <th>BKR Total Moisture</th>
                                        <th>BKR Pemanfaatan</th>
                                        <th>BKR Jenis Pemanfaatan</th>
                                        <th>PBKR Tonase</th>
                                        <th>Cadangan Marginal Ada/Tidak</th>
                                        <th>Cadangan Marginal Kumulatif Awal Tahun</th>
                                        <th>Cadangan Marginal Lokasi</th>
                                        <th>Cadangan Marginal Kuantitas</th>
                                        <th>Cadangan Marginal Kalori</th>
                                        <th>Cadangan Marginal Abu</th>
                                        <th>Cadangan Marginal Sulfur</th>
                                        <th>Cadangan Marginal Total Moisture</th>
                                        <th>Cadangan Marginal Penyebab</th>
                                        <th>Cadangan Marginal Optimalisasi</th>
                                        <th>Cadangan Marginal Yang Sudah Ditambang</th>
                                        <th>SHP Kumulatif Awal Tahun</th>
                                        <th>SHP Lokasi</th>
                                        <th>SHP Kuantitas</th>
                                        <th>SHP Kalori</th>
                                        <th>SHP Abu</th>
                                        <th>SHP Sulfur</th>
                                        <th>SHP Total Moisture</th>
                                        <th>PSHP Volume</th>
                                        <th>Cadangan Tidak Tertambang Kumulatif Awal Tahun</th>
                                        <th>Cadangan Tidak Tertambang Lokasi</th>
                                        <th>Cadangan Tidak Tertambang Kuantitas</th>
                                        <th>Cadangan Tidak Tertambang Kedalaman</th>
                                        <th>Cadangan Tidak Tertambang Kalori</th>
                                        <th>Cadangan Tidak Tertambang Abu</th>
                                        <th>Cadangan Tidak Tertambang Sulfur</th>
                                        <th>Cadangan Tidak Tertambang Total Moisture</th>
                                        <th>Cadangan Tidak Tertambang Alasan</th>
                                        <th>Laporan</th>
                                        <th>Peta Konservasi</th>
                                        <th>Waktu Input</th>
                                        <th width="5%">Aksi</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <!-- Data dimuat secara Server-Side via AJAX (get_laporan_data.php) -->
                                </tbody>
                                <tfoot class="table-dark">
                                    <tr>
                                        <th>Total</th>
                                        <?php for ($i = 1; $i <= 60; $i++): ?>
                                            <th>-</th>
                                        <?php endfor; ?>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                    </div>
                </div>
            <?php endif; ?>

        <?php endif; ?>
    </div>

    <!-- Footer -->
    <footer class="mt-5 py-4 bg-dark text-white">
        <div class="container text-center">
            <p class="mb-0">&copy; <?php echo date('Y'); ?> Dashboard Pelaporan Minerba. All rights reserved.</p>
        </div>
    </footer>

    <!-- Modal Daftar Perusahaan -->
    <div class="modal fade" id="modalPerusahaan" tabindex="-1" aria-labelledby="modalPerusahaanLabel"
        aria-hidden="true">
        <div class="modal-dialog modal-xl">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="modalPerusahaanLabel">
                        <i class="bi bi-building"></i> <span id="modalTitle">Daftar Perusahaan</span>
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div id="modalLoading" class="text-center py-4">
                        <div class="spinner-border text-primary" role="status">
                            <span class="visually-hidden">Loading...</span>
                        </div>
                        <p class="mt-2">Memuat data perusahaan...</p>
                    </div>
                    <div id="modalContent" style="display: none;">
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <div class="alert alert-info mb-0">
                                    <small id="modalInfo">Informasi filter akan ditampilkan di sini</small>
                                </div>
                            </div>
                            <div class="col-md-6 text-end">
                                <button class="btn btn-outline-success btn-sm" onclick="exportModalToExcel()">
                                    <i class="bi bi-file-earmark-excel"></i> Export Excel
                                </button>
                                <button class="btn btn-outline-primary btn-sm ms-1" onclick="printModal()">
                                    <i class="bi bi-printer"></i> Print
                                </button>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-striped table-hover" id="tableModalPerusahaan">
                                <thead class="table-dark">
                                    <tr>
                                        <th>No</th>
                                        <th>Nama Perusahaan</th>
                                        <th>SK IUP</th>
                                        <th>Provinsi</th>
                                        <th>Jenis Izin</th>
                                        <th>Status Laporan</th>
                                        <th>Triwulan</th>
                                        <th>Tahun</th>
                                        <th>Terakhir Update</th>
                                    </tr>
                                </thead>
                                <tbody id="modalTableBody">
                                    <!-- Data akan diisi via JavaScript -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Scripts -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.0/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.0/js/dataTables.bootstrap5.min.js"></script>
    <!-- DataTables FixedColumns JS -->
    <script src="https://cdn.datatables.net/fixedcolumns/4.2.2/js/dataTables.fixedColumns.min.js"></script>

    <script>
        // Data Grand Total Keseluruhan dari Database untuk Filter Aktif
        window.grandTotals = <?php echo json_encode($grand_totals ?: (object) []); ?>;

        // Enhanced Loading Functions
        let loadingTimeout;
        let downloadCheckInterval;

        function showLoading(message = 'Memuat Data...', subMessage = 'Mohon tunggu sebentar') {
            $('#loadingOverlay').find('.loading-text').text(message);
            $('#loadingOverlay').find('.loading-subtext').text(subMessage);
            $('#loadingOverlay').show().css('display', 'flex');

            // Clear any existing timeout
            if (loadingTimeout) {
                clearTimeout(loadingTimeout);
            }

            // Add body class to prevent scrolling
            $('body').addClass('loading-active');
        }

        function hideLoading() {
            $('#loadingOverlay').fadeOut(300);
            $('body').removeClass('loading-active');

            if (loadingTimeout) {
                clearTimeout(loadingTimeout);
                loadingTimeout = null;
            }
            if (downloadCheckInterval) {
                clearInterval(downloadCheckInterval);
                downloadCheckInterval = null;
            }
        }

        // Enhanced loading for downloads with better detection
        function showLoadingForDownload(message, onComplete) {
            showLoading(message, 'Memproses permintaan...');

            let startTime = Date.now();
            let checkCount = 0;
            const maxChecks = 20; // Maximum 10 seconds

            // Check for download completion using multiple methods
            downloadCheckInterval = setInterval(function () {
                checkCount++;

                // Check if we've waited long enough or reached max checks
                if (checkCount >= maxChecks || (Date.now() - startTime) > 10000) {
                    clearInterval(downloadCheckInterval);
                    hideLoading();
                    if (onComplete) onComplete();
                    return;
                }

                // For download links, assume success after reasonable time
                if (checkCount > 6) { // After 3 seconds
                    clearInterval(downloadCheckInterval);
                    setTimeout(function () {
                        hideLoading();
                        if (onComplete) onComplete();
                    }, 500);
                }
            }, 500);

            // Fallback timeout
            loadingTimeout = setTimeout(function () {
                hideLoading();
                if (onComplete) onComplete();
            }, 8000);
        }

        // Show loading on form submit
        function showLoadingButton(button) {
            $(button).addClass('btn-loading');
            $(button).find('i').addClass('d-none');
            $(button).prop('disabled', true);
        }

        function hideLoadingButton(button) {
            $(button).removeClass('btn-loading');
            $(button).find('i').removeClass('d-none');
            $(button).prop('disabled', false);
        }

        // Utility function for showing alerts
        function showAlert(type, title, message) {
            // You can implement your preferred alert system here
            // For now, using browser alert
            if (type === 'success') {
                alert(title + ': ' + message);
            } else if (type === 'error') {
                alert('Error: ' + message);
            }
        }

        $(document).ready(function () {
            // Hide loading on page load
            hideLoading();

            // Initialize DataTables with loading
            showLoading('Memuat Tabel Data...', 'Sedang menyiapkan tabel laporan');

            function escapeHtml(text) {
                if (text === null || text === undefined) return '';
                return String(text)
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")
                    .replace(/'/g, "&#039;");
            }

            // Tangani error DataTables secara konsol & tidak menampilkan alert popup default
            $.fn.dataTable.ext.errMode = 'none';

            var dataTable = $('#dataTable').DataTable({
                "processing": false, // Matikan loading bawaan DataTables karena sering nyangkut
                "serverSide": true,
                "ajax": {
                    "url": "gat_laporan_data.php",
                    "type": "POST",
                    "data": function (d) {
                        d.nama_perusahaan = $('#nama_perusahaan').val();
                        d.provinsi = $('#provinsi').val();
                        d.triwulan = $('#triwulan').val();
                        d.tahun = $('#tahun').val();
                        d.jenis_perizinan = $('#jenis_perizinan').val();
                        d.filter_objek = getSelectedFilterObjek();
                        d.sub_filter = getSelectedSubFilters();
                        d.status_produksi = getSelectedStatusProduksi();
                    },
                    "dataSrc": function (json) {
                        if (json && json.grandTotals) {
                            window.grandTotals = json.grandTotals;
                        }
                        return json.data || [];
                    },
                    "error": function (xhr, error, thrown) {
                        console.error("DataTables Ajax error:", error, thrown, xhr.responseText);
                        hideLoading();
                    }
                },
                "language": {
                    "url": "//cdn.datatables.net/plug-ins/1.13.0/i18n/id.json"
                },
                "pageLength": 10,
                "responsive": true,
                "scrollX": true,
                "order": [[9, "desc"]],
                "footerCallback": function (row, data, start, end, display) {
                    var api = this.api();

                    // Fungsi pembantu parsing string angka ke float murni
                    var parseNumber = function (val) {
                        if (typeof val === 'number') return val;
                        if (!val || val === '-' || val === null || val === undefined) return 0;
                        if (typeof val === 'string') {
                            var clean = val.replace(/<[^>]*>/g, '').trim();
                            // Jika ada pemisah ribuan titik dan desimal koma (format Indo)
                            if (clean.indexOf(',') > -1 && clean.indexOf('.') > -1) {
                                if (clean.indexOf('.') < clean.indexOf(',')) {
                                    clean = clean.replace(/\./g, '').replace(',', '.');
                                } else {
                                    clean = clean.replace(/,/g, '');
                                }
                            } else if (clean.indexOf(',') > -1) {
                                clean = clean.replace(',', '.');
                            }
                            var num = parseFloat(clean);
                            return isNaN(num) ? 0 : num;
                        }
                        return 0;
                    };

                    // Format angka ke format ribuan Indonesia
                    var formatIndo = function (num) {
                        if (num === 0) return '-';
                        return num.toLocaleString('id-ID', {
                            minimumFractionDigits: 0,
                            maximumFractionDigits: 2
                        });
                    };

                    // Kolom-kolom tonase/kuantitas yang dijumlahkan sesuai tanda 'A' pada Filter Objek:
                    // 1. Batubara Kualitas Rendah (Kumulatif: 19, Kuantitas: 21, PBKR: 28)
                    // 2. Cadangan Marginal (Kumulatif: 30, Kuantitas: 32, Sudah Ditambang: 39)
                    // 3. Sisa Hasil Pengolahan (Kumulatif: 40, Kuantitas: 42, PSHP: 47)
                    // 4. Cadangan Tidak Tertambang (Kumulatif: 48, Kuantitas: 50)
                    // Ditambah kolom 29 (Cadangan Marginal Ada/Tidak) yang dihitung ada/tidaknya
                    var numericColumns = [
                        19, 21, 28, // Batubara Kualitas Rendah
                        30, 32, 39, // Cadangan Marginal
                        40, 42, 47, // Sisa Hasil Pengolahan
                        48, 50      // Cadangan Tidak Tertambang
                    ];

                    $(api.column(0).footer()).html(
                        '<div class="d-flex flex-column text-start">' +
                            '<span class="fw-bold text-warning" style="white-space: nowrap;">Total Semua</span>' +
                            '<small class="text-info" style="font-size: 0.72rem; white-space: nowrap;">(Hal. Ini)</small>' +
                        '</div>'
                    );

                    // Hitung total tiap kolom
                    api.columns().every(function (colIdx) {
                        if (colIdx === 0) return;
                        var footerCell = $(api.column(colIdx).footer());

                        if (numericColumns.indexOf(colIdx) !== -1) {
                            var colData = api.column(colIdx, { page: 'current' }).data();
                            var pageSum = 0;

                            colData.each(function (val) {
                                pageSum += parseNumber(val);
                            });

                            // Ambil Grand Total keseluruhan dari server (database)
                            var grandTotal = (window.grandTotals && window.grandTotals[colIdx] !== undefined)
                                ? Number(window.grandTotals[colIdx])
                                : pageSum;

                            if (grandTotal > 0 || pageSum > 0) {
                                footerCell.html(
                                    '<div class="d-flex flex-column align-items-center">' +
                                        '<span class="text-warning fw-bold" style="white-space: nowrap;" title="Total Keseluruhan (Semua Data Laporan Sesuai Filter)">' + formatIndo(grandTotal) + '</span>' +
                                        '<small class="text-info opacity-75" style="font-size: 0.72rem; white-space: nowrap;" title="Subtotal Halaman Ini">(Hal: ' + formatIndo(pageSum) + ')</small>' +
                                    '</div>'
                                );
                            } else {
                                footerCell.html('-');
                            }
                        } else if (colIdx === 29) {
                            // Kolom Cadangan Marginal Ada/Tidak
                            var colData = api.column(colIdx, { page: 'current' }).data();
                            var pageAda = 0;
                            var pageTidak = 0;

                            colData.each(function (val) {
                                if (val && typeof val === 'string') {
                                    var clean = val.replace(/<[^>]*>/g, '').trim().toLowerCase();
                                    if (clean.indexOf('tidak') !== -1) {
                                        pageTidak++;
                                    } else if (clean.indexOf('ada') !== -1) {
                                        pageAda++;
                                    }
                                }
                            });

                            // Ambil Grand Total dari database (semua record yang difilter)
                            var grandAda = (window.grandTotals && window.grandTotals[29] && window.grandTotals[29].ada !== undefined)
                                ? Number(window.grandTotals[29].ada)
                                : pageAda;
                            var grandTidak = (window.grandTotals && window.grandTotals[29] && window.grandTotals[29].tidak !== undefined)
                                ? Number(window.grandTotals[29].tidak)
                                : pageTidak;

                            if (grandAda > 0 || grandTidak > 0 || pageAda > 0 || pageTidak > 0) {
                                footerCell.html(
                                    '<div class="d-flex flex-column align-items-center" style="min-width: 125px; line-height: 1.25;">' +
                                        '<div class="text-nowrap mb-1" title="Total Keseluruhan (Semua Data Sesuai Filter): Ada &amp; Tidak Ada">' +
                                            '<span class="badge bg-success" style="font-size: 0.72rem; padding: 2px 5px;" title="Total Ada">Ada: ' + grandAda + '</span> ' +
                                            '<span class="badge bg-secondary" style="font-size: 0.72rem; padding: 2px 5px;" title="Total Tidak Ada">Tidak: ' + grandTidak + '</span>' +
                                        '</div>' +
                                        '<small class="text-info opacity-75 text-nowrap" style="font-size: 0.70rem;" title="Subtotal Halaman Ini">' +
                                            '(Hal: ' + pageAda + ' &bull; ' + pageTidak + ')' +
                                        '</small>' +
                                    '</div>'
                                );
                            } else {
                                footerCell.html('-');
                            }
                        } else {
                            footerCell.html('-');
                        }
                    });
                },
                "columns": [
                    {
                        "data": null,
                        "orderable": false,
                        "width": "3%",
                        "render": function (data, type, row, meta) {
                            return meta.row + meta.settings._iDisplayStart + 1;
                        }
                    },
                    { "data": "id", "defaultContent": "-" },
                    { "data": "jenis_perizinan_1_1", "defaultContent": "-" },
                    {
                        "data": "nama_provinsi",
                        "render": function (data) {
                            return '<span class="badge bg-info">' + escapeHtml(data || '(Tidak Ada Data)') + '</span>';
                        }
                    },
                    { "data": "nama_perusahaan", "defaultContent": "-" },
                    {
                        "data": "sk_iup",
                        "render": function (data) { return '<small>' + escapeHtml(data || '-') + '</small>'; }
                    },
                    {
                        "data": "alamat_email_1_4",
                        "render": function (data) { return '<small>' + escapeHtml(data || '-') + '</small>'; }
                    },
                    {
                        "data": "sistem_penambangan_1_5",
                        "defaultContent": "-",
                        "render": function (data) {
                            if (!data || data === '-') return '-';
                            var clean = String(data);
                            if (clean.toLowerCase().indexOf('belum produksi') !== -1) {
                                return '<span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle" title="Status: Belum Produksi (BP)"><i class="bi bi-clock-history me-1"></i>' + escapeHtml(clean) + '</span>';
                            }
                            return '<span class="text-dark" title="Status: Sudah Produksi (P)">' + escapeHtml(clean) + '</span>';
                        }
                    },
                    { "data": "waktu_perlaporan_laporan_1_6", "defaultContent": "-" },
                    {
                        "data": "tahun_1_7",
                        "render": function (data) { return '<strong>' + escapeHtml(data || '-') + '</strong>'; }
                    },
                    { "data": "rencana_recovery_penambangan", "defaultContent": "-" },
                    { "data": "rkab_2_1", "defaultContent": "-" },
                    { "data": "studi_kelayakan_2_1", "defaultContent": "-" },
                    { "data": "recovery_penambangan_truck_2_1", "defaultContent": "-" },
                    { "data": "recovery_penambangan_survey_2_2", "defaultContent": "-" },
                    { "data": "rencana_recovery_pengolahan", "defaultContent": "-" },
                    { "data": "rkab_2_4", "defaultContent": "-" },
                    { "data": "studi_kelayakan_2_4", "defaultContent": "-" },
                    { "data": "recovery_pengolahan_2_3", "defaultContent": "-" },
                    { "data": "bkr_komulatif_awal_tahun", "defaultContent": "-" },
                    { "data": "bkr_lokasi", "defaultContent": "-" },
                    { "data": "bkr_kuantitas", "defaultContent": "-" },
                    { "data": "bkr_calorie_values_3_1", "defaultContent": "-" },
                    { "data": "bkr_ash_3_1", "defaultContent": "-" },
                    { "data": "bkr_sulfur_3_1", "defaultContent": "-" },
                    { "data": "bkr_total_moisture_3_1", "defaultContent": "-" },
                    { "data": "bkr_pemanfaatan_sudah_belum_3_2", "defaultContent": "-" },
                    { "data": "bkr_jenis_pemanfaatan", "defaultContent": "-" },
                    { "data": "pbkr_volume", "defaultContent": "-" },
                    { "data": "cm_ada_tidak", "defaultContent": "-" },
                    { "data": "cm_komulatif_awal_tahun", "defaultContent": "-" },
                    { "data": "cm_lokasi", "defaultContent": "-" },
                    { "data": "cm_kuantitas", "defaultContent": "-" },
                    { "data": "cm_calorie_values_4_1", "defaultContent": "-" },
                    { "data": "cm_ash_4_1", "defaultContent": "-" },
                    { "data": "cm_sulfur_4_1", "defaultContent": "-" },
                    { "data": "cm_total_moisture_4_1", "defaultContent": "-" },
                    { "data": "cm_penyebab_4_2", "defaultContent": "-" },
                    { "data": "cm_optimalisasi_sudah_belum_4_3", "defaultContent": "-" },
                    { "data": "cm_yang_sudah_ditambang_", "defaultContent": "-" },
                    { "data": "shp_komulatif_awal_tahun", "defaultContent": "-" },
                    { "data": "shp_lokasi", "defaultContent": "-" },
                    { "data": "shp_kuantitas", "defaultContent": "-" },
                    { "data": "shp_calorie_values_5_1", "defaultContent": "-" },
                    { "data": "shp_ash_5_1", "defaultContent": "-" },
                    { "data": "shp_sulfur_5_1", "defaultContent": "-" },
                    { "data": "shp_total_moisture_5_1", "defaultContent": "-" },
                    { "data": "pshp_volume", "defaultContent": "-" },
                    { "data": "ctt_komulatif_awal_tahun", "defaultContent": "-" },
                    { "data": "ctt_lokasi", "defaultContent": "-" },
                    { "data": "ctt_kuantitas", "defaultContent": "-" },
                    { "data": "ctt_kedalaman", "defaultContent": "-" },
                    { "data": "ctt_calorie_values_6_1", "defaultContent": "-" },
                    { "data": "ctt_ash_6_1", "defaultContent": "-" },
                    { "data": "ctt_sulfur_6_1", "defaultContent": "-" },
                    { "data": "ctt_total_moisture_6_1", "defaultContent": "-" },
                    { "data": "ctt_alasan_6_2", "defaultContent": "-" },
                    {
                        "data": "laporan_7_1",
                        "render": function (data, type, row) {
                            if (data) {
                                // Cek apakah data merupakan URL (link GDrive / external link)
                                if (data.startsWith('http://') || data.startsWith('https://')) {
                                    return '<a href="' + escapeHtml(data) + '" class="text-primary fw-bold" title="Buka Link Google Drive" target="_blank"><i class="bi bi-link-45deg"></i> Link Google Drive</a>';
                                }
                                if (row.laporan_exists) {
                                    return '<a href="download.php?file=' + encodeURIComponent(data) + '&type=laporan" class="text-primary" title="Klik untuk download" target="_blank">' + escapeHtml(data) + '</a>';
                                } else {
                                    return '<span class="text-danger"><i class="bi bi-exclamation-triangle"></i> File tidak ditemukan</span>';
                                }
                            }
                            return '<span class="text-muted">-</span>';
                        }
                    },
                    {
                        "data": "peta_konservasi_7_2",
                        "render": function (data, type, row) {
                            if (data) {
                                // Cek apakah data merupakan URL (link GDrive / external link)
                                if (data.startsWith('http://') || data.startsWith('https://')) {
                                    return '<a href="' + escapeHtml(data) + '" class="text-primary fw-bold" title="Buka Link Google Drive" target="_blank"><i class="bi bi-link-45deg"></i> Link Google Drive</a>';
                                }
                                if (row.peta_exists) {
                                    return '<a href="download.php?file=' + encodeURIComponent(data) + '&type=peta" class="text-primary" title="Klik untuk download" target="_blank">' + escapeHtml(data) + '</a>';
                                } else {
                                    return '<span class="text-danger"><i class="bi bi-exclamation-triangle"></i> File tidak ditemukan</span>';
                                }
                            }
                            return '<span class="text-muted">-</span>';
                        }
                    },
                    {
                        "data": "waktu_input_8",
                        "render": function (data) {
                            if (!data) return '-';
                            var d = new Date(data);
                            if (isNaN(d.getTime())) return escapeHtml(data);
                            var day = ("0" + d.getDate()).slice(-2);
                            var month = ("0" + (d.getMonth() + 1)).slice(-2);
                            var year = d.getFullYear();
                            var hours = ("0" + d.getHours()).slice(-2);
                            var mins = ("0" + d.getMinutes()).slice(-2);
                            return '<small>' + day + '/' + month + '/' + year + ' ' + hours + ':' + mins + '</small>';
                        }
                    },
                    {
                        "data": "id",
                        "orderable": false,
                        "width": "5%",
                        "render": function (data) {
                            return '<button class="btn btn-sm btn-outline-primary" onclick="viewDetail(' + data + ')" title="Lihat Detail"><i class="bi bi-eye"></i></button>';
                        }
                    }
                ],
                "fixedColumns": {
                    "leftColumns": 5
                },
                "drawCallback": function (settings) {
                    setTimeout(function () {
                        applyFilterObjekVisibility();
                        hideLoading();
                    }, 300);
                }
            });

            // Helper: Dapatkan list objek terpilih
            function getSelectedFilterObjek() {
                var selected = [];
                $('input[name="filter_objek[]"]:checked').each(function () {
                    selected.push($(this).val());
                });
                return selected;
            }

            // Helper: Dapatkan list sub-filter terpilih
            function getSelectedSubFilters() {
                var selected = [];
                $('input[name="sub_filter[]"]:checked').each(function () {
                    selected.push($(this).val());
                });
                return selected;
            }

            // Helper: Dapatkan list status produksi terpilih (P / BP)
            function getSelectedStatusProduksi() {
                var selected = [];
                $('input[name="status_produksi[]"]:checked').each(function () {
                    selected.push($(this).val());
                });
                return selected;
            }

            // Fungsi Kontrol Visibilitas Kolom DataTables berdasarkan Filter Objek
            function applyFilterObjekVisibility() {
                if (!dataTable) return;

                var isAll = $('#objek_all').is(':checked');
                var isRecTambang = $('#objek_rec_tambang').is(':checked');
                var isRecOlah = $('#objek_rec_olah').is(':checked');
                var isBkr = $('#objek_bkr').is(':checked');
                var isBkrKum = $('#sub_bkr_kum').is(':checked');
                var isBkrKuan = $('#sub_bkr_kuan').is(':checked');
                var isCm = $('#objek_cm').is(':checked');
                var isCmKum = $('#sub_cm_kum').is(':checked');
                var isCmKuan = $('#sub_cm_kuan').is(':checked');
                var isCtt = $('#objek_ctt').is(':checked');
                var isCttKum = $('#sub_ctt_kum').is(':checked');
                var isCttKuan = $('#sub_ctt_kuan').is(':checked');
                var isShp = $('#objek_shp').is(':checked');
                var isShpKum = $('#sub_shp_kum').is(':checked');
                var isShpKuan = $('#sub_shp_kuan').is(':checked');

                // Jika tidak ada sama sekali yang dipilih, default ke All
                if (!isAll && !isRecTambang && !isRecOlah && !isBkr && !isCm && !isCtt && !isShp) {
                    isAll = true;
                    $('#objek_all').prop('checked', true);
                    $('.filter-objek-checkbox').prop('checked', true);
                }

                var visibleCols = {};

                // Kolom Dasar (SELALU DITAMPILKAN):
                // 0: No, 2: Jenis Perizinan, 3: Provinsi, 4: Nama Perusahaan, 7: Sistem Penambangan, 8: Waktu Pelaporan, 9: Tahun, 60: Aksi
                [0, 2, 3, 4, 7, 8, 9, 60].forEach(function (idx) {
                    visibleCols[idx] = true;
                });

                if (isAll) {
                    // Tampilkan semua 61 kolom
                    for (var i = 0; i <= 60; i++) {
                        visibleCols[i] = true;
                    }
                } else {
                    // Recovery Penambangan (Cols 10 to 14)
                    if (isRecTambang) {
                        [10, 11, 12, 13, 14].forEach(function (i) { visibleCols[i] = true; });
                    }
                    // Recovery Pengolahan (Cols 15 to 18)
                    if (isRecOlah) {
                        [15, 16, 17, 18].forEach(function (i) { visibleCols[i] = true; });
                    }
                    // Batubara Kualitas Rendah (Cols 19 to 28)
                    if (isBkr) {
                        if (isBkrKum) visibleCols[19] = true; // BKR Kumulatif Awal Tahun
                        if (isBkrKuan) { visibleCols[21] = true; visibleCols[28] = true; } // BKR Kuantitas & PBKR Tonase
                        if (isBkrKum || isBkrKuan) {
                            [20, 22, 23, 24, 25, 26, 27].forEach(function (i) { visibleCols[i] = true; });
                        }
                    }
                    // Cadangan Marginal (Cols 29 to 39)
                    if (isCm) {
                        visibleCols[29] = true; // Cadangan Marginal Ada/Tidak
                        if (isCmKum) visibleCols[30] = true; // CM Kumulatif Awal Tahun
                        if (isCmKuan) { visibleCols[32] = true; visibleCols[39] = true; } // CM Kuantitas & Sudah Ditambang
                        if (isCmKum || isCmKuan) {
                            [31, 33, 34, 35, 36, 37, 38].forEach(function (i) { visibleCols[i] = true; });
                        }
                    }
                    // Sisa Hasil Pengolahan (Cols 40 to 47)
                    if (isShp) {
                        if (isShpKum) visibleCols[40] = true; // SHP Kumulatif Awal Tahun
                        if (isShpKuan) { visibleCols[42] = true; visibleCols[47] = true; } // SHP Kuantitas & PSHP Volume
                        if (isShpKum || isShpKuan) {
                            [41, 43, 44, 45, 46].forEach(function (i) { visibleCols[i] = true; });
                        }
                    }
                    // Cadangan Tidak Tertambang (Cols 48 to 56)
                    if (isCtt) {
                        if (isCttKum) visibleCols[48] = true; // CTT Kumulatif Awal Tahun
                        if (isCttKuan) visibleCols[50] = true; // CTT Kuantitas
                        if (isCttKum || isCttKuan) {
                            [49, 51, 52, 53, 54, 55, 56].forEach(function (i) { visibleCols[i] = true; });
                        }
                    }
                }

                // Terapkan ke setiap kolom DataTable
                for (var col = 0; col <= 60; col++) {
                    var shouldShow = !!visibleCols[col];
                    if (dataTable.column(col).visible() !== shouldShow) {
                        dataTable.column(col).visible(shouldShow, false);
                    }
                }

                // Sesuaikan layout tabel
                dataTable.columns.adjust();
                if (dataTable.fixedColumns) {
                    try {
                        dataTable.fixedColumns().relayout();
                    } catch (e) { }
                }
            }

            // Sinkronisasi status checkbox 'Semua Objek'
            function syncAllObjekCheckbox() {
                var totalMain = $('.main-objek').length;
                var checkedMain = $('.main-objek:checked').length;
                if (checkedMain === totalMain) {
                    $('#objek_all').prop('checked', true);
                } else {
                    $('#objek_all').prop('checked', false);
                }
            }

            // Event handler Checkbox 'Semua Objek'
            $('#objek_all').on('change', function () {
                var checked = $(this).is(':checked');
                $('.filter-objek-checkbox').not(this).prop('checked', checked);
                applyFilterObjekVisibility();
            });

            // Event handler Parent yang punya Sub (BKR, CM, CTT, SHP)
            $('.has-sub').on('change', function () {
                var parentName = $(this).data('parent');
                var checked = $(this).is(':checked');
                $('[data-child-of="' + parentName + '"]').prop('checked', checked);
                syncAllObjekCheckbox();
                applyFilterObjekVisibility();
            });

            // Event handler Sub-item (Kumulatif, Kuantitatif)
            $('.sub-item').on('change', function () {
                var parentName = $(this).data('child-of');
                var anyChildChecked = $('[data-child-of="' + parentName + '"]:checked').length > 0;
                $('[data-parent="' + parentName + '"]').prop('checked', anyChildChecked);
                syncAllObjekCheckbox();
                applyFilterObjekVisibility();
            });

            // Event handler Objek mandiri (Recovery Penambangan, Recovery Pengolahan)
            $('.main-objek').not('.has-sub').on('change', function () {
                syncAllObjekCheckbox();
                applyFilterObjekVisibility();
            });

            // Event handler Filter Status Produksi (live update DataTables AJAX)
            $('input[name="status_produksi[]"]').on('change', function () {
                if (dataTable) {
                    dataTable.ajax.reload();
                }
            });

            // Event handler Filter Jenis Perizinan
            $('#jenis_perizinan').on('change', function () {
                if (dataTable) {
                    dataTable.ajax.reload();
                    applyFilterObjekVisibility();
                }
            });

            // Tombol Pilih Semua Objek
            $('#btnSelectAllObjek').on('click', function () {
                $('.filter-objek-checkbox').prop('checked', true);
                $('input[name="status_produksi[]"]').prop('checked', true);
                applyFilterObjekVisibility();
                if (dataTable) dataTable.ajax.reload();
            });

            // Tombol Reset Objek
            $('#btnResetObjek').on('click', function () {
                $('.filter-objek-checkbox').prop('checked', true);
                $('input[name="status_produksi[]"]').prop('checked', true);
                applyFilterObjekVisibility();
                if (dataTable) dataTable.ajax.reload();
            });

            // Jalankan initial visibility saat ready
            applyFilterObjekVisibility();

            // Handle form submission
            $('form').on('submit', function (e) {
                const submitButton = $(this).find('button[type="submit"]');
                showLoadingButton(submitButton);
                showLoading('Memproses Filter...', 'Sedang mencari data sesuai filter');

                // Let the form submit naturally
                return true;
            });
        });

        // Function untuk view detail
        function viewDetail(id) {
            // Implementasi view detail - bisa redirect ke halaman detail
            alert('Fitur detail untuk ID: ' + id + ' akan ditambahkan');
            // window.location.href = 'detail_laporan.php?id=' + id;
        }

        // Enhanced Function untuk export Excel
        function exportToExcel() {
            // Ambil parameter filter saat ini
            const params = new URLSearchParams();

            const namaPerusahaan = document.getElementById('nama_perusahaan').value;
            const provinsi = document.getElementById('provinsi').value;
            const triwulan = document.getElementById('triwulan').value;
            const tahun = document.getElementById('tahun').value;
            const jenisPerizinan = document.getElementById('jenis_perizinan') ? document.getElementById('jenis_perizinan').value : '';

            if (namaPerusahaan) params.append('nama_perusahaan', namaPerusahaan);
            if (provinsi && provinsi !== 'semua') params.append('provinsi', provinsi);
            if (triwulan && triwulan !== 'semua') params.append('triwulan', triwulan);
            if (tahun && tahun !== 'semua') params.append('tahun', tahun);
            if (jenisPerizinan && jenisPerizinan !== 'semua') params.append('jenis_perizinan', jenisPerizinan);

            // Tambahkan parameter filter objek
            const selectedObjek = [];
            $('input[name="filter_objek[]"]:checked').each(function () {
                params.append('filter_objek[]', $(this).val());
            });
            $('input[name="sub_filter[]"]:checked').each(function () {
                params.append('sub_filter[]', $(this).val());
            });
            $('input[name="status_produksi[]"]:checked').each(function () {
                params.append('status_produksi[]', $(this).val());
            });

            // Show loading with enhanced detection
            showLoadingForDownload(
                'Memproses Export Laporan...',
                function () {
                    showAlert('success', 'Export berhasil!', 'File laporan telah diunduh ke komputer Anda.');
                }
            );

            // Create and trigger download
            const downloadLink = document.createElement('a');
            downloadLink.href = 'export_laporan.php?' + params.toString();
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }

        // Function untuk export CSV (alias untuk kompatibilitas)
        function exportToCSV(filename) {
            exportToExcel();
        }

        // Auto-submit on select change (optional)
        $('.form-select').on('change', function () {
            // Uncomment untuk auto-submit
            // $(this).closest('form').submit();
        });

        // Function untuk show modal
        function showModal(status, provinsi, tahun, triwulan, jenis_perizinan) {
            jenis_perizinan = jenis_perizinan || $('#jenis_perizinan').val() || 'semua';

            // Set title berdasarkan status
            let title = '';
            let statusText = '';
            switch (status) {
                case 'total':
                    title = 'Daftar Semua Perusahaan';
                    statusText = 'Semua Perusahaan';
                    break;
                case 'sudah_lapor':
                    title = 'Daftar Perusahaan yang Sudah Melaporkan';
                    statusText = 'Sudah Melaporkan';
                    break;
                case 'belum_lapor':
                    title = 'Daftar Perusahaan yang Belum Melaporkan';
                    statusText = 'Belum Melaporkan';
                    break;
            }

            $('#modalTitle').text(title);

            // Simpan parameter untuk export
            window.currentModalParams = {
                status: status,
                provinsi: provinsi,
                tahun: tahun,
                triwulan: triwulan,
                jenis_perizinan: jenis_perizinan
            };

            // Set info filter
            let filterInfo = 'Status: ' + statusText;
            if (provinsi && provinsi !== 'semua') {
                filterInfo += ' | Provinsi: ' + provinsi;
            }
            if (tahun && tahun !== 'semua') {
                filterInfo += ' | Tahun: ' + tahun;
            }
            if (triwulan && triwulan !== 'semua') {
                const triwulanText = {
                    '1': 'Triwulan I',
                    '2': 'Triwulan II',
                    '3': 'Triwulan III',
                    '4': 'Triwulan IV'
                };
                filterInfo += ' | ' + triwulanText[triwulan];
            }
            if (jenis_perizinan && jenis_perizinan !== 'semua') {
                filterInfo += ' | Perizinan: ' + jenis_perizinan;
            }
            $('#modalInfo').text(filterInfo);

            // Show modal
            $('#modalPerusahaan').modal('show');

            // Show loading
            $('#modalLoading').show();
            $('#modalContent').hide();

            // Load data via AJAX
            loadPerusahaanData(status, provinsi, tahun, triwulan, jenis_perizinan);
        }

        // Function untuk load data perusahaan
        function loadPerusahaanData(status, provinsi, tahun, triwulan, jenis_perizinan) {
            jenis_perizinan = jenis_perizinan || $('#jenis_perizinan').val() || 'semua';

            // Logging untuk debugging
            console.log('Loading data with params:', {
                status: status,
                provinsi: provinsi,
                tahun: tahun,
                triwulan: triwulan,
                jenis_perizinan: jenis_perizinan
            });

            $.ajax({
                url: 'get_perusahaan_data.php',
                method: 'POST',
                data: {
                    status: status,
                    provinsi: provinsi,
                    tahun: tahun,
                    triwulan: triwulan,
                    jenis_perizinan: jenis_perizinan
                },
                dataType: 'json',
                beforeSend: function () {
                    // Show modal loading state
                    $('#modalLoading').show();
                    $('#modalContent').hide();
                },
                success: function (response) {
                    console.log('Response received:', response);
                    console.log('Total records:', response.data ? response.data.length : 0);

                    // Log sample data
                    if (response.data && response.data.length > 0) {
                        console.log('Sample first record:', response.data[0]);
                        console.log('Status laporan in data:', response.data[0].status_laporan);
                    }

                    if (response.success) {
                        populateModalTable(response.data);
                    } else {
                        showModalError('Error: ' + response.message);
                    }
                },
                error: function (xhr, status, error) {
                    console.error('AJAX Error:', error);
                    console.error('Response text:', xhr.responseText);
                    showModalError('Terjadi kesalahan saat memuat data: ' + error);
                },
                complete: function () {
                    $('#modalLoading').hide();
                    $('#modalContent').show();
                }
            });
        }

        // Function untuk populate table
        function populateModalTable(data) {
            // Destroy DataTable FIRST if it exists to prevent DataTables from restoring cached old rows
            if ($.fn.DataTable.isDataTable('#tableModalPerusahaan')) {
                $('#tableModalPerusahaan').DataTable().destroy();
            }

            let tbody = $('#modalTableBody');
            tbody.empty();

            console.log('Populating table with', data.length, 'records');

            if (data.length === 0) {
                tbody.append(`
                    <tr>
                        <td colspan="9" class="text-center py-4">
                            <i class="bi bi-inbox display-6 text-muted"></i>
                            <p class="text-muted mt-2">Tidak ada data perusahaan</p>
                        </td>
                    </tr>
                `);
                return;
            }

            // Validasi data - pastikan status_laporan sesuai
            let statusCount = {};
            data.forEach(function (item) {
                statusCount[item.status_laporan] = (statusCount[item.status_laporan] || 0) + 1;
            });
            console.log('Status distribution:', statusCount);

            data.forEach(function (item, index) {
                let statusClass = item.status_laporan === 'Sudah Lapor' ? 'success' : 'warning';
                let tanggalUpdate = item.waktu_input_8 ? new Date(item.waktu_input_8).toLocaleDateString('id-ID') : '-';
                let triwulan = item.triwulan || item.triwulan_laporan || '-';

                tbody.append(`
                    <tr>
                        <td>${index + 1}</td>
                        <td><strong>${item.nama_perusahaan || '-'}</strong></td>
                        <td><small>${item.sk_iup || '-'}</small></td>
                        <td><span class="badge bg-info">${item.nama_provinsi || '(Tidak Ada Data)'}</span></td>
                        <td>${item.jenis_izin || '-'}</td>
                        <td><span class="badge bg-${statusClass}">${item.status_laporan}</span></td>
                        <td>${triwulan}</td>
                        <td><strong>${item.tahun_1_7 || '-'}</strong></td>
                        <td><small>${tanggalUpdate}</small></td>
                    </tr>
                `);
            });

            // Initialize DataTable for modal
            $('#tableModalPerusahaan').DataTable({
                "language": {
                    "url": "//cdn.datatables.net/plug-ins/1.13.0/i18n/id.json"
                },
                "pageLength": 10,
                "responsive": true,
                "order": [[1, "asc"]], // Sort by nama perusahaan
                "columnDefs": [
                    { "orderable": false, "targets": [0] } // Disable sorting for No column
                ]
            });
        }

        // Function untuk show error
        function showModalError(message) {
            $('#modalTableBody').html(`
                <tr>
                    <td colspan="9" class="text-center py-4">
                        <i class="bi bi-exclamation-triangle display-6 text-danger"></i>
                        <p class="text-danger mt-2">${message}</p>
                    </td>
                </tr>
            `);
        }

        // Function untuk export Excel modal
        function exportModalToExcel() {
            // Ambil parameter dari modal yang sedang aktif
            const params = new URLSearchParams();

            let status = 'all';
            let provinsi = '';
            let tahun = '';

            // Ambil dari storage global
            if (window.currentModalParams) {
                status = window.currentModalParams.status;
                provinsi = window.currentModalParams.provinsi;
                tahun = window.currentModalParams.tahun;
                triwulan = window.currentModalParams.triwulan;
            }

            params.append('status', status);
            if (provinsi && provinsi !== 'semua') params.append('provinsi', provinsi);
            if (tahun && tahun !== 'semua') params.append('tahun', tahun);
            if (triwulan && triwulan !== 'semua') params.append('triwulan', triwulan);

            // Enhanced loading for modal export
            showLoadingForDownload(
                'Memproses Export Perusahaan...',
                function () {
                    showAlert('success', 'Export berhasil!', 'Data perusahaan telah diunduh.');
                    $('#modalPerusahaan').modal('hide');
                }
            );

            // Create and trigger download
            const downloadLink = document.createElement('a');
            downloadLink.href = 'export_perusahaan.php?' + params.toString();
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }

        // Function untuk print modal
        function printModal() {
            let modalContent = document.getElementById('modalContent').innerHTML;
            let printWindow = window.open('', '_blank');
            printWindow.document.write(`
                <html>
                <head>
                    <title>Daftar Perusahaan</title>
                    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
                    <style>
                        @media print {
                            .btn { display: none !important; }
                            .alert { display: none !important; }
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h3 class="mb-4">${document.getElementById('modalTitle').textContent}</h3>
                        ${modalContent}
                    </div>
                </body>
                </html>
            `);
            printWindow.document.close();
            printWindow.print();
        }

        // Function untuk validasi export
        function validateExportData() {
            const namaPerusahaan = document.getElementById('nama_perusahaan').value;
            const provinsi = document.getElementById('provinsi').value;
            const triwulan = document.getElementById('triwulan').value;
            const tahun = document.getElementById('tahun').value;

            // Log untuk debugging
            console.log('Export Parameters:', {
                nama_perusahaan: namaPerusahaan,
                provinsi: provinsi,
                triwulan: triwulan,
                tahun: tahun
            });

            return true;
        }

        // Function untuk export dengan notifikasi
        function exportWithNotification(exportFunction, type = 'data') {
            if (!validateExportData()) {
                alert('Terjadi kesalahan dalam validasi data export');
                return;
            }

            // Tampilkan notifikasi
            const notification = document.createElement('div');
            notification.className = 'alert alert-info position-fixed top-0 end-0 m-3';
            notification.style.zIndex = '9999';
            notification.innerHTML = `
                <div class="d-flex align-items-center">
                    <div class="spinner-border spinner-border-sm me-2" role="status"></div>
                    <span>Mempersiapkan file ${type}...</span>
                </div>
            `;
            document.body.appendChild(notification);

            // Execute export function
            exportFunction();

            // Remove notification after delay
            setTimeout(() => {
                if (notification && notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 3000);
        }

        // Enhanced export functions
        function exportToExcelEnhanced() {
            exportWithNotification(exportToExcel, 'Laporan Batubara');
        }

        function exportModalToExcelEnhanced() {
            exportWithNotification(exportModalToExcel, 'Data Perusahaan');
        }

        // Function untuk cek status export
        function checkExportStatus() {
            // Simple check untuk memastikan file export ada
            const testUrls = ['export_laporan.php', 'export_perusahaan.php'];
            testUrls.forEach(url => {
                fetch(url, { method: 'HEAD' })
                    .then(response => {
                        if (!response.ok) {
                            console.warn(`Export file ${url} mungkin tidak tersedia`);
                        }
                    })
                    .catch(error => {
                        console.warn(`Tidak dapat mengakses ${url}:`, error);
                    });
            });
        }

        // Function untuk download dengan progress
        function downloadWithProgress(url, filename) {
            showLoading('Mengunduh File...', 'Proses download sedang berlangsung');

            fetch(url)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.blob();
                })
                .then(blob => {
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = filename;
                    document.body.appendChild(a);
                    a.click();
                    window.URL.revokeObjectURL(url);
                    document.body.removeChild(a);
                })
                .catch(error => {
                    console.error('Download error:', error);
                    alert('Terjadi kesalahan saat mengunduh file. Silakan coba lagi.');
                })
                .finally(() => {
                    hideLoading();
                });
        }

        // Make functions global
        window.showModal = showModal;
        window.exportModalToExcel = exportModalToExcel;
        window.exportToExcelEnhanced = exportToExcelEnhanced;
        window.exportModalToExcelEnhanced = exportModalToExcelEnhanced;
        window.printModal = printModal;
        window.validateExportData = validateExportData;
        window.checkExportStatus = checkExportStatus;

        // Initialize export status check
        $(document).ready(function () {
            checkExportStatus();
        });

        // Card watermark verifier - sama seperti form_input_laporan dan perusahaan_batubara
        setTimeout(function () {
            const testImg = new Image();
            testImg.onload = function () {
                console.log('✅ ESDM watermark logo loaded successfully for lbatubara cards and tables');
            };
            testImg.onerror = function () {
                console.warn('⚠️ ESDM logo not found, adding text watermark fallback');
                // Add text watermark fallback for cards and tables
                const style = document.createElement('style');
                style.textContent = `
                    .card::after {
                        content: 'ESDM' !important;
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        transform: translate(-50%, -50%) !important;
                        font-size: 48px !important;
                        font-weight: bold !important;
                        color: rgba(0,0,0,0.05) !important;
                        z-index: 1 !important;
                        pointer-events: none !important;
                    }
                    .table-responsive::after {
                        content: 'ESDM' !important;
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        transform: translate(-50%, -50%) !important;
                        font-size: 36px !important;
                        font-weight: bold !important;
                        color: rgba(0,0,0,0.03) !important;
                        z-index: 0 !important;
                        pointer-events: none !important;
                    }
                `;
                document.head.appendChild(style);
            };
            testImg.src = 'esdm2.png';
        }, 1000);
    </script>

    <!-- Modal Kelola Status Aktif / Non-Aktif Perusahaan -->
    <div class="modal fade" id="modalStatusPerusahaan" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header bg-dark text-white">
                    <h5 class="modal-title"><i class="bi bi-sliders me-2"></i>Kelola Status Perusahaan (Aktif / Non-Aktif)</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="alert alert-warning py-2 small mb-3">
                        <i class="bi bi-info-circle-fill me-1"></i>
                        Perusahaan yang berstatus <strong>Non-Aktif</strong> dikecualikan dari pembagi Total Perusahaan Wajib Lapor sehingga <strong>Persentase Tingkat Kepatuhan</strong> otomatis disesuaikan.
                    </div>
                    <div class="row g-2 mb-3 align-items-center">
                        <div class="col-md-5">
                            <input type="text" id="statusSearchInput" class="form-control form-control-sm" placeholder="Cari nama perusahaan / SK IUP / provinsi...">
                        </div>
                        <div class="col-md-7 text-md-end">
                            <div class="btn-group btn-group-sm" role="group">
                                <button type="button" class="btn btn-outline-danger active status-filter-btn" data-filter="nonaktif">Non-Aktif</button>
                                <button type="button" class="btn btn-outline-success status-filter-btn" data-filter="aktif">Aktif</button>
                                <button type="button" class="btn btn-outline-secondary status-filter-btn" data-filter="semua">Semua</button>
                            </div>
                        </div>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-sm table-hover align-middle">
                            <thead class="table-light">
                                <tr>
                                    <th width="45">No</th>
                                    <th>Nama Perusahaan</th>
                                    <th>SK IUP</th>
                                    <th>Provinsi</th>
                                    <th width="110">Status</th>
                                    <th width="140" class="text-center">Aksi</th>
                                </tr>
                            </thead>
                            <tbody id="statusCompanyTableBody">
                                <tr><td colspan="6" class="text-center py-4 text-muted">Memuat data...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentStatusFilter = 'nonaktif';
        let statusChangedInModal = false;

        function openStatusModal(filter) {
            currentStatusFilter = filter || 'nonaktif';
            statusChangedInModal = false;
            $('.status-filter-btn').removeClass('active');
            $('.status-filter-btn[data-filter="' + currentStatusFilter + '"]').addClass('active');
            $('#statusSearchInput').val('');
            $('#modalStatusPerusahaan').modal('show');
            loadStatusCompanies();
        }

        function loadStatusCompanies() {
            const q = $('#statusSearchInput').val() || '';
            const prov = $('#provinsi').val() || '<?php echo htmlspecialchars($provinsi ?? 'semua'); ?>';
            $('#statusCompanyTableBody').html('<tr><td colspan="6" class="text-center py-4 text-muted">Memuat data perusahaan...</td></tr>');
            $.post('lbatubara.php', {
                action: 'manage_company_status',
                filter_status: currentStatusFilter,
                q: q,
                provinsi: prov
            }, function(res) {
                if (!res || !res.success) {
                    $('#statusCompanyTableBody').html('<tr><td colspan="6" class="text-center text-danger py-4">Gagal memuat data.</td></tr>');
                    return;
                }
                if (!res.data || res.data.length === 0) {
                    $('#statusCompanyTableBody').html('<tr><td colspan="6" class="text-center text-muted py-4">Tidak ada perusahaan pada filter ini.</td></tr>');
                    return;
                }
                let html = '';
                res.data.forEach(function(item, idx) {
                    const badge = item.is_active
                        ? '<span class="badge bg-success">Aktif</span>'
                        : '<span class="badge bg-danger">Non-Aktif</span>';
                    const btn = item.is_active
                        ? '<button class="btn btn-outline-danger btn-sm" onclick="toggleCompanyStatusWeb(' + item.id + ', 0)"><i class="bi bi-slash-circle"></i> Non-Aktifkan</button>'
                        : '<button class="btn btn-outline-success btn-sm" onclick="toggleCompanyStatusWeb(' + item.id + ', 1)"><i class="bi bi-check-circle"></i> Aktifkan</button>';
                    html += '<tr>' +
                        '<td>' + (idx + 1) + '</td>' +
                        '<td class="fw-semibold">' + $('<div>').text(item.nama_perusahaan).html() + '</td>' +
                        '<td><code>' + $('<div>').text(item.sk_iup).html() + '</code></td>' +
                        '<td>' + $('<div>').text(item.nama_provinsi).html() + '</td>' +
                        '<td>' + badge + '</td>' +
                        '<td class="text-center">' + btn + '</td>' +
                        '</tr>';
                });
                $('#statusCompanyTableBody').html(html);
            }, 'json');
        }

        function toggleCompanyStatusWeb(id, targetActive) {
            const label = targetActive === 1 ? 'mengaktifkan' : 'menonaktifkan';
            const pin = prompt('Masukkan PIN keamanan untuk ' + label + ' perusahaan ini:');
            if (pin === null) return;
            $.post('lbatubara.php', {
                action: 'toggle_company_status',
                id: id,
                is_active: targetActive,
                pin: pin.trim()
            }, function(res) {
                if (res && res.success) {
                    statusChangedInModal = true;
                    alert(res.message + '\nHalaman akan dimuat ulang untuk memperbarui persentase.');
                    location.reload();
                } else {
                    alert((res && res.message) ? res.message : 'Gagal mengubah status.');
                }
            }, 'json');
        }

        $(document).on('click', '.status-filter-btn', function() {
            currentStatusFilter = $(this).data('filter');
            $('.status-filter-btn').removeClass('active');
            $(this).addClass('active');
            loadStatusCompanies();
        });

        let statusSearchTimer = null;
        $(document).on('input', '#statusSearchInput', function() {
            clearTimeout(statusSearchTimer);
            statusSearchTimer = setTimeout(loadStatusCompanies, 300);
        });
    </script>

</body>

</html>