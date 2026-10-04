const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Folder Uploads
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}

// Database Connection Pool
const db = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'db_absensi',
  timezone:'+07:00',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test Database Connection
async function checkDb() {
  try {
    const conn = await db.getConnection();
    console.log('✅ Terhubung ke MySQL (db_absensi)');
    conn.release();
  } catch (err) {
    console.error('❌ Gagal Koneksi DB:', err.message);
  }
}
checkDb();

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'absen-' + uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage });

// ===================================================
// API ENDPOINTS
// ===================================================

// 1. Get List Semua Murid (Untuk Dropdown/Pilihan di Flutter Absen)
app.get('/api/murid', async (req, res) => {
  try {
    const [rows] = await db.execute('SELECT * FROM murid ORDER BY nama ASC');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 2. Submit Absensi Murid (Relasi via murid_id)
app.post('/api/absen', upload.single('foto'), async (req, res) => {
  const { murid_id, lokasi } = req.body;

  if (!murid_id || !lokasi || !req.file) {
    return res.status(400).json({
      success: false,
      message: 'murid_id, lokasi, dan foto wajib diisi!'
    });
  }

  const fotoUrl = `http://localhost:${PORT}/uploads/${req.file.filename}`;

  try {
    // Cek apakah murid_id valid
    const [checkMurid] = await db.execute('SELECT id FROM murid WHERE id = ?', [murid_id]);
    if (checkMurid.length === 0) {
      return res.status(404).json({ success: false, message: 'Data murid tidak ditemukan!' });
    }

    // Insert ke tabel absen
    const query = 'INSERT INTO absen (murid_id, lokasi, foto_url) VALUES (?, ?, ?)';
    const [result] = await db.execute(query, [murid_id, lokasi, fotoUrl]);

    res.status(201).json({
      success: true,
      message: 'Absensi berhasil dikirim!',
      data: {
        id: result.insertId,
        murid_id,
        lokasi,
        fotoUrl
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Gagal menyimpan absensi' });
  }
});

// 3. Login Admin (Tabel Admin)
app.post('/api/admin/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Username & Password wajib diisi' });
  }

  try {
    const query = 'SELECT id, username, nama_admin FROM admin WHERE username = ? AND password = ?';
    const [rows] = await db.execute(query, [username, password]);

    if (rows.length > 0) {
      res.json({
        success: true,
        message: 'Login Berhasil',
        data: rows[0]
      });
    } else {
      res.status(401).json({ success: false, message: 'Username atau Password salah!' });
    }
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 4. Get Rekap Absensi untuk Admin (JOIN Tabel Absen & Murid)
app.get('/api/admin/absensi', async (req, res) => {
  try {
    const query = `
      SELECT 
        a.id AS absen_id,
        m.id AS murid_id,
        m.nis,
        m.nama AS nama_murid,
        m.kelas,
        a.lokasi,
        a.foto_url AS fotoUrl,
        a.waktu_absen AS waktuAbsen
      FROM absen a
      JOIN murid m ON a.murid_id = m.id
      ORDER BY a.waktu_absen DESC
    `;
    const [rows] = await db.execute(query);

    res.json({
      success: true,
      data: rows
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Start Server
app.listen(PORT, () => {
  console.log(`🚀 Server berjalan di http://localhost:${PORT}`);
});