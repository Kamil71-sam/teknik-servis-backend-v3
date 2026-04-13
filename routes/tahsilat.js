
const express = require('express');
const router = express.Router();
const db = require('../database');

// --- MÜDÜRÜN ZIRHLI TAHSİLAT VANASI ---
router.post('/process', async (req, res) => {
    const { id, servis_no, kategori, tutar, aciklama, islem_yapan, new_status } = req.body;

    try {
        // 🛡️ ANA MOTOR KALKANI 🛡️
        if (id) {
            // 🚨 MÜDÜRÜM: ILIKE komutunu çöpe attık, '=', yani kesin eşleşme getirdik!
            const pQuery = `
                SELECT SUM(mr.quantity * COALESCE(e.alis_fiyati, 0)) as toplam_maliyet
                FROM material_requests mr
                LEFT JOIN envanter e ON mr.part_name = e.malzeme_adi
                WHERE mr.service_id = $1
            `;
            const pResult = await db.query(pQuery, [id]);
            const maliyet = parseFloat(pResult.rows[0].toplam_maliyet || 0);
            const girilenTutar = parseFloat(tutar || 0);
            
            // 💰 PATRON TİCARİ KURALI (%25 Kar + %20 KDV) = Maliyet x 1.50
            const olmasiGerekenTutar = maliyet * 1.50;

            // 🚨 ZARARINA İŞLEMSE VERİTABANINI KİLİTLE VE İŞLEMİ REDDET!
            if (maliyet > girilenTutar) {
                return res.status(400).json({ 
                    success: false, 
                    error: `🚨 SİSTEM REDDETTİ!\n\nTahsil Etmek İstediğiniz: ${girilenTutar.toFixed(2)} ₺\nGerçek Parça Maliyeti: ${maliyet.toFixed(2)} ₺\nSistem Hedefi (%25 Kâr+%20 KDV): ${olmasiGerekenTutar.toFixed(2)} ₺\n\nBu işlem dükkanı zarara soktuğu için kasa girişi YAPILAMAZ ve cihaz 'Teslim Edildi' yapılamaz!` 
                });
            }
        }

        // Kalkanı geçtiyse işlemi başlat
        await db.query('BEGIN'); 

        // 1. Kasa Kaydı
        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
            VALUES ('GİRİŞ', $1, $2, $3, $4, $5, $6)
        `;
        await db.query(kasaQuery, [kategori, tutar, aciklama, islem_yapan, id, servis_no]);

        // 2. Servis Statü Güncelleme
        const updateQuery = `UPDATE services SET status = $1, updated_at = NOW() WHERE id = $2`;
        await db.query(updateQuery, [new_status, id]);

        await db.query('COMMIT'); 
        res.json({ success: true, message: "Tahsilat yapıldı ve kayıt arşivlendi." });

    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("Tahsilat Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- BANKO TAHSİLAT ---
router.post('/banko-tahsilat', async (req, res) => {
    const { id, servis_no, kategori, tutar, aciklama, islem_yapan, new_status } = req.body;

    try {
        await db.query('BEGIN'); 

        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
            VALUES ('GİRİŞ', $1, $2, $3, $4, $5, $6)
        `;
        await db.query(kasaQuery, [kategori, tutar, aciklama, islem_yapan, id, servis_no]);

        const updateAppQuery = `
            UPDATE appointments 
            SET status = $1 
            WHERE servis_no = $2 AND appointment_date >= '2020-08-01'
        `;
        await db.query(updateAppQuery, [new_status, servis_no]);

        await db.query('COMMIT'); 
        res.json({ success: true, message: "Banko tahsilatı yapıldı, randevu kapatıldı." });

    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("Banko Tahsilat Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;











/* 130426 1502
const express = require('express');
const router = express.Router();
const db = require('../database');

// --- MÜDÜRÜN ZIRHLI TAHSİLAT VANASI ---
router.post('/process', async (req, res) => {
    const { id, servis_no, kategori, tutar, aciklama, islem_yapan, new_status } = req.body;

    try {
        // 🛡️ ANA MOTOR KALKANI (KASAYA GİRMEDEN ÖNCE BURAYA TOSLAR) 🛡️
        if (id) {
            // Taktığı parçaların GÜNCEL ALIŞ MALİYETİNİ (Depodan) topla
            const pQuery = `
                SELECT SUM(mr.quantity * COALESCE(e.alis_fiyati, 0)) as toplam_maliyet
                FROM material_requests mr
                LEFT JOIN envanter e ON TRIM(mr.part_name) ILIKE '%' || TRIM(e.malzeme_adi) || '%'
                WHERE mr.service_id = $1
            `;
            const pResult = await db.query(pQuery, [id]);
            const maliyet = parseFloat(pResult.rows[0].toplam_maliyet || 0);
            const girilenTutar = parseFloat(tutar || 0);

            // 🚨 ZARARINA İŞLEMSE VERİTABANINI KİLİTLE VE İŞLEMİ REDDET!
            if (maliyet > girilenTutar) {
                return res.status(400).json({ 
                    success: false, 
                    error: `🚨 SİSTEM REDDETTİ!\n\nTahsil Etmek İstediğiniz: ${girilenTutar.toFixed(2)} ₺\nKullanılan Parça Maliyeti: ${maliyet.toFixed(2)} ₺\n\nBu işlem dükkanı zarara soktuğu için kasa girişi YAPILAMAZ ve cihaz 'Teslim Edildi' yapılamaz!` 
                });
            }
        }

        // Kalkanı geçtiyse işlemi başlat
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


// --- MÜDÜR: YENİ VE İZOLE KAPI (SADECE BANKO RANDEVULARINI KAPATIR) ---
router.post('/banko-tahsilat', async (req, res) => {
    const { id, servis_no, kategori, tutar, aciklama, islem_yapan, new_status } = req.body;

    try {
        await db.query('BEGIN'); 

        // 1. Kasa Kaydı (Sistemle aynı)
        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no)
            VALUES ('GİRİŞ', $1, $2, $3, $4, $5, $6)
        `;
        await db.query(kasaQuery, [kategori, tutar, aciklama, islem_yapan, id, servis_no]);

        // 2. SADECE RANDEVULAR TABLOSUNU KAPATIR (Eski sistemi bozmaz!)
        const updateAppQuery = `
            UPDATE appointments 
            SET status = $1 
            WHERE servis_no = $2 AND appointment_date >= '2020-08-01'
        `;
        await db.query(updateAppQuery, [new_status, servis_no]);

        await db.query('COMMIT'); 
        res.json({ success: true, message: "Banko tahsilatı yapıldı, randevu kapatıldı." });

    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("Banko Tahsilat Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;


*/