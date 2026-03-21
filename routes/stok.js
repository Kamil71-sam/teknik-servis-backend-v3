const express = require('express');
const router = express.Router();
const db = require('../database'); // Müdürüm: Senin db bağlantı dosyanın yolu neyse ona göre ayarla

// --- 1. TÜM DEPOYU GETİR (Ana Ekrandaki Liste İçin) ---
router.get('/all', async (req, res) => {
    try {
        const result = await db.query("SELECT * FROM envanter ORDER BY son_guncelleme DESC");
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Depo listeleme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 2. STOK GİRİŞİ YAP (Tamamlama veya Bekleyen Parça) ---
router.post('/add', async (req, res) => {
    // request_id: Eğer Ustanın siparişi ise oradan gelen gizli numara
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id } = req.body;
    
    try {
        await db.query('BEGIN'); // ÇELİK KAPIYI KİLİTLE (Zincirleme işlem başlıyor)

        // A. Depoya Malı Ekle (ON CONFLICT zekası: Eğer aynı barkod zaten varsa, hata verme, sadece üstüne ekle!)
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

        // --- MÜDÜR: İŞTE O YENİ TETİK BURASI ---
        // B. Eğer Ustanın siparişi geldiyse Banko ekranı için ışıkları yak!
        if (request_id) {
            // 1. Bayrağı kaldır ve Statüyü Banko'nun göreceği şekilde değiştir
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            
            // 2. Sisteme Log düş (Siparişin bağlı olduğu servisi bulup log yazar)
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }
        // ----------------------------------------

        await db.query('COMMIT'); // İŞLEMLERİ ONAYLA VE KAPIYI AÇ
        res.json({ success: true, message: 'Stok başarıyla eklendi.', data: result.rows[0] });

    } catch (err) {
        await db.query('ROLLBACK'); // Hata çıkarsa hiçbir şeyi kaydetme, geriye sar!
        console.error("Stok Ekleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 3. BARKODLU STOK ÇIKIŞI VE KASA ENTEGRASYONU (Altın Vuruş) ---
router.post('/sell', async (req, res) => {
    // id: Malın depodaki numarası, barkod: Radarın okuduğu numara
    const { id, barkod, cikan_adet, satis_fiyati } = req.body;

    try {
        await db.query('BEGIN');

        // A. Depodan Düş
        const updateQuery = `
            UPDATE envanter 
            SET miktar = miktar - $1, son_guncelleme = CURRENT_TIMESTAMP 
            WHERE (id = $2 OR barkod = $3) AND miktar >= $1
            RETURNING malzeme_adi, miktar;
        `;
        const invResult = await db.query(updateQuery, [cikan_adet, id, barkod]);

        if (invResult.rows.length === 0) {
            throw new Error("Malzeme depoda bulunamadı veya yetersiz stok!");
        }

        const malzemeAdi = invResult.rows[0].malzeme_adi;

        await db.query('COMMIT');
        res.json({ success: true, message: 'Satış yapıldı, stoktan düşüldü ve kasaya işlendi.' });

    } catch (err) {
        await db.query('ROLLBACK');
        console.error("Stok Çıkış Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 4. AMELİYAT MASASI: SİLME VE GÜNCELLEME ---
router.delete('/delete/:id', async (req, res) => {
    try {
        await db.query("DELETE FROM envanter WHERE id = $1", [req.params.id]);
        res.json({ success: true, message: 'Stok kartı kalıcı olarak silindi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

router.put('/update/:id', async (req, res) => {
    const { malzeme_adi, marka, miktar } = req.body;
    try {
        await db.query(
            "UPDATE envanter SET malzeme_adi=$1, marka=$2, miktar=$3, son_guncelleme=CURRENT_TIMESTAMP WHERE id=$4",
            [malzeme_adi, marka, miktar, req.params.id]
        );
        res.json({ success: true, message: 'Stok kartı güncellendi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 5. AKILLI RADAR (Barkod veya İsimle Depoda Mal Arama) ---
router.get('/search', async (req, res) => {
    // Mobil bize ya barkod gönderecek ya da malzeme adı
    const { malzeme_adi, barkod } = req.query;
    
    try {
        let query = "";
        let values = [];

        if (barkod) {
            // Barkod okutulduysa direkt onu ara
            query = "SELECT * FROM envanter WHERE barkod = $1 LIMIT 1";
            values = [barkod];
        } else if (malzeme_adi) {
            // Ustanın siparişi seçildiyse isimden ara (ILIKE ile büyük/küçük harfe bakmadan)
            query = "SELECT * FROM envanter WHERE malzeme_adi ILIKE $1 LIMIT 1";
            values = [`%${malzeme_adi}%`];
        } else {
            return res.json({ success: false, message: 'Arama kriteri yok.' });
        }

        const result = await db.query(query, values);
        
        if (result.rows.length > 0) {
            // Malzeme bulundu! Alarmları yeşil yakacağız.
            res.json({ success: true, data: result.rows[0], found: true });
        } else {
            // Malzeme yok! Alarmları kırmızı yakacağız.
            res.json({ success: true, found: false });
        }
    } catch (err) {
        console.error("Radar Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



module.exports = router;