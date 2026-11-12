<?php
/**
 * AJAX Handler untuk mendapatkan data perusahaan batubara
 * File: get_perusahaan_data.php
 */

// Start session dan cek login
session_start();

// Cek apakah user sudah login
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized access. Please login first.'
    ]);
    exit();
}

// Enable error reporting untuk debugging
error_reporting(E_ALL);
ini_set('display_errors', 0); // Jangan tampilkan error di output JSON
ini_set('log_errors', 1);

require_once 'koneksi.php';

// Safe escape helper
if (!function_exists('escapeString')) {
    function escapeString($val) {
        global $koneksi, $conn, $db;
        $link = $koneksi ?? $conn ?? $db ?? null;
        if ($link && is_object($link)) {
            return mysqli_real_escape_string($link, $val);
        }
        return addslashes($val);
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

// Set header JSON
header('Content-Type: application/json');

// Cek method POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        'success' => false,
        'message' => 'Method tidak diizinkan'
    ]);
    exit;
}

try {
    // Ambil parameter
    $status = isset($_POST['status']) ? $_POST['status'] : 'all';
    $provinsi = isset($_POST['provinsi']) ? $_POST['provinsi'] : '';
    $tahun = isset($_POST['tahun']) ? $_POST['tahun'] : '';
    $triwulan = isset($_POST['triwulan']) ? $_POST['triwulan'] : '';
    $jenis_perizinan = isset($_POST['jenis_perizinan']) ? $_POST['jenis_perizinan'] : '';
    
    // Log untuk debugging
    error_log("AJAX Request Batubara - Status: $status, Provinsi: $provinsi, Tahun: $tahun, Triwulan: $triwulan, Perizinan: $jenis_perizinan");
    
    // Validasi status
    $allowed_status = ['total', 'sudah_lapor', 'belum_lapor'];
    if (!in_array($status, $allowed_status)) {
        throw new Exception('Status tidak valid: ' . $status);
    }
    
    // Konversi status untuk function
    $function_status = $status;
    if ($status === 'total') {
        $function_status = 'all';
    }
    
    // Test koneksi database
    if (!$conn) {
        throw new Exception('Koneksi database tidak tersedia');
    }
    
    $where_conditions = array();
    
    // Filter provinsi jika ada
    if (!empty($provinsi) && $provinsi != 'semua') {
        $provinsi_escaped = escapeString($provinsi);
        $where_conditions[] = "pb.id_provinsi IN (SELECT id_provinsi FROM provinsi WHERE nama_provinsi = '$provinsi_escaped')";
    }
    
    // Buat kondisi untuk laporan yang sudah sesuai filter
    $laporan_condition_parts = array("nama_perusahaan IS NOT NULL");
    
    // Filter tahun untuk laporan
    if (!empty($tahun) && $tahun != 'semua') {
        $laporan_condition_parts[] = "tahun_1_7 = '" . escapeString($tahun) . "'";
    }
    
    // Filter triwulan untuk laporan
    if (!empty($triwulan) && $triwulan != 'semua') {
        switch($triwulan) {
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
    
    // Filter jenis perizinan untuk laporan
    if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
        $jp_esc = escapeString($jenis_perizinan);
        $laporan_condition_parts[] = "jenis_perizinan_1_1 = '$jp_esc'";
    }
    
    $laporan_condition = implode(' AND ', $laporan_condition_parts);

    $sql = "";
    
    // Query berbeda berdasarkan status
    if ($function_status == 'belum_lapor') {
        // Untuk yang belum lapor, ambil perusahaan yang tidak ada di laporan sesuai filter
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
                
    } elseif ($function_status == 'sudah_lapor') {
        // Untuk yang sudah lapor sesuai filter - ambil perusahaan unik (GROUP BY)
        $where_conditions_laporan = array();
        $where_conditions_laporan[] = "nama_provinsi IS NOT NULL";
        $where_conditions_laporan[] = "nama_perusahaan IS NOT NULL";
        
        // Filter provinsi
        if (!empty($provinsi) && $provinsi != 'semua') {
            $provinsi_escaped = escapeString($provinsi);
            $where_conditions_laporan[] = "nama_provinsi = '$provinsi_escaped'";
        }
        
        // Filter tahun
        if (!empty($tahun) && $tahun != 'semua') {
            $where_conditions_laporan[] = "tahun_1_7 = '" . escapeString($tahun) . "'";
        }
        
        // Filter triwulan
        if (!empty($triwulan) && $triwulan != 'semua') {
            switch($triwulan) {
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
            switch($triwulan) {
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

        // Filter jenis perizinan untuk status
        if (!empty($jenis_perizinan) && $jenis_perizinan != 'semua') {
            $jp_esc = escapeString($jenis_perizinan);
            $status_condition .= " AND vlb.jenis_perizinan_1_1 = '$jp_esc'";
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
    
    $result = executeQuery($sql);
    
    if (!$result) {
        throw new Exception('Query gagal dieksekusi: ' . $conn->error);
    }
    
    // Convert result ke array
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = [
            'nama_perusahaan' => $row['nama_perusahaan'] ?? '',
            'sk_iup' => $row['sk_iup'] ?? '',
            'jenis_izin' => $row['jenis_izin'] ?? '',
            'komoditas' => $row['komoditas'] ?? '',
            'nama_provinsi' => $row['nama_provinsi'] ?? '',
            'status_laporan' => $row['status_laporan'] ?? '',
            'triwulan' => $row['triwulan'] ?? '',
            'tahun_1_7' => $row['tahun_1_7'] ?? '',
            'waktu_input_8' => $row['waktu_input_8'] ?? ''
        ];
    }
    
    // Log hasil
    error_log("AJAX Response Batubara - Total records: " . count($data));
    
    // Return success response
    echo json_encode([
        'success' => true,
        'data' => $data,
        'total' => count($data),
        'filter' => [
            'status' => $status,
            'provinsi' => $provinsi,
            'tahun' => $tahun,
            'triwulan' => $triwulan
        ]
    ]);
    
} catch (Exception $e) {
    // Log error
    error_log("AJAX Error Batubara: " . $e->getMessage());
    
    // Return error response
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'data' => [],
        'debug' => [
            'status' => $status ?? 'undefined',
            'provinsi' => $provinsi ?? 'undefined',
            'tahun' => $tahun ?? 'undefined',
            'triwulan' => $triwulan ?? 'undefined'
        ]
    ]);
}
?>