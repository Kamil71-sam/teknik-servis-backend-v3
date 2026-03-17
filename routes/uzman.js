const express = require("express");
const router = express.Router();
const db = require("../database");

// --- MÜDÜR: USTA DASHBOARD (ONAY VE PARÇA BEKLEYENLER AYRILDI) ---
router.post("/dashboard", async (req, res) => {
    const { email } = req.body; 
    const ustaParam = email ? email.replace('_', ' ') : ''; 

    try {
        const statsRes = await db.query(
            `SELECT 
                COUNT(*) FILTER (WHERE status NOT IN ('Pasif', 'Teslim Edildi', 'İptal Edildi', 'İptal')) as atanan,
                COUNT(*) FILTER (WHERE status IN ('Onaylandı', 'Tamirde')) as aktif,
                COUNT(*) FILTER (WHERE status = 'Parça Bekliyor') as parca_bekleyen,
                -- MÜDÜR: Onay bekleyenleri buradan saydırıp UI'ya gönderiyoruz
                COUNT(*) FILTER (WHERE status = 'Onay Bekliyor') as onay_bekleyen
             FROM services 
             WHERE TRIM(atanan_usta) ILIKE $1`, [`%${ustaParam}%`]
        );
        
        const sonIslerRes = await db.query(
            `SELECT 
                s.id, s.servis_no, s.issue_text as issue, s.status, 
                CONCAT(d.brand, ' ', d.model) as marka_model, d.cihaz_turu,
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as customer
             FROM services s
             LEFT JOIN devices d ON s.device_id = d.id
             LEFT JOIN customers c ON d.customer_id = c.id
             LEFT JOIN firms f ON d.firm_id = f.id
             WHERE TRIM(s.atanan_usta) ILIKE $1 
               AND s.status NOT IN ('Pasif', 'Teslim Edildi', 'İptal Edildi', 'İptal')
             ORDER BY s.id DESC LIMIT 2`, 
            [`%${ustaParam}%`]
        );

        res.json({
            success: true,
            data: {
                atanananIslerSayisi: parseInt(statsRes.rows[0].atanan) || 0,
                aktifIslerSayisi: parseInt(statsRes.rows[0].aktif) || 0,
                parcaBekleyenSayisi: parseInt(statsRes.rows[0].parca_bekleyen) || 0,
                onayBekleyenSayisi: parseInt(statsRes.rows[0].onay_bekleyen) || 0,
                randevuSayisi: 0,
                sonIsler: sonIslerRes.rows,
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- MÜDÜR: TÜM İŞLER LİSTESİ (MARKA-MODEL BİRLEŞTİRİLDİ) ---
router.post("/tum-isler", async (req, res) => {
    const { email } = req.body;
    const ustaParam = email ? email.replace('_', ' ') : '';

    try {
        const tumIslerRes = await db.query(
            `SELECT 
                s.id, s.servis_no, s.issue_text as issue, s.status, s.created_at,
                s.musteri_notu, 
                d.cihaz_turu, 
                CONCAT(d.brand, ' ', d.model) as marka_model, 
                d.serial_no as seri_no,
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as customer
             FROM services s
             LEFT JOIN devices d ON s.device_id = d.id
             LEFT JOIN customers c ON d.customer_id = c.id
             LEFT JOIN firms f ON d.firm_id = f.id
             WHERE TRIM(s.atanan_usta) ILIKE $1 
               AND (s.status NOT IN ('Pasif', 'Teslim Edildi', 'İptal Edildi', 'İptal') OR s.status IS NULL)
             ORDER BY s.id DESC`, 
            [`%${ustaParam}%`]
        );
        res.json({ success: true, data: tumIslerRes.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- MÜDÜR: PİNPON GÜNCELLEME (HİÇ DOKUNULMADI) ---
router.post("/servis-guncelle", async (req, res) => {
    const { id, offer_price, expert_note, status, changed_by, old_status } = req.body;
    try {
        await db.query(
            `UPDATE services SET offer_price = COALESCE($1, offer_price), expert_note = $2, status = $3, updated_at = NOW() WHERE id = $4`,
            [offer_price, expert_note, status, id]
        );
        await db.query(
            `INSERT INTO service_status_history (service_id, old_status, new_status, changed_by, note) VALUES ($1, $2, $3, $4, $5)`,
            [id, old_status, status, changed_by, expert_note]
        );
        res.json({ success: true, message: "İşlem tamam" });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;