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



/*

// --- 2. BANKO LİSTESİ (GET) ---
router.get('/all', async (req, res) => {
    // MÜDÜR: brand ve model sütunlarını birleştirip 'marka_model' takma adıyla çekiyoruz
    const query = `
        SELECT 
            mr.id, 
            mr.service_id,
            mr.part_name, 
            mr.quantity, 
            mr.description, 
            mr.status,
            mr.created_at,
            s.servis_no,
            (d.brand || ' ' || d.model) as marka_model
        FROM material_requests mr
        LEFT JOIN services s ON mr.service_id = s.id
        LEFT JOIN devices d ON s.device_id = d.id
        ORDER BY mr.created_at DESC
    `;

    try {
        const result = await db.query(query);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("MÜDÜR - Sorgu Hatası Detayı:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



*/





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


module.exports = router;