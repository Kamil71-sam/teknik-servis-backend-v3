const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: 1. KAPI (LİSTELEME - FİYAT ZIMBALANDI) ---
router.get("/all", async (req, res) => {
  try {
    const query = `
      SELECT v.*, s.offer_price 
      FROM servis_detay v
      LEFT JOIN services s ON v.id = s.id
      WHERE v.durum != 'Pasif' AND v.durum != 'PASIF / ARSIV' 
      ORDER BY v.id DESC
    `;
    const result = await db.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error("Liste Çekme Hatası:", err.message);
    res.status(500).json({ error: "SQL hatası: " + err.message });
  }
});

// --- MÜDÜR: 2. KAPI (KAYIT EKLEME - NOT BORUSU BAĞLANDI) ---
router.post("/", async (req, res) => {
  // MÜDÜR: musteri_notu'nu da body'den içeri aldık
  const { device_id, issue_text, atanan_usta, musteri_notu } = req.body;
  try {
    const result = await db.query(
      `INSERT INTO services (device_id, issue_text, atanan_usta, musteri_notu, status) 
       VALUES ($1, $2, $3, $4, 'Yeni Kayıt') 
       RETURNING id, servis_no`,
      [device_id, issue_text, atanan_usta, musteri_notu || '']
    );
    res.json({ 
      message: "Servis kaydı oluşturuldu", 
      id: result.rows[0].id,
      servis_no: result.rows[0].servis_no 
    });
  } catch (err) {
    console.error("Kayıt Ekleme Hatası:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// --- MÜDÜR: 3. KAPI (DETAY - FİYAT ZIMBALANDI) ---
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (isNaN(id)) return res.status(400).json({ error: "Geçersiz ID" });

  try {
    const query = `
      SELECT v.*, s.offer_price 
      FROM servis_detay v
      LEFT JOIN services s ON v.id = s.id
      WHERE v.id = $1
    `;
    const service = await db.query(query, [id]);
    const notes = await db.query(
      "SELECT * FROM service_notes WHERE service_id = $1 ORDER BY id ASC", 
      [id]
    );
    res.json({ service: service.rows[0], notes: notes.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- MÜDÜR: 4. DURUM GÜNCELLEME ---
router.put("/:id/status", async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    const result = await db.query(
      "UPDATE services SET status = $1 WHERE id = $2 RETURNING *", 
      [status, id]
    );
    res.json({ message: "Güncellendi", service: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- MÜDÜR: 5. KAPI (ARŞİVLEME) ---
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query(
      "UPDATE services SET status = 'Pasif' WHERE id = $1", 
      [id]
    );
    if (result.rowCount > 0) {
      res.json({ success: true, message: "Kayıt arşivlendi." });
    } else {
      res.status(404).json({ success: false, error: "Kayıt bulunamadı." });
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- MÜDÜR: 6. KAPI (GÜNCELLEME - USTAYI KORUYAN VERSİYON) ---
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { issue_text, status, atanan_usta, offer_price, musteri_notu } = req.body;

  try {
    // MÜDÜR: COALESCE kullanarak eğer yeni veri gelmemişse eskisini koruyoruz!
    const query = `
      UPDATE services 
      SET issue_text = COALESCE($1, issue_text), 
          status = COALESCE($2, status), 
          atanan_usta = COALESCE($3, atanan_usta), 
          offer_price = COALESCE($4, offer_price), 
          musteri_notu = COALESCE($5, musteri_notu), 
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $6
      RETURNING *`;
    
    const values = [
      issue_text || null, 
      status || null, 
      atanan_usta || null, // Eğer boş gelirse eskisi kalacak
      offer_price || null, 
      musteri_notu || null, 
      id
    ];

    const result = await db.query(query, values);

    if (result.rowCount > 0) {
      res.json({ success: true, message: "Güncellendi, usta hala görevde!", data: result.rows[0] });
    } else {
      res.status(404).json({ success: false, error: "Kayıt bulunamadı." });
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;