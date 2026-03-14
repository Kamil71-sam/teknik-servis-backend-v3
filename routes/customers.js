const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜŞTERİ EKLEME (POST) ---
router.post("/", async (req, res) => {
  const { name, phone, fax, email, address } = req.body;
  try {
    const result = await db.query(
      "INSERT INTO customers (name, phone, fax, email, address) VALUES ($1, $2, $3, $4, $5) RETURNING id",
      [name, phone, fax, email, address]
    );
    res.json({ success: true, message: "Müşteri başarıyla oluşturuldu.", id: result.rows[0].id });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- MÜŞTERİ LİSTELEME (GET) ---
router.get("/", async (req, res) => {
  try {
    const result = await db.query("SELECT * FROM customers ORDER BY id ASC");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- MÜŞTERİ SİLME (DELETE) ---
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  
  try {
    // 1. ADIM: Müşteriye bağlı cihaz var mı?
    const checkDevice = await db.query(
      "SELECT id FROM devices WHERE customer_id = $1 LIMIT 1", 
      [id]
    );

    if (checkDevice.rows.length > 0) {
      return res.status(400).json({ 
        success: false, 
        message: "Müşteriye ait kayıtlı cihazlar bulunmaktadır. Güvenlik nedeniyle önce bu cihazları silmeniz veya başka müşteriye aktarmanız gerekmektedir." 
      });
    }

    // 2. ADIM: Cihaz yoksa doğrudan müşteriyi sil
    const deleteResult = await db.query("DELETE FROM customers WHERE id = $1", [id]);
    
    if (deleteResult.rowCount > 0) {
      res.json({ success: true, message: "Müşteri kaydı sistemden başarıyla kaldırıldı." });
    } else {
      res.status(404).json({ success: false, message: "Silinmek istenen müşteri kaydı bulunamadı." });
    }

  } catch (err) {
    console.error("SİLME HATASI:", err.message);
    res.status(500).json({ success: false, error: "Veritabanı işlemi sırasında teknik bir hata oluştu." });
  }
});

// --- İŞTE EKSİK OLAN KISIM: MÜŞTERİ GÜNCELLEME (PUT) ---
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { name, phone, fax, email, address } = req.body;
  
  try {
    const result = await db.query(
      "UPDATE customers SET name = $1, phone = $2, fax = $3, email = $4, address = $5 WHERE id = $6 RETURNING *",
      [name, phone, fax, email, address, id]
    );

    if (result.rowCount > 0) {
      res.json({ success: true, message: "Müşteri bilgileri başarıyla güncellendi." });
    } else {
      res.status(404).json({ success: false, message: "Güncellenecek müşteri bulunamadı." });
    }
  } catch (err) {
    console.error("GÜNCELLEME HATASI:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;