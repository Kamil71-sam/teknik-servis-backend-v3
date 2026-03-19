const express = require('express');
const router = express.Router();
const db = require('../db'); // Veritabanı bağlantı yolun

// 1. BANKO: Yarınki Teyit Bekleyenleri Getir
router.get('/pending-confirmations', async (req, res) => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];

        const query = `
            SELECT a.id, a.servis_no, 
                   COALESCE(c.name, f.firma_adi) as musterı, 
                   a.appointment_time, a.appointment_date
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

// 3. USTA: Kendine Atanan ve Teyitli İşleri Getir
router.get('/usta-jobs/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    try {
        const query = `
            SELECT a.*, COALESCE(c.name, f.firma_adi) as musterı, 
                   COALESCE(c.phone, f.yetkili_telefon) as telefon
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.assigned_usta = $1 
            AND a.is_confirmed = true 
            AND a.status NOT IN ('Tamamlandı', 'İptal')
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

module.exports = router;