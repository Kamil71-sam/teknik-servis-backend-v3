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

// --- YENİ FİRMA KAYIT (POST) ---
router.post('/add', async (req, res) => {
  const { firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres } = req.body;

  if (!firma_adi) {
    return res.status(400).json({ success: false, error: "Firma adı / Ünvanı zorunludur müdürüm!" });
  }

  try {
    const query = `
      INSERT INTO firms (firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres)
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *`;
    
    // Uygulamadan faks gelmezse undefined olup çökmesin diye faks || null yaptık
    const values = [firma_adi, yetkili_ad_soyad, telefon, faks || null, vergi_no, eposta, adres];
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

// --- TÜM FİRMALARI ÇEKME (GET) ---
router.get('/all', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM firms ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    console.error("Firma çekme hatası:", err.message);
    res.status(500).json({ error: "Veriler dükkandan gelmiyor: " + err.message });
  }
});


// --- 1. FİRMA SİLME (Bireyseldeki Gibi Cihaz Kontrolü Eklendi) ---
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    // MÜDÜR: Hata buradaydı! Önce 'devices' tablosuna bakıyoruz.
    const checkDevice = await pool.query("SELECT id FROM devices WHERE firm_id = $1 LIMIT 1", [id]);
    
    if (checkDevice.rows.length > 0) {
      return res.status(400).json({ 
        success: false,
        message: "Bu firmaya ait kayıtlı cihazlar bulunmaktadır. Önce cihazları silmeniz gerekmektedir!" 
      });
    }

    // Cihaz yoksa firmayı sil
    const deleteResult = await pool.query("DELETE FROM firms WHERE id = $1", [id]);
    
    if (deleteResult.rowCount > 0) {
      res.json({ success: true, message: "Firma kaydı başarıyla silindi." });
    } else {
      res.status(404).json({ success: false, message: "Silinecek firma bulunamadı." });
    }

  } catch (err) {
    console.error("Firma silme hatası:", err.message);
    res.status(500).json({ success: false, error: "Silme sırasında hata oluştu: " + err.message });
  }
});

// --- 2. FİRMA GÜNCELLEME (Düzeltme) ---
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres } = req.body;

  if (!firma_adi) {
    return res.status(400).json({ success: false, error: "Firma adı boş bırakılamaz müdürüm!" });
  }

  try {
    const query = `
      UPDATE firms 
      SET firma_adi = $1, yetkili_ad_soyad = $2, telefon = $3, faks = $4, vergi_no = $5, eposta = $6, adres = $7 
      WHERE id = $8 RETURNING *`;
    
    const values = [firma_adi, yetkili_ad_soyad, telefon, faks || null, vergi_no, eposta, adres, id];
    const result = await pool.query(query, values);

    if (result.rowCount > 0) {
      res.json({ success: true, message: "Firma bilgileri jilet gibi güncellendi!" });
    } else {
      res.status(404).json({ success: false, message: "Güncellenecek firma bulunamadı." });
    }

  } catch (err) {
    console.error("Firma güncelleme hatası:", err.message);
    res.status(500).json({ success: false, error: "Güncelleme sırasında hata oluştu: " + err.message });
  }
});

module.exports = router;
