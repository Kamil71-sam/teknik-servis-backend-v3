const express = require('express');
const router = express.Router();
const db = require('../database'); 

// --- 1. TÜM DEPOYU GETİR ---
router.get('/all', async (req, res) => {
    try {
        const result = await db.query("SELECT * FROM envanter ORDER BY son_guncelleme DESC");
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Depo listeleme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 2. STOK GİRİŞİ YAP ---
router.post('/add', async (req, res) => {
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id } = req.body;
    try {
        await db.query('BEGIN');
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                alis_fiyati = EXCLUDED.alis_fiyati,
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati]);

        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }
        await db.query('COMMIT');
        res.json({ success: true, message: 'Stok başarıyla eklendi.', data: result.rows[0] });
    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});





router.post('/sell', async (req, res) => {
    const { id, barkod, cikan_adet, manual_discount } = req.body;

    try {
        await db.query('BEGIN');

        const invRes = await db.query("SELECT * FROM envanter WHERE id = $1 OR barkod = $2", [id, barkod]);
        if (invRes.rows.length === 0) throw new Error("Malzeme yok!");
        const mal = invRes.rows[0];

        const settingsRes = await db.query("SELECT * FROM shop_settings");
        const getSetting = (key) => parseFloat(settingsRes.rows.find(r => r.key_name === key)?.value_text || "0");

        // 1. Temel Değerler
        const birimAlis = parseFloat(mal.alis_fiyati || 0);
        const defaultKar = parseFloat(getSetting('profit_margin') || 20);
        const aktifKdv = parseFloat(getSetting('default_tax_rate') || 20);
        const indirimOrani = parseFloat(manual_discount || 0);

        let birimSatis = 0;
        let indirimNotu = indirimOrani > 0 ? ` (%${indirimOrani} İskonto)` : "";

        // --- 🚨 MÜDÜR: İŞTE O GERÇEK HESAP BURADA ---
        if (birimAlis > 0) {
            // İndirim SADECE kâr oranından düşer
            const netKarOrani = defaultKar - indirimOrani; 
            
            // Yeni Matrah = Alış + (Alış * Net Kâr)
            const matrah = birimAlis * (1 + (netKarOrani / 100));
            // KDV'yi de bu yeni matrah üstünden bin
            const kdvTutari = matrah * (aktifKdv / 100);
            birimSatis = matrah + kdvTutari;
        } else {
            // Eğer alış fiyatı hala sıfırsa, mecburen elle girilen fiyattan yüzde düşer (B planı)
            const eskiSatis = parseFloat(mal.satis_fiyati || 0);
            birimSatis = eskiSatis * (1 - (indirimOrani / 100));
        }

        const toplamTahsilat = birimSatis * parseInt(cikan_adet);

        // Stok düş ve Kasa işlemleri...
        await db.query("UPDATE envanter SET miktar = miktar - $1 WHERE id = $2", [cikan_adet, mal.id]);
        
        const kasaAciklama = `Stok Satışı: ${mal.malzeme_adi}${indirimNotu} | Alış: ${birimAlis} | Satış: ${birimSatis.toFixed(2)}`;
        await db.query(`INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                        VALUES ('GİRİŞ', 'Stok Satışı', $1, $2, 'Barkod Satış')`, 
                        [toplamTahsilat, kasaAciklama]);

        await db.query('COMMIT');
        res.json({ success: true, message: `Tahsilat: ${toplamTahsilat.toFixed(2)} TL` });

    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});



// --- 4. SİLME VE GÜNCELLEME ---
router.delete('/delete/:id', async (req, res) => {
    try {
        await db.query("DELETE FROM envanter WHERE id = $1", [req.params.id]);
        res.json({ success: true, message: 'Stok kartı silindi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

router.put('/update/:id', async (req, res) => {
    const { malzeme_adi, marka, miktar, alis_fiyati, barkod, uyumlu_cihaz } = req.body;
    try {
        await db.query(
            "UPDATE envanter SET malzeme_adi=$1, marka=$2, miktar=$3, alis_fiyati=$4, barkod=$5, uyumlu_cihaz=$6, son_guncelleme=CURRENT_TIMESTAMP WHERE id=$7",
            [malzeme_adi, marka, miktar, alis_fiyati, barkod, uyumlu_cihaz, req.params.id]
        );
        res.json({ success: true, message: 'Güncellendi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 5. AKILLI RADAR ---
router.get('/search', async (req, res) => {
    const { malzeme_adi, barkod } = req.query;
    try {
        let query = "";
        let values = [];
        if (barkod) {
            query = "SELECT * FROM envanter WHERE barkod = $1 LIMIT 1";
            values = [barkod];
        } else if (malzeme_adi) {
            query = "SELECT * FROM envanter WHERE malzeme_adi ILIKE $1 LIMIT 1";
            values = [`%${malzeme_adi}%`];
        }
        const result = await db.query(query, values);
        res.json({ success: true, data: result.rows[0], found: result.rows.length > 0 });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});



// --- MÜDÜR: ÜRÜN ÖZELİNDE FİYAT GEÇMİŞİNİ GETİR ---
router.get('/history/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await db.query(
            "SELECT * FROM price_history WHERE inventory_id = $1 ORDER BY degisim_tarihi DESC LIMIT 20",
            [id]
        );
        
        // Eğer veri varsa gönder, yoksa boş dizi gönder
        res.json({ 
            success: true, 
            data: result.rows 
        });
    } catch (err) {
        console.error("Geçmiş çekme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



module.exports = router;