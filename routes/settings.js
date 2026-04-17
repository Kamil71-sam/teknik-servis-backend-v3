const express = require('express');
const router = express.Router();
const db = require('../database');

// --- 1. TÜM AYARLARI GETİR ---
router.get('/', async (req, res) => {
    try {
        const result = await db.query("SELECT key_name, value_text FROM shop_settings");
        
        // Array'i ön yüzde kolay kullanmak için objeye (JSON) çeviriyoruz
        const settingsObj = {};
        result.rows.forEach(row => {
            settingsObj[row.key_name] = row.value_text;
        });

        res.json({ success: true, data: settingsObj });
    } catch (err) {
        console.error("Ayarları çekme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 2. AYARLARI GÜNCELLE ---
router.post('/update', async (req, res) => {
    const settings = req.body; // Gelen veri: { firma_adi: "...", firma_adres: "..." } vs.
    
    try {
        await db.query('BEGIN');
        
        // Gelen her bir ayar için döngüye girip veritabanına yazıyoruz
        for (const [key, value] of Object.entries(settings)) {
            // Önce bu ayar var mı diye bak (Hata vermemesi için en güvenli yöntem)
            const check = await db.query("SELECT id FROM shop_settings WHERE key_name = $1", [key]);
            
            if (check.rows.length > 0) {
                // Varsa Güncelle
                await db.query("UPDATE shop_settings SET value_text = $1 WHERE key_name = $2", [String(value), key]);
            } else {
                // Yoksa Yeni Ekle
                await db.query("INSERT INTO shop_settings (key_name, value_text) VALUES ($1, $2)", [key, String(value)]);
            }
        }
        
        await db.query('COMMIT');
        res.json({ success: true, message: 'Ayarlar başarıyla güncellendi.' });
    } catch (err) {
        await db.query('ROLLBACK');
        console.error("Ayar güncelleme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;