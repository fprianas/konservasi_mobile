<?php
/**
 * REST API Binwas (Pembinaan & Pengawasan Konservasi Minerba)
 * Endpoint: /public_html/v2/api_binwas.php
 * Mendukung: Filter, Pencarian Perusahaan, Checklist Inspeksi, Rekap Objek Konservasi, Matriks Temuan & Upload Bukti Foto
 */

// Header CORS & Format JSON
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Suppress output error mentah agar tidak merusak format JSON
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_reporting(E_ALL);

// Load koneksi database
$koneksi_path = __DIR__ . '/koneksi.php';
if (!file_exists($koneksi_path)) {
    $koneksi_path = dirname(__DIR__) . '/koneksi.php';
}
if (file_exists($koneksi_path)) {
    require_once $koneksi_path;
}

// Helper escape string untuk keamanan query
function dbEscape($val) {
    global $koneksi, $conn, $db;
    $link = $koneksi ?? $conn ?? $db ?? null;
    if ($link && is_object($link)) {
        return mysqli_real_escape_string($link, trim((string)$val));
    }
    return addslashes(trim((string)$val));
}

// Helper eksekusi query
function dbQuery($sql) {
    global $koneksi, $conn, $db;
    $link = $koneksi ?? $conn ?? $db ?? null;
    if ($link && is_object($link)) {
        return mysqli_query($link, $sql);
    }
    return false;
}

// Helper insert ID
function dbInsertId() {
    global $koneksi, $conn, $db;
    $link = $koneksi ?? $conn ?? $db ?? null;
    if ($link && is_object($link)) {
        return mysqli_insert_id($link);
    }
    return 0;
}

// Auto-migration kolom binwas_inspeksi
function ensureBinwasColumns() {
    static $done = false;
    if ($done) return;
    $done = true;

    try {
        $chk_asal = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
        if (!$chk_asal || $chk_asal->num_rows === 0) {
            dbQuery("ALTER TABLE binwas_inspeksi ADD COLUMN asal_input VARCHAR(50) DEFAULT 'pusat' AFTER status");
        }
        // Record uji coba awal (ID 1-5 atau yang belum diset) adalah data pusat
        dbQuery("UPDATE binwas_inspeksi SET asal_input = 'pusat' WHERE asal_input IS NULL OR asal_input = '' OR id <= 5");

        $chk_kom = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'komoditas'");
        if (!$chk_kom || $chk_kom->num_rows === 0) {
            dbQuery("ALTER TABLE binwas_inspeksi ADD COLUMN komoditas VARCHAR(100) NULL AFTER tipe_komoditas");
        }
    } catch (Throwable $e) {
        // Abaikan error skema
    }
}

$action = $_GET['action'] ?? $_POST['action'] ?? 'get_rekap';

try {
    ensureBinwasColumns();
    switch ($action) {
        case 'get_filters':
            handleGetFilters();
            break;

        case 'search_companies':
            handleSearchCompanies();
            break;

        case 'get_master_temuan':
            handleGetMasterTemuan();
            break;

        case 'submit_inspeksi':
            handleSubmitInspeksi();
            break;

        case 'get_history':
            handleGetHistory();
            break;

        case 'get_detail':
            handleGetDetail();
            break;

        case 'get_rekap':
        case 'get_dashboard':
        case 'get_summary':
            handleGetRekap();
            break;

        case 'get_matrix':
            handleGetMatrix();
            break;

        case 'upload_foto':
            handleUploadFoto();
            break;

        case 'update_tindak_lanjut':
            handleUpdateTindakLanjut();
            break;

        case 'upload_surat':
            handleUploadSurat();
            break;

        case 'seed_dummy':
            handleSeedDummy();
            break;

        case 'login_provinsi':
            handleLoginProvinsi();
            break;

        case 'migrate_user_provinsi':
            handleMigrateUserProvinsi();
            break;

        case 'get_laporan_khusus':
            handleGetLaporanKhusus();
            break;

        case 'get_petugas_list':
            handleGetPetugasList();
            break;

        case 'update_evaluasi':
            handleUpdateEvaluasi();
            break;

        default:
            echo json_encode([
                'success' => false,
                'message' => 'Action tidak dikenali'
            ]);
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

/**
 * 1. Filter opsi: Provinsi, Jenis Izin & Komoditas (Batubara & Mineral)
 */
function handleGetFilters() {
    $tipe = strtolower($_GET['tipe'] ?? 'batubara');

    $provinsi_list = [];
    $izin_list = [];
    $komoditas_list = [];

    if ($tipe === 'batubara') {
        // Provinsi Batubara
        $sql_p = "SELECT id_provinsi, nama_provinsi FROM provinsi WHERE nama_provinsi IS NOT NULL AND nama_provinsi != '' ORDER BY nama_provinsi ASC";
        $res_p = dbQuery($sql_p);
        if ($res_p) {
            while ($r = $res_p->fetch_assoc()) {
                $provinsi_list[] = [
                    'id_provinsi' => $r['id_provinsi'],
                    'nama_provinsi' => trim($r['nama_provinsi'])
                ];
            }
        }

        // Jenis Izin Batubara
        $sql_i = "SELECT DISTINCT jenis_izin FROM perusahaan_batubara WHERE jenis_izin IS NOT NULL AND jenis_izin != '' ORDER BY jenis_izin ASC";
        $res_i = dbQuery($sql_i);
        if ($res_i) {
            while ($r = $res_i->fetch_assoc()) {
                $izin_list[] = trim($r['jenis_izin']);
            }
        }
        $komoditas_list = ['Batubara'];
    } else {
        // Provinsi Mineral (relasi: perusahaan_mineral.id_provinsi = provinsi_mineral.id)
        $sql_p = "SELECT id as id_provinsi, nama_provinsi FROM provinsi_mineral WHERE nama_provinsi IS NOT NULL AND nama_provinsi != '' ORDER BY nama_provinsi ASC";
        $res_p = dbQuery($sql_p);
        if ($res_p) {
            while ($r = $res_p->fetch_assoc()) {
                $provinsi_list[] = [
                    'id_provinsi' => $r['id_provinsi'],
                    'nama_provinsi' => trim($r['nama_provinsi'])
                ];
            }
        }

        // Jenis Izin Mineral
        $sql_i = "SELECT DISTINCT jenis_izin FROM perusahaan_mineral WHERE jenis_izin IS NOT NULL AND jenis_izin != '' ORDER BY jenis_izin ASC";
        $res_i = dbQuery($sql_i);
        if ($res_i) {
            while ($r = $res_i->fetch_assoc()) {
                $izin_list[] = trim($r['jenis_izin']);
            }
        }

        // Komoditas Mineral
        $sql_k = "SELECT DISTINCT komoditas FROM perusahaan_mineral WHERE komoditas IS NOT NULL AND komoditas != '' ORDER BY komoditas ASC";
        $res_k = dbQuery($sql_k);
        if ($res_k) {
            while ($r = $res_k->fetch_assoc()) {
                $komoditas_list[] = trim($r['komoditas']);
            }
        }
        if (empty($komoditas_list)) {
            $komoditas_list = ['Nikel', 'Bauksit', 'Emas', 'Tembaga', 'Timah', 'Batu Gamping'];
        }
    }

    echo json_encode([
        'success' => true,
        'tipe' => $tipe,
        'data' => [
            'provinsi' => $provinsi_list,
            'jenis_izin' => $izin_list,
            'komoditas' => $komoditas_list,
            'triwulan' => ['Triwulan 1', 'Triwulan 2', 'Triwulan 3', 'Triwulan 4'],
            'tahun' => [date('Y'), date('Y') - 1, date('Y') - 2]
        ]
    ]);
}

/**
 * 2. Pencarian Perusahaan Target Inspeksi
 */
function handleSearchCompanies() {
    $tipe = strtolower($_GET['tipe'] ?? 'batubara');
    $id_provinsi = dbEscape($_GET['id_provinsi'] ?? '');
    $nama_provinsi = dbEscape($_GET['nama_provinsi'] ?? $_GET['provinsi'] ?? '');
    $jenis_izin = dbEscape($_GET['jenis_izin'] ?? '');
    $komoditas = dbEscape($_GET['komoditas'] ?? '');
    $q = dbEscape($_GET['q'] ?? $_GET['query'] ?? '');
    $limit = max(10, min(100, (int)($_GET['limit'] ?? 40)));

    $table = ($tipe === 'mineral') ? 'perusahaan_mineral' : 'perusahaan_batubara';
    $prov_table = ($tipe === 'mineral') ? 'provinsi_mineral' : 'provinsi';
    $prov_join_col = ($tipe === 'mineral') ? 'prov.id' : 'prov.id_provinsi';

    $where = ["p.nama_perusahaan IS NOT NULL", "p.nama_perusahaan != ''"];

    if (!empty($id_provinsi) && $id_provinsi !== 'semua') {
        $where[] = "p.id_provinsi = '$id_provinsi'";
    }

    if (!empty($nama_provinsi) && $nama_provinsi !== 'semua') {
        $where[] = "prov.nama_provinsi LIKE '%$nama_provinsi%'";
    }

    if (!empty($jenis_izin) && $jenis_izin !== 'semua') {
        $where[] = "p.jenis_izin = '$jenis_izin'";
    }

    if (!empty($komoditas) && $komoditas !== 'semua') {
        $where[] = "p.komoditas LIKE '%$komoditas%'";
    }

    if (!empty($q)) {
        $where[] = "(p.nama_perusahaan LIKE '%$q%' OR p.sk_iup LIKE '%$q%' OR p.komoditas LIKE '%$q%')";
    }

    $where_sql = implode(' AND ', $where);

    $sql = "SELECT p.id, p.nama_perusahaan, p.komoditas, p.jenis_izin, p.kode_wiup, p.sk_iup, 
                   prov.nama_provinsi 
            FROM $table p 
            LEFT JOIN $prov_table prov ON p.id_provinsi = $prov_join_col 
            WHERE $where_sql 
            ORDER BY p.nama_perusahaan ASC 
            LIMIT $limit";

    $res = dbQuery($sql);
    $companies = [];

    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $companies[] = [
                'id' => (int)$row['id'],
                'tipe_komoditas' => $tipe,
                'nama_perusahaan' => trim($row['nama_perusahaan']),
                'komoditas' => trim($row['komoditas'] ?? ($tipe === 'batubara' ? 'Batubara' : 'Mineral')),
                'jenis_izin' => trim($row['jenis_izin'] ?? '-'),
                'kode_wiup' => trim($row['kode_wiup'] ?? '-'),
                'sk_iup' => trim($row['sk_iup'] ?? '-'),
                'nama_provinsi' => trim($row['nama_provinsi'] ?? '-')
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'tipe' => $tipe,
        'total' => count($companies),
        'data' => $companies
    ]);
}

/**
 * 3. Master Butir Temuan (Dikelompokkan per Kategori)
 */
function handleGetMasterTemuan() {
    $sql_kat = "SELECT id, nama_kategori, urutan FROM binwas_kategori_temuan ORDER BY urutan ASC, id ASC";
    $res_kat = dbQuery($sql_kat);

    $categories = [];
    if ($res_kat) {
        while ($kat = $res_kat->fetch_assoc()) {
            $kat_id = (int)$kat['id'];

            $sql_items = "SELECT id, id_kategori, deskripsi_temuan, objek_konservasi 
                          FROM binwas_item_temuan 
                          WHERE id_kategori = $kat_id AND is_active = 1 
                          ORDER BY id ASC";
            $res_items = dbQuery($sql_items);
            $items = [];
            if ($res_items) {
                while ($it = $res_items->fetch_assoc()) {
                    $items[] = [
                        'id' => (int)$it['id'],
                        'id_kategori' => (int)$it['id_kategori'],
                        'deskripsi_temuan' => trim($it['deskripsi_temuan']),
                        'objek_konservasi' => trim($it['objek_konservasi'] ?? 'Administrasi')
                    ];
                }
            }

            $categories[] = [
                'id' => $kat_id,
                'nama_kategori' => trim($kat['nama_kategori']),
                'urutan' => (int)$kat['urutan'],
                'items' => $items
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'data' => $categories
    ]);
}

/**
 * 4. Submit Hasil Inspeksi Lapangan (Mendukung Insert Temuan Kustom Dinamis)
 */
function handleSubmitInspeksi() {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $tipe_komoditas = dbEscape($input['tipe_komoditas'] ?? 'batubara');
    $id_perusahaan = (int)($input['id_perusahaan'] ?? 0);
    $nama_perusahaan = dbEscape($input['nama_perusahaan'] ?? '');
    $nama_provinsi = dbEscape($input['nama_provinsi'] ?? '');
    $jenis_izin = dbEscape($input['jenis_izin'] ?? '');
    $nama_petugas = dbEscape($input['nama_petugas'] ?? 'Petugas Binwas');
    $tanggal_inspeksi = dbEscape($input['tanggal_inspeksi'] ?? date('Y-m-d'));
    $triwulan = dbEscape($input['triwulan'] ?? 'Triwulan 2');
    $tahun = (int)($input['tahun'] ?? date('Y'));
    $catatan_umum = dbEscape($input['catatan_umum'] ?? '');
    $items = $input['items'] ?? [];

    if ($id_perusahaan <= 0 || empty($nama_perusahaan)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Perusahaan wajib dipilih terlebih dahulu sebelum menyimpan!'
        ]);
        return;
    }

    // Auto-migration: Pastikan kolom objek_konservasi ada pada binwas_temuan_detail
    $chk_col_obj = dbQuery("SHOW COLUMNS FROM binwas_temuan_detail LIKE 'objek_konservasi'");
    $has_col_obj = false;
    if ($chk_col_obj && $chk_col_obj->num_rows > 0) {
        $has_col_obj = true;
    } else {
        $alter = dbQuery("ALTER TABLE binwas_temuan_detail ADD COLUMN objek_konservasi VARCHAR(255) NULL AFTER id_item_temuan");
        if ($alter) $has_col_obj = true;
    }

    // Auto-migration: Pastikan kolom komoditas ada pada binwas_inspeksi
    $chk_col_kom = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'komoditas'");
    $has_col_kom = false;
    if ($chk_col_kom && $chk_col_kom->num_rows > 0) {
        $has_col_kom = true;
    } else {
        $alter2 = dbQuery("ALTER TABLE binwas_inspeksi ADD COLUMN komoditas VARCHAR(100) NULL AFTER tipe_komoditas");
        if ($alter2) $has_col_kom = true;
    }

    // Tentukan nama komoditas spesifik
    $komoditas = dbEscape($input['komoditas'] ?? '');
    if (empty($komoditas)) {
        if ($tipe_komoditas === 'batubara') {
            $komoditas = 'Batubara';
        } else {
            $chk_pm = dbQuery("SELECT komoditas FROM perusahaan_mineral WHERE id = $id_perusahaan LIMIT 1");
            if ($chk_pm && $pmrow = $chk_pm->fetch_assoc()) {
                $komoditas = dbEscape($pmrow['komoditas']);
            }
            if (empty($komoditas)) $komoditas = 'Mineral';
        }
    }

    // Hitung total temuan (ada_temuan = 1)
    $total_temuan = 0;
    foreach ($items as $item) {
        if (!empty($item['ada_temuan'])) {
            $total_temuan++;
        }
    }

    // Auto-migration: Pastikan kolom asal_input ada pada binwas_inspeksi
    $chk_col_asal = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
    $has_col_asal = false;
    if ($chk_col_asal && $chk_col_asal->num_rows > 0) {
        $has_col_asal = true;
    } else {
        $alter3 = dbQuery("ALTER TABLE binwas_inspeksi ADD COLUMN asal_input VARCHAR(50) DEFAULT 'pusat' AFTER status");
        if ($alter3) $has_col_asal = true;
    }

    $asal_input = dbEscape($input['asal_input'] ?? 'pusat');
    $col_asal_hdr = $has_col_asal ? ", asal_input" : "";
    $val_asal_hdr = $has_col_asal ? ", '$asal_input'" : "";

    // Simpan Header Inspeksi
    $col_kom_hdr = $has_col_kom ? ", komoditas" : "";
    $val_kom_hdr = $has_col_kom ? ", '$komoditas'" : "";
    $sql_hdr = "INSERT INTO binwas_inspeksi 
                (tipe_komoditas$col_kom_hdr, id_perusahaan, nama_perusahaan, nama_provinsi, jenis_izin, 
                 nama_petugas, tanggal_inspeksi, triwulan, tahun, total_temuan, catatan_umum, status$col_asal_hdr)
                VALUES 
                ('$tipe_komoditas'$val_kom_hdr, $id_perusahaan, '$nama_perusahaan', '$nama_provinsi', '$jenis_izin',
                 '$nama_petugas', '$tanggal_inspeksi', '$triwulan', $tahun, $total_temuan, '$catatan_umum', 'Submitted'$val_asal_hdr)";

    $res_hdr = dbQuery($sql_hdr);
    if (!$res_hdr) {
        throw new Exception("Gagal menyimpan data inspeksi");
    }

    $inspeksi_id = dbInsertId();

    // Simpan Detail Butir Temuan
    foreach ($items as $it) {
        $id_item_temuan = (int)($it['id_item_temuan'] ?? 0);
        $deskripsi_kustom = trim($it['deskripsi_temuan_baru'] ?? '');

        // Fitur dinamis: Jika temuan baru belum ada di master, buat otomatis
        if ($id_item_temuan <= 0 && !empty($deskripsi_kustom)) {
            $id_kat = (int)($it['id_kategori'] ?? 10);
            $obj_kons = dbEscape($it['objek_konservasi'] ?? 'Administrasi');
            $desc_esc = dbEscape($deskripsi_kustom);

            $sql_new_item = "INSERT INTO binwas_item_temuan (id_kategori, deskripsi_temuan, objek_konservasi, is_active) 
                             VALUES ($id_kat, '$desc_esc', '$obj_kons', 0)";
            dbQuery($sql_new_item);
            $id_item_temuan = dbInsertId();
        }

        $ada_temuan = !empty($it['ada_temuan']) ? 1 : 0;
        $keterangan = dbEscape($it['keterangan_lapangan'] ?? '');
        $rekomendasi = dbEscape($it['rekomendasi'] ?? '');
        $foto = dbEscape($it['foto_temuan'] ?? '');
        $objek_kons = dbEscape($it['objek_konservasi'] ?? '');

        if ($id_item_temuan > 0) {
            $col_obj_ins = ($has_col_obj && !empty($objek_kons)) ? ", objek_konservasi" : "";
            $val_obj_ins = ($has_col_obj && !empty($objek_kons)) ? ", '$objek_kons'" : "";
            $sql_det = "INSERT INTO binwas_temuan_detail 
                        (id_inspeksi, id_item_temuan$col_obj_ins, ada_temuan, keterangan_lapangan, rekomendasi, foto_temuan)
                        VALUES 
                        ($inspeksi_id, $id_item_temuan$val_obj_ins, $ada_temuan, '$keterangan', '$rekomendasi', '$foto')";
            dbQuery($sql_det);
        }
    }

    echo json_encode([
        'success' => true,
        'message' => 'Laporan inspeksi Binwas berhasil disimpan',
        'inspeksi_id' => $inspeksi_id,
        'total_temuan' => $total_temuan
    ]);
}

/**
 * 5. Riwayat Inspeksi Binwas
 */
function handleGetHistory() {
    $limit = max(10, min(100, (int)($_GET['limit'] ?? 40)));
    $tipe = dbEscape($_GET['tipe'] ?? '');
    $tahun = dbEscape($_GET['tahun'] ?? '');
    $triwulan = dbEscape($_GET['triwulan'] ?? '');
    $provinsi = dbEscape($_GET['provinsi'] ?? $_GET['nama_provinsi'] ?? '');
    $asal_input = dbEscape($_GET['asal_input'] ?? '');
    $q = dbEscape($_GET['q'] ?? $_GET['search'] ?? '');

    $where = ["1=1"];
    if (!empty($tipe) && $tipe !== 'semua') {
        $where[] = "tipe_komoditas = '$tipe'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $where[] = "triwulan = '$triwulan'";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "nama_provinsi LIKE '%$provinsi%'";
    }
    $chk_col = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
    $has_col = ($chk_col && $chk_col->num_rows > 0);
    if ($has_col && !empty($asal_input) && $asal_input !== 'semua') {
        $where[] = "asal_input = '$asal_input'";
    }
    if (!empty($q)) {
        $where[] = "(nama_perusahaan LIKE '%$q%' OR nama_petugas LIKE '%$q%' OR nama_provinsi LIKE '%$q%')";
    }

    $where_sql = implode(' AND ', $where);

    $sql = "SELECT id, tipe_komoditas, id_perusahaan, nama_perusahaan, nama_provinsi, jenis_izin,
                   nama_petugas, tanggal_inspeksi, triwulan, tahun, total_temuan, status, created_at 
            FROM binwas_inspeksi 
            WHERE $where_sql 
            ORDER BY id DESC 
            LIMIT $limit";

    $res = dbQuery($sql);
    $history = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $history[] = [
                'id' => (int)$row['id'],
                'tipe_komoditas' => $row['tipe_komoditas'],
                'id_perusahaan' => (int)$row['id_perusahaan'],
                'nama_perusahaan' => trim($row['nama_perusahaan']),
                'nama_provinsi' => trim($row['nama_provinsi'] ?? '-'),
                'jenis_izin' => trim($row['jenis_izin'] ?? '-'),
                'nama_petugas' => trim($row['nama_petugas']),
                'tanggal_inspeksi' => $row['tanggal_inspeksi'],
                'triwulan' => $row['triwulan'],
                'tahun' => (int)$row['tahun'],
                'total_temuan' => (int)$row['total_temuan'],
                'status' => $row['status'],
                'created_at' => $row['created_at']
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'total' => count($history),
        'data' => $history
    ]);
}

/**
 * 6. Detail Inspeksi & Temuannya
 */
function handleGetDetail() {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID inspeksi tidak valid']);
        return;
    }

    $sql = "SELECT * FROM binwas_inspeksi WHERE id = $id LIMIT 1";
    $res = dbQuery($sql);
    if (!$res || $res->num_rows === 0) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Data inspeksi tidak ditemukan']);
        return;
    }

    $inspeksi = $res->fetch_assoc();

    // Cek apakah tabel binwas_tindak_lanjut ada di database
    $has_tl_table = false;
    $chk_tl = dbQuery("SHOW TABLES LIKE 'binwas_tindak_lanjut'");
    if ($chk_tl && $chk_tl->num_rows > 0) {
        $has_tl_table = true;
    }

    // Ambil detail temuan beserta tindak lanjutnya (jika ada)
    if ($has_tl_table) {
        $sql_det = "SELECT d.*, it.deskripsi_temuan, 
                           COALESCE(NULLIF(d.objek_konservasi, ''), it.objek_konservasi) AS objek_konservasi, kat.nama_kategori, kat.urutan,
                           tl.status_tindakan, tl.langkah_temuan, tl.nomor_surat, tl.tanggal_surat, tl.file_surat, tl.petugas_tindak_lanjut
                    FROM binwas_temuan_detail d 
                    JOIN binwas_item_temuan it ON d.id_item_temuan = it.id 
                    JOIN binwas_kategori_temuan kat ON it.id_kategori = kat.id 
                    LEFT JOIN (
                        SELECT * FROM binwas_tindak_lanjut 
                        WHERE id_inspeksi = $id 
                        ORDER BY id DESC
                    ) tl ON tl.id_temuan_detail = d.id
                    WHERE d.id_inspeksi = $id 
                    GROUP BY d.id
                    ORDER BY kat.urutan ASC, it.id ASC";
    } else {
        $sql_det = "SELECT d.*, it.deskripsi_temuan, 
                           COALESCE(NULLIF(d.objek_konservasi, ''), it.objek_konservasi) AS objek_konservasi, kat.nama_kategori, kat.urutan 
                    FROM binwas_temuan_detail d 
                    JOIN binwas_item_temuan it ON d.id_item_temuan = it.id 
                    JOIN binwas_kategori_temuan kat ON it.id_kategori = kat.id 
                    WHERE d.id_inspeksi = $id 
                    ORDER BY kat.urutan ASC, it.id ASC";
    }

    $res_det = dbQuery($sql_det);
    $items = [];
    if ($res_det) {
        while ($row = $res_det->fetch_assoc()) {
            $status_tl = $row['status_tindakan'] ?? 'Belum';
            if (empty($status_tl)) $status_tl = 'Belum';

            $items[] = [
                'id' => (int)$row['id'],
                'id_item_temuan' => (int)$row['id_item_temuan'],
                'nama_kategori' => trim($row['nama_kategori']),
                'deskripsi_temuan' => trim($row['deskripsi_temuan']),
                'objek_konservasi' => trim($row['objek_konservasi']),
                'ada_temuan' => (int)$row['ada_temuan'] === 1,
                'keterangan_lapangan' => trim($row['keterangan_lapangan'] ?? ''),
                'rekomendasi' => trim($row['rekomendasi'] ?? ''),
                'foto_temuan' => trim($row['foto_temuan'] ?? ''),
                'status_tindakan' => $status_tl,
                'langkah_temuan' => trim($row['langkah_temuan'] ?? ''),
                'nomor_surat' => trim($row['nomor_surat'] ?? ''),
                'tanggal_surat' => trim($row['tanggal_surat'] ?? ''),
                'file_surat' => trim($row['file_surat'] ?? ''),
                'petugas_tindak_lanjut' => !empty(trim($inspeksi['petugas'] ?? '')) ? trim($inspeksi['petugas']) : trim($row['petugas_tindak_lanjut'] ?? '')
            ];
        }
    }

    $inspeksi['items'] = $items;

    echo json_encode([
        'success' => true,
        'data' => $inspeksi
    ]);
}

/**
 * 7. Rekapitulasi Dashboard: 8 Objek Konservasi & 10 Kategori Temuan (Sesuai Excel)
 */
function handleGetRekap() {
    $tipe = dbEscape($_GET['tipe'] ?? '');
    $tahun = dbEscape($_GET['tahun'] ?? '');
    $triwulan = dbEscape($_GET['triwulan'] ?? '');
    $provinsi = dbEscape($_GET['provinsi'] ?? $_GET['nama_provinsi'] ?? '');
    $asal_input = dbEscape($_GET['asal_input'] ?? '');

    $where_ins = ["1=1"];
    if (!empty($tipe) && $tipe !== 'semua') {
        $where_ins[] = "i.tipe_komoditas = '$tipe'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where_ins[] = "i.tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $where_ins[] = "i.triwulan = '$triwulan'";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where_ins[] = "i.nama_provinsi LIKE '%$provinsi%'";
    }
    $chk_col = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
    $has_col = ($chk_col && $chk_col->num_rows > 0);
    if ($has_col && !empty($asal_input) && $asal_input !== 'semua') {
        $where_ins[] = "i.asal_input = '$asal_input'";
    }
    $where_sql = implode(' AND ', $where_ins);

    // KPI Utama
    $sql_kpi = "SELECT 
                    COUNT(DISTINCT i.id) as total_inspeksi,
                    COUNT(DISTINCT i.id_perusahaan) as total_perusahaan,
                    COALESCE(SUM(i.total_temuan), 0) as total_temuan
                FROM binwas_inspeksi i 
                WHERE $where_sql";
    $res_kpi = dbQuery($sql_kpi);
    $total_inspeksi = 0;
    $total_perusahaan = 0;
    $total_temuan = 0;
    if ($res_kpi && $rk = $res_kpi->fetch_assoc()) {
        $total_inspeksi = (int)$rk['total_inspeksi'];
        $total_perusahaan = (int)$rk['total_perusahaan'];
        $total_temuan = (int)$rk['total_temuan'];
    }

    $rata_rata_temuan = $total_inspeksi > 0 ? round($total_temuan / $total_inspeksi, 1) : 0;

    // Jika belum ada data inspeksi sama sekali untuk filter ini, kembalikan 0 langsung
    if ($total_inspeksi === 0) {
        $res_kat = dbQuery("SELECT id as id_kategori, nama_kategori, urutan FROM binwas_kategori_temuan ORDER BY urutan ASC");
        $rekap_kategori = [];
        if ($res_kat) {
            while ($r = $res_kat->fetch_assoc()) {
                $rekap_kategori[] = [
                    'id_kategori' => (int)$r['id_kategori'],
                    'nama_kategori' => trim($r['nama_kategori']),
                    'jumlah_temuan' => 0,
                    'persentase' => 0.0
                ];
            }
        }
        echo json_encode([
            'success' => true,
            'kpi' => [
                'total_inspeksi' => 0,
                'total_perusahaan' => 0,
                'total_temuan' => 0,
                'rata_rata_temuan' => 0.0
            ],
            'rekap_kategori' => $rekap_kategori,
            'rekap_objek' => [],
            'rekap_komoditas' => [],
            'top_temuan' => []
        ]);
        return;
    }

    // Rekap 10 Kategori Temuan
    $sql_kat = "SELECT 
                    kat.id as id_kategori,
                    kat.nama_kategori,
                    kat.urutan,
                    COUNT(CASE WHEN i.id IS NOT NULL AND d.ada_temuan = 1 THEN 1 END) as jumlah_temuan
                FROM binwas_kategori_temuan kat
                LEFT JOIN binwas_item_temuan it ON kat.id = it.id_kategori
                LEFT JOIN binwas_temuan_detail d ON it.id = d.id_item_temuan
                LEFT JOIN binwas_inspeksi i ON d.id_inspeksi = i.id AND $where_sql
                GROUP BY kat.id, kat.nama_kategori, kat.urutan
                ORDER BY kat.urutan ASC";

    $res_kat = dbQuery($sql_kat);
    $rekap_kategori = [];
    if ($res_kat) {
        while ($r = $res_kat->fetch_assoc()) {
            $jml = (int)$r['jumlah_temuan'];
            $persen = $total_temuan > 0 ? round(($jml * 100.0) / $total_temuan, 2) : 0.0;
            $rekap_kategori[] = [
                'id_kategori' => (int)$r['id_kategori'],
                'nama_kategori' => trim($r['nama_kategori']),
                'jumlah_temuan' => $jml,
                'persentase' => $persen
            ];
        }
    }

    // Rekap Objek Konservasi (Presisi: Menghitung objek terpilih per butir temuan)
    $sql_obj_raw = "SELECT COALESCE(NULLIF(d.objek_konservasi, ''), it.objek_konservasi) as objek_raw
                    FROM binwas_temuan_detail d
                    JOIN binwas_item_temuan it ON d.id_item_temuan = it.id
                    JOIN binwas_inspeksi i ON d.id_inspeksi = i.id
                    WHERE d.ada_temuan = 1 AND $where_sql";
    $res_obj_raw = dbQuery($sql_obj_raw);
    $obj_counts = [];
    $total_obj_hits = 0;
    if ($res_obj_raw) {
        while ($ro = $res_obj_raw->fetch_assoc()) {
            $raw = trim($ro['objek_raw'] ?? '');
            if (empty($raw)) continue;
            $parts = explode(',', $raw);
            foreach ($parts as $p) {
                $p = trim($p);
                if (empty($p)) continue;
                if (!isset($obj_counts[$p])) $obj_counts[$p] = 0;
                $obj_counts[$p]++;
                $total_obj_hits++;
            }
        }
    }
    arsort($obj_counts);
    $rekap_objek = [];
    foreach ($obj_counts as $obj_name => $count) {
        $persen = $total_obj_hits > 0 ? round(($count * 100.0) / $total_obj_hits, 1) : 0.0;
        $rekap_objek[] = [
            'objek_konservasi' => $obj_name,
            'jumlah_temuan' => $count,
            'persentase' => $persen
        ];
    }

    // Rekap Temuan Berdasarkan Komoditas (Batubara, Nikel, Emas, Tembaga, Batu Gamping, Bauksit, dll.)
    $chk_kom = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'komoditas'");
    $col_kom_expr = ($chk_kom && $chk_kom->num_rows > 0) ? "NULLIF(i.komoditas, '')" : "NULL";

    $sql_komoditas = "SELECT 
                        CASE 
                            WHEN i.tipe_komoditas = 'batubara' THEN 'Batubara'
                            WHEN $col_kom_expr IS NOT NULL THEN $col_kom_expr
                            WHEN pm.komoditas IS NOT NULL AND pm.komoditas != '' THEN pm.komoditas
                            ELSE 'Mineral'
                        END AS nama_komoditas,
                        COUNT(CASE WHEN d.ada_temuan = 1 THEN 1 END) as jumlah_temuan
                      FROM binwas_temuan_detail d
                      JOIN binwas_inspeksi i ON d.id_inspeksi = i.id
                      LEFT JOIN perusahaan_mineral pm ON i.id_perusahaan = pm.id
                      WHERE d.ada_temuan = 1 AND $where_sql
                      GROUP BY nama_komoditas
                      HAVING jumlah_temuan > 0
                      ORDER BY jumlah_temuan DESC";
    $res_kom = dbQuery($sql_komoditas);
    $rekap_komoditas = [];
    $total_kom_temuan = 0;
    $raw_kom = [];
    if ($res_kom) {
        while ($rk = $res_kom->fetch_assoc()) {
            $jml = (int)$rk['jumlah_temuan'];
            $total_kom_temuan += $jml;
            $raw_kom[] = [
                'nama_komoditas' => trim($rk['nama_komoditas']),
                'jumlah_temuan' => $jml
            ];
        }
    }
    foreach ($raw_kom as $item) {
        $persen = $total_kom_temuan > 0 ? round(($item['jumlah_temuan'] * 100.0) / $total_kom_temuan, 1) : 0.0;
        $rekap_komoditas[] = [
            'nama_komoditas' => $item['nama_komoditas'],
            'jumlah_temuan' => $item['jumlah_temuan'],
            'persentase' => $persen
        ];
    }
    

    // Top 5 Temuan Terbanyak di Lapangan
    $sql_top = "SELECT 
                    it.id,
                    it.deskripsi_temuan,
                    it.objek_konservasi,
                    kat.nama_kategori,
                    COUNT(CASE WHEN i.id IS NOT NULL AND d.ada_temuan = 1 THEN 1 END) as total_pelanggaran
                FROM binwas_item_temuan it
                JOIN binwas_kategori_temuan kat ON it.id_kategori = kat.id
                LEFT JOIN binwas_temuan_detail d ON it.id = d.id_item_temuan
                LEFT JOIN binwas_inspeksi i ON d.id_inspeksi = i.id AND $where_sql
                GROUP BY it.id, it.deskripsi_temuan, it.objek_konservasi, kat.nama_kategori
                HAVING total_pelanggaran > 0
                ORDER BY total_pelanggaran DESC
                LIMIT 5";

    $res_top = dbQuery($sql_top);
    $top_temuan = [];
    if ($res_top) {
        while ($r = $res_top->fetch_assoc()) {
            $top_temuan[] = [
                'id' => (int)$r['id'],
                'deskripsi_temuan' => trim($r['deskripsi_temuan']),
                'objek_konservasi' => trim($r['objek_konservasi']),
                'nama_kategori' => trim($r['nama_kategori']),
                'total_pelanggaran' => (int)$r['total_pelanggaran']
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'summary' => [
                'total_inspeksi' => $total_inspeksi,
                'total_perusahaan' => $total_perusahaan,
                'total_temuan' => $total_temuan,
                'rata_rata_temuan' => $rata_rata_temuan
            ],
            'rekap_kategori' => $rekap_kategori,
            'rekap_objek_konservasi' => $rekap_objek,
            'rekap_komoditas' => $rekap_komoditas,
            'top_temuan' => $top_temuan
        ]
    ]);
}

/**
 * 8. Matriks Tabel Silang: Perusahaan vs Butir Temuan (Persis Spreadsheet Excel)
 */
function handleGetMatrix() {
    $tipe = dbEscape($_GET['tipe'] ?? '');
    $tahun = dbEscape($_GET['tahun'] ?? '');
    $triwulan = dbEscape($_GET['triwulan'] ?? '');
    $provinsi = dbEscape($_GET['provinsi'] ?? $_GET['nama_provinsi'] ?? '');
    $asal_input = dbEscape($_GET['asal_input'] ?? '');
    $limit = max(10, min(100, (int)($_GET['limit'] ?? 40)));

    $where = ["1=1"];
    if (!empty($tipe) && $tipe !== 'semua') {
        $where[] = "tipe_komoditas = '$tipe'";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $where[] = "triwulan = '$triwulan'";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "nama_provinsi LIKE '%$provinsi%'";
    }
    $chk_col = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
    $has_col = ($chk_col && $chk_col->num_rows > 0);
    if ($has_col && !empty($asal_input) && $asal_input !== 'semua') {
        $where[] = "asal_input = '$asal_input'";
    }
    $where_sql = implode(' AND ', $where);

    // Ambil Kolom (Perusahaan yang diinspeksi)
    $sql_companies = "SELECT id, nama_perusahaan, tipe_komoditas, total_temuan, tanggal_inspeksi 
                      FROM binwas_inspeksi 
                      WHERE $where_sql 
                      ORDER BY id ASC 
                      LIMIT $limit";
    $res_comp = dbQuery($sql_companies);
    $columns = [];
    $inspeksi_ids = [];

    if ($res_comp) {
        while ($r = $res_comp->fetch_assoc()) {
            $inspeksi_ids[] = (int)$r['id'];
            $columns[] = [
                'id_inspeksi' => (int)$r['id'],
                'nama_perusahaan' => trim($r['nama_perusahaan']),
                'tipe_komoditas' => $r['tipe_komoditas'],
                'total_temuan' => (int)$r['total_temuan'],
                'tanggal_inspeksi' => $r['tanggal_inspeksi']
            ];
        }
    }

    $total_perusahaan = count($columns);

    // Ambil Data Nilai (1 / 0) untuk tiap sel
    $matrix_values = [];
    if (!empty($inspeksi_ids)) {
        $ids_str = implode(',', $inspeksi_ids);
        $sql_vals = "SELECT id_inspeksi, id_item_temuan, ada_temuan 
                     FROM binwas_temuan_detail 
                     WHERE id_inspeksi IN ($ids_str)";
        $res_vals = dbQuery($sql_vals);
        if ($res_vals) {
            while ($v = $res_vals->fetch_assoc()) {
                $matrix_values[(int)$v['id_item_temuan']][(int)$v['id_inspeksi']] = (int)$v['ada_temuan'];
            }
        }
    }

    // Ambil Baris (Master Butir Temuan per Kategori)
    $sql_rows = "SELECT it.id, it.id_kategori, it.deskripsi_temuan, it.objek_konservasi, kat.nama_kategori 
                 FROM binwas_item_temuan it
                 JOIN binwas_kategori_temuan kat ON it.id_kategori = kat.id
                 WHERE it.is_active = 1
                 ORDER BY kat.urutan ASC, it.id ASC";
    $res_rows = dbQuery($sql_rows);
    $rows = [];

    if ($res_rows) {
        while ($rw = $res_rows->fetch_assoc()) {
            $item_id = (int)$rw['id'];
            $scores = [];
            $count_temuan = 0;

            foreach ($columns as $c) {
                $insp_id = $c['id_inspeksi'];
                $val = $matrix_values[$item_id][$insp_id] ?? 0;
                $scores[(string)$insp_id] = $val;
                if ($val === 1) {
                    $count_temuan++;
                }
            }

            $persen = $total_perusahaan > 0 ? round(($count_temuan * 100.0) / $total_perusahaan, 2) : 0.0;

            $rows[] = [
                'id_item' => $item_id,
                'id_kategori' => (int)$rw['id_kategori'],
                'nama_kategori' => trim($rw['nama_kategori']),
                'deskripsi_temuan' => trim($rw['deskripsi_temuan']),
                'objek_konservasi' => trim($rw['objek_konservasi']),
                'scores' => $scores,
                'jumlah' => $count_temuan,
                'persentase' => $persen
            ];
        }
    }

    // Agregasi Subtotal per Kategori & Grand Total
    $rekap_kategori_map = [];
    $company_grand_totals = [];
    foreach ($columns as $c) {
        $company_grand_totals[(string)$c['id_inspeksi']] = 0;
    }
    $grand_total = 0;

    foreach ($rows as $rw) {
        $kat_id = $rw['id_kategori'];
        $kat_nama = $rw['nama_kategori'];
        if (!isset($rekap_kategori_map[$kat_id])) {
            $initial_scores = [];
            foreach ($columns as $c) {
                $initial_scores[(string)$c['id_inspeksi']] = 0;
            }
            $rekap_kategori_map[$kat_id] = [
                'id_kategori' => $kat_id,
                'nama_kategori' => $kat_nama,
                'total_temuan' => 0,
                'jumlah_butir' => 0,
                'persentase' => 0.0,
                'scores' => $initial_scores
            ];
        }

        $rekap_kategori_map[$kat_id]['jumlah_butir']++;
        $rekap_kategori_map[$kat_id]['total_temuan'] += $rw['jumlah'];
        $grand_total += $rw['jumlah'];

        foreach ($rw['scores'] as $insp_id_str => $val) {
            if ($val === 1) {
                $rekap_kategori_map[$kat_id]['scores'][$insp_id_str]++;
                if (isset($company_grand_totals[$insp_id_str])) {
                    $company_grand_totals[$insp_id_str]++;
                }
            }
        }
    }

    $rekap_kategori = array_values($rekap_kategori_map);
    foreach ($rekap_kategori as &$rk) {
        $rk['persentase'] = $grand_total > 0 ? round(($rk['total_temuan'] * 100.0) / $grand_total, 2) : 0.0;
    }
    unset($rk);

    echo json_encode([
        'success' => true,
        'total_perusahaan' => $total_perusahaan,
        'grand_total' => $grand_total,
        'company_totals' => $company_grand_totals,
        'rekap_kategori' => $rekap_kategori,
        'columns' => $columns,
        'rows' => $rows
    ]);
}

/**
 * 9. Upload Foto Dokumentasi Temuan Lapangan
 */
function handleUploadFoto() {
    if (!isset($_FILES['foto'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Berkas foto tidak ditemukan']);
        return;
    }

    $file = $_FILES['foto'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Error upload berkas kode: ' . $file['error']]);
        return;
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'webp'];
    if (!in_array($ext, $allowed)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Format file tidak diizinkan. Gunakan JPG, PNG, atau WebP']);
        return;
    }

    $upload_dir = __DIR__ . '/uploads/binwas/';
    if (!is_dir($upload_dir)) {
        mkdir($upload_dir, 0755, true);
    }

    $new_filename = 'binwas_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
    $target_path = $upload_dir . $new_filename;

    if (move_uploaded_file($file['tmp_name'], $target_path)) {
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
        $host = $_SERVER['HTTP_HOST'];
        $public_url = $protocol . $host . '/v2/uploads/binwas/' . $new_filename;

        echo json_encode([
            'success' => true,
            'message' => 'Foto berhasil diupload',
            'file_name' => $new_filename,
            'url' => $public_url
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal memindahkan berkas upload']);
    }
}

/**
 * 9b. Upload Berkas Surat Dasar Tindakan (Mendukung PDF, DOC, Gambar)
 */
function handleUploadSurat() {
    $file_key = isset($_FILES['surat']) ? 'surat' : (isset($_FILES['file']) ? 'file' : null);
    if (!$file_key || !isset($_FILES[$file_key])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Berkas surat tidak ditemukan']);
        return;
    }

    $file = $_FILES[$file_key];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Error upload berkas kode: ' . $file['error']]);
        return;
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'];
    if (!in_array($ext, $allowed)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Format file tidak diizinkan. Gunakan PDF, DOC/DOCX, atau Gambar (JPG/PNG)']);
        return;
    }

    $upload_dir = __DIR__ . '/uploads/binwas/';
    if (!is_dir($upload_dir)) {
        mkdir($upload_dir, 0755, true);
    }

    $clean_original = preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', pathinfo($file['name'], PATHINFO_FILENAME));
    $new_filename = 'surat_binwas_' . date('Ymd_His') . '_' . substr($clean_original, 0, 30) . '.' . $ext;
    $target_path = $upload_dir . $new_filename;

    if (move_uploaded_file($file['tmp_name'], $target_path)) {
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
        $host = $_SERVER['HTTP_HOST'];
        $public_url = $protocol . $host . '/v2/uploads/binwas/' . $new_filename;

        echo json_encode([
            'success' => true,
            'message' => 'Berkas surat berhasil diupload',
            'file_name' => $new_filename,
            'original_name' => $file['name'],
            'url' => $public_url
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal memindahkan berkas surat']);
    }
}

/**
 * 9c. Update Langkah Temuan / Tindak Lanjut & Dokumen Surat Dasar
 */
function handleUpdateTindakLanjut() {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $id_inspeksi = (int)($input['id_inspeksi'] ?? 0);
    $id_temuan_detail = (int)($input['id_temuan_detail'] ?? 0);
    $status_tindakan = dbEscape($input['status_tindakan'] ?? 'Belum');
    $langkah_temuan = dbEscape($input['langkah_temuan'] ?? '');
    $nomor_surat = dbEscape($input['nomor_surat'] ?? '');
    $tanggal_surat = dbEscape($input['tanggal_surat'] ?? date('Y-m-d'));
    $file_surat = dbEscape($input['file_surat'] ?? '');
    $petugas = dbEscape($input['petugas_tindak_lanjut'] ?? $input['petugas'] ?? '');
    $chk_insp = dbQuery("SELECT petugas FROM binwas_inspeksi WHERE id = $id_inspeksi LIMIT 1");
    if ($chk_insp && $row_insp = $chk_insp->fetch_assoc()) {
        if (!empty(trim($row_insp['petugas'] ?? ''))) {
            $petugas = dbEscape(trim($row_insp['petugas']));
        }
    }
    if (empty($petugas)) {
        $petugas = 'Petugas Binwas';
    }

    if ($id_inspeksi <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID Inspeksi tidak valid']);
        return;
    }

    $valid_status = ['Belum', 'Sedang Dilakukan', 'Sudah'];
    if (!in_array($status_tindakan, $valid_status)) {
        $status_tindakan = 'Belum';
    }

    // 1. Cek & simpan ke tabel binwas_tindak_lanjut (jika tabel sudah dibuat user)
    $chk_tl = dbQuery("SHOW TABLES LIKE 'binwas_tindak_lanjut'");
    if ($chk_tl && $chk_tl->num_rows > 0) {
        $sql_cek = "SELECT id FROM binwas_tindak_lanjut 
                    WHERE id_inspeksi = $id_inspeksi AND id_temuan_detail = $id_temuan_detail 
                    LIMIT 1";
        $res_cek = dbQuery($sql_cek);

        if ($res_cek && $res_cek->num_rows > 0) {
            $row_cek = $res_cek->fetch_assoc();
            $tl_id = (int)$row_cek['id'];
            $file_clause = !empty($file_surat) ? ", file_surat = '$file_surat'" : "";
            $sql_upd = "UPDATE binwas_tindak_lanjut 
                        SET status_tindakan = '$status_tindakan',
                            langkah_temuan = '$langkah_temuan',
                            nomor_surat = '$nomor_surat',
                            tanggal_surat = '$tanggal_surat',
                            petugas_tindak_lanjut = '$petugas'
                            $file_clause
                        WHERE id = $tl_id";
            dbQuery($sql_upd);
        } else {
            $sql_ins = "INSERT INTO binwas_tindak_lanjut 
                        (id_inspeksi, id_temuan_detail, status_tindakan, langkah_temuan, nomor_surat, tanggal_surat, file_surat, petugas_tindak_lanjut)
                        VALUES 
                        ($id_inspeksi, $id_temuan_detail, '$status_tindakan', '$langkah_temuan', '$nomor_surat', '$tanggal_surat', '$file_surat', '$petugas')";
            dbQuery($sql_ins);
        }
    }

    // 2. Juga simpan/update ke binwas_temuan_detail jika kolom status_tindakan ditambahkan langsung
    $chk_col = dbQuery("SHOW COLUMNS FROM binwas_temuan_detail LIKE 'status_tindakan'");
    if ($chk_col && $chk_col->num_rows > 0 && $id_temuan_detail > 0) {
        $file_clause = !empty($file_surat) ? ", file_surat = '$file_surat'" : "";
        $sql_det_upd = "UPDATE binwas_temuan_detail 
                        SET status_tindakan = '$status_tindakan',
                            langkah_temuan = '$langkah_temuan',
                            nomor_surat = '$nomor_surat'
                            $file_clause
                        WHERE id = $id_temuan_detail";
        dbQuery($sql_det_upd);
    }

    echo json_encode([
        'success' => true,
        'message' => 'Langkah temuan dan status tindakan berhasil diperbarui',
        'status_tindakan' => $status_tindakan,
        'langkah_temuan' => $langkah_temuan,
        'file_surat' => $file_surat,
        'nomor_surat' => $nomor_surat
    ]);
}

/**
 * 10. Seed 5 Data Acak Inspeksi Binwas untuk Simulasi & Tampilan Visual
 */
function handleSeedDummy() {
    // 1. Ambil seluruh item master temuan yang aktif
    $sql_items = "SELECT id, id_kategori, deskripsi_temuan, objek_konservasi FROM binwas_item_temuan WHERE is_active = 1 ORDER BY id ASC";
    $res_items = dbQuery($sql_items);
    $master_items = [];
    if ($res_items) {
        while ($it = $res_items->fetch_assoc()) {
            $master_items[] = [
                'id' => (int)$it['id'],
                'id_kategori' => (int)$it['id_kategori'],
                'deskripsi' => trim($it['deskripsi_temuan']),
                'objek' => trim($it['objek_konservasi'])
            ];
        }
    }

    if (empty($master_items)) {
        echo json_encode(['success' => false, 'message' => 'Master item temuan belum tersedia di database']);
        return;
    }

    // 2. Daftar 5 Perusahaan Acak (kombinasi batubara & mineral)
    $dummy_companies = [
        [
            'tipe' => 'batubara',
            'id_perusahaan' => 101,
            'nama_perusahaan' => 'PT Arutmin Indonesia',
            'komoditas' => 'Batubara',
            'nama_provinsi' => 'Kalimantan Selatan',
            'jenis_izin' => 'IUP Operasi Produksi',
            'nama_petugas' => 'Aryanti',
            'tanggal' => '2026-04-18',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Perlu penataan dewatering pada pit barat dan perbaikan tanggul stockpile.',
            'num_temuan' => 4
        ],
        [
            'tipe' => 'mineral',
            'id_perusahaan' => 202,
            'nama_perusahaan' => 'PT Vale Indonesia Tbk',
            'komoditas' => 'Nikel',
            'nama_provinsi' => 'Sulawesi Selatan',
            'jenis_izin' => 'Kontrak Karya (KK)',
            'nama_petugas' => 'Nyke',
            'tanggal' => '2026-04-24',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Pengelolaan bijih kadar rendah sudah mulai berjalan, FS recovery perlu pembaruan.',
            'num_temuan' => 3
        ],
        [
            'tipe' => 'batubara',
            'id_perusahaan' => 103,
            'nama_perusahaan' => 'PT Trubaindo Coal Mining',
            'komoditas' => 'Batubara',
            'nama_provinsi' => 'Kalimantan Timur',
            'jenis_izin' => 'PKP2B',
            'nama_petugas' => 'Alpon',
            'tanggal' => '2026-05-02',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Terdapat batubara ekspose di area pit utara yang belum segera diangkut.',
            'num_temuan' => 3
        ],
        [
            'tipe' => 'mineral',
            'id_perusahaan' => 204,
            'nama_perusahaan' => 'PT Amman Mineral Nusa Tenggara',
            'komoditas' => 'Tembaga',
            'nama_provinsi' => 'Nusa Tenggara Barat',
            'jenis_izin' => 'IUPK Operasi Produksi',
            'nama_petugas' => 'Dody',
            'tanggal' => '2026-05-15',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'SOP konservasi minerba sedang dalam proses pengesahan KTT.',
            'num_temuan' => 2
        ],
        [
            'tipe' => 'mineral',
            'id_perusahaan' => 205,
            'nama_perusahaan' => 'PT Aneka Tambang Tbk (UBP Pongkor)',
            'komoditas' => 'Emas',
            'nama_provinsi' => 'Jawa Barat',
            'jenis_izin' => 'IUP BUMN',
            'nama_petugas' => 'Nyke',
            'tanggal' => '2026-05-25',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Kajian recovery pengolahan emas perlu diperbaiki berkala.',
            'num_temuan' => 3
        ],
        [
            'tipe' => 'mineral',
            'id_perusahaan' => 206,
            'nama_perusahaan' => 'PT Semen Indonesia Tbk',
            'komoditas' => 'Batu Gamping',
            'nama_provinsi' => 'Jawa Timur',
            'jenis_izin' => 'IUP Operasi Produksi',
            'nama_petugas' => 'Putu',
            'tanggal' => '2026-05-28',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Pengendalian losses penambangan batu gamping sudah cukup memadai.',
            'num_temuan' => 2
        ],
        [
            'tipe' => 'batubara',
            'id_perusahaan' => 105,
            'nama_perusahaan' => 'PT Mahakam Sumber Jaya',
            'komoditas' => 'Batubara',
            'nama_provinsi' => 'Kalimantan Timur',
            'jenis_izin' => 'PKP2B',
            'nama_petugas' => 'Rozy',
            'tanggal' => '2026-05-22',
            'triwulan' => 'Triwulan 2',
            'tahun' => 2026,
            'catatan' => 'Tingkatkan pengawasan front loading untuk menekan losses dan potensi dilusi batubara.',
            'num_temuan' => 5
        ],
    ];

    $total_inserted = 0;

    foreach ($dummy_companies as $idx => $comp) {
        $tipe = dbEscape($comp['tipe']);
        $id_per = (int)$comp['id_perusahaan'];
        $nama_per = dbEscape($comp['nama_perusahaan']);
        $prov = dbEscape($comp['nama_provinsi']);
        $izin = dbEscape($comp['jenis_izin']);
        $petugas = dbEscape($comp['nama_petugas']);
        $tgl = dbEscape($comp['tanggal']);
        $tw = dbEscape($comp['triwulan']);
        $thn = (int)$comp['tahun'];
        $catatan = dbEscape($comp['catatan']);
        $target_temuan = $comp['num_temuan'];

        // Acak butir temuan yang bernilai 1
        $shuffled = $master_items;
        shuffle($shuffled);
        $selected_temuan_ids = array_slice(array_column($shuffled, 'id'), 0, $target_temuan);

        // Insert Header
        $col_kom_seed = $has_col_kom ? ", komoditas" : "";
        $val_kom_seed = $has_col_kom ? ", '" . dbEscape($comp['komoditas'] ?? '') . "'" : "";
        $sql_hdr = "INSERT INTO binwas_inspeksi 
                    (tipe_komoditas$col_kom_seed, id_perusahaan, nama_perusahaan, nama_provinsi, jenis_izin, 
                     nama_petugas, tanggal_inspeksi, triwulan, tahun, total_temuan, catatan_umum, status)
                    VALUES 
                    ('$tipe', $id_per, '$nama_per', '$prov', '$izin',
                     '$petugas', '$tgl', '$tw', $thn, $target_temuan, '$catatan', 'Submitted')";
        
        $res_hdr = dbQuery($sql_hdr);
        if ($res_hdr) {
            $inspeksi_id = dbInsertId();
            $total_inserted++;

            // Insert Detail untuk setiap master item
            foreach ($master_items as $item) {
                $id_it = (int)$item['id'];
                $is_temuan = in_array($id_it, $selected_temuan_ids) ? 1 : 0;
                $ket = $is_temuan ? dbEscape('Kondisi lapangan terindikasi: ' . $item['deskripsi']) : '';
                $rek = $is_temuan ? dbEscape('Segera lakukan evaluasi SOP dan perbaikan teknis operasional terkait ' . $item['objek']) : '';

                $col_obj_ins = ($has_col_obj && !empty($objek_kons)) ? ", objek_konservasi" : "";
            $val_obj_ins = ($has_col_obj && !empty($objek_kons)) ? ", '$objek_kons'" : "";
            $sql_det = "INSERT INTO binwas_temuan_detail 
                            (id_inspeksi, id_item_temuan$col_obj_ins, ada_temuan, keterangan_lapangan, rekomendasi, foto_temuan)
                            VALUES 
                            ($inspeksi_id, $id_it, $is_temuan, '$ket', '$rek', '')";
                dbQuery($sql_det);
            }
        }
    }

    echo json_encode([
        'success' => true,
        'message' => '5 data acak inspeksi berhasil ditambahkan!',
        'total_inserted' => $total_inserted
    ]);
}

/**
 * 12. Auto-migration & Seeding Akun Admin Provinsi
 */
function ensureUserProvinsiTableAndSeed() {
    $sql_create = "CREATE TABLE IF NOT EXISTS `binwas_user_provinsi` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(50) NOT NULL,
        `password` VARCHAR(100) NOT NULL,
        `nama_provinsi` VARCHAR(100) NOT NULL,
        `tipe_sektor` ENUM('batubara', 'mineral') NOT NULL,
        `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `unique_user_sektor` (`username`, `tipe_sektor`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
    dbQuery($sql_create);

    $accounts_batubara = [
        ['sumut', 'pass456', 'SUMATERA UTARA'],
        ['sultra', 'pass789', 'SULAWESI TENGGARA'],
        ['aceh', 'pass879', 'ACEH'],
        ['jambi', 'pass990', 'JAMBI'],
        ['kalsel', 'pass654', 'KALIMANTAN SELATAN'],
        ['kalut', 'pass743', 'KALIMANTAN UTARA'],
        ['kalbar', 'pass096', 'KALIMANTAN BARAT'],
        ['kaltim', 'pass663', 'KALIMANTAN TIMUR'],
        ['kalteng', 'pass791', 'KALIMANTAN TENGAH'],
        ['riau', 'pass691', 'RIAU'],
        ['lampung', 'pass889', 'LAMPUNG'],
        ['maluku', 'pass663', 'MALUKU'],
        ['malut', 'pass234', 'MALUKU UTARA'],
        ['papbar', 'pass007', 'PAPUA BARAT'],
        ['sulbar', 'pass223', 'SULAWESI BARAT'],
        ['sumbar', 'pass909', 'SUMATERA BARAT'],
        ['sumsel', 'pass294', 'SUMATERA SELATAN']
    ];

    $accounts_mineral = [
        ['sumut', 'pass456', 'SUMATERA UTARA'],
        ['sultra', 'pass789', 'SULAWESI TENGGARA'],
        ['jatim', 'pass654', 'JAWA TIMUR'],
        ['jateng', 'pass123', 'JAWA TENGAH'],
        ['jabar', 'pass267', 'JAWA BARAT'],
        ['aceh', 'pass879', 'ACEH'],
        ['banten', 'pass890', 'BANTEN'],
        ['gorontalo', 'pass987', 'GORONTALO'],
        ['jambi', 'pass990', 'JAMBI'],
        ['kalsel', 'pass654', 'KALIMANTAN SELATAN'],
        ['kalut', 'pass743', 'KALIMANTAN UTARA'],
        ['kalbar', 'pass096', 'KALIMANTAN BARAT'],
        ['kaltim', 'pass663', 'KALIMANTAN TIMUR'],
        ['kalteng', 'pass791', 'KALIMANTAN TENGAH'],
        ['babel', 'pass799', 'KEPULAUAN BANGKA BELITUNG'],
        ['kepri', 'pass690', 'KEPULAUAN RIAU'],
        ['lampung', 'pass889', 'LAMPUNG'],
        ['maluku', 'pass663', 'MALUKU'],
        ['malut', 'pass234', 'MALUKU UTARA'],
        ['nnb', 'pass754', 'NUSATENGGARA BARAT'],
        ['ntt', 'pass651', 'NUSATENGGARA TIMUR'],
        ['papbar', 'pass007', 'PAPUA BARAT'],
        ['papua', 'pass909', 'PAPUA'],
        ['papbd', 'pass890', 'PAPUA BARAT DAYA'],
        ['papteng', 'pass780', 'PAPUA TENGAH'],
        ['sulbar', 'pass223', 'SULAWESI BARAT'],
        ['sulteng', 'pass324', 'SULAWESI TENGAH'],
        ['sulut', 'pass709', 'SULAWESI UTARA'],
        ['sumbar', 'pass909', 'SUMATERA BARAT'],
        ['yogya', 'pass890', 'YOGYAKARTA'],
        ['sulsel', 'pass294', 'SULAWESI SELATAN']
    ];

    $chk = dbQuery("SELECT COUNT(*) as total FROM binwas_user_provinsi");
    $total = 0;
    if ($chk && $r = $chk->fetch_assoc()) {
        $total = (int)$r['total'];
    }

    if ($total < (count($accounts_batubara) + count($accounts_mineral))) {
        foreach ($accounts_batubara as $acc) {
            $u = dbEscape($acc[0]);
            $p = dbEscape($acc[1]);
            $prov = dbEscape($acc[2]);
            dbQuery("INSERT INTO binwas_user_provinsi (username, password, nama_provinsi, tipe_sektor) 
                     VALUES ('$u', '$p', '$prov', 'batubara') 
                     ON DUPLICATE KEY UPDATE password = VALUES(password), nama_provinsi = VALUES(nama_provinsi)");
        }
        foreach ($accounts_mineral as $acc) {
            $u = dbEscape($acc[0]);
            $p = dbEscape($acc[1]);
            $prov = dbEscape($acc[2]);
            dbQuery("INSERT INTO binwas_user_provinsi (username, password, nama_provinsi, tipe_sektor) 
                     VALUES ('$u', '$p', '$prov', 'mineral') 
                     ON DUPLICATE KEY UPDATE password = VALUES(password), nama_provinsi = VALUES(nama_provinsi)");
        }
    }
}

/**
 * 13. Login Akun Admin Pengawas Provinsi
 */
function handleLoginProvinsi() {
    ensureUserProvinsiTableAndSeed();

    $input = json_decode(file_get_contents('php://input'), true);
    if (!is_array($input)) {
        $input = $_POST;
    }

    $username = strtolower(trim($input['username'] ?? $_GET['username'] ?? ''));
    $password = trim($input['password'] ?? $_GET['password'] ?? '');
    $sektor = strtolower(trim($input['sektor'] ?? $_GET['sektor'] ?? 'batubara'));

    if (empty($username) || empty($password)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Username dan password wajib diisi'
        ]);
        return;
    }

    $u_esc = dbEscape($username);
    $p_esc = dbEscape($password);
    $s_esc = dbEscape($sektor);

    $sql = "SELECT id, username, nama_provinsi, tipe_sektor 
            FROM binwas_user_provinsi 
            WHERE username = '$u_esc' AND password = '$p_esc' AND tipe_sektor = '$s_esc' 
            LIMIT 1";
    $res = dbQuery($sql);

    if ($res && $row = $res->fetch_assoc()) {
        echo json_encode([
            'success' => true,
            'message' => 'Login berhasil',
            'data' => [
                'id' => (int)$row['id'],
                'username' => trim($row['username']),
                'nama_provinsi' => trim($row['nama_provinsi']),
                'tipe_sektor' => trim($row['tipe_sektor'])
            ]
        ]);
    } else {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Username, password, atau pilihan sektor tidak sesuai. Pastikan sektor dan data login benar.'
        ]);
    }
}

/**
 * 14. Endpoint Migrasi & Verifikasi User Provinsi
 */
function handleMigrateUserProvinsi() {
    ensureUserProvinsiTableAndSeed();
    $chk = dbQuery("SELECT COUNT(*) as total FROM binwas_user_provinsi");
    $total = 0;
    if ($chk && $r = $chk->fetch_assoc()) {
        $total = (int)$r['total'];
    }
    echo json_encode([
        'success' => true,
        'message' => 'Migrasi dan sinkronisasi akun admin provinsi selesai',
        'total_accounts' => $total
    ]);
}

/**
 * 15. Auto-migration kolom evaluasi pada binwas_temuan_detail
 */
function ensureEvaluasiColumns() {
    static $done = false;
    if ($done) return;
    $done = true;
    try {
        $chk_stat = dbQuery("SHOW COLUMNS FROM binwas_temuan_detail LIKE 'status_evaluasi'");
        if (!$chk_stat || $chk_stat->num_rows === 0) {
            dbQuery("ALTER TABLE binwas_temuan_detail ADD COLUMN status_evaluasi VARCHAR(50) DEFAULT 'On Progress' AFTER rekomendasi");
        }
        $chk_cat = dbQuery("SHOW COLUMNS FROM binwas_temuan_detail LIKE 'catatan_evaluasi'");
        if (!$chk_cat || $chk_cat->num_rows === 0) {
            dbQuery("ALTER TABLE binwas_temuan_detail ADD COLUMN catatan_evaluasi TEXT NULL AFTER status_evaluasi");
        }
    } catch (Throwable $e) {}
}

/**
 * 16. Daftar Petugas Binwas untuk Filter Aplikasi Minerba Mobile Pusat
 */
function handleGetPetugasList() {
    $sql = "SELECT DISTINCT nama_petugas 
            FROM binwas_inspeksi 
            WHERE nama_petugas IS NOT NULL AND nama_petugas != '' 
            ORDER BY nama_petugas ASC";
    $res = dbQuery($sql);
    $list = [];
    if ($res) {
        while ($r = $res->fetch_assoc()) {
            $name = trim($r['nama_petugas']);
            if (!empty($name) && !in_array($name, $list)) {
                $list[] = $name;
            }
        }
    }
    echo json_encode([
        'success' => true,
        'total' => count($list),
        'data' => $list
    ]);
}

/**
 * 17. Laporan Khusus Evaluasi Pembinaan & Pengawasan (Format Tabel Standar)
 */
function handleGetLaporanKhusus() {
    ensureEvaluasiColumns();

    $tahun = dbEscape($_GET['tahun'] ?? '');
    $triwulan = dbEscape($_GET['triwulan'] ?? '');
    $nama_petugas = dbEscape($_GET['nama_petugas'] ?? '');
    $provinsi = dbEscape($_GET['provinsi'] ?? $_GET['nama_provinsi'] ?? '');
    $asal_input = dbEscape($_GET['asal_input'] ?? '');
    $id_perusahaan = (int)($_GET['id_perusahaan'] ?? 0);
    $id_inspeksi = (int)($_GET['id_inspeksi'] ?? 0);

    $where = ["1=1"];
    if ($id_inspeksi > 0) {
        $where[] = "i.id = $id_inspeksi";
    }
    if (!empty($tahun) && $tahun !== 'semua') {
        $where[] = "i.tahun = '$tahun'";
    }
    if (!empty($triwulan) && $triwulan !== 'semua') {
        $where[] = "i.triwulan = '$triwulan'";
    }
    if (!empty($nama_petugas) && $nama_petugas !== 'semua') {
        $where[] = "i.nama_petugas LIKE '%$nama_petugas%'";
    }
    if (!empty($provinsi) && $provinsi !== 'semua') {
        $where[] = "i.nama_provinsi LIKE '%$provinsi%'";
    }
    if ($id_perusahaan > 0) {
        $where[] = "i.id_perusahaan = $id_perusahaan";
    }

    $chk_col = dbQuery("SHOW COLUMNS FROM binwas_inspeksi LIKE 'asal_input'");
    $has_col = ($chk_col && $chk_col->num_rows > 0);
    if ($has_col && !empty($asal_input) && $asal_input !== 'semua') {
        $where[] = "i.asal_input = '$asal_input'";
    }

    $where_sql = implode(' AND ', $where);

    $sql_insp = "SELECT i.*, 
                        COALESCE(NULLIF(i.komoditas, ''), CASE WHEN i.tipe_komoditas = 'batubara' THEN 'Batubara' ELSE 'Mineral' END) as komoditas_label
                 FROM binwas_inspeksi i
                 WHERE $where_sql
                 ORDER BY i.tahun DESC, i.triwulan DESC, i.id DESC";
    $res_insp = dbQuery($sql_insp);

    $laporan_list = [];
    if ($res_insp) {
        while ($insp = $res_insp->fetch_assoc()) {
            $insp_id = (int)$insp['id'];

            // Ambil butir temuan (utamanya yang ada_temuan = 1)
            $sql_items = "SELECT d.id as id_detail, 
                                 it.deskripsi_temuan, 
                                 d.keterangan_lapangan, 
                                 d.rekomendasi, 
                                 kat.nama_kategori,
                                 COALESCE(NULLIF(d.objek_konservasi, ''), it.objek_konservasi, kat.nama_kategori) as objek_konservasi,
                                 COALESCE(NULLIF(d.status_evaluasi, ''), 'On Progress') as status,
                                 COALESCE(d.catatan_evaluasi, '') as catatan_evaluasi,
                                 d.foto_temuan
                          FROM binwas_temuan_detail d
                          JOIN binwas_item_temuan it ON d.id_item_temuan = it.id
                          JOIN binwas_kategori_temuan kat ON it.id_kategori = kat.id
                          WHERE d.id_inspeksi = $insp_id AND d.ada_temuan = 1
                          ORDER BY kat.urutan ASC, it.id ASC";
            $res_items = dbQuery($sql_items);
            $items = [];
            if ($res_items) {
                while ($it = $res_items->fetch_assoc()) {
                    $deskripsi_final = !empty(trim($it['keterangan_lapangan'])) ? trim($it['keterangan_lapangan']) : trim($it['deskripsi_temuan']);
                    $rekomendasi_final = !empty(trim($it['rekomendasi'])) ? trim($it['rekomendasi']) : '-';
                    $items[] = [
                        'id_detail' => (int)$it['id_detail'],
                        'temuan' => $deskripsi_final,
                        'rekomendasi' => $rekomendasi_final,
                        'kategori' => trim($it['nama_kategori']),
                        'objek_konservasi' => trim($it['objek_konservasi']),
                        'objek_kategori' => trim($it['nama_kategori']) . ' / ' . trim($it['objek_konservasi']),
                        'status' => trim($it['status']),
                        'catatan_evaluasi' => trim($it['catatan_evaluasi']),
                        'foto_temuan' => trim($it['foto_temuan'] ?? '')
                    ];
                }
            }

            $laporan_list[] = [
                'id_inspeksi' => $insp_id,
                'nama_petugas' => trim($insp['nama_petugas']),
                'perusahaan' => trim($insp['nama_perusahaan']),
                'id_perusahaan' => (int)$insp['id_perusahaan'],
                'komoditas' => trim($insp['komoditas_label']),
                'tanggal_binwas' => $insp['tanggal_inspeksi'],
                'triwulan' => $insp['triwulan'],
                'tahun' => (int)$insp['tahun'],
                'nama_provinsi' => trim($insp['nama_provinsi'] ?? '-'),
                'total_temuan' => count($items),
                'items' => $items
            ];
        }
    }

    echo json_encode([
        'success' => true,
        'total' => count($laporan_list),
        'data' => $laporan_list
    ]);
}

/**
 * 18. Simpan / Perbarui Catatan Evaluasi & Status Temuan
 */
function handleUpdateEvaluasi() {
    ensureEvaluasiColumns();

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $id_detail = (int)($input['id_detail'] ?? $input['id_temuan_detail'] ?? 0);
    $status = dbEscape($input['status'] ?? 'On Progress');
    $catatan = dbEscape($input['catatan_evaluasi'] ?? '');

    $allowed_status = ['Memadai', 'Belum Memadai', 'On Progress'];
    if (!in_array($status, $allowed_status)) {
        $status = 'On Progress';
    }

    if ($id_detail <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID detail temuan tidak valid']);
        return;
    }

    $sql = "UPDATE binwas_temuan_detail 
            SET status_evaluasi = '$status', catatan_evaluasi = '$catatan' 
            WHERE id = $id_detail";
    $res = dbQuery($sql);

    if ($res) {
        echo json_encode([
            'success' => true,
            'message' => 'Status & catatan evaluasi berhasil disimpan',
            'id_detail' => $id_detail,
            'status' => $status,
            'catatan_evaluasi' => $catatan
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal memperbarui catatan evaluasi']);
    }
}
