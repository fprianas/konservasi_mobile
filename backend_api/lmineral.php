<?php
/**
 * Laporan Mineral - Dashboard Pelaporan Mineral
 * File: lmineral.php
 * Sumber Data: view vlaporan_mineral
 * 
 * IMPORTANT - ANTI-REDUNDANCY FILTER:
 * ====================================
 * Semua query yang menampilkan data pelaporan menggunakan GROUP BY
 * untuk menghindari duplikasi berdasarkan kombinasi:
 * - sk_iup (Nomor SK IUP Perusahaan)
 * - tahun (Tahun Pelaporan)
 * - waktu_pelaporan (Triwulan)
 * 
 * Jika ada data duplikat dengan kombinasi yang sama, sistem akan:
 * - Hanya menampilkan 1 record
 * - Mengambil data dengan waktu_input terbaru (MAX(waktu_input))
 * 
 * Ini memastikan satu perusahaan untuk satu periode (tahun + triwulan)
 * hanya muncul sekali dalam laporan.
 */

// Start session dan cek login
session_start();

// Cek apakah user sudah login
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    // Jika belum login, redirect ke login page
    header('Location: login.php');
    exit();
}

// Suppress any accidental output
ob_start();

require_once 'koneksi.php';

// AJAX handler untuk manajemen status aktif/non-aktif perusahaan mineral
if (isset($_POST['action']) && in_array($_POST['action'], ['manage_company_status', 'toggle_company_status'], true)) {
    while (ob_get_level()) { ob_end_clean(); }
    header('Content-Type: application/json; charset=utf-8');
    $act = $_POST['action'];

    if ($act === 'manage_company_status') {
        $filter_status = $_POST['filter_status'] ?? 'nonaktif';
        $q = escapeString(trim($_POST['q'] ?? ''));
        $provinsi = escapeString(trim($_POST['provinsi'] ?? ''));

        $where = ["pm.sk_iup IS NOT NULL", "pm.sk_iup != ''"];
        if ($filter_status === 'nonaktif') {
            $where[] = "COALESCE(pm.is_active, 1) = 0";
        } elseif ($filter_status === 'aktif') {
            $where[] = "COALESCE(pm.is_active, 1) = 1";
        }
        if (!empty($provinsi) && $provinsi !== 'semua') {
            $where[] = "prov.nama_provinsi = '$provinsi'";
        }
        if (!empty($q)) {
            $where[] = "(pm.nama_perusahaan LIKE '%$q%' OR pm.sk_iup LIKE '%$q%' OR COALESCE(prov.nama_provinsi, '') LIKE '%$q%')";
        }
        $where_sql = implode(' AND ', $where);
        $sql = "SELECT pm.id, pm.nama_perusahaan, pm.sk_iup, COALESCE(prov.nama_provinsi, '-') as nama_provinsi,
                       COALESCE(pm.jenis_izin, '-') as jenis_izin, COALESCE(pm.is_active, 1) as is_active
                FROM perusahaan_mineral pm
                LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id
                WHERE $where_sql
                ORDER BY pm.is_active ASC, pm.nama_perusahaan ASC
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
        $ok = executeQuery("UPDATE perusahaan_mineral SET is_active = $is_active WHERE id = $id");
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

// Handle AJAX requests - HARUS DI PALING ATAS sebelum output apapun
if (isset($_POST['action']) && $_POST['action'] == 'get_detail') {
    // Clear all output buffers
    while (ob_get_level()) {
        ob_end_clean();
    }
    
    // Start clean output buffer
    ob_start();
    
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-cache, must-revalidate');
    
    $status = $_POST['status'] ?? '';
    $tahun = $_POST['tahun'] ?? '';
    $triwulan = $_POST['triwulan'] ?? '';
    $provinsi = $_POST['provinsi'] ?? '';
    
    // Debug log
    error_log("AJAX Request - Status: $status, Tahun: $tahun, Triwulan: $triwulan, Provinsi: $provinsi");
    
    try {
        // Debug query khusus untuk total
        if ($status == 'total') {
            error_log("=== DEBUG TOTAL PERUSAHAAN ===");
            error_log("Filter provinsi yang diterima: '$provinsi'");
            
            // Test tanpa filter dulu
            $test_total_sql = "SELECT COUNT(*) as total FROM perusahaan_mineral per WHERE per.sk_iup IS NOT NULL AND per.sk_iup != ''";
            $test_total_result = executeQuery($test_total_sql);
            if ($test_total_result) {
                $test_total_row = $test_total_result->fetch_assoc();
                error_log("Total perusahaan tanpa filter: " . $test_total_row['total']);
            } else {
                error_log("Error pada test query total perusahaan");
            }
            
            // Test simple query untuk total
            $simple_test_sql = "SELECT per.sk_iup, per.nama_perusahaan FROM perusahaan_mineral per WHERE per.sk_iup IS NOT NULL LIMIT 5";
            $simple_test_result = executeQuery($simple_test_sql);
            if ($simple_test_result) {
                $simple_count = mysqli_num_rows($simple_test_result);
                error_log("Simple test query menghasilkan: " . $simple_count . " rows");
            } else {
                error_log("Error pada simple test query");
            }
            
            // Test dengan join provinsi
            $test_join_sql = "SELECT COUNT(*) as total, GROUP_CONCAT(DISTINCT prov.nama_provinsi SEPARATOR ', ') as provinsi_list
                             FROM perusahaan_mineral per 
                             LEFT JOIN provinsi_mineral prov ON per.id_provinsi = prov.id 
                             WHERE per.sk_iup IS NOT NULL AND per.sk_iup != ''";
            $test_join_result = executeQuery($test_join_sql);
            if ($test_join_result) {
                $test_join_row = $test_join_result->fetch_assoc();
                error_log("Total dengan join: " . $test_join_row['total']);
                error_log("Provinsi yang ada: " . $test_join_row['provinsi_list']);
            }
            
            // Test dengan filter provinsi jika ada
            if (!empty($provinsi) && $provinsi != 'semua') {
                $test_filter_sql = "SELECT COUNT(*) as total 
                                   FROM perusahaan_mineral per 
                                   LEFT JOIN provinsi_mineral prov ON per.id_provinsi = prov.id 
                                   WHERE per.sk_iup IS NOT NULL AND per.sk_iup != '' 
                                   AND prov.nama_provinsi = '$provinsi'";
                $test_filter_result = executeQuery($test_filter_sql);
                if ($test_filter_result) {
                    $test_filter_row = $test_filter_result->fetch_assoc();
                    error_log("Total dengan filter provinsi '$provinsi': " . $test_filter_row['total']);
                }
            }
        }
        
        // Debug query khusus untuk sudah_lapor
        if ($status == 'sudah_lapor') {
            $test_sql = "SELECT COUNT(*) as total FROM vlaporan_mineral";
            $test_result = executeQuery($test_sql);
            if ($test_result) {
                $test_row = $test_result->fetch_assoc();
                error_log("Test vlaporan_mineral - Total records: " . $test_row['total']);
            }
            
            // Test dengan filter yang sama
            $where_conditions = array();
            if (!empty($tahun) && $tahun != 'semua') {
                $where_conditions[] = "tahun = '$tahun'";
            }
            if (!empty($triwulan) && $triwulan != 'semua') {
                $where_conditions[] = "waktu_pelaporan = '$triwulan'";
            }
            if (!empty($provinsi) && $provinsi != 'semua') {
                $where_conditions[] = "provinsi = '$provinsi'";
            }
            
            if (!empty($where_conditions)) {
                $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
                $test_filtered_sql = "SELECT COUNT(*) as total FROM vlaporan_mineral $where_clause";
                $test_filtered_result = executeQuery($test_filtered_sql);
                if ($test_filtered_result) {
                    $test_filtered_row = $test_filtered_result->fetch_assoc();
                    error_log("Test vlaporan_mineral with filters - Total records: " . $test_filtered_row['total']);
                }
            }
        }
        
        $result = getDetailPerusahaanByStatus($status, $tahun, $triwulan, $provinsi);
        
        // Handle test data (array) vs normal database result
        if (is_array($result)) {
            error_log("Handling test data array - Count: " . count($result));
            $headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Alamat', 'Email', 'Provinsi', 'Status'];
            
            $response = array(
                'success' => true,
                'data' => $result,
                'headers' => $headers,
                'message' => 'Data test berhasil dimuat (' . count($result) . ' rows)'
            );
            
            echo json_encode($response);
            exit();
        } else if ($result && mysqli_num_rows($result) > 0) {
            $data = array();
            $headers = array();
            
            // Determine headers based on status
            switch($status) {
                case 'total':
                    $headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Jenis Izin', 'Komoditas', 'Provinsi', 'Status'];
                    break;
                case 'sudah_lapor':
                    $headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Provinsi', 'Tahun', 'Triwulan', 'Komoditas', 'Status'];
                    break;
                case 'belum_lapor':
                    $headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Jenis Izin', 'Komoditas', 'Provinsi', 'Status'];
                    break;
                default:
                    $headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Provinsi'];
            }
            
            while($row = $result->fetch_assoc()) {
                $data[] = $row;
            }
            
            // Bebaskan memory result
            freeResult($result);
            
            error_log("AJAX Response - Found " . count($data) . " records");
            
            echo json_encode([
                'success' => true,
                'data' => $data,
                'headers' => $headers,
                'count' => count($data),
                'debug' => "Status: $status, Records: " . count($data)
            ]);
            exit();
        } else {
            // Jika tidak ada data, coba query yang lebih sederhana untuk debugging
            if ($status == 'total') {
                // FALLBACK UNTUK TOTAL - QUERY SUPER SEDERHANA
                $simple_sql = "SELECT sk_iup, nama_perusahaan, alamat_perusahaan, email, id_provinsi, 'Terdaftar' as status_detail FROM perusahaan_mineral LIMIT 10";
                error_log("Fallback query untuk total: " . $simple_sql);
                $simple_result = executeQuery($simple_sql);
                if ($simple_result && mysqli_num_rows($simple_result) > 0) {
                    $sample_data = array();
                    while($row = $simple_result->fetch_assoc()) {
                        $sample_data[] = $row;
                    }
                    freeResult($simple_result);
                    error_log("Fallback berhasil, data: " . count($sample_data) . " rows");
                    echo json_encode([
                        'success' => true,
                        'data' => $sample_data,
                        'headers' => ['No', 'SK IUP', 'Nama Perusahaan', 'Alamat', 'Email', 'ID Provinsi', 'Status'],
                        'count' => count($sample_data),
                        'message' => 'Data total perusahaan (fallback) - ' . count($sample_data) . ' records'
                    ]);
                    exit;
                } else {
                    error_log("Fallback juga gagal!");
                }
            }
            
            if ($status == 'belum_lapor') {
                // Query fallback dengan LEFT JOIN approach
                $fallback_sql = "SELECT DISTINCT
                                    per.sk_iup,
                                    per.nama_perusahaan,
                                    COALESCE(per.alamat_perusahaan, 'N/A') as alamat_perusahaan,
                                    COALESCE(per.email, 'N/A') as email,
                                    COALESCE(prov.nama_provinsi, 'Tidak Diketahui') as provinsi,
                                    'Belum Melaporkan (Fallback)' as status_detail
                                FROM perusahaan_mineral per
                                LEFT JOIN provinsi_mineral prov ON per.id_provinsi = prov.id
                                LEFT JOIN vlaporan_mineral vlap ON per.sk_iup = vlap.sk_iup
                                WHERE per.sk_iup IS NOT NULL 
                                AND per.sk_iup != ''
                                AND vlap.sk_iup IS NULL
                                ORDER BY per.nama_perusahaan ASC 
                                LIMIT 10";
                
                $fallback_result = executeQuery($fallback_sql);
                
                if ($fallback_result && mysqli_num_rows($fallback_result) > 0) {
                    $fallback_data = array();
                    while($row = $fallback_result->fetch_assoc()) {
                        $fallback_data[] = $row;
                    }
                    freeResult($fallback_result);
                    
                    echo json_encode([
                        'success' => true,
                        'data' => $fallback_data,
                        'headers' => ['No', 'SK IUP', 'Nama Perusahaan', 'Alamat', 'Email', 'Provinsi', 'Status'],
                        'count' => count($fallback_data),
                        'message' => 'Data belum lapor (LEFT JOIN fallback) - ' . count($fallback_data) . ' records'
                    ]);
                    exit;
                }
            }
            
            error_log("AJAX Response - No data found for status: $status");
            echo json_encode([
                'success' => false,
                'data' => [],
                'headers' => ['No', 'SK IUP', 'Nama Perusahaan'],
                'count' => 0,
                'message' => "Tidak ada data ditemukan untuk status: $status dengan filter yang dipilih"
            ]);
            exit();
        }
    } catch (Exception $e) {
        error_log("AJAX Error: " . $e->getMessage());
        echo json_encode([
            'success' => false,
            'message' => 'Error: ' . $e->getMessage(),
            'debug' => "Status: $status, Error: " . $e->getMessage()
        ]);
        exit();
    } finally {
        // Pastikan koneksi ditutup setelah AJAX request selesai
        global $conn;
        if (isset($conn) && $conn) {
            mysqli_close($conn);
        }
        
        // Clean flush output
        $output = ob_get_clean();
        
        // Only output if it's valid JSON or empty
        if (!empty($output) && json_decode($output) === null) {
            // If output is not valid JSON, something went wrong - output clean error
            echo json_encode([
                'success' => false,
                'message' => 'Invalid output detected',
                'debug' => 'Output length: ' . strlen($output)
            ]);
        } else {
            echo $output;
        }
    }
    exit();
}

// Fungsi untuk mendapatkan daftar triwulan
function getTriwulanList() {
    $triwulan_options = [
        'Triwulan I',
        'Triwulan II', 
        'Triwulan III',
        'Triwulan IV'
    ];
    return $triwulan_options;
}

// Fungsi untuk mendapatkan statistik pelaporan dengan relasi yang benar
function getStatistikPelaporan($tahun = '', $triwulan = '', $provinsi = '') {
    $where_conditions = array();
    
    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "v.tahun = '$tahun'";
    }
    
    // Filter triwulan  
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "v.waktu_pelaporan = '$triwulan'";
    }
    
    // Filter provinsi dengan relasi yang benar
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions[] = "pm.nama_provinsi = '$provinsi'";
    }
    
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'AND ' . implode(' AND ', $where_conditions);
    }
    
    // Query dengan relasi yang benar:
    // perusahaan_mineral.sk_iup = vlaporan_mineral.sk_iup
    // perusahaan_mineral.id_provinsi = provinsi_mineral.id_provinsi
    $sql = "SELECT 
                COUNT(DISTINCT per.sk_iup) as total_perusahaan,
                COUNT(DISTINCT CASE WHEN v.sk_iup IS NOT NULL THEN per.sk_iup END) as sudah_melaporkan,
                COUNT(DISTINCT CASE WHEN v.sk_iup IS NULL THEN per.sk_iup END) as belum_melaporkan,
                ROUND(
                    (COUNT(DISTINCT CASE WHEN v.sk_iup IS NOT NULL THEN per.sk_iup END) * 100.0 / 
                     NULLIF(COUNT(DISTINCT per.sk_iup), 0)), 2
                ) as tingkat_kepatuhan
            FROM perusahaan_mineral per
            LEFT JOIN provinsi_mineral pm ON per.id_provinsi = pm.id_provinsi
            LEFT JOIN vlaporan_mineral v ON per.sk_iup = v.sk_iup 
            WHERE per.sk_iup IS NOT NULL AND COALESCE(per.is_active, 1) = 1 $where_clause";
    
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan statistik per provinsi dengan relasi yang benar
function getStatistikPerProvinsi($tahun = '', $triwulan = '') {
    $where_conditions = array();
    
    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "v.tahun = '$tahun'";
    }
    
    // Filter triwulan
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "v.waktu_pelaporan = '$triwulan'";
    }
    
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'AND ' . implode(' AND ', $where_conditions);
    }
    
    // Query statistik per provinsi dengan relasi yang benar
    $sql = "SELECT 
                COALESCE(pm.nama_provinsi, 'Tidak Diketahui') as nama_provinsi,
                COUNT(DISTINCT per.sk_iup) as total_perusahaan,
                COUNT(DISTINCT CASE WHEN v.sk_iup IS NOT NULL THEN per.sk_iup END) as sudah_melaporkan,
                COUNT(DISTINCT CASE WHEN v.sk_iup IS NULL THEN per.sk_iup END) as belum_melaporkan,
                ROUND(
                    (COUNT(DISTINCT CASE WHEN v.sk_iup IS NOT NULL THEN per.sk_iup END) * 100.0 / 
                     NULLIF(COUNT(DISTINCT per.sk_iup), 0)), 2
                ) as tingkat_kepatuhan
            FROM perusahaan_mineral per
            LEFT JOIN provinsi_mineral pm ON per.id_provinsi = pm.id_provinsi
            LEFT JOIN vlaporan_mineral v ON per.sk_iup = v.sk_iup 
            WHERE per.sk_iup IS NOT NULL AND COALESCE(per.is_active, 1) = 1 $where_clause
            GROUP BY pm.id_provinsi, pm.nama_provinsi
            HAVING total_perusahaan > 0
            ORDER BY tingkat_kepatuhan DESC, total_perusahaan DESC";
    
    return executeQuery($sql);
}

// Fungsi statistik 2 tabel sederhana - dengan support filter provinsi dan jenis perizinan
function getStatistikFallback($tahun = '', $triwulan = '', $provinsi = '', $jenis_perizinan = '') {
    
    // Query 1: Total perusahaan dari perusahaan_mineral dengan filter provinsi jika ada
    $where_conditions_total = array("sk_iup IS NOT NULL", "sk_iup != ''");
    
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        // Join dengan provinsi_mineral untuk filter provinsi
        $sql_total = "SELECT COUNT(DISTINCT pm.sk_iup) as total 
                      FROM perusahaan_mineral pm 
                      LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id 
                      WHERE pm.sk_iup IS NOT NULL AND pm.sk_iup != '' 
                      AND COALESCE(pm.is_active, 1) = 1
                      AND prov.nama_provinsi = '$provinsi'";
    } else {
        $sql_total = "SELECT COUNT(DISTINCT sk_iup) as total FROM perusahaan_mineral WHERE sk_iup IS NOT NULL AND sk_iup != '' AND COALESCE(is_active, 1) = 1";
    }
    
    $result_total = executeQuery($sql_total);
    $total_perusahaan = 0;
    if ($result_total && $row_total = $result_total->fetch_assoc()) {
        $total_perusahaan = $row_total['total'];
    }
    
    // Query 2: Perusahaan yang sudah melaporkan dari vlaporan_mineral dengan semua filter
    $where_conditions = array("sk_iup NOT IN (SELECT sk_iup FROM perusahaan_mineral WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')");
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "waktu_pelaporan = '$triwulan'";
    }
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions[] = "provinsi = '$provinsi'";
    }
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        $jp_esc = escapeString($jenis_perizinan);
        $where_conditions[] = "jenis_perizinan = '$jp_esc'";
    }
    
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions) . ' AND ';
    } else {
        $where_clause = 'WHERE ';
    }
    
    // Query dengan GROUP BY untuk menghitung unique combination (sk_iup + tahun + triwulan)
    // Ini memastikan konsistensi dengan tampilan data (tidak ada duplikasi)
    $sql_lapor = "SELECT COUNT(*) as sudah_lapor 
                  FROM (
                      SELECT sk_iup, tahun, waktu_pelaporan 
                      FROM vlaporan_mineral 
                      {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                      GROUP BY sk_iup, tahun, waktu_pelaporan
                  ) as unique_reports";
    $result_lapor = executeQuery($sql_lapor);
    $sudah_melaporkan = 0;
    if ($result_lapor && $row_lapor = $result_lapor->fetch_assoc()) {
        $sudah_melaporkan = $row_lapor['sudah_lapor'];
    }
    
    // Query 3: Hitung perusahaan yang belum melaporkan dengan cara yang lebih akurat
    // Menggunakan NOT IN dengan subquery yang konsisten dengan query sudah_lapor
    $provinsi_filter = '';
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi_filter = " AND prov.nama_provinsi = '" . escapeString($provinsi) . "'";
    }
    
    $sql_belum_lapor = "SELECT COUNT(DISTINCT pm.sk_iup) as belum_lapor
                        FROM perusahaan_mineral pm
                        LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id
                        WHERE pm.sk_iup IS NOT NULL 
                        AND pm.sk_iup != ''
                        AND COALESCE(pm.is_active, 1) = 1
                        $provinsi_filter
                        AND pm.sk_iup NOT IN (
                            SELECT DISTINCT sk_iup 
                            FROM vlaporan_mineral 
                            {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                        )";
    
    $result_belum = executeQuery($sql_belum_lapor);
    $belum_melaporkan = 0;
    if ($result_belum && $row_belum = $result_belum->fetch_assoc()) {
        $belum_melaporkan = $row_belum['belum_lapor'];
    }
    
    // Hitung tingkat kepatuhan
    $tingkat_kepatuhan = $total_perusahaan > 0 ? round(($sudah_melaporkan * 100.0) / $total_perusahaan, 2) : 0;
    
    // Log untuk debugging
    error_log("=== STATISTIK CALCULATION ===");
    error_log("Total Perusahaan: $total_perusahaan");
    error_log("Sudah Melaporkan: $sudah_melaporkan");
    error_log("Belum Melaporkan: $belum_melaporkan (query langsung)");
    error_log("Tingkat Kepatuhan: $tingkat_kepatuhan%");
    error_log("Filter - Tahun: " . ($tahun ?? 'semua') . ", Triwulan: " . ($triwulan ?? 'semua') . ", Provinsi: " . ($provinsi ?? 'semua'));
    
    // Hitung perusahaan non-aktif
    if (!empty($provinsi) && $provinsi != 'semua') {
        $prov_esc = escapeString($provinsi);
        $sql_nonaktif = "SELECT COUNT(DISTINCT pm.sk_iup) as total_nonaktif
                         FROM perusahaan_mineral pm
                         LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id
                         WHERE pm.sk_iup IS NOT NULL AND pm.sk_iup != ''
                         AND COALESCE(pm.is_active, 1) = 0
                         AND prov.nama_provinsi = '$prov_esc'";
    } else {
        $sql_nonaktif = "SELECT COUNT(DISTINCT sk_iup) as total_nonaktif FROM perusahaan_mineral WHERE sk_iup IS NOT NULL AND sk_iup != '' AND COALESCE(is_active, 1) = 0";
    }
    $res_nonaktif = executeQuery($sql_nonaktif);
    $total_nonaktif = 0;
    if ($res_nonaktif && $row_na = $res_nonaktif->fetch_assoc()) {
        $total_nonaktif = intval($row_na['total_nonaktif']);
    }

    // Return hasil dalam format array
    return array(
        'total_perusahaan' => $total_perusahaan,
        'sudah_melaporkan' => $sudah_melaporkan,
        'belum_melaporkan' => $belum_melaporkan,
        'non_aktif' => $total_nonaktif,
        'tingkat_kepatuhan' => $tingkat_kepatuhan
    );
}

// Fungsi statistik per provinsi (sementara dari view saja)
function getStatistikProvinsieFallback($tahun = '', $triwulan = '') {
    $where_conditions = array();
    
    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "tahun = '$tahun'";
    }
    
    // Filter triwulan
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "waktu_pelaporan = '$triwulan'";
    }
    
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
    }
    
    // Query sederhana dari view saja dulu
    $sql = "SELECT 
                provinsi as nama_provinsi,
                COUNT(DISTINCT sk_iup) as total_perusahaan,
                COUNT(DISTINCT sk_iup) as sudah_melaporkan,
                0 as belum_melaporkan,
                100.0 as tingkat_kepatuhan
            FROM vlaporan_mineral 
            $where_clause
            GROUP BY provinsi
            ORDER BY total_perusahaan DESC
            LIMIT 10";
    
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar provinsi dari view
function getProvinsiList() {
    $sql = "SELECT DISTINCT provinsi as nama_provinsi 
            FROM vlaporan_mineral 
            WHERE provinsi IS NOT NULL 
            ORDER BY provinsi ASC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan statistik detail per provinsi dengan relasi yang benar
function getStatistikDetailPerProvinsi($tahun = '', $triwulan = '', $provinsi = '') {
    // Step 1: Ambil data laporan per provinsi dari vlaporan_mineral
    $where_conditions_laporan = array();
    
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions_laporan[] = "tahun = '$tahun'";
    }
    
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions_laporan[] = "waktu_pelaporan = '$triwulan'";
    }
    
    // Filter provinsi - ini adalah kunci utama untuk menampilkan provinsi tertentu saja
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions_laporan[] = "provinsi = '$provinsi'";
    }
    
    $where_clause_laporan = '';
    if (!empty($where_conditions_laporan)) {
        $where_clause_laporan = 'WHERE ' . implode(' AND ', $where_conditions_laporan) . ' AND ';
    } else {
        $where_clause_laporan = 'WHERE ';
    }
    
    // Query dengan relasi yang benar: perusahaan_mineral.id_provinsi = provinsi_mineral.id
    $sql = "SELECT 
                v.provinsi as nama_provinsi,
                COUNT(DISTINCT v.sk_iup) as sudah_melaporkan,
                GROUP_CONCAT(DISTINCT v.komoditas_mineral ORDER BY v.komoditas_mineral SEPARATOR ', ') as komoditas_dilaporkan,
                0 as total_perusahaan_terdaftar
            FROM vlaporan_mineral v
            {$where_clause_laporan}v.provinsi IS NOT NULL 
            AND v.provinsi != ''
            AND v.sk_iup NOT IN (SELECT sk_iup FROM perusahaan_mineral WHERE is_active = 0 AND sk_iup IS NOT NULL AND sk_iup != '')
            GROUP BY v.provinsi
            ORDER BY sudah_melaporkan DESC
            LIMIT 25";
    
    $result = executeQuery($sql);
    
    // Jika query dengan subquery gagal, coba query sederhana untuk debug
    if (!$result) {
        // Query debug sederhana dengan filter provinsi yang sama
        $sql_debug = "SELECT 
                    provinsi as nama_provinsi,
                    COUNT(DISTINCT sk_iup) as sudah_melaporkan,
                    0 as total_perusahaan_terdaftar,
                    GROUP_CONCAT(DISTINCT komoditas_mineral ORDER BY komoditas_mineral SEPARATOR ', ') as komoditas_dilaporkan
                FROM vlaporan_mineral 
                {$where_clause_laporan}provinsi IS NOT NULL 
                AND provinsi != ''
                GROUP BY provinsi
                ORDER BY sudah_melaporkan DESC
                LIMIT 25";
        
        $result = executeQuery($sql_debug);
    }
    
    return $result;
}

// Fungsi debug untuk memverifikasi struktur relasi tabel
function debugRelasiTabel() {
    echo "<!-- DEBUG RELASI TABEL -->";
    
    // 1. Cek struktur tabel perusahaan_mineral
    $sql1 = "DESCRIBE perusahaan_mineral";
    $result1 = executeQuery($sql1);
    echo "<!-- Struktur perusahaan_mineral: ";
    if ($result1) {
        while($row = $result1->fetch_assoc()) {
            echo $row['Field'] . " (" . $row['Type'] . "), ";
        }
    }
    echo " -->";
    
    // 2. Cek struktur tabel provinsi_mineral
    $sql2 = "DESCRIBE provinsi_mineral";
    $result2 = executeQuery($sql2);
    echo "<!-- Struktur provinsi_mineral: ";
    if ($result2) {
        while($row = $result2->fetch_assoc()) {
            echo $row['Field'] . " (" . $row['Type'] . "), ";
        }
    }
    echo " -->";
    
    // 3. Test relasi dengan sample data
    $sql3 = "SELECT 
                pm.sk_iup, 
                pm.nama_perusahaan, 
                pm.id_provinsi as pm_id_prov,
                prov.id as prov_id,
                prov.nama_provinsi 
             FROM perusahaan_mineral pm 
             LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id 
             WHERE pm.sk_iup IS NOT NULL 
             LIMIT 5";
    $result3 = executeQuery($sql3);
    echo "<!-- Sample relasi data: ";
    if ($result3) {
        while($row = $result3->fetch_assoc()) {
            echo "[SK:" . $row['sk_iup'] . " PM_ID:" . $row['pm_id_prov'] . " PROV_ID:" . $row['prov_id'] . " NAMA:" . $row['nama_provinsi'] . "] ";
        }
    }
    echo " -->";
}

// Fungsi untuk mendapatkan detail perusahaan berdasarkan status
function getDetailPerusahaanByStatus($status = 'all', $tahun = '', $triwulan = '', $provinsi = '') {
    error_log("Function called with Status: $status, Tahun: $tahun, Triwulan: $triwulan, Provinsi: $provinsi");
    
    // Query berdasarkan status
    switch($status) {
        case 'total':
            // Query dengan RELASI YANG BENAR berdasarkan koreksi
            // perusahaan_mineral.id_provinsi = provinsi_mineral.id
            
            $where_clause = "WHERE per.sk_iup IS NOT NULL AND per.sk_iup != '' AND COALESCE(per.is_active, 1) = 1";
            
            // Tambahkan filter provinsi jika ada
            if (!empty($provinsi) && $provinsi != 'semua') {
                $provinsi = escapeString($provinsi);
                $where_clause .= " AND prov.nama_provinsi = '$provinsi'";
            }
            
            $sql = "SELECT 
                        per.sk_iup,
                        per.nama_perusahaan,
                        per.jenis_izin,
                        per.komoditas,
                        prov.nama_provinsi as provinsi,
                        'Terdaftar' as status_detail
                    FROM perusahaan_mineral per
                    LEFT JOIN provinsi_mineral prov ON per.id_provinsi = prov.id
                    $where_clause
                    ORDER BY per.nama_perusahaan ASC";
            
            error_log("Query total dengan relasi benar: " . $sql);
            break;
            
        case 'sudah_lapor':
            // Query untuk yang sudah lapor - dengan GROUP BY untuk menghindari duplikasi
            // Filter: kombinasi sk_iup + tahun + triwulan hanya ditampilkan sekali
            $where_conditions = array();
            
            if (!empty($tahun) && $tahun != 'semua') {
                $tahun = escapeString($tahun);
                $where_conditions[] = "tahun = '$tahun'";
            }
            if (!empty($triwulan) && $triwulan != 'semua') {
                $triwulan = escapeString($triwulan);
                $where_conditions[] = "waktu_pelaporan = '$triwulan'";
            }
            if (!empty($provinsi) && $provinsi != 'semua') {
                $provinsi = escapeString($provinsi);
                $where_conditions[] = "provinsi = '$provinsi'";
            }
            
            $where_clause = '';
            if (!empty($where_conditions)) {
                $where_clause = 'WHERE ' . implode(' AND ', $where_conditions) . ' AND ';
            } else {
                $where_clause = 'WHERE ';
            }
            
            // Query dengan GROUP BY untuk menghindari redundansi
            // Jika ada duplikasi (sk_iup + tahun + triwulan sama), ambil yang terakhir diinput
            $sql = "SELECT 
                        sk_iup,
                        nama_perusahaan,
                        provinsi,
                        tahun,
                        waktu_pelaporan as triwulan,
                        komoditas_mineral,
                        'Sudah Melaporkan' as status_detail,
                        MAX(waktu_input) as laporan_terakhir
                    FROM vlaporan_mineral 
                    {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                    GROUP BY sk_iup, tahun, waktu_pelaporan
                    ORDER BY nama_perusahaan ASC";
            break;
            
        case 'belum_lapor':
            // Logika: Total Perusahaan - Perusahaan yang Sudah Lapor = Perusahaan yang Belum Lapor
            // PENTING: Query ini harus konsisten dengan perhitungan statistik
            // Harus mempertimbangkan filter tahun dan triwulan yang aktif
            
            // Build filter conditions untuk subquery
            $where_conditions_subquery = array();
            
            if (!empty($tahun) && $tahun != 'semua') {
                $tahun = escapeString($tahun);
                $where_conditions_subquery[] = "tahun = '$tahun'";
            }
            if (!empty($triwulan) && $triwulan != 'semua') {
                $triwulan = escapeString($triwulan);
                $where_conditions_subquery[] = "waktu_pelaporan = '$triwulan'";
            }
            if (!empty($provinsi) && $provinsi != 'semua') {
                $provinsi = escapeString($provinsi);
                $where_conditions_subquery[] = "provinsi = '$provinsi'";
            }
            
            $where_clause_subquery = '';
            if (!empty($where_conditions_subquery)) {
                $where_clause_subquery = 'WHERE ' . implode(' AND ', $where_conditions_subquery) . ' AND ';
            } else {
                $where_clause_subquery = 'WHERE ';
            }
            
            // Filter provinsi untuk main query
            $provinsi_filter = "";
            if (!empty($provinsi) && $provinsi != 'semua') {
                $provinsi_filter = " AND prov.nama_provinsi = '" . escapeString($provinsi) . "'";
            }
            
            // Query dengan subquery yang konsisten dengan GROUP BY di sudah_lapor
            // NOT IN menggunakan kombinasi (sk_iup, tahun, triwulan) yang sudah unique
            $sql = "SELECT 
                        per.sk_iup,
                        per.nama_perusahaan,
                        per.jenis_izin,
                        per.komoditas,
                        prov.nama_provinsi as provinsi,
                        'Belum Melaporkan' as status_detail
                    FROM perusahaan_mineral per
                    LEFT JOIN provinsi_mineral prov ON per.id_provinsi = prov.id
                    WHERE per.sk_iup IS NOT NULL 
                    AND per.sk_iup != ''
                    AND COALESCE(per.is_active, 1) = 1
                    $provinsi_filter
                    AND per.sk_iup NOT IN (
                        SELECT sk_iup 
                        FROM (
                            SELECT sk_iup, tahun, waktu_pelaporan
                            FROM vlaporan_mineral 
                            {$where_clause_subquery}sk_iup IS NOT NULL AND sk_iup != ''
                            GROUP BY sk_iup, tahun, waktu_pelaporan
                        ) as sudah_lapor_unique
                    )
                    ORDER BY per.nama_perusahaan ASC";
            
            error_log("Query belum_lapor with filters - Tahun: $tahun, Triwulan: $triwulan, Provinsi: $provinsi");
            break;
            
        case 'test_data':
            // Query simple untuk debugging - return static data
            $data = array();
            $data[] = array(
                'sk_iup' => 'TEST001',
                'nama_perusahaan' => 'PT Test Company',
                'alamat_perusahaan' => 'Test Address',
                'email' => 'test@company.com',
                'provinsi' => 'Test Province',
                'status_detail' => 'Test Status'
            );
            
            $data[] = array(
                'sk_iup' => 'TEST002',
                'nama_perusahaan' => 'PT Another Test',
                'alamat_perusahaan' => 'Another Address',
                'email' => 'another@company.com',
                'provinsi' => 'Another Province',
                'status_detail' => 'Another Status'
            );
            
            error_log("Returning test data: " . count($data) . " rows");
            return $data;
            break;
            
        case 'simple_test':
            // Query paling sederhana
            $sql = "SELECT 'TEST' as sk_iup, 'Test Company' as nama_perusahaan, 'Test Address' as alamat_perusahaan, 'test@email.com' as email, 'Test Province' as provinsi, 'Test Status' as status_detail";
            break;
            
        case 'test_vlaporan':
            // Test query untuk vlaporan_mineral
            $sql = "SELECT 
                        sk_iup,
                        nama_perusahaan,
                        provinsi,
                        tahun,
                        waktu_pelaporan as triwulan,
                        komoditas_mineral,
                        'Sudah Lapor' as status_detail
                    FROM vlaporan_mineral 
                    ORDER BY waktu_input DESC 
                    LIMIT 10";
            break;
            
        default:
            error_log("Unknown status: $status");
            return null;
    }
    
    error_log("Executing SQL: " . $sql);
    $result = executeQuery($sql);
    
    if ($result) {
        $count = mysqli_num_rows($result);
        error_log("Query result: $count rows");
    } else {
        error_log("Query failed");
    }
    
    return $result;
}

// Fungsi khusus untuk mendapatkan total perusahaan per provinsi dengan relasi yang benar
function getTotalPerusahaanPerProvinsi() {
    // Relasi yang benar: perusahaan_mineral.id_provinsi = provinsi_mineral.id
    $sql = "SELECT 
                prov.nama_provinsi,
                prov.id as id_provinsi,
                COUNT(DISTINCT per.sk_iup) as total_perusahaan
            FROM provinsi_mineral prov
            LEFT JOIN perusahaan_mineral per ON prov.id = per.id_provinsi AND COALESCE(per.is_active, 1) = 1
            WHERE per.sk_iup IS NOT NULL AND per.sk_iup != ''
            GROUP BY prov.id, prov.nama_provinsi
            ORDER BY total_perusahaan DESC";
    
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan detail perusahaan per provinsi tertentu
function getDetailPerusahaanProvinsi($id_provinsi, $tahun = '', $triwulan = '') {
    $where_conditions = array("per.id_provinsi = " . intval($id_provinsi));
    
    // Filter tahun untuk laporan
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "v.tahun = '$tahun'";
    }
    
    // Filter triwulan untuk laporan
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "v.waktu_pelaporan = '$triwulan'";
    }
    
    $where_clause = 'WHERE ' . implode(' AND ', $where_conditions);
    
    // Query detail perusahaan dalam provinsi tersebut
    $sql = "SELECT 
                per.sk_iup,
                per.nama_perusahaan,
                pm.nama_provinsi,
                CASE WHEN v.sk_iup IS NOT NULL THEN 'Sudah Lapor' ELSE 'Belum Lapor' END as status_pelaporan,
                v.tahun,
                v.waktu_pelaporan as triwulan,
                v.komoditas_mineral,
                v.tanggal_lapor
            FROM perusahaan_mineral per
            LEFT JOIN provinsi_mineral pm ON per.id_provinsi = pm.id_provinsi
            LEFT JOIN vlaporan_mineral v ON per.sk_iup = v.sk_iup 
                AND (" . str_replace('per.id_provinsi = ' . intval($id_provinsi) . ' AND ', '', implode(' AND ', array_slice($where_conditions, 1))) . ")
            $where_clause
            ORDER BY per.nama_perusahaan ASC, v.tahun DESC, v.waktu_pelaporan DESC";
    
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar tahun dari view
function getTahunList() {
    $sql = "SELECT DISTINCT tahun 
            FROM vlaporan_mineral 
            WHERE tahun IS NOT NULL 
            AND tahun != '' 
            ORDER BY tahun DESC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar komoditas mineral dari view
function getKomoditasList() {
    $sql = "SELECT DISTINCT komoditas_mineral 
            FROM vlaporan_mineral 
            WHERE komoditas_mineral IS NOT NULL 
            AND komoditas_mineral != '' 
            ORDER BY komoditas_mineral ASC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan daftar jenis perizinan dari view
function getJenisPerizinanList() {
    $sql = "SELECT DISTINCT jenis_perizinan 
            FROM vlaporan_mineral 
            WHERE jenis_perizinan IS NOT NULL 
            AND jenis_perizinan != '' 
            AND jenis_perizinan != '-' 
            ORDER BY jenis_perizinan ASC";
    return executeQuery($sql);
}

// Fungsi untuk mendapatkan semua data atau dengan filter
function getAllMineralData($nama_perusahaan = '', $provinsi = '', $komoditas = '', $tahun = '', $triwulan = '', $filter_objek = array(), $status_produksi = array(), $jenis_perizinan = '', $limit = null) {
    $where_conditions = array();
    
    // Filter nama perusahaan (pencarian LIKE)
    if (!empty($nama_perusahaan) && trim($nama_perusahaan) != '') {
        $nama_perusahaan = escapeString(trim($nama_perusahaan));
        $where_conditions[] = "nama_perusahaan LIKE '%$nama_perusahaan%'";
    }
    
    // Filter provinsi
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi = escapeString($provinsi);
        $where_conditions[] = "provinsi = '$provinsi'";
    }
    
    // Filter komoditas
    if (!empty($komoditas) && $komoditas != 'semua') {
        $komoditas = escapeString($komoditas);
        $where_conditions[] = "komoditas_mineral = '$komoditas'";
    }
    
    // Filter tahun
    if (!empty($tahun) && $tahun != 'semua') {
        $tahun = escapeString($tahun);
        $where_conditions[] = "tahun = '$tahun'";
    }
    
    // Filter triwulan (pencarian EXACT MATCH, bukan LIKE)
    if (!empty($triwulan) && $triwulan != 'semua') {
        $triwulan = escapeString($triwulan);
        $where_conditions[] = "waktu_pelaporan = '$triwulan'";
    }
    
    // Filter Jenis Perizinan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        if (is_array($jenis_perizinan)) {
            $jp_clean = array_filter($jenis_perizinan, function($v) { return $v !== 'semua' && !empty($v); });
            if (!empty($jp_clean)) {
                $jp_escaped = array_map(function($item) {
                    return "'" . escapeString(trim($item)) . "'";
                }, $jp_clean);
                $where_conditions[] = "jenis_perizinan IN (" . implode(',', $jp_escaped) . ")";
            }
        } else {
            $jenis_perizinan_clean = escapeString(trim($jenis_perizinan));
            $where_conditions[] = "jenis_perizinan = '$jenis_perizinan_clean'";
        }
    }
    
    // Filter Status Produksi (berdasarkan kolom sistem_penambangan)
    if (!empty($status_produksi)) {
        $has_sudah = in_array('sudah', $status_produksi);
        $has_belum = in_array('belum', $status_produksi);
        
        if ($has_belum && !$has_sudah) {
            // Hanya Belum Produksi: terdapat kata 'Belum produksi'
            $where_conditions[] = "LOWER(sistem_penambangan) LIKE '%belum produksi%'";
        } elseif ($has_sudah && !$has_belum) {
            // Hanya Sudah Produksi: tidak terdapat kata 'Belum produksi'
            $where_conditions[] = "(sistem_penambangan IS NOT NULL AND sistem_penambangan != '' AND sistem_penambangan != '-' AND LOWER(sistem_penambangan) NOT LIKE '%belum produksi%')";
        }
    }
    
    // Filter Objek Konservasi (Hanya tampilkan record yang mengisi objek yang dipilih)
    if (!empty($filter_objek) && !in_array('semua', $filter_objek)) {
        $objek_conds = array();
        
        // 1. Recovery Penambangan
        if (in_array('recovery_penambangan', $filter_objek)) {
            $objek_conds[] = "((rencana_recovery_2_1 IS NOT NULL AND rencana_recovery_2_1 != '' AND rencana_recovery_2_1 != '-' AND rencana_recovery_2_1 != '0') OR " .
                             "(recovery_penambangan_truck_2_2 IS NOT NULL AND recovery_penambangan_truck_2_2 != '' AND recovery_penambangan_truck_2_2 != '-' AND recovery_penambangan_truck_2_2 != '0') OR " .
                             "(recovery_penambangan_survey_2_3 IS NOT NULL AND recovery_penambangan_survey_2_3 != '' AND recovery_penambangan_survey_2_3 != '-' AND recovery_penambangan_survey_2_3 != '0') OR " .
                             "(rencana_recovery_2_4 IS NOT NULL AND rencana_recovery_2_4 != '' AND rencana_recovery_2_4 != '-' AND rencana_recovery_2_4 != '0'))";
        }
        
        // 2. Recovery Pengolahan
        if (in_array('recovery_pengolahan', $filter_objek)) {
            $objek_conds[] = "((rencana_recovery_pengolahan_fs IS NOT NULL AND rencana_recovery_pengolahan_fs != '' AND rencana_recovery_pengolahan_fs != '-' AND rencana_recovery_pengolahan_fs != '0') OR " .
                             "(rencana_recovery_pengolahan_rkab IS NOT NULL AND rencana_recovery_pengolahan_rkab != '' AND rencana_recovery_pengolahan_rkab != '-' AND rencana_recovery_pengolahan_rkab != '0') OR " .
                             "(recovery_pemulihan_2_6 IS NOT NULL AND recovery_pemulihan_2_6 != '' AND recovery_pemulihan_2_6 != '-' AND recovery_pemulihan_2_6 != '0'))";
        }
        
        // 3. Mineral Kadar Rendah (MKR)
        $mkr_conds = array();
        if (in_array('mkr_kumulatif', $filter_objek) || in_array('mkr', $filter_objek)) {
            $mkr_conds[] = "(mkr_stok_awal_tahun IS NOT NULL AND mkr_stok_awal_tahun != '' AND mkr_stok_awal_tahun != '-' AND mkr_stok_awal_tahun != '0')";
        }
        if (in_array('mkr_kuantitatif', $filter_objek) || in_array('mkr', $filter_objek)) {
            $mkr_conds[] = "((mkr_kuantitas IS NOT NULL AND mkr_kuantitas != '' AND mkr_kuantitas != '-' AND mkr_kuantitas != '0') OR (pmkr_volume IS NOT NULL AND pmkr_volume != '' AND pmkr_volume != '-' AND pmkr_volume != '0'))";
        }
        if (!empty($mkr_conds)) {
            $objek_conds[] = "(" . implode(' OR ', $mkr_conds) . ")";
        }
        
        // 4. Mineral Ikutan (MI)
        $mi_conds = array();
        if (in_array('mi_kumulatif', $filter_objek) || in_array('mi', $filter_objek)) {
            $mi_conds[] = "(mi_stok_awal_tahun IS NOT NULL AND mi_stok_awal_tahun != '' AND mi_stok_awal_tahun != '-' AND mi_stok_awal_tahun != '0')";
        }
        if (in_array('mi_kuantitatif', $filter_objek) || in_array('mi', $filter_objek)) {
            $mi_conds[] = "((mi_kuantitias IS NOT NULL AND mi_kuantitias != '' AND mi_kuantitias != '-' AND mi_kuantitias != '0') OR (pmi_volume IS NOT NULL AND pmi_volume != '' AND pmi_volume != '-' AND pmi_volume != '0'))";
        }
        if (!empty($mi_conds)) {
            $objek_conds[] = "(" . implode(' OR ', $mi_conds) . ")";
        }
        
        // 5. Cadangan Marginal (CM)
        $cm_conds = array();
        if (in_array('cm_kumulatif', $filter_objek) || in_array('cm', $filter_objek)) {
            $cm_conds[] = "(cm_stok_awal_tahun IS NOT NULL AND cm_stok_awal_tahun != '' AND cm_stok_awal_tahun != '-' AND cm_stok_awal_tahun != '0')";
        }
        if (in_array('cm_kuantitatif', $filter_objek) || in_array('cm', $filter_objek)) {
            $cm_conds[] = "((cm_kuantitas IS NOT NULL AND cm_kuantitas != '' AND cm_kuantitas != '-' AND cm_kuantitas != '0') OR (pcm_volume IS NOT NULL AND pcm_volume != '' AND pcm_volume != '-' AND pcm_volume != '0'))";
        }
        if (!empty($cm_conds)) {
            $objek_conds[] = "(" . implode(' OR ', $cm_conds) . ")";
        }
        
        // 6. Cadangan Tidak Tertambang (CMTT)
        $cmtt_conds = array();
        if (in_array('cmtt_kumulatif', $filter_objek) || in_array('cmtt_kuantitatif', $filter_objek) || in_array('cmtt', $filter_objek)) {
            $cmtt_conds[] = "(cmtt_kuantitas_cadangan IS NOT NULL AND cmtt_kuantitas_cadangan != '' AND cmtt_kuantitas_cadangan != '-' AND cmtt_kuantitas_cadangan != '0')";
        }
        if (!empty($cmtt_conds)) {
            $objek_conds[] = "(" . implode(' OR ', $cmtt_conds) . ")";
        }
        
        // 7. Sisa Hasil Pengolahan (SHP)
        $shp_conds = array();
        if (in_array('shp_kumulatif', $filter_objek) || in_array('shp', $filter_objek)) {
            $shp_conds[] = "(shp_komulatif_awal_tahun IS NOT NULL AND shp_komulatif_awal_tahun != '' AND shp_komulatif_awal_tahun != '-' AND shp_komulatif_awal_tahun != '0')";
        }
        if (in_array('shp_kuantitatif', $filter_objek) || in_array('shp', $filter_objek)) {
            $shp_conds[] = "((shp_kuantitas IS NOT NULL AND shp_kuantitas != '' AND shp_kuantitas != '-' AND shp_kuantitas != '0') OR (pshpp_volume IS NOT NULL AND pshpp_volume != '' AND pshpp_volume != '-' AND pshpp_volume != '0'))";
        }
        if (!empty($shp_conds)) {
            $objek_conds[] = "(" . implode(' OR ', $shp_conds) . ")";
        }
        
        if (!empty($objek_conds)) {
            $where_conditions[] = "(" . implode(' OR ', $objek_conds) . ")";
        }
    }
    
    // Gabungkan kondisi WHERE
    $where_clause = '';
    if (!empty($where_conditions)) {
        $where_clause = 'WHERE ' . implode(' AND ', $where_conditions) . ' AND ';
    } else {
        $where_clause = 'WHERE ';
    }
    
    // Query dengan GROUP BY untuk menghindari redundansi
    // Filter: kombinasi sk_iup + tahun + triwulan hanya ditampilkan sekali
    // Jika ada duplikasi, ambil record dengan waktu_input terbaru
    $sql = "SELECT v.* 
            FROM vlaporan_mineral v
            INNER JOIN (
                SELECT sk_iup, tahun, waktu_pelaporan, MAX(id) as max_id
                FROM vlaporan_mineral
                {$where_clause}sk_iup IS NOT NULL AND sk_iup != ''
                GROUP BY sk_iup, tahun, waktu_pelaporan
            ) latest ON v.id = latest.max_id
            ORDER BY v.waktu_input DESC";
            
    if ($limit !== null) {
        $sql .= " LIMIT " . intval($limit);
    }
    
    return executeQuery($sql);
}

// Selalu tampilkan data - baik semua data atau hasil pencarian
$mineral_data = null;
$show_table = true;
$total_records = 0; // Untuk tracking total data
$filter_objek = isset($_GET['filter_objek']) && is_array($_GET['filter_objek']) ? $_GET['filter_objek'] : array();
$status_produksi = isset($_GET['status_produksi']) && is_array($_GET['status_produksi']) ? $_GET['status_produksi'] : array('sudah', 'belum');

// Filter jenis perizinan
$filter_jenis_perizinan = isset($_GET['jenis_perizinan']) ? $_GET['jenis_perizinan'] : '';

// Jika ada parameter pencarian, gunakan filter
if (isset($_GET['action']) && $_GET['action'] == 'search') {
    $nama_perusahaan = isset($_GET['nama_perusahaan']) ? $_GET['nama_perusahaan'] : '';
    $provinsi = isset($_GET['provinsi']) ? $_GET['provinsi'] : '';
    $komoditas = isset($_GET['komoditas']) ? $_GET['komoditas'] : '';
    $tahun = isset($_GET['tahun']) ? $_GET['tahun'] : '';
    $triwulan = isset($_GET['triwulan']) ? $_GET['triwulan'] : '';
    $status_produksi = isset($_GET['status_produksi']) && is_array($_GET['status_produksi']) ? $_GET['status_produksi'] : array();
    
    $mineral_data = getAllMineralData($nama_perusahaan, $provinsi, $komoditas, $tahun, $triwulan, $filter_objek, $status_produksi, $filter_jenis_perizinan);
} else {
    // Default: tampilkan 200 data terbaru untuk kecepatan load awal
    $mineral_data = getAllMineralData('', '', '', '', '', array(), array(), '', 200);
}

// Hitung total records untuk pagination
if ($mineral_data) {
    $total_records = mysqli_num_rows($mineral_data);
}

// Get data untuk dropdown
$provinsi_list = null;
$tahun_list = null;
$komoditas_list = null;
$jenis_perizinan_list = null;
$jenis_perizinan_options = array();
$statistik_umum = null;
$statistik_provinsi = null;

try {
    $provinsi_list = getProvinsiList();
    $tahun_list = getTahunList();
    $komoditas_list = getKomoditasList();
    $jenis_perizinan_list = getJenisPerizinanList();
    
    // Ambil daftar perizinan unik
    if ($jenis_perizinan_list && mysqli_num_rows($jenis_perizinan_list) > 0) {
        while($row_jp = $jenis_perizinan_list->fetch_assoc()) {
            $jp_val = trim($row_jp['jenis_perizinan']);
            if (!empty($jp_val) && $jp_val != '-' && !in_array($jp_val, $jenis_perizinan_options)) {
                $jenis_perizinan_options[] = $jp_val;
            }
        }
    }
    // Fallback jika database belum ada atau kosong
    if (empty($jenis_perizinan_options)) {
        $jenis_perizinan_options = ['IUP', 'IUPK', 'KK', 'IPR', 'SIPB'];
    }
    
    // Ambil parameter filter untuk statistik
    $filter_tahun = isset($_GET['tahun']) ? $_GET['tahun'] : '';
    $filter_triwulan = isset($_GET['triwulan']) ? $_GET['triwulan'] : '';
    $filter_provinsi = isset($_GET['provinsi']) ? $_GET['provinsi'] : '';
    
    // Debug: tampilkan parameter filter
    echo "<!-- Debug - Filter: Tahun=$filter_tahun, Triwulan=$filter_triwulan, Provinsi=$filter_provinsi, Perizinan=$filter_jenis_perizinan -->";
    
    // Ambil statistik dengan metode sederhana
    $stats_array = getStatistikFallback($filter_tahun, $filter_triwulan, $filter_provinsi, $filter_jenis_perizinan);
    
    // Debug: tampilkan hasil statistik yang terfilter
    if ($stats_array) {
        echo "<!-- Debug - Statistik Terfilter: Total={$stats_array['total_perusahaan']}, Lapor={$stats_array['sudah_melaporkan']}, Belum={$stats_array['belum_melaporkan']}, Kepatuhan={$stats_array['tingkat_kepatuhan']}% -->";
    }
    
    // Convert ke format yang diharapkan dashboard
    $statistik_umum = null;
    if ($stats_array) {
        // Buat object simulasi untuk kompatibilitas
        $statistik_umum = (object)$stats_array;
        echo "<!-- Debug - Statistik berhasil: Total={$stats_array['total_perusahaan']}, Lapor={$stats_array['sudah_melaporkan']}, Kepatuhan={$stats_array['tingkat_kepatuhan']}% -->";
    } else {
        echo "<!-- Debug - Statistik gagal -->";
    }
    
    // Statistik provinsi sederhana dari view saja
    $statistik_provinsi = getStatistikProvinsieFallback($filter_tahun, $filter_triwulan);
    
} catch (Exception $e) {
    // Error handling dengan detail error
    echo "<!-- Error: " . $e->getMessage() . " -->";
    $provinsi_list = null;
    $tahun_list = null;
    $komoditas_list = null;
    $statistik_umum = null;
    $statistik_provinsi = null;
}
?>

<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daftar Laporan Konservasi Minerba Mineral</title>
    
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Bootstrap Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <!-- DataTables CSS -->
    <link href="https://cdn.datatables.net/1.13.0/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    <link href="https://cdn.datatables.net/fixedcolumns/4.2.1/css/fixedColumns.bootstrap5.min.css" rel="stylesheet">
    
    <style>
        /* Background Image Styling */
        body {
            background-size: 50%; /* Ukuran gambar diperkecil menjadi 50% */
            background-position: center center;
            background-repeat: no-repeat;
            background-attachment: fixed;
            position: relative;
        }
        
        /* Overlay untuk memberikan efek transparansi agar content tetap readable */
        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.85); /* White overlay dikembalikan ke 85% */
            z-index: -1;
            pointer-events: none;
        }
        
        /* Navbar styling untuk blend dengan background */
        .navbar {
            background: rgba(13, 110, 253, 0.95) !important; /* Semi-transparent blue */
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        /* Logo ESDM styling */
        .navbar-brand img {
            height: 40px;
            width: auto;
            margin-right: 10px;
            filter: brightness(1.1) contrast(1.1);
        }
        
        .navbar-brand {
            display: flex;
            align-items: center;
            font-size: 1.1rem;
        }
        
        /* Card styling untuk blend dengan background */
        .card {
            background: rgba(255, 255, 255, 0.95) !important;
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1) !important;
        }
        
        /* Alert styling */
        .alert {
            background: rgba(255, 255, 255, 0.9) !important;
            backdrop-filter: blur(5px);
            -webkit-backdrop-filter: blur(5px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        
        /* Footer styling */
        .bg-dark {
            background: rgba(33, 37, 41, 0.95) !important;
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
        }
        
        .table-container {
            font-size: 11px;
        }
        .table th, .table td {
            white-space: nowrap;
            padding: 0.25rem;
            vertical-align: middle;
        }
        #mineralTable tfoot th {
            background-color: #212529 !important;
            color: #ffffff !important;
            vertical-align: middle !important;
            text-align: center;
            padding: 8px 10px !important;
            border-top: 2px solid #495057 !important;
            white-space: nowrap;
        }
        #mineralTable tfoot th:first-child {
            text-align: left;
        }
        .fixed-column {
            background-color: #f8f9fa !important;
            position: sticky;
            left: 0;
            z-index: 10;
        }
        
        /* Dashboard Statistics Cards */
        .card {
            transition: all 0.3s ease;
            border-radius: 10px;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
        }
        .card-body {
            padding: 1.5rem;
        }
        .fs-1 {
            font-size: 2.5rem !important;
        }
        
        /* Clickable cards styling */
        .card-clickable {
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .card-clickable:hover {
            transform: translateY(-8px);
            box-shadow: 0 12px 35px rgba(0,0,0,0.2);
            background: rgba(255, 255, 255, 0.98) !important;
        }
        
        /* Progress bars */
        .progress {
            border-radius: 10px;
        }
        .progress-bar {
            border-radius: 10px;
            font-weight: bold;
            font-size: 0.75rem;
        }
        
        /* Badge styling */
        .badge {
            font-size: 0.85rem;
            padding: 0.5rem 0.75rem;
        }
        
        /* Tabel Provinsi Styling */
        .provinsi-stats-table {
            font-size: 0.9rem;
        }
        .provinsi-stats-table td, .provinsi-stats-table th {
            padding: 0.75rem 0.5rem;
            vertical-align: middle;
        }
        .provinsi-stats-table .badge {
            font-size: 0.8rem;
            min-width: 45px;
            text-align: center;
        }
        .table-secondary {
            background-color: #e9ecef !important;
            border-color: #dee2e6 !important;
        }
    </style>
</head>

<body>
    <!-- Header -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary shadow-sm">
        <div class="container-fluid">
            <a class="navbar-brand fw-bold" href="#">
                <span>
                    <i class="bi bi-gem"></i> Daftar Laporan Konservasi Minerba Mineral
                </span>
            </a>
            
            <!-- User Info & Logout -->
            <div class="d-flex align-items-center gap-2">
                <a href="ai_mineral.php" class="btn btn-success btn-sm rounded-pill text-white px-3 fw-bold me-2 shadow-sm" title="Asisten AI SIMINERAL">
                    <i class="bi bi-robot me-1 fs-6"></i> Asisten AI
                </a>
                <span class="text-white me-2">
                    <i class="bi bi-person-circle"></i> 
                    <strong><?php echo htmlspecialchars($_SESSION['username'] ?? 'admin'); ?></strong>
                </span>
                <a href="logout.php" class="btn btn-outline-light btn-sm" title="Logout">
                    <i class="bi bi-box-arrow-right"></i> Logout
                </a>
            </div>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container-fluid mt-4">
        
        <!-- Page Title -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <div>
                        <h2 class="h3 mb-1">
                            <i class="bi bi-table text-primary"></i> Daftar Laporan Konservasi Minerba Mineral
                        </h2>
                        <p class="text-muted mb-0">Data lengkap laporan konservasi minerba dengan 58 kolom informasi</p>
                    </div>
                    <div>
                        <a href="ai_mineral.php" class="btn btn-success btn-lg shadow rounded-pill px-4 text-white d-flex align-items-center gap-2 fw-bold" style="background: linear-gradient(135deg, #10a37f 0%, #059669 100%); border: none;">
                            <i class="bi bi-robot fs-4"></i>
                            <span>Buka Asisten AI</span>
                        </a>
                    </div>
                </div>
            </div>
        </div>

        <!-- Search Form -->
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-white">
                <h5 class="card-title mb-0">
                    <i class="bi bi-search"></i> Filter Data
                </h5>
            </div>
            <div class="card-body">
                <form method="GET" action="" class="row g-3">
                    <input type="hidden" name="action" value="search">
                    
                    <div class="col-md-4">
                        <label for="nama_perusahaan" class="form-label">Nama Perusahaan</label>
                        <input type="text" class="form-control" id="nama_perusahaan" name="nama_perusahaan" 
                               placeholder="Cari nama perusahaan..." 
                               value="<?php echo isset($_GET['nama_perusahaan']) ? htmlspecialchars($_GET['nama_perusahaan']) : ''; ?>">
                    </div>
                    
                    <div class="col-md-4">
                        <label for="provinsi" class="form-label">Provinsi</label>
                        <select class="form-select" id="provinsi" name="provinsi">
                            <option value="semua">Semua Provinsi</option>
                            <?php 
                            if ($provinsi_list && mysqli_num_rows($provinsi_list) > 0) {
                                while($row = $provinsi_list->fetch_assoc()) {
                                    $selected = (isset($_GET['provinsi']) && $_GET['provinsi'] == $row['nama_provinsi']) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($row['nama_provinsi']) . "' $selected>" . 
                                         htmlspecialchars($row['nama_provinsi']) . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>
                    
                    <div class="col-md-4">
                        <label for="komoditas" class="form-label">Komoditas</label>
                        <select class="form-select" id="komoditas" name="komoditas">
                            <option value="semua">Semua Komoditas</option>
                            <?php 
                            if ($komoditas_list && mysqli_num_rows($komoditas_list) > 0) {
                                while($row = $komoditas_list->fetch_assoc()) {
                                    $selected = (isset($_GET['komoditas']) && $_GET['komoditas'] == $row['komoditas_mineral']) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($row['komoditas_mineral']) . "' $selected>" . 
                                         htmlspecialchars($row['komoditas_mineral']) . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>
                    
                    <div class="col-md-6">
                        <label for="tahun" class="form-label">Tahun</label>
                        <select class="form-select" id="tahun" name="tahun">
                            <option value="semua">Semua Tahun</option>
                            <?php 
                            if ($tahun_list && mysqli_num_rows($tahun_list) > 0) {
                                while($row = $tahun_list->fetch_assoc()) {
                                    $selected = (isset($_GET['tahun']) && $_GET['tahun'] == $row['tahun']) ? 'selected' : '';
                                    echo "<option value='" . htmlspecialchars($row['tahun']) . "' $selected>" . 
                                         htmlspecialchars($row['tahun']) . "</option>";
                                }
                            }
                            ?>
                        </select>
                    </div>
                    
                    <div class="col-md-6">
                        <label for="triwulan" class="form-label">Triwulan</label>
                        <select class="form-select" id="triwulan" name="triwulan">
                            <option value="semua">Semua Triwulan</option>
                            <?php 
                            $triwulan_list = getTriwulanList();
                            foreach($triwulan_list as $triwulan_option) {
                                $selected = (isset($_GET['triwulan']) && $_GET['triwulan'] == $triwulan_option) ? 'selected' : '';
                                echo "<option value='" . htmlspecialchars($triwulan_option) . "' $selected>" . 
                                     htmlspecialchars($triwulan_option) . "</option>";
                            }
                            ?>
                        </select>
                    </div>
                    
                    <!-- Filter Objek Pelaporan -->
                    <div class="col-12 mt-2">
                        <div class="card border border-2 border-primary-subtle shadow-sm bg-light-subtle">
                            <div class="card-header bg-white py-2 d-flex justify-content-between align-items-center flex-wrap gap-2">
                                <span class="fw-bold text-primary fs-6">
                                    <i class="bi bi-ui-checks-grid me-1"></i> Filter Objek :
                                </span>
                                <div class="form-check form-check-inline m-0">
                                    <input class="form-check-input" type="checkbox" id="objek_semua" name="filter_objek[]" value="semua" <?php echo (empty($filter_objek) || in_array('semua', $filter_objek)) ? 'checked' : ''; ?>>
                                    <label class="form-check-label fw-bold text-dark" for="objek_semua">
                                        Semua Objek (All Objek)
                                    </label>
                                </div>
                            </div>
                            <div class="card-body p-3">
                                <!-- Status Produksi Filter didalam Filter Objek -->
                                <div class="p-2 px-3 mb-3 border rounded bg-white shadow-sm d-flex align-items-center justify-content-between flex-wrap gap-2" style="border-left: 4px solid #ffc107 !important;">
                                    <div class="d-flex align-items-center gap-2">
                                        <i class="bi bi-funnel-fill text-warning"></i>
                                        <span class="fw-bold text-dark">Status Produksi (Sistem Penambangan):</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-4">
                                        <div class="form-check m-0 d-flex align-items-center gap-1">
                                            <input class="form-check-input" type="checkbox" id="status_produksi_p" name="status_produksi[]" value="sudah" <?php echo (empty($status_produksi) || in_array('sudah', $status_produksi)) ? 'checked' : ''; ?>>
                                            <label class="form-check-label fw-semibold" for="status_produksi_p" role="button">
                                                Sudah Produksi
                                            </label>
                                            <span class="badge ms-1" style="background-color: #d1e7dd; color: #0f5132; border: 1px solid #a3cfbb; font-weight: bold; font-size: 11px;">P</span>
                                        </div>
                                        <div class="form-check m-0 d-flex align-items-center gap-1">
                                            <input class="form-check-input" type="checkbox" id="status_produksi_bp" name="status_produksi[]" value="belum" <?php echo (empty($status_produksi) || in_array('belum', $status_produksi)) ? 'checked' : ''; ?>>
                                            <label class="form-check-label fw-semibold" for="status_produksi_bp" role="button">
                                                Belum Produksi
                                            </label>
                                            <span class="badge ms-1" style="background-color: #fff3cd; color: #664d03; border: 1px solid #ffe69c; font-weight: bold; font-size: 11px;">BP</span>
                                        </div>
                                    </div>
                                </div>

                                <div class="row g-3">
                                    <!-- Recovery Penambangan & Pengolahan -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-2">
                                                <input class="form-check-input objek-item" type="checkbox" id="objek_rec_tambang" name="filter_objek[]" value="recovery_penambangan" <?php echo in_array('recovery_penambangan', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_rec_tambang">
                                                    Recovery Penambangan
                                                </label>
                                            </div>
                                            <div class="form-check">
                                                <input class="form-check-input objek-item" type="checkbox" id="objek_rec_olah" name="filter_objek[]" value="recovery_pengolahan" <?php echo in_array('recovery_pengolahan', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_rec_olah">
                                                    Recovery Pengolahan
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Mineral Kadar Rendah -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-1">
                                                <input class="form-check-input objek-item parent-objek" type="checkbox" id="objek_mkr" name="filter_objek[]" value="mkr" data-children="mkr-child" <?php echo in_array('mkr', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_mkr">
                                                    Mineral Kadar Rendah
                                                </label>
                                            </div>
                                            <div class="ms-3 ps-2 border-start">
                                                <div class="form-check form-check-sm mb-1">
                                                    <input class="form-check-input objek-item mkr-child" type="checkbox" id="objek_mkr_kumulatif" name="filter_objek[]" value="mkr_kumulatif" data-parent="objek_mkr" <?php echo in_array('mkr_kumulatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_mkr_kumulatif">
                                                        • Kumulatif (Tonase)
                                                    </label>
                                                </div>
                                                <div class="form-check form-check-sm">
                                                    <input class="form-check-input objek-item mkr-child" type="checkbox" id="objek_mkr_kuantitatif" name="filter_objek[]" value="mkr_kuantitatif" data-parent="objek_mkr" <?php echo in_array('mkr_kuantitatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_mkr_kuantitatif">
                                                        • Kuantitatif (Triwulan) (Tonase)
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Mineral Ikutan -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-1">
                                                <input class="form-check-input objek-item parent-objek" type="checkbox" id="objek_mi" name="filter_objek[]" value="mi" data-children="mi-child" <?php echo in_array('mi', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_mi">
                                                    Mineral Ikutan
                                                </label>
                                            </div>
                                            <div class="ms-3 ps-2 border-start">
                                                <div class="form-check form-check-sm mb-1">
                                                    <input class="form-check-input objek-item mi-child" type="checkbox" id="objek_mi_kumulatif" name="filter_objek[]" value="mi_kumulatif" data-parent="objek_mi" <?php echo in_array('mi_kumulatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_mi_kumulatif">
                                                        • Kumulatif (Tonase)
                                                    </label>
                                                </div>
                                                <div class="form-check form-check-sm">
                                                    <input class="form-check-input objek-item mi-child" type="checkbox" id="objek_mi_kuantitatif" name="filter_objek[]" value="mi_kuantitatif" data-parent="objek_mi" <?php echo in_array('mi_kuantitatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_mi_kuantitatif">
                                                        • Kuantitatif (Triwulan) (Tonase)
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Cadangan Marginal -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-1">
                                                <input class="form-check-input objek-item parent-objek" type="checkbox" id="objek_cm" name="filter_objek[]" value="cm" data-children="cm-child" <?php echo in_array('cm', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_cm">
                                                    Cadangan Marginal
                                                </label>
                                            </div>
                                            <div class="ms-3 ps-2 border-start">
                                                <div class="form-check form-check-sm mb-1">
                                                    <input class="form-check-input objek-item cm-child" type="checkbox" id="objek_cm_kumulatif" name="filter_objek[]" value="cm_kumulatif" data-parent="objek_cm" <?php echo in_array('cm_kumulatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_cm_kumulatif">
                                                        • Kumulatif (Tonase)
                                                    </label>
                                                </div>
                                                <div class="form-check form-check-sm">
                                                    <input class="form-check-input objek-item cm-child" type="checkbox" id="objek_cm_kuantitatif" name="filter_objek[]" value="cm_kuantitatif" data-parent="objek_cm" <?php echo in_array('cm_kuantitatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_cm_kuantitatif">
                                                        • Kuantitatif (Triwulan) (Tonase)
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Cadangan Tidak Tertambang -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-1">
                                                <input class="form-check-input objek-item parent-objek" type="checkbox" id="objek_cmtt" name="filter_objek[]" value="cmtt" data-children="cmtt-child" <?php echo in_array('cmtt', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_cmtt">
                                                    Cadangan Tidak Tertambang
                                                </label>
                                            </div>
                                            <div class="ms-3 ps-2 border-start">
                                                <div class="form-check form-check-sm mb-1">
                                                    <input class="form-check-input objek-item cmtt-child" type="checkbox" id="objek_cmtt_kumulatif" name="filter_objek[]" value="cmtt_kumulatif" data-parent="objek_cmtt" <?php echo in_array('cmtt_kumulatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_cmtt_kumulatif">
                                                        • Kumulatif (Tonase)
                                                    </label>
                                                </div>
                                                <div class="form-check form-check-sm">
                                                    <input class="form-check-input objek-item cmtt-child" type="checkbox" id="objek_cmtt_kuantitatif" name="filter_objek[]" value="cmtt_kuantitatif" data-parent="objek_cmtt" <?php echo in_array('cmtt_kuantitatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_cmtt_kuantitatif">
                                                        • Kuantitatif (Triwulan) (Tonase)
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Sisa Hasil Pengolahan -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm">
                                            <div class="form-check mb-1">
                                                <input class="form-check-input objek-item parent-objek" type="checkbox" id="objek_shp" name="filter_objek[]" value="shp" data-children="shp-child" <?php echo in_array('shp', $filter_objek) ? 'checked' : ''; ?>>
                                                <label class="form-check-label fw-semibold" for="objek_shp">
                                                    Sisa Hasil Pengolahan
                                                </label>
                                            </div>
                                            <div class="ms-3 ps-2 border-start">
                                                <div class="form-check form-check-sm mb-1">
                                                    <input class="form-check-input objek-item shp-child" type="checkbox" id="objek_shp_kumulatif" name="filter_objek[]" value="shp_kumulatif" data-parent="objek_shp" <?php echo in_array('shp_kumulatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_shp_kumulatif">
                                                        • Kumulatif (Tonase)
                                                    </label>
                                                </div>
                                                <div class="form-check form-check-sm">
                                                    <input class="form-check-input objek-item shp-child" type="checkbox" id="objek_shp_kuantitatif" name="filter_objek[]" value="shp_kuantitatif" data-parent="objek_shp" <?php echo in_array('shp_kuantitatif', $filter_objek) ? 'checked' : ''; ?>>
                                                    <label class="form-check-label small text-primary" for="objek_shp_kuantitatif">
                                                        • Kuantitatif (Triwulan) (Tonase)
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Jenis Perizinan (Mengisi slot kosong) -->
                                    <div class="col-md-4 col-lg-3">
                                        <div class="p-2 border rounded bg-white h-100 shadow-sm" style="border-top: 3px solid #0d6efd !important;">
                                            <div class="fw-semibold mb-1 text-dark d-flex align-items-center gap-1">
                                                <i class="bi bi-card-checklist text-primary"></i>
                                                <label for="jenis_perizinan" class="form-label m-0 fw-semibold text-dark">Jenis Perizinan</label>
                                            </div>
                                            <div class="pt-1">
                                                <select class="form-select form-select-sm" id="jenis_perizinan" name="jenis_perizinan">
                                                    <option value="semua">Semua Perizinan</option>
                                                    <?php 
                                                    if (!empty($jenis_perizinan_options)) {
                                                        foreach($jenis_perizinan_options as $jp_opt) {
                                                            $selected = ($filter_jenis_perizinan == $jp_opt) ? 'selected' : '';
                                                            echo "<option value='" . htmlspecialchars($jp_opt) . "' $selected>" . 
                                                                 htmlspecialchars($jp_opt) . "</option>";
                                                        }
                                                    }
                                                    ?>
                                                </select>
                                                <small class="text-muted d-block mt-2" style="font-size: 11px;">
                                                    <i class="bi bi-info-circle text-primary"></i> Filter kolom Jenis Perizinan
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-12 mt-3">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-search"></i> Filter Data & Update Statistik
                        </button>
                        <a href="lmineral.php" class="btn btn-outline-secondary">
                            <i class="bi bi-arrow-clockwise"></i> Reset
                        </a>
                    </div>
                </form>
            </div>
        </div>

        <!-- Dashboard Statistik -->
        <?php if ($statistik_umum): ?>
        
        <!-- Indikator Filter Aktif -->
        <?php 
        $filter_aktif = array();
        if (!empty($filter_tahun) && $filter_tahun != 'semua') $filter_aktif[] = "Tahun: $filter_tahun";
        if (!empty($filter_triwulan) && $filter_triwulan != 'semua') $filter_aktif[] = "Triwulan: $filter_triwulan";
        if (!empty($filter_provinsi) && $filter_provinsi != 'semua') $filter_aktif[] = "Provinsi: $filter_provinsi";
        if (!empty($filter_komoditas) && $filter_komoditas != 'semua') $filter_aktif[] = "Komoditas: $filter_komoditas";
        if (!empty($filter_jenis_perizinan) && $filter_jenis_perizinan != 'semua') $filter_aktif[] = "Izin: $filter_jenis_perizinan";
        
        // Objek label untuk Filter Aktif
        if (!empty($filter_objek) && !in_array('semua', $filter_objek)) {
            $obj_lbls = array();
            if (in_array('recovery_penambangan', $filter_objek)) $obj_lbls[] = "Rec. Penambangan";
            if (in_array('recovery_pengolahan', $filter_objek)) $obj_lbls[] = "Rec. Pengolahan";
            if (in_array('mkr', $filter_objek)) {
                $obj_lbls[] = "MKR (Semua)";
            } else {
                if (in_array('mkr_kumulatif', $filter_objek)) $obj_lbls[] = "MKR (Kumulatif)";
                if (in_array('mkr_kuantitatif', $filter_objek)) $obj_lbls[] = "MKR (Kuantitatif)";
            }
            if (in_array('mi', $filter_objek)) {
                $obj_lbls[] = "MI (Semua)";
            } else {
                if (in_array('mi_kumulatif', $filter_objek)) $obj_lbls[] = "MI (Kumulatif)";
                if (in_array('mi_kuantitatif', $filter_objek)) $obj_lbls[] = "MI (Kuantitatif)";
            }
            if (in_array('cm', $filter_objek)) {
                $obj_lbls[] = "CM (Semua)";
            } else {
                if (in_array('cm_kumulatif', $filter_objek)) $obj_lbls[] = "CM (Kumulatif)";
                if (in_array('cm_kuantitatif', $filter_objek)) $obj_lbls[] = "CM (Kuantitatif)";
            }
            if (in_array('cmtt', $filter_objek) || in_array('cmtt_kumulatif', $filter_objek) || in_array('cmtt_kuantitatif', $filter_objek)) {
                $obj_lbls[] = "CMTT";
            }
            if (in_array('shp', $filter_objek)) {
                $obj_lbls[] = "SHP (Semua)";
            } else {
                if (in_array('shp_kumulatif', $filter_objek)) $obj_lbls[] = "SHP (Kumulatif)";
                if (in_array('shp_kuantitatif', $filter_objek)) $obj_lbls[] = "SHP (Kuantitatif)";
            }
            if (!empty($obj_lbls)) {
                $filter_aktif[] = "Objek: " . implode(', ', $obj_lbls);
            }
        }
        
        // Status Produksi label untuk Filter Aktif
        if (!empty($status_produksi)) {
            $has_sudah = in_array('sudah', $status_produksi);
            $has_belum = in_array('belum', $status_produksi);
            if ($has_belum && !$has_sudah) {
                $filter_aktif[] = "Status: Belum Produksi (BP)";
            } elseif ($has_sudah && !$has_belum) {
                $filter_aktif[] = "Status: Sudah Produksi (P)";
            }
        }
        
        if (!empty($filter_aktif)): 
        ?>
        <div class="row mb-3">
            <div class="col-12">
                <div class="alert alert-success border-start border-4 border-success">
                    <i class="bi bi-funnel-fill"></i> <strong>Filter Aktif:</strong> 
                    <?php echo implode(' • ', $filter_aktif); ?>
                    <span class="badge bg-success ms-2">Statistik Terfilter</span>
                </div>
            </div>
        </div>
        <?php endif; ?>
        
        <div class="row row-cols-1 row-cols-md-5 g-3 mb-4">
            <div class="col">
                <div class="card border-primary h-100 card-clickable" 
                     data-bs-toggle="modal" 
                     data-bs-target="#detailModal" 
                     data-status="total"
                     data-title="Total Perusahaan Wajib Lapor (Aktif)">
                    <div class="card-body text-center">
                        <i class="bi bi-building-fill text-primary fs-1 mb-2"></i>
                        <h4 class="card-title text-primary"><?php echo number_format($statistik_umum->total_perusahaan); ?></h4>
                        <p class="card-text text-muted mb-0">Perusahaan Wajib Lapor (Aktif)</p>
                        <small class="text-muted"><i class="bi bi-cursor-fill"></i> Klik untuk detail</small>
                    </div>
                </div>
            </div>
            <div class="col">
                <div class="card border-success h-100 card-clickable" 
                     data-bs-toggle="modal" 
                     data-bs-target="#detailModal" 
                     data-status="sudah_lapor"
                     data-title="Perusahaan yang Sudah Melaporkan">
                    <div class="card-body text-center">
                        <i class="bi bi-check-circle-fill text-success fs-1 mb-2"></i>
                        <h4 class="card-title text-success"><?php echo number_format($statistik_umum->sudah_melaporkan); ?></h4>
                        <p class="card-text text-muted mb-0">Sudah Melaporkan</p>
                        <small class="text-muted"><i class="bi bi-cursor-fill"></i> Klik untuk detail</small>
                    </div>
                </div>
            </div>
            <div class="col">
                <div class="card border-warning h-100 card-clickable" 
                     data-bs-toggle="modal" 
                     data-bs-target="#detailModal" 
                     data-status="belum_lapor"
                     data-title="Perusahaan yang Belum Melaporkan">
                    <div class="card-body text-center">
                        <i class="bi bi-exclamation-circle-fill text-warning fs-1 mb-2"></i>
                        <h4 class="card-title text-warning"><?php echo number_format($statistik_umum->belum_melaporkan); ?></h4>
                        <p class="card-text text-muted mb-0">Belum Melaporkan</p>
                        <small class="text-muted"><i class="bi bi-cursor-fill"></i> Klik untuk detail</small>
                    </div>
                </div>
            </div>
            <div class="col">
                <div class="card border-danger h-100 card-clickable"
                     onclick="openStatusModal('nonaktif')">
                    <div class="card-body text-center">
                        <i class="bi bi-slash-circle-fill text-danger fs-1 mb-2"></i>
                        <h4 class="card-title text-danger"><?php echo number_format($statistik_umum->non_aktif ?? 0); ?></h4>
                        <p class="card-text text-muted mb-0">Perusahaan Non-Aktif</p>
                        <small class="text-danger fw-semibold d-block">(Dikecualikan dari %)</small>
                        <small class="text-muted"><i class="bi bi-sliders"></i> Kelola Aktif/Non-Aktif</small>
                    </div>
                </div>
            </div>
            <div class="col">
                <div class="card border-info h-100">
                    <div class="card-body text-center">
                        <i class="bi bi-graph-up text-info fs-1 mb-2"></i>
                        <h4 class="card-title text-info"><?php echo $statistik_umum->tingkat_kepatuhan; ?>%</h4>
                        <p class="card-text text-muted mb-0">Tingkat Kepatuhan</p>
                        <small class="text-muted">Basis: <?php echo number_format($statistik_umum->total_perusahaan); ?> Aktif</small>
                    </div>
                </div>
            </div>
        </div>
        <?php else: ?>
        <!-- Info jika statistik tidak tersedia -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="alert alert-info">
                    <i class="bi bi-info-circle"></i> <strong>Info:</strong> Dashboard statistik sedang dioptimalkan untuk performa yang lebih baik.
                    <br>Data laporan tersedia di tabel di bawah ini.
                </div>
            </div>
        </div>
        <?php endif; ?>

        <!-- Performance & Filter Note -->
        <div class="row mb-3">
            <div class="col-12">
                <div class="alert alert-info alert-dismissible fade show" role="alert">
                    <i class="bi bi-speedometer2"></i> <strong>Dashboard Interaktif:</strong> 
                    Statistik akan berubah sesuai filter yang dipilih (Tahun, Triwulan, Provinsi). 
                    Data dari relasi <code>perusahaan_mineral ↔ provinsi_mineral ↔ vlaporan_mineral</code>.
                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                </div>
            </div>
        </div>

        <!-- Statistik Per Provinsi dengan Relasi Lengkap -->
        <?php 
        // Debug: Tampilkan parameter yang digunakan
        echo "<!-- Debug Provinsi - Tahun: '$filter_tahun', Triwulan: '$filter_triwulan' -->";
        echo "<!-- Debug Relasi - perusahaan_mineral.id_provinsi = provinsi_mineral.id -->";
        
        // Panggil fungsi debug untuk memverifikasi struktur tabel
        debugRelasiTabel();
        
        // Test relasi terlebih dahulu
        $test_relasi = executeQuery("SELECT COUNT(*) as total FROM perusahaan_mineral pm LEFT JOIN provinsi_mineral prov ON pm.id_provinsi = prov.id WHERE pm.sk_iup IS NOT NULL");
        if ($test_relasi && $row_test = $test_relasi->fetch_assoc()) {
            echo "<!-- Debug Test Relasi - Total perusahaan dengan relasi: " . $row_test['total'] . " -->";
        }
        
        // Ambil statistik detail per provinsi dengan pendekatan sederhana
        $statistik_detail_provinsi = null;
        try {
            $statistik_detail_provinsi = getStatistikDetailPerProvinsi($filter_tahun, $filter_triwulan, $filter_provinsi);
            if ($statistik_detail_provinsi) {
                $count_rows = mysqli_num_rows($statistik_detail_provinsi);
                echo "<!-- Debug - Statistik provinsi berhasil: $count_rows baris, Filter Provinsi: '$filter_provinsi' -->";
            } else {
                echo "<!-- Debug - Statistik provinsi gagal atau null -->";
            }
        } catch (Exception $e) {
            echo "<!-- Debug Error - Statistik provinsi: " . $e->getMessage() . " -->";
        }
        
        if ($statistik_detail_provinsi && mysqli_num_rows($statistik_detail_provinsi) > 0): 
        ?>
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-white">
                <h5 class="card-title mb-0">
                    <i class="bi bi-geo-alt-fill"></i> Detail Statistik Pelaporan Per Provinsi
                    <?php if (!empty($filter_provinsi) && $filter_provinsi != 'semua'): ?>
                        <small class="text-success">(Filter: <?php echo htmlspecialchars($filter_provinsi); ?>)</small>
                    <?php else: ?>
                        <small class="text-muted">(Semua Provinsi)</small>
                    <?php endif; ?>
                </h5>
            </div>
            <div class="card-body">
                <div class="alert alert-success">
                    <i class="bi bi-check-circle"></i> <strong>Data Lengkap:</strong> 
                    <?php if (!empty($filter_provinsi) && $filter_provinsi != 'semua'): ?>
                        Menampilkan statistik khusus untuk provinsi <strong><?php echo htmlspecialchars($filter_provinsi); ?></strong>
                        <?php if (!empty($filter_tahun) && $filter_tahun != 'semua'): ?>
                            pada tahun <?php echo htmlspecialchars($filter_tahun); ?>
                        <?php endif; ?>
                        <?php if (!empty($filter_triwulan) && $filter_triwulan != 'semua'): ?>
                            <?php echo !empty($filter_tahun) && $filter_tahun != 'semua' ? ', ' : 'pada '; ?>
                            <?php echo htmlspecialchars($filter_triwulan); ?>
                        <?php endif; ?>.
                    <?php else: ?>
                        Menampilkan total perusahaan terdaftar, yang sudah melaporkan, belum melaporkan, dan tingkat kepatuhan untuk semua provinsi.
                    <?php endif; ?>
                </div>
                
                <div class="table-responsive">
                    <table class="table table-striped table-hover provinsi-stats-table">
                        <thead class="table-primary">
                            <tr>
                                <th style="width: 5%">No</th>
                                <th style="width: 25%">Provinsi</th>
                                <th style="width: 15%">Total Perusahaan</th>
                                <th style="width: 15%">Sudah Melaporkan</th>
                                <th style="width: 15%">Belum Melaporkan</th>
                                <th style="width: 10%">Kepatuhan (%)</th>
                                <th style="width: 15%">Komoditas Utama</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php 
                            $no_provinsi = 1;
                            $total_semua_perusahaan = 0;
                            $total_semua_lapor = 0;
                            
                            // Ambil data total perusahaan per provinsi untuk referensi
                            $data_total_perusahaan = array();
                            $total_per_provinsi = getTotalPerusahaanPerProvinsi();
                            if ($total_per_provinsi && mysqli_num_rows($total_per_provinsi) > 0) {
                                while($row_total = $total_per_provinsi->fetch_assoc()) {
                                    $data_total_perusahaan[$row_total['nama_provinsi']] = $row_total['total_perusahaan'];
                                }
                            }
                            
                            while($row_prov = $statistik_detail_provinsi->fetch_assoc()): 
                                $nama_provinsi = $row_prov['nama_provinsi'];
                                $sudah_melaporkan = intval($row_prov['sudah_melaporkan']);
                                
                                // Ambil total perusahaan dari data referensi atau fallback ke data laporan
                                $total_perusahaan = isset($data_total_perusahaan[$nama_provinsi]) ? 
                                                  $data_total_perusahaan[$nama_provinsi] : 
                                                  intval($row_prov['total_perusahaan_terdaftar']);
                                
                                $belum_melaporkan = max(0, $total_perusahaan - $sudah_melaporkan);
                                $tingkat_kepatuhan = $total_perusahaan > 0 ? round(($sudah_melaporkan * 100.0) / $total_perusahaan, 1) : 0;
                                
                                // Tentukan warna badge berdasarkan tingkat kepatuhan
                                $badge_class = 'bg-success';
                                if ($tingkat_kepatuhan < 50) $badge_class = 'bg-danger';
                                else if ($tingkat_kepatuhan < 75) $badge_class = 'bg-warning text-dark';
                                
                                // Akumulasi untuk ringkasan
                                $total_semua_perusahaan += $total_perusahaan;
                                $total_semua_lapor += $sudah_melaporkan;
                            ?>
                            <tr>
                                <td><?php echo $no_provinsi++; ?></td>
                                <td>
                                    <strong><?php echo htmlspecialchars($nama_provinsi); ?></strong>
                                </td>
                                <td>
                                    <span class="badge bg-info fs-6">
                                        <?php echo number_format($total_perusahaan); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge bg-success fs-6">
                                        <?php echo number_format($sudah_melaporkan); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge bg-warning text-dark fs-6">
                                        <?php echo number_format($belum_melaporkan); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge <?php echo $badge_class; ?> fs-6">
                                        <?php echo $tingkat_kepatuhan; ?>%
                                    </span>
                                </td>
                                <td>
                                    <small class="text-muted">
                                        <?php 
                                        if (!empty($row_prov['komoditas_dilaporkan'])) {
                                            $komoditas = explode(', ', $row_prov['komoditas_dilaporkan']);
                                            echo htmlspecialchars(implode(', ', array_slice($komoditas, 0, 2)));
                                            if (count($komoditas) > 2) echo ' <br><em>+' . (count($komoditas) - 2) . ' lainnya</em>';
                                        } else {
                                            echo '<em>Tidak ada</em>';
                                        }
                                        ?>
                                    </small>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                            
                            <!-- Baris Ringkasan Total -->
                            <tr class="table-secondary fw-bold">
                                <td colspan="2"><strong>TOTAL KESELURUHAN</strong></td>
                                <td>
                                    <span class="badge bg-primary fs-6">
                                        <?php echo number_format($total_semua_perusahaan); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge bg-success fs-6">
                                        <?php echo number_format($total_semua_lapor); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge bg-warning text-dark fs-6">
                                        <?php echo number_format($total_semua_perusahaan - $total_semua_lapor); ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge bg-info fs-6">
                                        <?php echo $total_semua_perusahaan > 0 ? round(($total_semua_lapor * 100.0) / $total_semua_perusahaan, 1) : 0; ?>%
                                    </span>
                                </td>
                                <td><em>Semua Komoditas</em></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                
                <!-- Summary Statistik Provinsi -->
                <div class="row mt-3">
                    <div class="col-md-12">
                        <div class="alert alert-info">
                            <h6><i class="bi bi-graph-up-arrow"></i> Penjelasan Data Per Provinsi:</h6>
                            <ul class="mb-0 small">
                                <li><strong>Total Perusahaan:</strong> Jumlah perusahaan terdaftar per provinsi (dari tabel perusahaan_mineral ↔ provinsi_mineral)</li>
                                <li><strong>Sudah Melaporkan:</strong> Jumlah perusahaan yang sudah submit laporan (dari vlaporan_mineral)</li>
                                <li><strong>Belum Melaporkan:</strong> Selisih antara total perusahaan dengan yang sudah melaporkan</li>
                                <li><strong>Tingkat Kepatuhan:</strong> Persentase perusahaan yang sudah melaporkan dari total perusahaan terdaftar</li>
                                <li><strong>Komoditas Utama:</strong> Jenis mineral yang dilaporkan di provinsi tersebut</li>
                            </ul>
                        </div>
                    </div>
                </div>
                
                <!-- Statistik Cards per Provinsi -->
                <div class="row mt-3">
                    <div class="col-md-3">
                        <div class="card border-info">
                            <div class="card-body text-center">
                                <i class="bi bi-geo-alt-fill text-info fs-2"></i>
                                <h6 class="card-title text-info">Total Provinsi</h6>
                                <h4 class="text-info"><?php echo mysqli_num_rows($statistik_detail_provinsi) > 0 ? ($no_provinsi - 1) : 0; ?></h4>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card border-primary">
                            <div class="card-body text-center">
                                <i class="bi bi-building-fill text-primary fs-2"></i>
                                <h6 class="card-title text-primary">Total Perusahaan</h6>
                                <h4 class="text-primary"><?php echo number_format($total_semua_perusahaan); ?></h4>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card border-success">
                            <div class="card-body text-center">
                                <i class="bi bi-check-circle-fill text-success fs-2"></i>
                                <h6 class="card-title text-success">Sudah Melaporkan</h6>
                                <h4 class="text-success"><?php echo number_format($total_semua_lapor); ?></h4>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card border-warning">
                            <div class="card-body text-center">
                                <i class="bi bi-exclamation-triangle-fill text-warning fs-2"></i>
                                <h6 class="card-title text-warning">Belum Melaporkan</h6>
                                <h4 class="text-warning"><?php echo number_format($total_semua_perusahaan - $total_semua_lapor); ?></h4>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <!-- Pesan jika tidak ada data statistik provinsi -->
        <div class="card shadow-sm mb-4">
            <div class="card-body">
                <?php if (!empty($filter_provinsi) && $filter_provinsi != 'semua'): ?>
                <div class="alert alert-warning">
                    <i class="bi bi-exclamation-triangle"></i> <strong>Tidak Ada Data:</strong> 
                    Tidak ditemukan data laporan untuk provinsi <strong><?php echo htmlspecialchars($filter_provinsi); ?></strong>
                    <?php if (!empty($filter_tahun) && $filter_tahun != 'semua'): ?>
                        pada tahun <?php echo htmlspecialchars($filter_tahun); ?>
                    <?php endif; ?>
                    <?php if (!empty($filter_triwulan) && $filter_triwulan != 'semua'): ?>
                        <?php echo !empty($filter_tahun) && $filter_tahun != 'semua' ? ', ' : 'pada '; ?>
                        <?php echo htmlspecialchars($filter_triwulan); ?>
                    <?php endif; ?>.
                    <br>
                    <small>Silakan pilih provinsi lain atau ubah filter periode.</small>
                </div>
                <?php else: ?>
                <div class="alert alert-warning">
                    <i class="bi bi-exclamation-triangle"></i> <strong>Info:</strong> 
                    Data statistik per provinsi tidak tersedia atau sedang dimuat. 
                    Silakan periksa filter atau hubungi administrator sistem.
                </div>
                <?php endif; ?>
            </div>
        </div>
        <?php endif; ?>

        <!-- Data Table -->
        <div class="card shadow-sm">
            <div class="card-header bg-white">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="card-title mb-0">
                        <i class="bi bi-table"></i> Daftar Laporan Konservasi Minerba
                    </h5>
                    <button type="button" class="btn btn-success btn-sm" id="exportMainBtn">
                        <i class="bi bi-download"></i> Export Excel
                    </button>
                </div>
            </div>
            <div class="card-body table-container">
                <?php if ($mineral_data && mysqli_num_rows($mineral_data) > 0): ?>
                
                <div class="table-responsive">
                    <table class="table table-striped table-hover table-sm" id="mineralTable">
                        <thead class="table-primary">
                            <tr>
                                <!-- Kolom dasar (fixed) -->
                                <th style="min-width: 50px;">No</th>
                                <th style="min-width: 80px;">ID</th>
                                <th style="min-width: 120px;">Komoditas</th>
                                <th style="min-width: 120px;">Jenis Perizinan</th>
                                <th style="min-width: 100px;">Provinsi</th>
                                <th style="min-width: 200px;">Nama Perusahaan</th>
                                <th style="min-width: 150px;">SK IUP</th>
                                <th style="min-width: 150px;">Email</th>
                                <th style="min-width: 120px;">Sistem Penambangan</th>
                                <th style="min-width: 120px;">Waktu Pelaporan</th>
                                <th style="min-width: 80px;">Tahun</th>
                                
                                <!-- Recovery columns -->
                                <th style="min-width: 120px;">Rencana Recovery 2.1</th>
                                <th style="min-width: 120px;">Recovery Truck 2.2</th>
                                <th style="min-width: 120px;">Recovery Survey 2.3</th>
                                <th style="min-width: 120px;">Rencana Recovery 2.4</th>
                                <th style="min-width: 150px;">Rencana Recovery Pengolahan FS</th>
                                <th style="min-width: 150px;">Rencana Recovery Pengolahan RKAB</th>
                                <th style="min-width: 120px;">Recovery Pemulihan 2.6</th>
                                
                                <!-- MI (Mineral Indication) columns -->
                                <th style="min-width: 100px;">MI Jenis</th>
                                <th style="min-width: 120px;">MI Stok Awal Tahun</th>
                                <th style="min-width: 100px;">MI Kuantitas</th>
                                <th style="min-width: 100px;">MI Kadar (g/t)</th>
                                <th style="min-width: 100px;">MI Kadar (%)</th>
                                <th style="min-width: 100px;">MI Lokasi</th>
                                <th style="min-width: 100px;">PMI Volume</th>
                                <th style="min-width: 100px;">PMI Kadar</th>
                                <th style="min-width: 100px;">PMI Persentase</th>
                                
                                <!-- MKR (Mineral Konsentrat) columns -->
                                <th style="min-width: 120px;">MKR Stok Awal Tahun</th>
                                <th style="min-width: 100px;">MKR Kuantitas</th>
                                <th style="min-width: 100px;">MKR Kadar (g/t)</th>
                                <th style="min-width: 100px;">MKR Kadar (%)</th>
                                <th style="min-width: 100px;">MKR Lokasi</th>
                                <th style="min-width: 100px;">PMKR Volume</th>
                                <th style="min-width: 100px;">PMKR Kadar</th>
                                <th style="min-width: 100px;">PMKR Persentase</th>
                                
                                <!-- CM (Concentrate Mineral) columns -->
                                <th style="min-width: 120px;">CM Stok Awal Tahun</th>
                                <th style="min-width: 100px;">CM Kuantitas</th>
                                <th style="min-width: 100px;">CM Kadar (g/t)</th>
                                <th style="min-width: 100px;">CM Kadar (%)</th>
                                <th style="min-width: 100px;">CM Lokasi</th>
                                <th style="min-width: 100px;">PCM Volume</th>
                                <th style="min-width: 100px;">PCM Kadar</th>
                                <th style="min-width: 100px;">PCM Persentase</th>
                                
                                <!-- SHP (Stock Heap/Pile) columns -->
                                <th style="min-width: 120px;">SHP Komulatif Awal</th>
                                <th style="min-width: 100px;">SHP Kuantitas</th>
                                <th style="min-width: 100px;">SHP Jenis</th>
                                <th style="min-width: 100px;">SHP Unsur</th>
                                <th style="min-width: 100px;">SHP Kadar (g/t)</th>
                                <th style="min-width: 100px;">SHP Kadar (%)</th>
                                <th style="min-width: 120px;">Calorin Valius SHPP</th>
                                <th style="min-width: 120px;">Pemanfaatan SHPP</th>
                                <th style="min-width: 100px;">SHP Lokasi</th>
                                <th style="min-width: 100px;">PSHPP Volume</th>
                                <th style="min-width: 100px;">PSHPP Kadar</th>
                                <th style="min-width: 100px;">PSHPP Persentase</th>
                                
                                <!-- CMTT (Coal Mine to Terminal/Terminal) columns -->
                                <th style="min-width: 100px;">CMTT Mineral</th>
                                <th style="min-width: 120px;">CMTT Kuantitas Cadangan</th>
                                <th style="min-width: 100px;">CMTT Kedalaman</th>
                                <th style="min-width: 100px;">CMTT Kadar (g/t)</th>
                                <th style="min-width: 100px;">CMTT Kadar (%)</th>
                                <th style="min-width: 100px;">CMTT Lokasi</th>
                                
                                <!-- Report columns -->
                                <th style="min-width: 100px;">Laporan</th>
                                <th style="min-width: 120px;">Peta Konservasi</th>
                                <th style="min-width: 120px;">Waktu Input</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php 
                            while($row = $mineral_data->fetch_assoc()): 
                            ?>
                            <tr>
                                <td class="row-number"></td> <!-- Akan diisi oleh DataTables dengan nomor yang benar -->
                                <td><?php echo htmlspecialchars($row['id'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['komoditas_mineral'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['jenis_perizinan'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['provinsi'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['nama_perusahaan'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['sk_iup'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['email'] ?? '-'); ?></td>
                                <td>
                                    <?php 
                                    $sistem_pen = $row['sistem_penambangan'] ?? '-';
                                    echo htmlspecialchars($sistem_pen);
                                    if ($sistem_pen != '-' && !empty($sistem_pen)) {
                                        if (stripos($sistem_pen, 'belum produksi') !== false) {
                                            echo ' <span class="badge" style="background-color: #fff3cd; color: #664d03; border: 1px solid #ffe69c; font-weight: bold; font-size: 10px;">BP</span>';
                                        } else {
                                            echo ' <span class="badge" style="background-color: #d1e7dd; color: #0f5132; border: 1px solid #a3cfbb; font-weight: bold; font-size: 10px;">P</span>';
                                        }
                                    }
                                    ?>
                                </td>
                                <td><?php echo htmlspecialchars($row['waktu_pelaporan'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['tahun'] ?? '-'); ?></td>
                                
                                <!-- Recovery data -->
                                <td><?php echo htmlspecialchars($row['rencana_recovery_2_1'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['recovery_penambangan_truck_2_2'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['recovery_penambangan_survey_2_3'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['rencana_recovery_2_4'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['rencana_recovery_pengolahan_fs'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['rencana_recovery_pengolahan_rkab'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['recovery_pemulihan_2_6'] ?? '-'); ?></td>
                                
                                <!-- MI data -->
                                <td><?php echo htmlspecialchars($row['mi_jenis'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mi_stok_awal_tahun'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mi_kuantitias'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mi_kadar_gram_ton'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mi_kadar_persentase'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mi_lokasi'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmi_volume'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmi_kadar'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmi_persentase'] ?? '-'); ?></td>
                                
                                <!-- MKR data -->
                                <td><?php echo htmlspecialchars($row['mkr_stok_awal_tahun'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mkr_kuantitas'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mkr_kadar_gram_ton'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mkr_kadar_persentase'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['mkr_lokasi'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmkr_volume'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmkr_kadar'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pmkr_persentase'] ?? '-'); ?></td>
                                
                                <!-- CM data -->
                                <td><?php echo htmlspecialchars($row['cm_stok_awal_tahun'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cm_kuantitas'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cm_kadar_gram_ton'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cm_kadar_persentase'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cm_lokasi'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pcm_volume'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pcm_kadar'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pcm_persentase'] ?? '-'); ?></td>
                                
                                <!-- SHP data -->
                                <td><?php echo htmlspecialchars($row['shp_komulatif_awal_tahun'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_kuantitas'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_jenis'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_unsur'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_kadar_gram_ton'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_kadar_persentase'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['calorin_valius_shpp'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pemanfaatan_shpp'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['shp_lokasi'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pshpp_volume'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pshpp_kadar'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['pshpp_persentase'] ?? '-'); ?></td>
                                
                                <!-- CMTT data -->
                                <td><?php echo htmlspecialchars($row['cmtt_mineral'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cmtt_kuantitas_cadangan'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cmtt_kedalaman'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cmtt_kadar_gram_ton'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cmtt_kadar_persentase'] ?? '-'); ?></td>
                                <td><?php echo htmlspecialchars($row['cmtt_lokasi'] ?? '-'); ?></td>
                                
                                <!-- Report data -->
                                <td>
                                    <?php 
                                    if (!empty($row['laporan']) && $row['laporan'] != '-') {
                                        // Coba beberapa kemungkinan path
                                        $possible_paths = [
                                            $_SERVER['DOCUMENT_ROOT'] . '/pelaporan-v3.2.3/Mineral/uploads/' . $row['laporan'],
                                            $_SERVER['DOCUMENT_ROOT'] . '/v2/mineral/uploads/' . $row['laporan'],
                                            dirname(__FILE__) . '/uploads/' . $row['laporan'],
                                            '/home/lapmineral/public_html/v2/mineral/uploads/' . $row['laporan']
                                        ];
                                        
                                        $file_url = '/pelaporan-v3.2.3/Mineral/uploads/' . $row['laporan']; // default
                                        
                                        // Cek setiap path
                                        foreach ($possible_paths as $index => $path) {
                                            if (file_exists($path)) {
                                                if ($index == 0) {
                                                    $file_url = '/pelaporan-v3.2.3/Mineral/uploads/' . $row['laporan'];
                                                } elseif ($index == 1) {
                                                    $file_url = '/v2/mineral/uploads/' . $row['laporan'];
                                                } elseif ($index == 2) {
                                                    $file_url = 'uploads/' . $row['laporan'];
                                                } elseif ($index == 3) {
                                                    $file_url = '/v2/mineral/uploads/' . $row['laporan'];
                                                }
                                                break;
                                            }
                                        }
                                        
                                        echo '<a href="' . htmlspecialchars($file_url) . '" download class="btn btn-sm btn-primary" title="Download Laporan">
                                                <i class="bi bi-download"></i> Download
                                              </a>';
                                    } else {
                                        echo '-';
                                    }
                                    ?>
                                </td>
                                <td>
                                    <?php 
                                    if (!empty($row['peta_konservasi']) && $row['peta_konservasi'] != '-') {
                                        // Coba beberapa kemungkinan path
                                        $possible_paths = [
                                            $_SERVER['DOCUMENT_ROOT'] . '/pelaporan-v3.2.3/Mineral/uploads/' . $row['peta_konservasi'],
                                            $_SERVER['DOCUMENT_ROOT'] . '/v2/mineral/uploads/' . $row['peta_konservasi'],
                                            dirname(__FILE__) . '/uploads/' . $row['peta_konservasi'],
                                            '/home/lapmineral/public_html/v2/mineral/uploads/' . $row['peta_konservasi']
                                        ];
                                        
                                        $file_url = '/pelaporan-v3.2.3/Mineral/uploads/' . $row['peta_konservasi']; // default
                                        
                                        // Cek setiap path
                                        foreach ($possible_paths as $index => $path) {
                                            if (file_exists($path)) {
                                                if ($index == 0) {
                                                    $file_url = '/pelaporan-v3.2.3/Mineral/uploads/' . $row['peta_konservasi'];
                                                } elseif ($index == 1) {
                                                    $file_url = '/v2/mineral/uploads/' . $row['peta_konservasi'];
                                                } elseif ($index == 2) {
                                                    $file_url = 'uploads/' . $row['peta_konservasi'];
                                                } elseif ($index == 3) {
                                                    $file_url = '/v2/mineral/uploads/' . $row['peta_konservasi'];
                                                }
                                                break;
                                            }
                                        }
                                        
                                        echo '<a href="' . htmlspecialchars($file_url) . '" download class="btn btn-sm btn-success" title="Download Peta Konservasi">
                                                <i class="bi bi-download"></i> Download
                                              </a>';
                                    } else {
                                        echo '-';
                                    }
                                    ?>
                                </td>
                                <td>
                                    <small><?php echo $row['waktu_input'] ? date('d/m/Y H:i', strtotime($row['waktu_input'])) : '-'; ?></small>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                        <tfoot class="table-dark" style="background-color: #212529; color: #fff;">
                            <tr>
                                <?php for ($c = 0; $c < 64; $c++): ?>
                                    <th class="<?php echo ($c === 0) ? 'text-start' : 'text-center'; ?>">-</th>
                                <?php endfor; ?>
                            </tr>
                        </tfoot>
                    </table>
                </div>
                
                <?php else: ?>
                <!-- Tidak Ada Data -->
                <div class="text-center py-5">
                    <i class="bi bi-inbox display-1 text-muted"></i>
                    <h4 class="mt-3 text-muted">Tidak Ada Laporan</h4>
                    <p class="text-muted">Tidak ada data laporan konservasi minerba atau data tidak memenuhi kriteria filter.</p>
                </div>
                <?php endif; ?>
            </div>
        </div>
        
    </div>

    <!-- Modal Detail Perusahaan -->
    <div class="modal fade" id="detailModal" tabindex="-1" aria-labelledby="detailModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-xl">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="detailModalLabel">
                        <i class="bi bi-list-ul"></i> Detail Perusahaan
                    </h5>
                    <div class="ms-auto me-2">
                        <button type="button" class="btn btn-success btn-sm" id="exportModalBtn">
                            <i class="bi bi-download"></i> Export Excel
                        </button>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <div>
                            <span class="badge bg-info" id="filterInfo">Memuat data...</span>
                        </div>
                    </div>
                    
                    <div class="table-responsive">
                        <table class="table table-striped table-hover" id="detailTable">
                            <thead class="table-primary">
                                <tr id="tableHeaders">
                                    <!-- Headers akan diisi dinamis -->
                                </tr>
                            </thead>
                            <tbody id="tableBody">
                                <tr>
                                    <td colspan="7" class="text-center">
                                        <div class="spinner-border text-primary" role="status">
                                            <span class="visually-hidden">Loading...</span>
                                        </div>
                                        <br>Memuat data...
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    
                    <!-- Pagination -->
                    <div class="d-flex justify-content-between align-items-center mt-3">
                        <div class="d-flex align-items-center gap-2">
                            <small class="text-muted" id="dataInfo">Menampilkan data...</small>
                            <select class="form-select form-select-sm" id="itemsPerPageSelect" style="width: auto;">
                                <option value="10">10 per halaman</option>
                                <option value="25" selected>25 per halaman</option>
                                <option value="50">50 per halaman</option>
                                <option value="100">100 per halaman</option>
                                <option value="500">500 per halaman</option>
                                <option value="999999">Semua</option>
                            </select>
                        </div>
                        <nav aria-label="Page navigation">
                            <ul class="pagination pagination-sm mb-0" id="modalPagination">
                                <li class="page-item disabled">
                                    <a class="page-link" href="#" id="prevPage">Previous</a>
                                </li>
                                <li class="page-item active">
                                    <a class="page-link" href="#" data-page="1">1</a>
                                </li>
                                <li class="page-item">
                                    <a class="page-link" href="#" id="nextPage">Next</a>
                                </li>
                            </ul>
                        </nav>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Tutup</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="mt-5 py-4 bg-dark text-white">
        <div class="container text-center">
            <p class="mb-0">&copy; <?php echo date('Y'); ?> Daftar Laporan Konservasi Minerba Mineral. All rights reserved.</p>
        </div>
    </footer>

    <!-- Bootstrap 5 JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <!-- DataTables JS -->
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.0/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.0/js/dataTables.bootstrap5.min.js"></script>
    <script src="https://cdn.datatables.net/fixedcolumns/4.2.1/js/dataTables.fixedColumns.min.js"></script>

    <script>
        $(document).ready(function() {
            // Note: Tabel provinsi menggunakan HTML sederhana tanpa DataTable untuk performa

            // Initialize DataTable untuk tabel utama mineral
            <?php if ($mineral_data && mysqli_num_rows($mineral_data) > 0): ?>
            <?php 
            $has_objek_filter = !empty($filter_objek) && !in_array('semua', $filter_objek);
            $vis_cols_js = 'null';
            if ($has_objek_filter) {
                // Kolom Data Utama yang SELALU disertakan:
                // 0: No, 1: ID, 4: Provinsi, 5: Nama Perusahaan, 8: Sistem Penambangan, 9: Waktu Pelaporan (Triwulan), 10: Tahun
                $vis_cols = [0, 1, 4, 5, 8, 9, 10];
                if (!empty($filter_jenis_perizinan) && $filter_jenis_perizinan != 'semua') {
                    $vis_cols[] = 3; // Tampilkan kolom Jenis Perizinan jika sedang difilter
                }
                
                // 1. Recovery Penambangan
                if (in_array('recovery_penambangan', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [11, 12, 13, 14]);
                }
                
                // 2. Recovery Pengolahan
                if (in_array('recovery_pengolahan', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [15, 16, 17]);
                }
                
                // 3. MI (Mineral Ikutan)
                if (in_array('mi', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [18, 19, 20, 21, 22, 23, 24, 25, 26]);
                } else {
                    if (in_array('mi_kumulatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [19]);
                    if (in_array('mi_kuantitatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [20, 24]);
                }
                
                // 4. MKR (Mineral Kadar Rendah)
                if (in_array('mkr', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [27, 28, 29, 30, 31, 32, 33, 34]);
                } else {
                    if (in_array('mkr_kumulatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [27]);
                    if (in_array('mkr_kuantitatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [28, 32]);
                }
                
                // 5. CM (Cadangan Marginal)
                if (in_array('cm', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [35, 36, 37, 38, 39, 40, 41, 42]);
                } else {
                    if (in_array('cm_kumulatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [35]);
                    if (in_array('cm_kuantitatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [36, 40]);
                }
                
                // 6. CMTT (Cadangan Tidak Tertambang)
                if (in_array('cmtt', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [55, 56, 57, 58, 59, 60]);
                } else {
                    if (in_array('cmtt_kumulatif', $filter_objek) || in_array('cmtt_kuantitatif', $filter_objek)) {
                        $vis_cols = array_merge($vis_cols, [56]);
                    }
                }
                
                // 7. SHP (Sisa Hasil Pengolahan)
                if (in_array('shp', $filter_objek)) {
                    $vis_cols = array_merge($vis_cols, [43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54]);
                } else {
                    if (in_array('shp_kumulatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [43]);
                    if (in_array('shp_kuantitatif', $filter_objek)) $vis_cols = array_merge($vis_cols, [44, 52]);
                }
                
                $vis_cols = array_values(array_unique($vis_cols));
                $vis_cols_js = json_encode($vis_cols);
            }
            ?>
            var table = $('#mineralTable').DataTable({
                "pageLength": 25,  // Default 25 data per halaman
                "lengthMenu": [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Semua"]],
                "language": {
                    "url": "//cdn.datatables.net/plug-ins/1.13.0/i18n/id.json"
                },
                "scrollX": true,
                <?php if ($has_objek_filter): ?>
                "fixedColumns": false,
                <?php else: ?>
                "fixedColumns": {
                    "leftColumns": 5  // Fix 5 kolom pertama pada tampilan semua objek
                },
                <?php endif; ?>
                "order": [[ 0, "asc" ]],
                "processing": false,
                "serverSide": false,
                "deferRender": true,
                "drawCallback": function(settings) {
                    // Update nomor urut setiap kali tabel di-redraw
                    var api = this.api();
                    var start = api.page.info().start;
                    api.column(0, {page: 'current'}).nodes().each(function(cell, i) {
                        cell.innerHTML = start + i + 1;
                    });
                },
                "columnDefs": [
                    {
                        "targets": 0, // Target kolom No
                        "width": "50px",
                        "searchable": false,
                        "orderable": false
                    },
                    { "width": "80px", "targets": 1 },   // ID
                    { "width": "120px", "targets": [2, 3, 8, 9] }, // Komoditas, Perizinan, Sistem, Waktu Pelaporan
                    { "width": "100px", "targets": [4, 10] },      // Provinsi, Tahun
                    { "width": "200px", "targets": 5 },            // Nama Perusahaan
                    { "width": "150px", "targets": [6, 7] },       // SK IUP, Email
                    { "width": "100px", "targets": function(index, data, node) {
                        return index >= 11 && index <= 60;
                    }},
                    { "width": "120px", "targets": [61, 62, 63] }, // Laporan, Peta, Waktu Input
                    <?php if ($has_objek_filter && $vis_cols_js !== 'null'): ?>
                    {
                        "targets": function(index) {
                            var visibleCols = <?php echo $vis_cols_js; ?>;
                            return !visibleCols.includes(index);
                        },
                        "visible": false
                    }
                    <?php endif; ?>
                ],
                "footerCallback": function (row, data, start, end, display) {
                    var api = this.api();
                    
                    var parseVal = function (i) {
                        if (typeof i === 'number') return isNaN(i) ? 0 : i;
                        if (typeof i === 'string') {
                            var clean = i.replace(/<[^>]*>/g, '').trim();
                            if (!clean || clean === '-' || clean === 'Belum Ada' || clean === 'Tidak Ada') return 0;
                            if (clean.includes(',')) {
                                clean = clean.replace(/\./g, '').replace(',', '.');
                            } else if (clean.includes('.')) {
                                var dotCount = (clean.match(/\./g) || []).length;
                                if (dotCount > 1) {
                                    clean = clean.replace(/\./g, '');
                                } else {
                                    var parts = clean.split('.');
                                    if (parts[1] && parts[1].length === 3 && parts[0].length >= 1) {
                                        clean = clean.replace(/\./g, '');
                                    }
                                }
                            }
                            var val = parseFloat(clean);
                            return isNaN(val) ? 0 : val;
                        }
                        return 0;
                    };
                    
                    var formatIndo = function (num) {
                        if (isNaN(num) || num === 0) return '0';
                        var isNeg = num < 0;
                        num = Math.abs(num);
                        var str = num.toFixed(2);
                        var parts = str.split('.');
                        var intPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
                        var decPart = parts[1];
                        if (decPart === '00') {
                            return (isNeg ? '-' : '') + intPart;
                        } else {
                            decPart = decPart.replace(/0+$/, '');
                            return (isNeg ? '-' : '') + intPart + ',' + decPart;
                        }
                    };
                    
                    // Indeks kolom-kolom numerik / tonase / kuantitatif
                    var numericColumns = [
                        11, 12, 13, 14, 15, 16, 17, 
                        19, 20, 21, 22, 24, 25, 26, 
                        27, 28, 29, 30, 32, 33, 34, 
                        35, 36, 37, 38, 40, 41, 42, 
                        43, 44, 47, 48, 49, 52, 53, 54, 
                        56, 57, 58, 59
                    ];
                    
                    // Kolom 0 (No)
                    $(api.column(0).footer()).html(
                        '<div class="text-start">' +
                        '<span class="fw-bold" style="color: #ffc107; font-size: 13px;">Total Semua</span><br>' +
                        '<small style="color: #0dcaf0; font-weight: 500;">(Hal. Ini)</small>' +
                        '</div>'
                    );
                    
                    // Kolom lainnya
                    api.columns().every(function (colIdx) {
                        if (colIdx === 0) return;
                        
                        var footerCell = $(this.footer());
                        if (!footerCell || footerCell.length === 0) return;
                        
                        if (numericColumns.includes(colIdx)) {
                            // Total Semua (data terfilter)
                            var totalAll = api.column(colIdx, { search: 'applied' }).data().reduce(function (a, b) {
                                return parseVal(a) + parseVal(b);
                            }, 0);
                            
                            // Total Halaman ini
                            var totalPage = api.column(colIdx, { page: 'current' }).data().reduce(function (a, b) {
                                return parseVal(a) + parseVal(b);
                            }, 0);
                            
                            if (totalAll > 0 || totalPage > 0) {
                                footerCell.html(
                                    '<span class="fw-bold" style="color: #ffc107; font-size: 13px;">' + formatIndo(totalAll) + '</span><br>' +
                                    '<small style="color: #0dcaf0; font-weight: 500;">(Hal: ' + formatIndo(totalPage) + ')</small>'
                                );
                            } else {
                                footerCell.html('<span class="text-white">-</span>');
                            }
                        } else {
                            footerCell.html('<span class="text-white">-</span>');
                        }
                    });
                }
            });
            <?php endif; ?>
            
            // Modal functionality untuk detail perusahaan
            let currentModalStatus = '';
            let isModalOpen = false;
            let currentPage = 1;
            let itemsPerPage = 25; // Default 25 data per halaman (bisa diubah user)
            let totalData = [];
            let filteredData = [];
            
            $('#detailModal').on('show.bs.modal', function (event) {
                var button = $(event.relatedTarget);
                var status = button.data('status');
                var title = button.data('title');
                
                // Store current status
                currentModalStatus = status;
                isModalOpen = true;
                
                var modal = $(this);
                modal.find('.modal-title').html('<i class="bi bi-list-ul"></i> ' + title);
                
                // Update filter info with current values
                updateModalFilterInfo();
                
                // Load data via AJAX
                loadDetailData(status);
            });
            
            // Handle modal close
            $('#detailModal').on('hidden.bs.modal', function() {
                isModalOpen = false;
                currentModalStatus = '';
            });
            
            // Handle filter changes - update modal if open
            $('select[name="tahun"], select[name="triwulan"], select[name="provinsi"]').on('change', function() {
                // Update modal if it's open
                if (isModalOpen && currentModalStatus) {
                    setTimeout(function() {
                        updateModalFilterInfo();
                        loadDetailData(currentModalStatus);
                    }, 100); // Small delay to ensure filter values are updated
                }
            });
            
            function updateModalFilterInfo() {
                const tahun = $('select[name="tahun"]').val() || 'semua';
                const triwulan = $('select[name="triwulan"]').val() || 'semua';
                const provinsi = $('select[name="provinsi"]').val() || 'semua';
                
                let filterText = 'Filter: ';
                const filters = [];
                
                if (tahun !== 'semua') filters.push('Tahun ' + tahun);
                if (triwulan !== 'semua') filters.push(triwulan);
                if (provinsi !== 'semua') filters.push('Provinsi ' + provinsi);
                
                if (filters.length > 0) {
                    filterText += filters.join(', ');
                } else {
                    filterText += 'Semua Data';
                }
                
                $('#filterInfo').html('<i class="bi bi-funnel"></i> ' + filterText);
            }
            
            function loadDetailData(status) {
                // Reset table
                $('#tableBody').html('<tr><td colspan="7" class="text-center"><div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div><br>Memuat data...</td></tr>');
                
                // Get current filter values from the form
                const tahun = $('select[name="tahun"]').val() || 'semua';
                const triwulan = $('select[name="triwulan"]').val() || 'semua';
                const provinsi = $('select[name="provinsi"]').val() || 'semua';
                
                // Prepare parameters
                var params = {
                    action: 'get_detail',
                    status: status,
                    tahun: tahun,
                    triwulan: triwulan,
                    provinsi: provinsi
                };
                
                console.log('AJAX Request params:', params);
                
                // AJAX request
                $.ajax({
                    url: 'lmineral.php',
                    method: 'POST',
                    data: params,
                    dataType: 'json',
                    success: function(response) {
                        console.log('AJAX Response:', response);
                        if (response.success) {
                            updateTable(response.data, response.headers, status);
                            if (response.message) {
                                $('#filterInfo').text($('#filterInfo').text() + ' - ' + response.message);
                            }
                        } else {
                            showError(response.message || 'Gagal memuat data');
                            console.error('Response error:', response);
                        }
                    },
                    error: function(xhr, status, error) {
                        console.error('AJAX Error:', xhr.responseText);
                        console.error('Status:', status, 'Error:', error);
                        
                        // Coba parse response untuk mendapatkan error detail
                        try {
                            var errorResponse = JSON.parse(xhr.responseText);
                            showError(errorResponse.message || 'Error: ' + error);
                        } catch(e) {
                            showError('Error: ' + error + ' - ' + xhr.responseText.substring(0, 200));
                        }
                    }
                });
            }
            
            function updateTable(data, headers, status) {
                // Batasi data sesuai dengan jumlah yang tercantum di card
                if (status === 'belum_lapor') {
                    // Ambil jumlah dari card "Belum Melaporkan"
                    var cardCount = parseInt($('.card[data-status="belum_lapor"] h4').text().replace(/\D/g, '')) || 0;
                    console.log('Card count:', cardCount, 'Data count:', data.length);
                    
                    // Batasi data maksimal sesuai card
                    if (data.length > cardCount) {
                        data = data.slice(0, cardCount);
                        console.log('Data limited to match card count:', cardCount);
                    }
                }
                
                // Store data for pagination
                totalData = data;
                currentPage = 1;
                
                // Update headers
                var headerHtml = '';
                headers.forEach(function(header) {
                    headerHtml += '<th>' + header + '</th>';
                });
                $('#tableHeaders').html(headerHtml);
                
                // Display paginated data
                displayPaginatedData();
                
                // Update pagination controls
                updatePagination();
                
                // Store data for export
                window.currentModalData = {data: data, headers: headers, status: status};
                
                // Log for debugging
                console.log('Table updated with', data.length, 'rows for status:', status);
            }
            
            function displayPaginatedData() {
                var startIndex = (currentPage - 1) * itemsPerPage;
                var endIndex = startIndex + itemsPerPage;
                var paginatedData = totalData.slice(startIndex, endIndex);
                
                // Update body
                var bodyHtml = '';
                if (paginatedData.length > 0) {
                    paginatedData.forEach(function(row, index) {
                        var globalIndex = startIndex + index + 1;
                        bodyHtml += '<tr>';
                        bodyHtml += '<td>' + globalIndex + '</td>';
                        
                        // Handle different data structures based on status
                        switch(currentModalStatus) {
                            case 'test_data':
                            case 'test_vlaporan':
                            case 'total':
                            case 'belum_lapor':
                                bodyHtml += '<td>' + (row.sk_iup || '-') + '</td>';
                                bodyHtml += '<td>' + (row.nama_perusahaan || '-') + '</td>';
                                bodyHtml += '<td>' + (row.jenis_izin || row.alamat_perusahaan || '-') + '</td>';
                                bodyHtml += '<td>' + (row.komoditas || row.email || '-') + '</td>';
                                bodyHtml += '<td>' + (row.provinsi || '-') + '</td>';
                                bodyHtml += '<td>' + (row.status_detail || '-') + '</td>';
                                break;
                            case 'sudah_lapor':
                                bodyHtml += '<td>' + (row.sk_iup || '-') + '</td>';
                                bodyHtml += '<td>' + (row.nama_perusahaan || '-') + '</td>';
                                bodyHtml += '<td>' + (row.provinsi || '-') + '</td>';
                                bodyHtml += '<td>' + (row.tahun || '-') + '</td>';
                                bodyHtml += '<td>' + (row.triwulan || '-') + '</td>';
                                bodyHtml += '<td>' + (row.komoditas_mineral || '-') + '</td>';
                                bodyHtml += '<td>' + (row.status_detail || 'Sudah Lapor') + '</td>';
                                break;
                        }
                        bodyHtml += '</tr>';
                    });
                } else {
                    var colSpan = $('#tableHeaders th').length;
                    bodyHtml = '<tr><td colspan="' + colSpan + '" class="text-center text-muted">Tidak ada data untuk halaman ini</td></tr>';
                }
                
                $('#tableBody').html(bodyHtml);
                
                // Update data info
                var start = totalData.length > 0 ? startIndex + 1 : 0;
                var end = Math.min(endIndex, totalData.length);
                $('#dataInfo').text('Menampilkan ' + start + '-' + end + ' dari ' + totalData.length + ' data');
            }
            
            function updatePagination() {
                var totalPages = Math.ceil(totalData.length / itemsPerPage);
                var paginationHtml = '';
                
                // Previous button
                var prevClass = currentPage === 1 ? 'disabled' : '';
                paginationHtml += '<li class="page-item ' + prevClass + '">';
                paginationHtml += '<a class="page-link" href="#" id="prevPage">Previous</a>';
                paginationHtml += '</li>';
                
                // Page numbers (show max 5 pages)
                var startPage = Math.max(1, currentPage - 2);
                var endPage = Math.min(totalPages, currentPage + 2);
                
                for (var i = startPage; i <= endPage; i++) {
                    var activeClass = i === currentPage ? 'active' : '';
                    paginationHtml += '<li class="page-item ' + activeClass + '">';
                    paginationHtml += '<a class="page-link page-number" href="#" data-page="' + i + '">' + i + '</a>';
                    paginationHtml += '</li>';
                }
                
                // Next button
                var nextClass = currentPage === totalPages || totalPages === 0 ? 'disabled' : '';
                paginationHtml += '<li class="page-item ' + nextClass + '">';
                paginationHtml += '<a class="page-link" href="#" id="nextPage">Next</a>';
                paginationHtml += '</li>';
                
                $('#modalPagination').html(paginationHtml);
                
                // Bind pagination events
                bindPaginationEvents();
            }
            
            function bindPaginationEvents() {
                // Previous button
                $('#prevPage').off('click').on('click', function(e) {
                    e.preventDefault();
                    if (currentPage > 1) {
                        currentPage--;
                        displayPaginatedData();
                        updatePagination();
                    }
                });
                
                // Next button
                $('#nextPage').off('click').on('click', function(e) {
                    e.preventDefault();
                    var totalPages = Math.ceil(totalData.length / itemsPerPage);
                    if (currentPage < totalPages) {
                        currentPage++;
                        displayPaginatedData();
                        updatePagination();
                    }
                });
                
                // Page numbers
                $('.page-number').off('click').on('click', function(e) {
                    e.preventDefault();
                    var page = parseInt($(this).data('page'));
                    if (page !== currentPage) {
                        currentPage = page;
                        displayPaginatedData();
                        updatePagination();
                    }
                });
                
                // Items per page change
                $('#itemsPerPageSelect').off('change').on('change', function() {
                    itemsPerPage = parseInt($(this).val());
                    currentPage = 1; // Reset ke halaman pertama
                    displayPaginatedData();
                    updatePagination();
                });
            }
            
            function showError(message) {
                $('#tableBody').html('<tr><td colspan="7" class="text-center text-danger"><i class="bi bi-exclamation-triangle"></i> ' + message + '</td></tr>');
            }
            
            function exportToCSV() {
                // Ambil SEMUA data dari variabel totalData (bukan hanya yang ditampilkan di halaman)
                if (!totalData || totalData.length === 0) {
                    alert('Tidak ada data untuk diekspor');
                    return;
                }
                
                // Header CSV dengan format Excel Indonesia
                var headers = [];
                var csv = '\uFEFF'; // BOM untuk UTF-8
                
                // Tentukan headers berdasarkan status
                switch(currentModalStatus) {
                    case 'total':
                    case 'belum_lapor':
                        headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Jenis Izin', 'Komoditas', 'Provinsi', 'Status'];
                        break;
                    case 'sudah_lapor':
                        headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Provinsi', 'Tahun', 'Triwulan', 'Komoditas', 'Status'];
                        break;
                    default:
                        headers = ['No', 'SK IUP', 'Nama Perusahaan', 'Provinsi', 'Status'];
                }
                
                csv += headers.join(';') + '\r\n'; // Semicolon delimiter untuk Excel Indonesia
                
                // Iterasi SEMUA data (bukan hanya halaman yang ditampilkan)
                totalData.forEach(function(row, index) {
                    var rowData = [];
                    rowData.push(index + 1); // Nomor urut
                    
                    // Handle different data structures based on status
                    switch(currentModalStatus) {
                        case 'total':
                        case 'belum_lapor':
                            rowData.push(cleanTextForExcel(row.sk_iup || '-'));
                            rowData.push(cleanTextForExcel(row.nama_perusahaan || '-'));
                            rowData.push(cleanTextForExcel(row.jenis_izin || row.alamat_perusahaan || '-'));
                            rowData.push(cleanTextForExcel(row.komoditas || row.email || '-'));
                            rowData.push(cleanTextForExcel(row.provinsi || '-'));
                            rowData.push(cleanTextForExcel(row.status_detail || '-'));
                            break;
                        case 'sudah_lapor':
                            rowData.push(cleanTextForExcel(row.sk_iup || '-'));
                            rowData.push(cleanTextForExcel(row.nama_perusahaan || '-'));
                            rowData.push(cleanTextForExcel(row.provinsi || '-'));
                            rowData.push(cleanTextForExcel(row.tahun || '-'));
                            rowData.push(cleanTextForExcel(row.triwulan || '-'));
                            rowData.push(cleanTextForExcel(row.komoditas_mineral || '-'));
                            rowData.push(cleanTextForExcel(row.status_detail || 'Sudah Lapor'));
                            break;
                        default:
                            rowData.push(cleanTextForExcel(row.sk_iup || '-'));
                            rowData.push(cleanTextForExcel(row.nama_perusahaan || '-'));
                            rowData.push(cleanTextForExcel(row.provinsi || '-'));
                            rowData.push(cleanTextForExcel(row.status_detail || '-'));
                    }
                    
                    csv += rowData.join(';') + '\r\n';
                });
                
                // Download file dengan format Excel-friendly
                var fileName = 'Detail_Perusahaan_';
                var modalTitle = $('#detailModalLabel').text();
                if (modalTitle.includes('Total')) fileName += 'Total_';
                else if (modalTitle.includes('Sudah')) fileName += 'Sudah_Lapor_';
                else if (modalTitle.includes('Belum')) fileName += 'Belum_Lapor_';
                
                // Format tanggal untuk nama file
                var now = new Date();
                var dateStr = now.getDate().toString().padStart(2, '0') + '-' + 
                             (now.getMonth() + 1).toString().padStart(2, '0') + '-' + 
                             now.getFullYear();
                
                var filename = fileName + dateStr + '.csv';
                
                // Tambahkan info jumlah data yang diekspor
                console.log('Exporting ' + totalData.length + ' records to CSV');
                alert('Mengekspor ' + totalData.length + ' data ke file CSV');
                
                downloadExcelFile(csv, filename);
            }
            
            // Event handler untuk tombol export modal
            $('#exportModalBtn').click(function() {
                exportToCSV();
            });
            
            // Event handler untuk tombol export tabel utama
            $('#exportMainBtn').click(function() {
                exportMainTableToCSV();
            });
            
            // Checkbox interaksi Filter Objek
            $('#objek_semua').on('change', function() {
                var isChecked = $(this).is(':checked');
                $('.objek-item').prop('checked', isChecked);
            });

            // Parent checkbox toggle children
            $('.parent-objek').on('change', function() {
                var childClass = $(this).data('children');
                var isChecked = $(this).is(':checked');
                $('.' + childClass).prop('checked', isChecked);
                checkAllObjekStatus();
            });

            // Child checkbox check parent
            $('[data-parent]').on('change', function() {
                var parentId = $(this).data('parent');
                var childClass = $('#' + parentId).data('children');
                var anyChildChecked = $('.' + childClass + ':checked').length > 0;
                $('#' + parentId).prop('checked', anyChildChecked);
                checkAllObjekStatus();
            });

            // Objek item change check 'Semua' status
            $('.objek-item').on('change', function() {
                checkAllObjekStatus();
            });

            function checkAllObjekStatus() {
                var totalItems = $('.objek-item').length;
                var checkedItems = $('.objek-item:checked').length;
                if (checkedItems === 0 || checkedItems === totalItems) {
                    $('#objek_semua').prop('checked', checkedItems === totalItems);
                } else {
                    $('#objek_semua').prop('checked', false);
                }
            }

            // Fungsi export tabel utama ke CSV (hanya mengekspor kolom yang terlihat / sesuai filter)
            function exportMainTableToCSV() {
                var table = $('#mineralTable').DataTable();
                var data = table.data().toArray();
                
                if (data.length === 0) {
                    alert('Tidak ada data untuk diekspor');
                    return;
                }
                
                // Ambil header dan indeks kolom yang sedang VISIBLE
                var visibleHeaders = [];
                var visibleIndices = [];
                table.columns().every(function(colIdx) {
                    if (this.visible()) {
                        var headerText = $(this.header()).text().replace(/\s+/g, ' ').trim();
                        visibleHeaders.push(headerText);
                        visibleIndices.push(colIdx);
                    }
                });
                
                var csv = '\uFEFF'; // BOM untuk UTF-8
                csv += visibleHeaders.join(';') + '\r\n'; // Semicolon delimiter untuk Excel Indonesia
                
                // Data rows - hanya kolom yang visible
                data.forEach(function(row, index) {
                    var rowData = [];
                    visibleIndices.forEach(function(colIdx) {
                        if (colIdx === 0) {
                            // Kolom pertama adalah nomor urut
                            rowData.push(index + 1);
                        } else {
                            // Bersihkan data dan hapus HTML tags (seperti button download)
                            var cellData = row[colIdx] || '';
                            cellData = cellData.toString().replace(/<[^>]*>/g, '').trim();
                            rowData.push(cleanTextForExcel(cellData));
                        }
                    });
                    
                    csv += rowData.join(';') + '\r\n';
                });
                
                // Download file dengan format Excel-friendly
                var now = new Date();
                var dateStr = now.getDate().toString().padStart(2, '0') + '-' + 
                              (now.getMonth() + 1).toString().padStart(2, '0') + '-' + 
                              now.getFullYear();
                
                var filename = 'Laporan_Mineral_Export_' + dateStr + '.csv';
                
                console.log('Exporting ' + data.length + ' records with ' + visibleHeaders.length + ' columns');
                alert('Mengekspor ' + data.length + ' data dengan ' + visibleHeaders.length + ' kolom ke file CSV');
                
                downloadExcelFile(csv, filename);
            }
            
            // Fungsi helper untuk membersihkan text agar kompatibel dengan Excel
            function cleanTextForExcel(text) {
                if (!text) return '';
                
                text = text.toString().trim();
                
                // Hapus HTML tags jika ada
                text = text.replace(/<[^>]*>/g, '');
                
                // Hapus extra whitespace dan line breaks
                text = text.replace(/\s+/g, ' ');
                
                // Handle special characters untuk Excel Indonesia
                if (text.includes(';') || text.includes('"') || text.includes('\n') || text.includes('\r')) {
                    text = '"' + text.replace(/"/g, '""') + '"';
                }
                
                return text;
            }
            
            // Fungsi untuk trigger download file Excel-compatible
            function downloadExcelFile(csvContent, filename) {
                // Buat blob dengan proper MIME type untuk Excel
                var blob = new Blob([csvContent], { 
                    type: 'application/vnd.ms-excel;charset=utf-8;' 
                });
                
                // Fallback untuk browser lama
                if (navigator.msSaveBlob) {
                    navigator.msSaveBlob(blob, filename);
                } else {
                    var url = window.URL.createObjectURL(blob);
                    var a = document.createElement('a');
                    a.href = url;
                    a.download = filename;
                    a.style.display = 'none';
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    window.URL.revokeObjectURL(url);
                }
            }
        });
    </script>

    <!-- Modal Kelola Status Aktif / Non-Aktif Perusahaan Mineral -->
    <div class="modal fade" id="modalStatusPerusahaan" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header bg-dark text-white">
                    <h5 class="modal-title"><i class="bi bi-sliders me-2"></i>Kelola Status Perusahaan Mineral (Aktif / Non-Aktif)</h5>
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

        function openStatusModal(filter) {
            currentStatusFilter = filter || 'nonaktif';
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
            $.post('lmineral.php', {
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
            $.post('lmineral.php', {
                action: 'toggle_company_status',
                id: id,
                is_active: targetActive,
                pin: pin.trim()
            }, function(res) {
                if (res && res.success) {
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