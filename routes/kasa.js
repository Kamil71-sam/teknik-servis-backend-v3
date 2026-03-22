const express = require('express');
const router = express.Router();
const db = require('../database'); 

// --- 1. KASA ÖZETİ VE LİSTESİ (Hatalı sütun kaldırıldı) ---
router.get('/all', async (req, res) => {
    try {
        const listeQuery = `
            SELECT 
                k.*,
                COALESCE(c.name, f.firma_adi) as musteri_adi,
                d.brand as marka,
                d.model as model
            FROM kasa_islemleri k
            LEFT JOIN services s ON k.servis_no = s.servis_no
            LEFT JOIN devices d ON s.device_id = d.id
            LEFT JOIN customers c ON s.customer_id = c.id
            LEFT JOIN firms f ON s.firm_id = f.id
            ORDER BY k.islem_tarihi DESC
        `;
        const listeResult = await db.query(listeQuery);

        const bakiyeQuery = `
            SELECT 
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' THEN tutar ELSE 0 END), 0) as toplam_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' THEN tutar ELSE 0 END), 0) as toplam_cikis
            FROM kasa_islemleri;
        `;
        const bakiyeResult = await db.query(bakiyeQuery);
        const hesap = bakiyeResult.rows[0];
        const net_bakiye = parseFloat(hesap.toplam_giris) - parseFloat(hesap.toplam_cikis);

        res.json({ 
            success: true, 
            data: listeResult.rows, 
            ozet: {
                toplam_giris: parseFloat(hesap.toplam_giris),
                toplam_cikis: parseFloat(hesap.toplam_cikis),
                net_bakiye: net_bakiye 
            }
        });
    } catch (err) {
        console.error("Kasa Listeleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 2. KASAYA İŞLEM EKLEME ---
router.post('/add', async (req, res) => {
    const { islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no } = req.body;
    try {
        const query = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *;
        `;
        const result = await db.query(query, [
            islem_yonu, kategori, tutar, aciklama, islem_yapan, 
            baglanti_id || null, 
            servis_no || null
        ]);
        res.json({ success: true, message: 'Kasa işlemi PG veritabanına mühürlendi.', data: result.rows[0] });
    } catch (err) {
        console.error("Kasa İşlem Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 3. CİHAZ ARAMA (Para Girişi Formundaki Radar İçin) ---
router.get('/search-service', async (req, res) => {
    const { servis_no } = req.query;
    try {
        const query = `
            SELECT 
                s.servis_no, 
                s.offer_price as fiyatTeklifi,
                d.brand as marka, 
                d.model, 
                d.serial_number as seriNo
            FROM services s
            LEFT JOIN devices d ON s.device_id = d.id
            WHERE s.servis_no = $1
        `;
        const result = await db.query(query, [servis_no]);
        if (result.rows.length > 0) {
            res.json({ success: true, found: true, device: result.rows[0] });
        } else {
            res.json({ success: true, found: false });
        }
    } catch (err) {
        console.error("Cihaz Arama Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;