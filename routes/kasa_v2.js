

const express = require('express');
const router = express.Router();
const db = require('../database');

router.get('/search-v2', async (req, res) => {
    const { servis_no } = req.query;
    
    try {
        const query = `
            SELECT 
                s.id,
                s.servis_no AS "servis_no",
                COALESCE(f.firma_adi, m.name, 'Bilinmeyen Müşteri') AS "musteri_adi",
                d.cihaz_turu AS "cihaz_turu",
                d.brand AS "marka",
                d.model AS "model",
                s.status AS "status",
                -- 🚨 MÜDÜRÜM: Fiyatı artık hem Servis'ten hem Randevu'dan (Hangisi doluysa) çekiyoruz!
                COALESCE(s.offer_price, a.price, 0) AS "fiyatTeklifi"
            FROM services s
            LEFT JOIN devices d ON s.device_id = d.id
            LEFT JOIN customers m ON s.customer_id = m.id
            LEFT JOIN firms f ON s.firm_id = f.id 
            -- 🚨 KÖPRÜYÜ BURAYA DA KURDUK
            LEFT JOIN appointments a ON CAST(s.servis_no AS TEXT) = CAST(a.servis_no AS TEXT)
            WHERE s.servis_no = $1 
              AND (s.status ILIKE 'Hazır' OR s.status ILIKE 'hazir')
            LIMIT 1
        `;
        
        const v2Result = await db.query(query, [servis_no]);
        console.log("Müdürüm Veritabanından Gelen Ham Veri:", v2Result.rows[0]);

        if (v2Result.rows.length > 0) {
            res.json({ success: true, found: true, device: v2Result.rows[0] });
        } else {
            res.json({ success: true, found: false, message: "Cihaz hazır statüsünde değil veya bulunamadı." });
        }
    } catch (err) {
        console.error("V2 Sorgu Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;








/* 130426 1503
const express = require('express');
const router = express.Router();
const db = require('../database');

router.get('/search-v2', async (req, res) => {
    const { servis_no } = req.query;
    
    try {

const query = `
    SELECT 
        s.id,
        s.servis_no AS "servis_no",
        -- MÜDÜR: Firma bağlantısı artık doğrudan 'services' tablosu üzerinden yapılıyor:
        COALESCE(f.firma_adi, m.name, 'Bilinmeyen Müşteri') AS "musteri_adi",
        d.cihaz_turu AS "cihaz_turu",
        d.brand AS "marka",
        d.model AS "model",
        s.status AS "status",
        s.offer_price AS "fiyatTeklifi"
    FROM services s
    LEFT JOIN devices d ON s.device_id = d.id
    -- MÜDÜR: Müşteri adı için bağlantı (m.name kullanıldı, senin tablonda 'name' yazıyor)
    LEFT JOIN customers m ON s.customer_id = m.id
    -- MÜDÜR: Firma adı için bağlantı (DOĞRUDAN s.firm_id üzerinden!)
    LEFT JOIN firms f ON s.firm_id = f.id 
    WHERE s.servis_no = $1 
      AND (s.status ILIKE 'Hazır' OR s.status ILIKE 'hazir')
    LIMIT 1
`;

     
        const v2Result = await db.query(query, [servis_no]);
        console.log("Müdürüm Veritabanından Gelen Ham Veri:", v2Result.rows[0]);

        if (v2Result.rows.length > 0) {
            res.json({ success: true, found: true, device: v2Result.rows[0] });
        } else {
            res.json({ success: true, found: false, message: "Cihaz hazır statüsünde değil veya bulunamadı." });
        }
    } catch (err) {
        console.error("V2 Sorgu Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;

*/