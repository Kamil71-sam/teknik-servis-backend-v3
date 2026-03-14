const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: 1. KAPI (LİSTELEME) ---
router.get("/all", async (req, res) => {
  try {
    // MÜDÜR: Senin 'servis_detay' sanal tablonu (View) kullanıyoruz.
    const query = `SELECT * FROM servis_detay ORDER BY id DESC`;
    const result = await db.query(query);

    // MÜDÜR: Mobildeki liste ekranı için verileri olduğu gibi gönderiyoruz.
    res.json(result.rows);
  } catch (err) {
    console.error("Liste Çekme Hatası:", err.message);
    res.status(500).json({ error: "SQL hatası: " + err.message });
  }
});

// --- MÜDÜR: 2. KAPI (KAYIT EKLEME) ---
router.post("/", async (req, res) => {
  const { device_id, issue_text, atanan_usta } = req.body;
  try {
    const result = await db.query(
      `INSERT INTO services (device_id, issue_text, atanan_usta, status) 
       VALUES ($1, $2, $3, 'KabulEdildi') 
       RETURNING id, servis_no`,
      [device_id, issue_text, atanan_usta]
    );
    res.json({ 
      message: "Servis kaydı oluşturuldu", 
      id: result.rows[0].id,
      servis_no: result.rows[0].servis_no 
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- MÜDÜR: 3. KAPI (DETAY - TAMİR EDİLEN BÖLÜM) ---
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  
  if (isNaN(id)) return res.status(400).json({ error: "Geçersiz ID" });

  try {
    // MÜDÜR: View'daki gerçek isimleri (plaka, musteri_adi, eklenen_notlar) 
    // mobildeki kutucukların isimleriyle (servis_no, muster_notu) eşleştirdik.
    const query = `
      SELECT 
        id,
        plaka AS servis_no,
        durum AS status,
        ariza AS issue_text,
        usta AS atanan_usta,
        musteri_adi,
        telefon,
        cihaz_tipi,
        marka_model AS marka,       -- Cihaz yazan yere Marka bilgisini soktuk
        seri_no,
        garanti,
        eklenen_notlar AS muster_notu, -- Müşterinin girdiği not artık burada!
        tarih AS created_at         -- 'Invalid Date' hatasını bitiren hazır format
      FROM servis_detay 
      WHERE id = $1
    `;
    
    const service = await db.query(query, [id]);
    const notes = await db.query(
      "SELECT * FROM service_notes WHERE service_id = $1 ORDER BY id ASC", 
      [id]
    );
    
    res.json({ 
      service: service.rows[0], 
      notes: notes.rows 
    });
  } catch (err) {
    console.error("Detay Çekme Hatası:", err.message);
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

module.exports = router;