const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: 1. KAPI (LİSTELEME) ---
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

// --- MÜDÜR: 2. KAPI (KAYIT EKLEME) ---
router.post("/", async (req, res) => {
  const { device_id, issue_text, atanan_usta, musteri_notu, customer_id, firm_id } = req.body; 
  
  try {
    const today = new Date();
    const yy = String(today.getFullYear()).slice(-2);
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const prefix = `${yy}${mm}${dd}`;

    const seqQuery = `
        SELECT MAX(servis_no) as max_no
        FROM (
            SELECT servis_no FROM appointments WHERE servis_no LIKE $1
            UNION ALL
            SELECT servis_no FROM services WHERE servis_no LIKE $1
        ) as combined
    `;
    const seqResult = await db.query(seqQuery, [`${prefix}%`]);
    
    let nextSeqNum = 1;
    if (seqResult.rows.length > 0 && seqResult.rows[0].max_no) {
        const maxStr = seqResult.rows[0].max_no; 
        const seqPart = maxStr.substring(6);     
        nextSeqNum = parseInt(seqPart, 10) + 1;  
    }
    
    const nextSeq = String(nextSeqNum).padStart(2, '0');
    const servisNo = `${prefix}${nextSeq}`;

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

// --- MÜDÜR: 3. KAPI (DETAY) ---
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

// --- 4. KAPI: DURUM GÜNCELLEME VE OTOMATİK KASA TETİKLEYİCİSİ ---
router.put("/:id/status", async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    // Müdür: Zincirleme işlem (Transaction) başlatıyoruz. Ya hepsi kaydolur, ya hiçbiri.
    await db.query('BEGIN');

    const result = await db.query("UPDATE services SET status = $1 WHERE id = $2 RETURNING *", [status, id]);
    const guncelServis = result.rows[0];

    // 🚨 İŞTE OTOMASYON BURADA BAŞLIYOR 🚨
    if (status === 'Teslim Edildi' && guncelServis.offer_price && parseFloat(guncelServis.offer_price) > 0) {
      // Çifte Tahsilat Koruması: Bu servis nosu ile daha önce para alınmış mı?
      const checkKasa = await db.query("SELECT id FROM kasa_islemleri WHERE servis_no = $1 AND kategori = 'Tamir Geliri'", [guncelServis.servis_no]);
      
      if (checkKasa.rows.length === 0) {
        // Alınmamış! O zaman Kasa'ya otomatik fiş kes!
        const kasaAciklama = `Otomatik Tahsilat: Cihaz müşteriye teslim edildi.`;
        const kasaQuery = `
          INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
          VALUES ('GİRİŞ', 'Tamir Geliri', $1, $2, 'Sistem Otomasyonu', $3, $4)
        `;
        await db.query(kasaQuery, [guncelServis.offer_price, kasaAciklama, guncelServis.id, guncelServis.servis_no]);
        console.log(`✅ [OTOMASYON] ${guncelServis.servis_no} numaralı işin ${guncelServis.offer_price} TL ücreti kasaya aktarıldı!`);
      }
    }

    await db.query('COMMIT');
    res.json({ message: "Güncellendi", service: guncelServis });
  } catch (err) { 
    await db.query('ROLLBACK');
    res.status(500).json({ error: err.message }); 
  }
});

router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    await db.query("UPDATE services SET status = 'Pasif' WHERE id = $1", [id]);
    res.json({ success: true, message: "Kayıt arşivlendi." });
  } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});

// --- 5. KAPI: GENEL GÜNCELLEME VE OTOMATİK KASA TETİKLEYİCİSİ ---
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { issue_text, status, atanan_usta, offer_price, musteri_notu } = req.body;
  try {
    await db.query('BEGIN');

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
    const guncelServis = result.rows[0];


    /*
    // 🚨 OTOMASYON BURADA DA VAR (Eğer durumu buradan güncellerlerse kaçırmayalım) 🚨

    
    if (status === 'Teslim Edildi' && guncelServis.offer_price && parseFloat(guncelServis.offer_price) > 0) {
      const checkKasa = await db.query("SELECT id FROM kasa_islemleri WHERE servis_no = $1 AND kategori = 'Tamir Geliri'", [guncelServis.servis_no]);
      if (checkKasa.rows.length === 0) {
        const kasaAciklama = `Otomatik Tahsilat: Cihaz detaylı ekrandan teslim edildi.`;
        await db.query(
          "INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no) VALUES ('GİRİŞ', 'Tamir Geliri', $1, $2, 'Sistem Otomasyonu', $3, $4)",
          [guncelServis.offer_price, kasaAciklama, guncelServis.id, guncelServis.servis_no]
        );
        console.log(`✅ [OTOMASYON] ${guncelServis.servis_no} numaralı işin ücreti kasaya aktarıldı!`);
      }
    }
    */
    await db.query('COMMIT');
    res.json({ success: true, message: "Güncellendi!", data: guncelServis });
  } catch (err) { 
    await db.query('ROLLBACK');
    res.status(500).json({ success: false, error: err.message }); 

    
  }

});


module.exports = router;