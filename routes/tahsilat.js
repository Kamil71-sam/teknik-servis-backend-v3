const express = require('express');
const router = express.Router();
const db = require('../database');

// --- MÜDÜRÜN ZIRHLI TAHSİLAT VANASI ---
router.post('/process', async (req, res) => {
    const { id, servis_no, kategori, tutar, aciklama, islem_yapan, new_status } = req.body;

    try {
        await db.query('BEGIN'); // Zinciri başlat (Hata olursa geri sarar)

        // 1. Kasa Kaydı (Mühürleme)
        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
            VALUES ('GİRİŞ', $1, $2, $3, $4, $5, $6)
        `;
        await db.query(kasaQuery, [kategori, tutar, aciklama, islem_yapan, id, servis_no]);

        // 2. Servis Statü Güncelleme (Teslim Edildi/Arşiv)
        const updateQuery = `UPDATE services SET status = $1, updated_at = NOW() WHERE id = $2`;
        await db.query(updateQuery, [new_status, id]);

        await db.query('COMMIT'); // Hepsini mühürle
        res.json({ success: true, message: "Tahsilat yapıldı ve kayıt arşivlendi." });

    } catch (err) {
        await db.query('ROLLBACK'); // Hata varsa her şeyi iptal et (Kasa şişmesin)
        console.error("Tahsilat Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;