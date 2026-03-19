const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: REHBER İÇİN TÜM MÜŞTERİ VE FİRMALARI GETİR (YENİ EKİ) ---
// Not: Bu rota, yeni randevu ekranındaki siyah rehber butonu için çalışır.
router.get("/all", async (req, res) => {
  try {
    // Hem bireysel müşterileri hem de kurumsal firmaları tek listede birleştiriyoruz
    const query = `
      SELECT id, name, phone, 'bireysel' as tip FROM customers
      UNION ALL
      SELECT id, firma_adi as name, telefon as phone, 'firma' as tip FROM firms
      ORDER BY name ASC
    `;
    const result = await db.query(query);
    res.json({ success: true, data: result.rows });
  } catch (err) {
    console.error("REHBER HATASI:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

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
    const result = await db.query("SELECT * FROM customers ORDER BY name ASC");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- MÜDÜR: AKILLI VE KÖKTEN SİLME (DELETE) ---
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  const { force } = req.query; // Mobilden "force=true" şifresi gelirse acımadan sileceğiz.

  try {
    // 1. KONTROL AŞAMASI: Bu müşteriye ait içeride servis kaydı var mı?
    const checkQuery = `
      SELECT s.servis_no 
      FROM services s
      JOIN devices d ON s.device_id = d.id
      WHERE d.customer_id = $1
    `;
    const checkResult = await db.query(checkQuery, [id]);

    // 2. UYARI AŞAMASI: Kayıt varsa ve mobilden "acımadan sil (force)" emri HENÜZ gelmediyse:
    if (checkResult.rowCount > 0 && force !== 'true') {
      const servisNumaralari = checkResult.rows.map(row => row.servis_no).join(', ');
      
      return res.json({ 
        uyariVar: true, 
        message: `Bu müşteriye ait [ ${servisNumaralari} ] numaralı iş kayıtları var.\n\nYine de hem müşteriyi hem de bu işleri SONSUZA KADAR silmek istiyor musunuz?` 
      });
    }

    // MÜDÜR NOTU: İş kaydı yok ama cihazı varsa diye ekstra kontrol (Yine uyaralım)
    const checkDeviceOnly = await db.query("SELECT id FROM devices WHERE customer_id = $1", [id]);
    if (checkDeviceOnly.rowCount > 0 && checkResult.rowCount === 0 && force !== 'true') {
        return res.json({
            uyariVar: true,
            message: `Bu müşterinin üzerine kayıtlı cihaz(lar) var ama hiç işlem görmemiş.\n\nYine de müşteriyi ve cihazlarını SONSUZA KADAR silmek istiyor musunuz?`
        });
    }

    // 3. İNFAZ AŞAMASI: Kayıt yoksa veya mobilden "force=true" emri geldiyse acımıyoruz!
    
    await db.query('BEGIN'); // Veritabanı işlemini başlatıyoruz (biri patlarsa hepsi iptal olsun diye)

    // a) Varsa bu adama ait servis notlarını (service_notes) uçur
    await db.query(`DELETE FROM service_notes WHERE service_id IN (SELECT s.id FROM services s JOIN devices d ON s.device_id = d.id WHERE d.customer_id = $1)`, [id]);
    
    // b) Servis (iş) kayıtlarını uçur
    await db.query(`DELETE FROM services WHERE device_id IN (SELECT id FROM devices WHERE customer_id = $1)`, [id]);
    
    // c) Cihazları uçur
    await db.query(`DELETE FROM devices WHERE customer_id = $1`, [id]);
    
    // d) En son müşterinin kendisini yeryüzünden sil
    const deleteResult = await db.query(`DELETE FROM customers WHERE id = $1`, [id]);

    await db.query('COMMIT'); // İşlemi onayla ve fişi çek

    if (deleteResult.rowCount > 0) {
      res.json({ success: true, uyariVar: false, message: "Müşteri ve tüm geçmişi kökten silindi." });
    } else {
      res.status(404).json({ success: false, message: "Silinmek istenen müşteri kaydı bulunamadı." });
    }

  } catch (err) {
    await db.query('ROLLBACK'); // Hata olursa hiçbir şeyi silme, sistemi geri al
    console.error("SİLME HATASI:", err.message);
    res.status(500).json({ success: false, error: "Silme işlemi sırasında hata oluştu: " + err.message });
  }
});

// --- MÜŞTERİ GÜNCELLEME (PUT) ---
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