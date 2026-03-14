const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: CİHAZ KAYIT KAPISI (Hatasız Ayar) ---
router.post("/", async (req, res) => {
  const { 
    customer_id, 
    firm_id,
    customer_type, 
    brand, 
    model, 
    serial_no,
    cihaz_turu,       
    garanti_durumu,   
    muster_notu       
  } = req.body;

  try {
    // MÜDÜR: Gelen tipi sağlama alıyoruz, küçük harfe çevirip kontrol ediyoruz.
    const type = customer_type ? customer_type.toLowerCase() : '';
    
    let c_id = null;
    let f_id = null;

    if (type === 'kurumsal') {
      f_id = (firm_id && firm_id > 0) ? firm_id : null;
      c_id = null; // Kurumsalsa müşteri ID kesinlikle boş kalmalı
    } else {
      c_id = (customer_id && customer_id > 0) ? customer_id : null;
      f_id = null; // Bireyselse firma ID kesinlikle boş kalmalı
    }

    // MÜDÜR: Sorguyu senin 'devices' tablonun kolon isimlerine göre (firm_id) sabitliyoruz.
    const result = await db.query(
      `INSERT INTO devices 
       (customer_id, firm_id, brand, model, serial_no, cihaz_turu, garanti_durumu, muster_notu) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
       RETURNING id`,
      [c_id, f_id, brand, model, serial_no, cihaz_turu, garanti_durumu, muster_notu]
    );

    res.json({
      message: "Cihaz başarıyla eklendi",
      id: result.rows[0].id
    });

  } catch (err) {
    console.error("Cihaz Kayıt Hatası:", err.message);
    res.status(500).json({ error: "Cihaz kaydedilemedi: " + err.message });
  }
});

// --- MÜDÜR: CİHAZ LİSTELEME (Ayrım Sabitlendi) ---
router.get("/customer/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { type } = req.query; // Mobilden gelen ?type=kurumsal kısmı

    const checkType = type ? type.toLowerCase() : '';
    let result;

    if (checkType === 'kurumsal') {
      // MÜDÜR: Cihazlar tablosunda firm_id sütununa bakıyoruz
      result = await db.query(
        "SELECT * FROM devices WHERE firm_id = $1 ORDER BY id DESC", 
        [id]
      );
    } else {
      // MÜDÜR: Cihazlar tablosunda customer_id sütununa bakıyoruz
      result = await db.query(
        "SELECT * FROM devices WHERE customer_id = $1 ORDER BY id DESC", 
        [id]
      );
    }
    
    res.json(result.rows);
  } catch (err) {
    console.error("Cihaz Listeleme Hatası:", err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;