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



/*
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
*/




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



/*
// --- KASA NAKİT GİRİŞİ (SADECE PARA HAREKETİ) ---
router.post('/add', async (req, res) => {
    // Mobil taraftan gelen paket: tutar, aciklama, islem_yapan, kategori
    const { kategori, tutar, aciklama, islem_yapan } = req.body;
    
    try {
        // Müdürüm, islem_yonu'nu biz burada 'GİRİŞ' olarak sabitliyoruz
        const query = `
            INSERT INTO kasa_islemleri (
                islem_yonu, 
                kategori, 
                tutar, 
                aciklama, 
                islem_yapan, 
                islem_tarihi
            )
            VALUES ('GİRİŞ', $1, $2, $3, $4, NOW())
            RETURNING *;
        `;
        
        const result = await db.query(query, [
            kategori || 'Kasaya Nakit Girişi', 
            tutar, 
            aciklama, 
            islem_yapan || 'Admin'
        ]);

        res.json({ 
            success: true, 
            message: 'Nakit girişi kasaya mühürlendi.', 
            data: result.rows[0] 
        });

    } catch (err) {
        console.error("Kasa Nakit Giriş Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});
*/
// --- KASAYA İŞLEM EKLEME VE STATÜ KAPATMA (TEK VE KESİN GÜÇ) ---
router.post('/add', async (req, res) => {
    // MÜDÜR: Bütün verileri tek bir yerde topladık
    const { islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no } = req.body;
    
    try {
        // 1. ADIM: Parayı Kasaya Mühürle
        const yon = islem_yonu || 'GİRİŞ'; 
        
        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no, islem_tarihi)
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
            RETURNING *;
        `;
        const result = await db.query(kasaQuery, [
            yon, 
            kategori || 'Kasaya Nakit Girişi', 
            tutar, 
            aciklama, 
            islem_yapan || 'Admin', 
            baglanti_id || null, 
            servis_no || null
        ]);

        // 2. ADIM: İŞTE HAYATİ DOKUNUŞ! 
        // Eğer bu para bir servis numarasından geldiyse, o işi 'Teslim Edildi' yapıyoruz.
        if (servis_no) {
            // Hem randevular tablosunu hem de servis tablosunu kapatıyoruz ki hiçbir yerde asılı kalmasın!
            await db.query(`UPDATE appointments SET status = 'Teslim Edildi' WHERE servis_no = $1`, [servis_no]);
            await db.query(`UPDATE services SET status = 'Teslim Edildi' WHERE servis_no = $1`, [servis_no]);
            
            console.log(`✅ [OTOMASYON] ${servis_no} nolu iş Teslim Edildi olarak kapatıldı!`);
        }

        res.json({ 
            success: true, 
            message: 'Para kasaya girdi ve iş ekrandan düşürüldü.', 
            data: result.rows[0] 
        });

    } catch (err) {
        console.error("Kasa İşlem Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});




module.exports = router;