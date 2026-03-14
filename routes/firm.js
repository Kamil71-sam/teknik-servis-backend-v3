const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

// MÜDÜR: Buradaki bilgiler senin pgAdmin ayarlarınla birebir aynı olmalı
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'teknik_servis', 
  password: '123456', // Burayı mutlaka kendi şifrenle değiştir
  port: 5432,
});

// YENİ FİRMA KAYIT (POST)
router.post('/add', async (req, res) => {
  const { firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres } = req.body;

  if (!firma_adi) {
    return res.status(400).json({ success: false, error: "Firma adı / Ünvanı zorunludur müdürüm!" });
  }

  try {
    // Tablo adını da 'firms' değil 'firm' yapmış olabiliriz db_kurulum'da, 
    // ama genelde tablolar çoğul olur. Eğer tablona 'firms' dediysen burası kalsın.
    const query = `
      INSERT INTO firms (firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres)
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *`;
    
    const values = [firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres];
    const result = await pool.query(query, values);

    res.status(201).json({ 
      success: true, 
      message: "Firma kaydı dükkan defterine mühürlendi!", 
      data: result.rows[0] 
    });
  } catch (err) {
    console.error("Firma kayıt hatası:", err.message);
    res.status(500).json({ success: false, error: "Sunucu hatası: " + err.message });
  }
});

// --- MÜDÜR: TÜM FİRMALARI ÇEKME (GET) ---
router.get('/all', async (req, res) => {
  try {
    // Dikkat: Tablo adın 'firms' ise kalsın, 'firm' ise düzelt
    const result = await pool.query('SELECT * FROM firms ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    console.error("Firma çekme hatası:", err.message);
    res.status(500).json({ error: "Veriler dükkandan gelmiyor: " + err.message });
  }
});

module.exports = router;