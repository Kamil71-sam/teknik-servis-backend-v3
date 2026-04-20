const express = require('express');
const router = express.Router();
const db = require('../database'); 

// --- 1. USTANIN MALZEME TALEBİ GÖNDERMESİ (POST) ---
router.post('/add', async (req, res) => {
    const { service_id, usta_email, part_name, quantity, description } = req.body;
    
    const query = `
        INSERT INTO material_requests 
        (service_id, usta_email, part_name, quantity, description, status) 
        VALUES ($1, $2, $3, $4, $5, 'Beklemede')
        RETURNING id;
    `;

    try {
        const result = await db.query(query, [service_id, usta_email, part_name, quantity, description]);
        res.json({ success: true, message: 'Malzeme talebi başarıyla iletildi.', id: result.rows[0].id });
    } catch (err) {
        console.error("PG Talep hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});






// --- 2. BANKO LİSTESİ (KAYIT KAÇIRMAYAN SORGU) ---
router.get('/all', async (req, res) => {
    const query = `
        SELECT 
            mr.id, 
            mr.service_id,
            mr.part_name, 
            mr.quantity, 
            mr.description, 
            mr.status,
            mr.created_at,
            COALESCE(s.servis_no, 'Servis Yok') as servis_no,
            COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as marka_model
        FROM material_requests mr
        LEFT JOIN services s ON mr.service_id = s.id
        LEFT JOIN devices d ON s.device_id = d.id
        ORDER BY mr.created_at DESC
    `;

    try {
        const result = await db.query(query);
        // Banko ekranı veriyi 'data' içinde beklediği için böyle yolluyoruz
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("MÜDÜR - Banko Sorgu Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});







// --- YEDEK PARÇA TAKİBİ İÇİN ÖZEL KAPI (TAM KAPSAMLI FİYAT ÇEKİCİ) ---
router.get('/takip-listesi', async (req, res) => {
    try {
        const query = `
            SELECT 
                m.*, 
                s.servis_no AS gercek_servis_no, 
                -- 🚨 AĞI GENİŞLETTİK: Hem Servis tablosunda (offer_price) hem Randevu tablosunda (price) arıyoruz! Hangisi doluysa onu alır.
                COALESCE(s.offer_price, a.price, 0) AS teklif_fiyati,   
                e.alis_fiyati AS price,
                e.barkod AS barkod
            FROM material_requests m
            LEFT JOIN services s ON m.service_id = s.id
            -- 🚨 TİP UYUŞMAZLIĞINI ENGELLEMEK İÇİN İKİSİNİ DE TEXT'E ÇEVİREREK BAĞLADIK
            LEFT JOIN appointments a ON CAST(s.servis_no AS TEXT) = CAST(a.servis_no AS TEXT) 
            LEFT JOIN envanter e ON m.part_name = e.malzeme_adi
            ORDER BY m.id DESC
        `;
        
        const result = await db.query(query);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Takip listesi çekilirken hata:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});













// --- 3. AKILLI DURUM GÜNCELLEME VE LOG SİSTEMİ (PUT) ---
router.put('/update-status/:id', async (req, res) => {
    const { id } = req.params;
    const { status, user_name } = req.body; 

    try {
        const findReq = await db.query("SELECT service_id, part_name FROM material_requests WHERE id = $1", [id]);
        
        if (findReq.rows.length === 0) {
            return res.status(404).json({ success: false, message: "Talep bulunamadı." });
        }

        const service_id = findReq.rows[0].service_id;
        const part_name = findReq.rows[0].part_name;

        // --- TRANSACTION BAŞLAT ---
        await db.query('BEGIN'); 

        // ADIM A: Parça talebini güncelle
        await db.query("UPDATE material_requests SET status = $1 WHERE id = $2", [status, id]);



        if (status === 'Geldi') {
            
            // 🚨 MÜDÜR: ÇIRAK ARTIK BURADA SAYIM YAPIYOR!
            // Bu cihaza ait 'Geldi', 'İptal' veya 'Reddedildi' OLMAYAN (yani hala bekleyen) başka parça var mı?
            const checkOthers = await db.query(`
                SELECT COUNT(*) FROM material_requests 
                WHERE service_id = $1 AND status NOT IN ('Geldi', 'İptal', 'Reddedildi')
            `, [service_id]);

            const kalanParcaSayisi = parseInt(checkOthers.rows[0].count);

            if (kalanParcaSayisi === 0) {
                // ADIM B1: Bekleyen BAŞKA parça kalmadıysa (hepsi geldiyse), o zaman Tamirde yap!
                await db.query("UPDATE services SET status = 'Tamirde' WHERE id = $1", [service_id]);

                // ADIM C1: Eksiksiz Teslim Logu
                const logNote = `${user_name}: ${part_name} teslim alındı. Cihazın bekleyen tüm parçaları tamamlandı, otomatik 'Tamirde' moduna çekildi.`;
                await db.query("INSERT INTO service_notes (service_id, note_text) VALUES ($1, $2)", [service_id, logNote]);
            } else {
                // ADIM B2: Hala bekleyen parça varsa, cihazın ana statüsüne DOKUNMA! Sadece log at.
                const logNote = `${user_name}: ${part_name} teslim alındı. (Hala bekleyen ${kalanParcaSayisi} adet farklı parça var. Cihaz beklemeye devam ediyor).`;
                await db.query("INSERT INTO service_notes (service_id, note_text) VALUES ($1, $2)", [service_id, logNote]);
            }
        }

        await db.query('COMMIT'); 
        res.json({ success: true, message: 'Parça ve Servis durumu güncellendi, log yazıldı.' });

    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("MÜDÜR - Zincirleme İşlem Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});













        /*


        if (status === 'Geldi') {
            // ADIM B: Servis kaydını otomatik 'Tamirde'ye çek
            await db.query("UPDATE services SET status = 'Tamirde' WHERE id = $1", [service_id]);

            // ADIM C: Senin tablo şemana (note_text) uygun log kaydı
            // Müdür: Şemanda 'note' yok 'note_text' var, onu düzelttim.
            const logNote = `${user_name}: ${part_name} teslim alındı. Cihaz otomatik 'Tamirde' moduna çekildi.`;
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                VALUES ($1, $2)
            `;
            await db.query(logQuery, [service_id, logNote]);
        }


        await db.query('COMMIT'); 
        res.json({ success: true, message: 'Parça ve Servis durumu güncellendi, log yazıldı.' });

    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("MÜDÜR - Zincirleme İşlem Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});


*/










// --- MÜDÜR: MOBİLİN HİÇBİR ŞEKİLDE 404 ALMAMASI İÇİN YEDEK ROTA ---
router.get('/', async (req, res) => {
    // Mobil uygulama /api/material-requests adresine direkt vurursa burası çalışır
    const query = `
        SELECT mr.id, mr.part_name as material_name, mr.quantity, 
        (d.brand || ' ' || d.model) as device_model
        FROM material_requests mr
        LEFT JOIN services s ON mr.service_id = s.id
        LEFT JOIN devices d ON s.device_id = d.id
        WHERE mr.status != 'Geldi'
        ORDER BY mr.created_at DESC
    `;
    try {
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        res.status(200).json([]); // Hata olsa bile 404 vermez, boş liste döner.
    }
});





// --- MÜDÜR: MOBİL STOK GİRİŞİ İÇİN KESİN ÇÖZÜM SORGUSU (USTA NOTU EKLENMİŞ HALİ) ---
router.get('/pending', async (req, res) => {
    const query = `
        SELECT 
            mr.id, 
            mr.part_name as material_name, 
            mr.quantity, 
            mr.description, -- 🚨 İŞTE USTANIN GİRDİĞİ O KRİTİK BİLGİ NOTU!
            COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as device_model,
            mr.stok_girisi_yapildi_mi 
        FROM material_requests mr
        LEFT JOIN services s ON mr.service_id = s.id
        LEFT JOIN devices d ON s.device_id = d.id
        WHERE mr.status != 'Geldi' 
          AND (mr.stok_girisi_yapildi_mi IS FALSE OR mr.stok_girisi_yapildi_mi IS NULL)
        ORDER BY mr.created_at DESC;
    `;

    try {
        const result = await db.query(query);
        res.json(result.rows || []); 
    } catch (err) {
        console.error("MÜDÜR - SQL Sorgu Hatası:", err.message);
        res.status(200).json([]); 
    }
});



// =================================================================
// 🚨 MÜDÜR: PATRON İÇİN PARÇA İPTAL ETME (SİLME) KAPISI 🚨
// =================================================================
router.delete('/sil/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await db.query("DELETE FROM material_requests WHERE id = $1", [id]);
        res.json({ success: true, message: 'Parça başarıyla silindi.' });
    } catch (err) {
        console.error("Silme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// =================================================================
// 🚨 MÜDÜR: PATRON İÇİN ADET, NOT VE FİYAT GÜNCELLEME KAPISI 🚨
// =================================================================
router.put('/guncelle/:id', async (req, res) => {
    const { id } = req.params;
    const { quantity, description, price, part_name } = req.body;

    try {
        await db.query('BEGIN'); // Zincirleme işlem başlat

        // 1. Adeti ve notu material_requests tablosunda güncelle
        await db.query(
            "UPDATE material_requests SET quantity = $1, description = $2 WHERE id = $3",
            [quantity, description, id]
        );

        // 2. FİYAT GÜNCELLEMESİ (Çok Kritik!)
        // Müdürüm: Fiyat material_requests tablosunda tutulmuyor, 'envanter'den çekiliyor.
        // O yüzden fiyatı değiştirince, envanterdeki (depodaki) 'alis_fiyati' güncellenecek.
        if (price !== undefined && part_name) {
            await db.query(
                "UPDATE envanter SET alis_fiyati = $1 WHERE malzeme_adi = $2",
                [price, part_name]
            );
        }

        await db.query('COMMIT');
        res.json({ success: true, message: 'Parça ve fiyat güncellendi.' });
    } catch (err) {
        await db.query('ROLLBACK'); // Hata olursa geri al
        console.error("Güncelleme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});









module.exports = router;