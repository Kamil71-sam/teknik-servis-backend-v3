const express = require("express");
const router = express.Router();
const db = require("../database");

// DASHBOARD VERİSİ
router.post("/dashboard", async (req, res) => {
    const { email } = req.body;
    console.log("📢 Dashboard isteği geldi:", email);
    try {
        const atananRes = await db.query(
            "SELECT COUNT(*) FROM services WHERE TRIM(atanan_usta) = $1", [email]
        );
        
        // MÜDÜR: Dashboard tarafı, marka (brand) tek olarak çekiliyor
        const sonIslerRes = await db.query(
            `SELECT 
                s.id, 
                s.servis_no, 
                s.issue_text as issue, 
                s.status,
                d.cihaz_turu,
                d.brand as marka_model
             FROM services s
             LEFT JOIN devices d ON s.device_id = d.id
             WHERE TRIM(s.atanan_usta) = $1 
             ORDER BY s.id DESC LIMIT 2`, 
            [email]
        );
        res.json({
            success: true,
            data: {
                atanananIslerSayisi: parseInt(atananRes.rows[0].count),
                aktifIslerSayisi: 0,
                parcaBekleyenSayisi: 0,
                randevuSayisi: 0,
                sonIsler: sonIslerRes.rows,
            }
        });
    } catch (err) {
        console.error("❌ DB Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// TÜM İŞLER LİSTESİ
router.post("/tum-isler", async (req, res) => {
    const { email } = req.body;
    console.log("📢 Tüm işler listesi istendi:", email);
    try {
        // MÜDÜR: Hatalı isimler (muster_notu) düzeltildi. Seri No devices'tan alınıyor. Marka tek kaldı.
        const tumIslerRes = await db.query(
            `SELECT 
                s.id, 
                s.servis_no, 
                s.issue_text as issue, 
                s.status,
                s.created_at,
                d.cihaz_turu,
                d.brand as marka_model,
                d.serial_no as seri_no,
                d.muster_notu as musteri_notu
             FROM services s
             LEFT JOIN devices d ON s.device_id = d.id
             WHERE TRIM(s.atanan_usta) = $1 
             ORDER BY s.id DESC`, 
            [email]
        );
        res.json({ success: true, data: tumIslerRes.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- YENİ EKLENEN SÜREÇ TAKİP ROTASI ---
// MÜDÜR: Bu rota hem işi günceller hem de tarihçeye (Log) kayıt atar.
router.post("/servis-guncelle", async (req, res) => {
    const { id, offer_price, expert_note, status, changed_by, old_status } = req.body;
    console.log(`📢 Durum Değişimi: ${id} nolu iş, ${old_status} -> ${status}`);

    try {
        // 1. İşlem: Ana tabloyu (services) güncelle
        // COALESCE kullanarak eğer fiyat veya not gelmezse eski veriyi koruyoruz.
        await db.query(
            `UPDATE services 
             SET offer_price = COALESCE($1, offer_price), 
                 expert_note = COALESCE($2, expert_note), 
                 status = $3, 
                 updated_at = NOW() 
             WHERE id = $4`,
            [offer_price, expert_note, status, id]
        );

        // 2. İşlem: Tarihçe (service_status_history) tablosuna kayıt at
        // Bu sayede "Kim, ne zaman değiştirdi?" sorusunun cevabı saklanır.
        await db.query(
            `INSERT INTO service_status_history (service_id, old_status, new_status, changed_by, note)
             VALUES ($1, $2, $3, $4, $5)`,
            [id, old_status, status, changed_by, expert_note || 'Durum güncellendi']
        );

        res.json({ success: true, message: "Süreç başarıyla güncellendi ve kaydedildi." });
    } catch (err) {
        console.error("❌ Süreç Güncelleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;