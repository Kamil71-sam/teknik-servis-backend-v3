const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: 1. KAPI (LİSTELEME - FİYAT VE MÜŞTERİ/FİRMA BAĞLANTISI GÜÇLENDİRİLDİ) ---
router.get("/all", async (req, res) => {
  try {
    const query = `
      SELECT 
        v.*, 
        s.offer_price, 
        COALESCE(c.name, f.firma_adi, 'İsimsiz') as musteri,
        COALESCE(c.name, f.firma_adi, 'İsimsiz') as musteri_adi
      FROM servis_detay v
      LEFT JOIN services s ON v.id = s.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN firms f ON s.firm_id = f.id
      WHERE v.durum NOT IN ('Pasif', 'PASIF / ARSIV', 'Teslim Edildi', 'İptal Edildi', 'İptal')
      ORDER BY v.id DESC
    `;
    const result = await db.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error("Liste Çekme Hatası:", err.message);
    res.status(500).json({ error: "SQL hatası: " + err.message });
  }
});



// --- MÜDÜR: 2. KAPI (KAYIT EKLEME - JAVASCRIPT MATEMATİĞİ VE KARAKUTU) ---
router.post("/", async (req, res) => {
  const { device_id, issue_text, atanan_usta, musteri_notu, customer_id, firm_id } = req.body; 
  
  try {
    const today = new Date();
    const yy = String(today.getFullYear()).slice(-2);
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const prefix = `${yy}${mm}${dd}`;

    // Matematiği kaldırdık, sadece en büyük sayıyı düz metin olarak getir diyoruz.
    const seqQuery = `
        SELECT MAX(servis_no) as max_no
        FROM (
            SELECT servis_no FROM appointments WHERE servis_no LIKE $1
            UNION ALL
            SELECT servis_no FROM services WHERE servis_no LIKE $1
        ) as combined
    `;
    const seqResult = await db.query(seqQuery, [`${prefix}%`]);
    
    // Matematiği Javascript ile biz yapıyoruz!
    let nextSeqNum = 1;
    if (seqResult.rows.length > 0 && seqResult.rows[0].max_no) {
        const maxStr = seqResult.rows[0].max_no; // Örn: "26031835"
        const seqPart = maxStr.substring(6);     // Sadece son rakamları al "35"
        nextSeqNum = parseInt(seqPart, 10) + 1;  // Üzerine 1 ekle
    }
    
    const nextSeq = String(nextSeqNum).padStart(2, '0');
    const servisNo = `${prefix}${nextSeq}`;

    // İŞTE BİZİM KARAKUTUMUZ! BİZE HER ŞEYİ İTİRAF EDECEK!
    console.log(`🚨 KARAKUTU [SERVİS]: DB'nin Gördüğü Max No: ${seqResult.rows[0].max_no} ---> Sana Ürettiği: ${servisNo}`);

    const result = await db.query(
      `INSERT INTO services (device_id, issue_text, atanan_usta, musteri_notu, status, servis_no, customer_id, firm_id) 
       VALUES ($1, $2, $3, $4, 'Yeni Kayıt', $5, $6, $7) 
       RETURNING id, servis_no`,
      [device_id, issue_text, atanan_usta, musteri_notu || '', servisNo, customer_id, firm_id]
    );

    res.json({ message: "Servis kaydı oluşturuldu", id: result.rows[0].id, servis_no: result.rows[0].servis_no });
  } catch (err) {
    console.error("Kayıt Ekleme Hatası:", err.message);
    res.status(500).json({ error: err.message });
  }
});











/*

// --- MÜDÜR: 2. KAPI (KAYIT EKLEME - ORTAK NUMARATÖR) ---
router.post("/", async (req, res) => {
  // MÜDÜR: İŞTE ALARM BURADA! KAYDETTİĞİNDE SİYAH EKRANA DÜŞMEK ZORUNDA!
  console.log("🚨 MÜDÜR DİKKAT: SERVİS YENİ KOD ÇALIŞTI!");

  const { device_id, issue_text, atanan_usta, musteri_notu, customer_id, firm_id } = req.body; 
  
  try {
    const today = new Date();
    const yy = String(today.getFullYear()).slice(-2);
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const prefix = `${yy}${mm}${dd}`;

    const seqQuery = `
        SELECT COALESCE(MAX(CAST(SUBSTRING(servis_no FROM 7) AS INTEGER)), 0) + 1 as next_seq
        FROM (
            SELECT servis_no FROM appointments WHERE servis_no LIKE $1
            UNION ALL
            SELECT servis_no FROM services WHERE servis_no LIKE $1
        ) as combined
    `;
    const seqResult = await db.query(seqQuery, [`${prefix}%`]);
    const nextSeq = String(seqResult.rows[0].next_seq).padStart(2, '0');
    const servisNo = `${prefix}${nextSeq}`;

    const result = await db.query(
      `INSERT INTO services (device_id, issue_text, atanan_usta, musteri_notu, status, servis_no, customer_id, firm_id) 
       VALUES ($1, $2, $3, $4, 'Yeni Kayıt', $5, $6, $7) 
       RETURNING id, servis_no`,
      [device_id, issue_text, atanan_usta, musteri_notu || '', servisNo, customer_id, firm_id]
    );

    res.json({ message: "Servis kaydı oluşturuldu", id: result.rows[0].id, servis_no: result.rows[0].servis_no });
  } catch (err) {
    console.error("Kayıt Ekleme Hatası:", err.message);
    res.status(500).json({ error: err.message });
  }
});



*/











// --- MÜDÜR: 3. KAPI (DETAY - MÜŞTERİ BİLGİSİ EKLENDİ) ---
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (isNaN(id)) return res.status(400).json({ error: "Geçersiz ID" });

  try {
    const query = `
      SELECT v.*, s.offer_price, s.customer_id 
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

// --- DİĞER KAPILAR (4, 5, 6) AYNI KALDI ---
router.put("/:id/status", async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    const result = await db.query("UPDATE services SET status = $1 WHERE id = $2 RETURNING *", [status, id]);
    res.json({ message: "Güncellendi", service: result.rows[0] });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    await db.query("UPDATE services SET status = 'Pasif' WHERE id = $1", [id]);
    res.json({ success: true, message: "Kayıt arşivlendi." });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { issue_text, status, atanan_usta, offer_price, musteri_notu } = req.body;
  try {
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
    const result = await db.query(query, [issue_text || null, status || null, atanan_usta || null, offer_price || null, musteri_notu || null, id]);
    res.json({ success: true, message: "Güncellendi!", data: result.rows[0] });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

module.exports = router;