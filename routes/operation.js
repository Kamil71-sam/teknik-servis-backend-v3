const express = require('express');
const router = express.Router();
const db = require('../database'); // Veritabanı bağlantı yolun

// 1. BANKO: Yarınki Teyit Bekleyenleri Getir
router.get('/pending-confirmations', async (req, res) => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];

        const query = `
            SELECT a.id, a.servis_no, 
                   COALESCE(c.name, f.firma_adi, 'Bilinmeyen') as musteri_adi, 
                   a.appointment_time as saat, a.appointment_date as tarih
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.appointment_date = $1 
            AND a.is_confirmed = false 
            AND a.status NOT IN ('İptal', 'Pasif')
        `;
        const result = await db.query(query, [tomorrowStr]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// 2. BANKO: Randevu Teyit Et
router.patch('/confirm-appointment/:id', async (req, res) => {
    const { id } = req.params;
    try {
        await db.query('UPDATE appointments SET is_confirmed = true WHERE id = $1', [id]);
        res.json({ success: true, message: "Teyit alındı." });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// 3. USTA: Kendine Atanan İşleri Getir
router.get('/usta-jobs/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                COALESCE(c.name, f.firma_adi, 'Müşteri Bilgisi Yok') as musteri_adi, 
                a.appointment_date::text as tarih, 
                a.appointment_time::text as saat,
                a.issue_text as detay,
                a.status
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.assigned_usta = $1 
            AND a.status IN ('Beklemede', 'Devam Ediyor')
            ORDER BY a.appointment_date ASC, a.appointment_time ASC;
        `;
        const result = await db.query(query, [ustaName]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// 4. USTA: İşi Bitir (Fiyat ve Not Gir)
router.patch('/complete-job/:id', async (req, res) => {
    const { id } = req.params;
    const { price, usta_notu } = req.body;
    try {
        const query = `
            UPDATE appointments 
            SET price = $1, usta_notu = $2, status = 'Tamamlandı' 
            WHERE id = $3
        `;
        await db.query(query, [price, usta_notu, id]);
        res.json({ success: true, message: "İşlem kaydedildi." });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});


router.get('/usta-stats/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    
    // MÜDÜR: Terminale ilk sinyali çakıyoruz
    console.log("-----------------------------------------");
    console.log("🔍 DASHBOARD İSTEĞİ GELDİ!");
    console.log("👤 Sorgulanan Usta:", ustaName);

    try {
        const query = `
            SELECT 
                COUNT(*)::int as randevu_sayisi
            FROM appointments 
            WHERE assigned_usta = $1 
            AND status IN ('Beklemede', 'Devam Ediyor')
        `;
        const result = await db.query(query, [ustaName]);
        
        // MÜDÜR: SQL'den o an ne geliyorsa terminalde göreceğiz
        const count = result.rows[0].randevu_sayisi || 0;
        console.log("📊 SQL'DEN DÖNEN RAKAM:", count);
        console.log("-----------------------------------------");

        res.json({ 
            success: true, 
            stats: {
                randevu: count
            } 
        });
    } catch (err) {
        console.error("❌ BACKEND HATASI:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

/*
// 5. MÜDÜR: DASHBOARD İSTATİSTİKLERİNİ CANLANDIRAN YENİ DAMAR
router.get('/usta-stats/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    try {
        const query = `
            SELECT 
                COUNT(*)::int as randevu_sayisi
            FROM appointments 
            WHERE assigned_usta = $1 
            AND status IN ('Beklemede', 'Devam Ediyor')
        `;
        const result = await db.query(query, [ustaName]);
        
        // Mavi rakamı besleyecek veri burası müdürüm
        res.json({ 
            success: true, 
            stats: {
                randevu: result.rows[0].randevu_sayisi || 0
            } 
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

*/
module.exports = router;